import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

final _pool = Pool(4);

const int _maxPreviewBytes = 20 * 1024 * 1024;

void _log(String msg) => debugPrint('[MediaPreview] $msg');


Future<Uint8List?> getEmbeddedJpeg(String filePath) =>
    _pool.withResource(() => extractEmbeddedPreview(filePath));

Future<Uint8List?> extractEmbeddedPreview(String filePath) {

  final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
  _log('extractEmbeddedPreview: $filePath  (ext=$ext)');
  return switch (ext) {
    'arw' || 'cr2' || 'cr3' || 'nef' || 'nrw' ||
    'rw2' || 'orf' || 'dng' || 'raf' || 'pef' =>
      _extractRawPreview(filePath),
    'mp4' || 'mov' || 'm4v' || 'mts' || 'm2ts' =>
      _extractVideoThumbnail(filePath),
    _ => () {
        _log('SKIP: unsupported extension "$ext"');
        return Future.value(null);
      }(),
  };
}

Future<Uint8List?> _extractRawPreview(String filePath) async {
  _log('RAW path: librawAvailable=${_LibRaw.available}');

  if (_LibRaw.available) {
    _log('Trying LibRaw FFI…');
    final result = await compute(_librawExtractThumb, filePath);
    if (result != null) {
      _log('LibRaw OK: ${result.length} bytes');
      return result;
    }
    _log('LibRaw returned null — falling back to TIFF walker');
  } else {
    _log('LibRaw not available — using TIFF walker directly');
  }

  return _extractTiffPreview(filePath);
}

// LibRaw FFI

Uint8List? _librawExtractThumb(String filePath) {
  final libraw = _LibRaw._instance;
  if (libraw == null) {
    debugPrint('[MediaPreview] _librawExtractThumb: _instance is null');
    return null;
  }

  final pathPtr = filePath.toNativeUtf8();
  final outLenPtr = calloc<Int32>();
  Pointer<Uint8> dataPtr = nullptr;
  try {
    dataPtr = libraw.extractThumb(pathPtr, outLenPtr);
    final outLen = outLenPtr.value;
    debugPrint('[MediaPreview] LibRaw native call: dataPtr=$dataPtr outLen=$outLen');
    if (dataPtr == nullptr || outLen <= 0) return null;

    final bytes = Uint8List.fromList(dataPtr.asTypedList(outLen));
    final isJpeg = _isJpeg(bytes);
    final isLossless = isJpeg && _isLosslessJpeg(bytes);
    debugPrint('[MediaPreview] LibRaw bytes: isJpeg=$isJpeg isLossless=$isLossless');
    if (!isJpeg || isLossless) return null;
    return bytes;
  } finally {
    calloc.free(outLenPtr);
    if (dataPtr != nullptr) libraw.freeBuffer(dataPtr);
    calloc.free(pathPtr);
  }
}

typedef _ExtractThumbNative = Pointer<Uint8> Function(
    Pointer<Utf8> path, Pointer<Int32> outLen);
typedef _ExtractThumbDart = Pointer<Uint8> Function(
    Pointer<Utf8> path, Pointer<Int32> outLen);
typedef _FreeBufferNative = Void Function(Pointer<Uint8> buf);
typedef _FreeBufferDart = void Function(Pointer<Uint8> buf);

class _LibRaw {
  _LibRaw._(DynamicLibrary lib)
      : extractThumb =
            lib.lookupFunction<_ExtractThumbNative, _ExtractThumbDart>(
                'libraw_flutter_extract_thumb'),
        freeBuffer = lib.lookupFunction<_FreeBufferNative, _FreeBufferDart>(
            'libraw_flutter_free_buffer');

  final _ExtractThumbDart extractThumb;
  final _FreeBufferDart freeBuffer;

  static _LibRaw? __instance;
  static bool _checked = false;

  static bool get available {
    _resolve();
    return __instance != null;
  }

  static _LibRaw? get _instance {
    _resolve();
    return __instance;
  }
  static void _resolve() {
    if (_checked) return;
    _checked = true;
    try {
      final lib = Platform.isAndroid
          ? DynamicLibrary.open('libraw_flutter.so')
          : DynamicLibrary.process();
      __instance = _LibRaw._(lib);
      debugPrint('[MediaPreview] LibRaw native library loaded OK');
    } catch (e) {
      debugPrint('[MediaPreview] LibRaw not available: $e');
    }
  }
}

Future<Uint8List?> _extractTiffPreview(String filePath) async {
  _log('TIFF walker start: $filePath');
  final file = File(filePath);

  if (!await file.exists()) {
    _log('TIFF walker ABORT: file does not exist');
    return null;
  }

  final fileSize = await file.length();
  _log('TIFF walker: fileSize=$fileSize');

  final raf = await file.open();
  try {
    final tiffHdr = await raf.read(8);
    if (tiffHdr.length < 8) {
      _log('TIFF walker ABORT: header too short (${tiffHdr.length} bytes)');
      return null;
    }

    final le = tiffHdr[0] == 0x49 && tiffHdr[1] == 0x49;
    _log('TIFF walker: byteOrder=${le ? "LE" : "BE"}');

    if (!le && !(tiffHdr[0] == 0x4D && tiffHdr[1] == 0x4D)) {
      _log('TIFF walker ABORT: not a TIFF byte-order mark');
      return null;
    }

    int u16(Uint8List b, int o) =>
        le ? b[o] | (b[o + 1] << 8) : (b[o] << 8) | b[o + 1];
    int u32(Uint8List b, int o) => le
        ? b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)
        : (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

    final magic = u16(tiffHdr, 2);
    if (magic != 42) {
      _log('TIFF walker ABORT: wrong magic ($magic)');
      return null;
    }

    int typedValue(Uint8List entries, int p) {
      final type = u16(entries, p + 2);
      if (type == 3 /* SHORT */) {
        return le
            ? entries[p + 8] | (entries[p + 9] << 8)
            : (entries[p + 10] << 8) | entries[p + 11];
      }
      return u32(entries, p + 8);
    }

    Future<Uint8List> readAt(int pos, int len) async {
      await raf.setPosition(pos);
      return raf.read(len);
    }

    int? explicitOffset;
    int explicitLen = 0;
    int? stripOffset;
    int stripBestLen = 0;

    int ifdOff = u32(tiffHdr, 4);
    int ifdIndex = 0;

    _log('TIFF walker: first IFD offset=0x${ifdOff.toRadixString(16)}');

    while (ifdOff != 0 && ifdOff < fileSize - 2) {
      _log('TIFF walker: --- IFD$ifdIndex @ 0x${ifdOff.toRadixString(16)} ---');

      final countBuf = await readAt(ifdOff, 2);
      if (countBuf.length < 2) {
        _log('TIFF walker: cannot read entry count — stop');
        break;
      }
      final count = u16(countBuf, 0);
      if (count == 0 || count > 512) {
        _log('TIFF walker: unreasonable count ($count) — stop');
        break;
      }

      final entries = await readAt(ifdOff + 2, count * 12);
      if (entries.length < count * 12) {
        _log('TIFF walker: entries buffer short — stop');
        break;
      }

      int jpegOff = 0, jpegLen = 0;
      int sOff = 0, sLen = 0, sCount = 1;
      int compression = 0;

      for (int i = 0; i < count; i++) {
        final ep = i * 12;
        final tag = u16(entries, ep);
        final type = u16(entries, ep + 2);
        final entryCount = u32(entries, ep + 4);
        final rawValue = u32(entries, ep + 8);
        final typedVal = typedValue(entries, ep);
        _log('  tag=0x${tag.toRadixString(16).padLeft(4, "0")} '
            'type=$type count=$entryCount '
            'rawVal=0x${rawValue.toRadixString(16)} typedVal=$typedVal');
        switch (tag) {
          case 0x0103: compression = typedVal;
          case 0x0111: sOff = rawValue; sCount = entryCount;
          case 0x0117: sLen = typedVal;
          case 0x0201: jpegOff = rawValue;
          case 0x0202: jpegLen = rawValue;
        }
      }

      _log('TIFF walker: IFD$ifdIndex summary — compression=$compression '
          'jpegOff=0x${jpegOff.toRadixString(16)} jpegLen=$jpegLen '
          'stripOff=0x${sOff.toRadixString(16)} stripLen=$sLen stripCount=$sCount');

      // ── 1. Explicit JPEG block (highest priority) ──
      if (jpegOff > 0 && jpegLen > 0 &&
          jpegLen <= _maxPreviewBytes && jpegLen > explicitLen &&
          jpegOff + jpegLen <= fileSize) {
        _log('TIFF walker: IFD$ifdIndex → explicit JPEG candidate '
            'offset=0x${jpegOff.toRadixString(16)} len=$jpegLen');
        explicitOffset = jpegOff;
        explicitLen = jpegLen;
      }

      if (ifdIndex > 0 && compression == 6 &&
          sOff > 0 && sLen > 0 &&
          sLen <= _maxPreviewBytes && sLen > stripBestLen) {
        int resolvedOff = sOff;
        if (sCount > 1) {
          final arr = await readAt(sOff, 4);
          if (arr.length >= 4) resolvedOff = u32(arr, 0);
          _log('TIFF walker: IFD$ifdIndex multi-strip resolved → '
              '0x${resolvedOff.toRadixString(16)}');
        }
        if (resolvedOff > 0 && resolvedOff + sLen <= fileSize) {
          _log('TIFF walker: IFD$ifdIndex → strip JPEG candidate '
              'offset=0x${resolvedOff.toRadixString(16)} len=$sLen');
          stripOffset = resolvedOff;
          stripBestLen = sLen;
        } else {
          _log('TIFF walker: IFD$ifdIndex strip REJECTED — out of bounds '
              '(off=0x${resolvedOff.toRadixString(16)} len=$sLen fileSize=$fileSize)');
        }
      }

      final nextBuf = await readAt(ifdOff + 2 + count * 12, 4);
      if (nextBuf.length < 4) {
        _log('TIFF walker: cannot read next IFD pointer — stop');
        break;
      }
      ifdOff = u32(nextBuf, 0);
      _log('TIFF walker: next IFD offset=0x${ifdOff.toRadixString(16)}');
      ifdIndex++;
    }

    final int? bestOffset;
    final int bestLen;
    if (explicitOffset != null) {
      bestOffset = explicitOffset;
      bestLen = explicitLen;
      _log('TIFF walker: using explicit JPEG '
          'offset=0x${bestOffset.toRadixString(16)} len=$bestLen');
    } else if (stripOffset != null) {
      bestOffset = stripOffset;
      bestLen = stripBestLen;
      _log('TIFF walker: no explicit JPEG found, using strip fallback '
          'offset=0x${bestOffset.toRadixString(16)} len=$bestLen');
    } else {
      _log('TIFF walker RESULT: null — no candidate found in any IFD');
      return null;
    }

    if (bestOffset + bestLen > fileSize) {
      _log('TIFF walker RESULT: null — best candidate out of bounds '
          '(offset=0x${bestOffset.toRadixString(16)} len=$bestLen fileSize=$fileSize)');
      return null;
    }

    await raf.setPosition(bestOffset);
    final data = await raf.read(bestLen);
    _log('TIFF walker: read ${data.length} bytes');

    final isJpeg = _isJpeg(data);
    final isLossless = isJpeg && _isLosslessJpeg(data);
    _log('TIFF walker: isJpeg=$isJpeg isLossless=$isLossless');

    if (!isJpeg) {
      _log('TIFF walker RESULT: null — not a JPEG '
          '(first bytes: ${data.take(4).map((b) => '0x${b.toRadixString(16)}').join(' ')})');
      return null;
    }
    if (isLossless) {
      _log('TIFF walker RESULT: null — lossless JPEG, not renderable');
      return null;
    }

    _log('TIFF walker RESULT: OK — ${data.length} bytes');
    return data;
  } catch (e, st) {
    _log('TIFF walker EXCEPTION: $e\n$st');
    return null;
  } finally {
    await raf.close();
  }
}

Future<Uint8List?> _extractVideoThumbnail(String filePath) async {
  try {
    final bytes = await FlutterVideoThumbnailPlus.thumbnailData(
      video: filePath,
      imageFormat: ImageFormat.jpeg,
      maxWidth: 400,
      timeMs: 1000,
      quality: 60,
    );
    if (bytes == null || bytes.isEmpty) {
      _log('Video thumbnail: no thumbnail generated');
      return null;
    }
    return bytes;
  } catch (e) {
    _log('Video thumbnail: error generating thumbnail — $e');
    return null;
  }
}

bool _isJpeg(Uint8List data) =>
    data.length > 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF;

bool _isLosslessJpeg(Uint8List data) {
  final limit = data.length.clamp(0, 65536);
  for (int i = 0; i < limit - 1; i++) {
    if (data[i] != 0xFF) continue;
    final marker = data[i + 1];
    if (marker == 0xC3 || marker == 0xC7 || marker == 0xF7) return true;
    if (marker == 0xDA) break; // SOS — no lossless SOF found, accept
  }
  return false;
}