import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:photo_sync/services/api_service.dart';
import 'package:win32/win32.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:exif/exif.dart';

List<String> getWindowsDrives() {
  final drives = <String>[];
  for (var letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
    final drive = Directory('$letter:\\');
    if (drive.existsSync()) {
      drives.add('$letter:\\');
    }
  }
  return drives;
}

List<Map<String, String>> getRemovableDrives() {
  final drives = <Map<String, String>>[];

  final Win32Result(:value) = GetLogicalDrives();
  final driveMask = value;

  for (int i = 0; i < 26; i++) {
    if (driveMask & (1 << i) != 0) {
      final driveLetter = '${String.fromCharCode(65 + i)}:\\';

      using((arena) {
        final driveType = GetDriveType(arena.pcwstr(driveLetter));

        if (driveType == DRIVE_REMOVABLE) {
          final volumeName = arena.pwstrBuffer(MAX_PATH);
          final fileSystem = arena.pwstrBuffer(MAX_PATH);

          GetVolumeInformation(
            arena.pcwstr(driveLetter),
            volumeName, 
            MAX_PATH,
            nullptr,
            nullptr,
            nullptr,
            fileSystem,
            MAX_PATH,
          );

          final label = volumeName.toDartString();
          drives.add({
            'letter': driveLetter,
            'label': label.isEmpty ? 'Removable Disk' : label,
            'fileSystem': fileSystem.toDartString(),
          });
        }
      });
    }
  }

  return drives;
}

const mediaExtensions = {
  '.jpg', '.jpeg', '.png', '.heic', '.heif', '.raw', '.cr2', '.nef', '.arw'// images
  '.mp4', '.mov', '.avi', '.mts', '.m2ts', '.mkv',                   // videos
};

List<FileSystemEntity> getMediaFiles(String folderPath) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) return [];

  return dir
      .listSync(recursive: false)
      .where((e) => e is File &&
          mediaExtensions.contains(
            p.extension(e.path).toLowerCase(),
          ))
      .toList();
}

const _videoExtensions = {
  'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'mpg', 'mpeg',
};

const _imageExtensions = {
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif', 'heic',
  'raw', 'cr2', 'nef', 'arw', 'dng',
};

Future<List<ImmichAsset>> scanDriveAssets(
  String rootPath, {
  void Function(String currentPath, int found)? onProgress,
}) async {
  final files = <(File, String)>[];
  final dir = Directory(rootPath);

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final ext = entity.path.split('.').last.toLowerCase();
    final isVideo = _videoExtensions.contains(ext);
    final isImage = _imageExtensions.contains(ext);
    if (!isVideo && !isImage) continue;
    files.add((entity, ext));
  }

  // Process in parallel - 8 at a time
  final results = <ImmichAsset>[];
  const chunkSize = 8;

  for (int i = 0; i < files.length; i += chunkSize) {
    final chunk = files.skip(i).take(chunkSize);
    final chunkResults = await Future.wait(
      chunk.map(((File, String) f) async {
        try {
          return _videoExtensions.contains(f.$2)
              ? await _assetFromVideo(f.$1, f.$2)
              : await _assetFromImage(f.$1, f.$2);
        } catch (_) {
          return null;
        }
      }),
    );
    results.addAll(chunkResults.whereType<ImmichAsset>());
    onProgress?.call(files[i].$1.path, results.length);
  }

  return results;
}
Future<ImmichAsset?> _assetFromImage(File file, String ext) async {
  final stat = await file.stat();
  final fileName = file.uri.pathSegments.last;
  final mimeType = _mimeType(ext);

  // Defaults — overwritten by EXIF if available
  DateTime fileCreatedAt = stat.changed;
  final exifInfo = <String, dynamic>{
    'fileSizeInByte': stat.size,
    'modifyDate': stat.modified.toIso8601String(),
  };

  try {
    final raf = await file.open();
    final bytes = await raf.read(65536); // first 64KB only
    await raf.close();
    final exif = await readExifFromBytes(bytes);
    final dateStr = exif['EXIF DateTimeOriginal']?.toString() ??
      exif['Image DateTime']?.toString();
    if (dateStr != null) {
      fileCreatedAt = _parseExifDate(dateStr) ?? fileCreatedAt;
    }

    // Dimensions
    final width = _exifInt(exif['Image ImageWidth'] ?? exif['EXIF ExifImageWidth']);
    final height = _exifInt(exif['Image ImageLength'] ?? exif['EXIF ExifImageLength']);

    exifInfo.addAll({ // todo note 'JPEGThumbnail' does exist here if i want to bundle it in
      'width': ?width,
      'height': ?height,
      if (exif['EXIF FocalLength'] != null) 'focalLength': exif['EXIF FocalLength'].toString(),
      if (exif['EXIF FNumber'] != null) 'fNumber': exif['EXIF FNumber'].toString(),
      if (exif['EXIF ISOSpeedRatings'] != null) 'iso': exif['EXIF ISOSpeedRatings'].toString(),
      if (exif['EXIF ExposureTime'] != null) 'exposureTime': exif['EXIF ExposureTime'].toString(),
      if (exif['Image Make'] != null) 'make': exif['Image Make'].toString(),
      if (exif['Image Model'] != null) 'model': exif['Image Model'].toString(),
      if (exif['GPS GPSLatitude'] != null) 'latitude': _gpsDecimal(exif['GPS GPSLatitude'], exif['GPS GPSLatitudeRef']?.toString()),
      if (exif['GPS GPSLongitude'] != null) 'longitude': _gpsDecimal(exif['GPS GPSLongitude'], exif['GPS GPSLongitudeRef']?.toString()),
      if (exif['Image Artist'] != null) 'artist': exif['Image Artist'].toString(),
      if (exif['Image ImageDescription'] != null) 'description': exif['Image ImageDescription'].toString(),
      if (exif['Image Orientation'] != null) 'Orientation': exif['Image Orientation'].toString(),
      if (exif['EXIF FocalLength'] != null) 'focalLength': exif['EXIF FocalLength'].toString(),
      if (exif['EXIF LensModel'] != null) 'lensModel': exif['EXIF LensModel'].toString(), // sony arw
      if (exif['MakerNote LensModel'] != null) 'lensModel': exif['MakerNote LensModel'].toString(), // cannon cr2
    });

    // Dates
  } catch (e) {
    print('Failed to read EXIF from ${file.path}: $e');
  }

  return ImmichAsset(
    id: _localId(file.path),
    type: 'IMAGE',
    originalFileName: fileName,
    fileCreatedAt: fileCreatedAt,
    mimeType: mimeType,
    exifInfo: exifInfo,
    localPath: file.path
  );
}

Future<ImmichAsset?> _assetFromVideo(File file, String ext) async {
  final stat = await file.stat();
  final fileName = file.uri.pathSegments.last;
  final mimeType = _mimeType(ext);

  DateTime fileCreatedAt = stat.changed;
  final exifInfo = <String, dynamic>{
    'fileSizeInByte': stat.size,
    'modifyDate': stat.modified.toIso8601String(),
  };

  try {
    exifInfo.addAll(await Mp4MetadataReader.fromPath(file.path));
  } catch (_) {}

  return ImmichAsset(
    id: _localId(file.path),
    type: 'VIDEO',
    originalFileName: fileName,
    fileCreatedAt: fileCreatedAt,
    mimeType: mimeType,
    exifInfo: exifInfo,
    localPath: file.path,
  );
}

// Helpers 
String _localId(String path) =>
    'local_${path.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

String? _mimeType(String ext) => const {
  'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
  'png': 'image/png',  'gif': 'image/gif',
  'bmp': 'image/bmp',  'webp': 'image/webp',
  'tiff': 'image/tiff','tif': 'image/tiff',
  'heic': 'image/heic','raw': 'image/raw',
  'cr2': 'image/cr2',  'nef': 'image/nef',
  'arw': 'image/arw',  'dng': 'image/dng',
  'mp4': 'video/mp4',  'mkv': 'video/x-matroska',
  'avi': 'video/x-msvideo', 'mov': 'video/quicktime',
  'wmv': 'video/x-ms-wmv',  'webm': 'video/webm',
  'm4v': 'video/x-m4v',
}[ext];

DateTime? _parseExifDate(String raw) {
  try {
    // EXIF format: "2024:01:15 14:30:00"
    final parts = raw.split(' ');
    final datePart = parts[0].replaceAll(':', '-');
    return DateTime.parse('$datePart ${parts.length > 1 ? parts[1] : '00:00:00'}');
  } catch (_) {
    return null;
  }
}

int? _exifInt(dynamic tag) =>
    tag == null ? null : int.tryParse(tag.toString().split(' ').first);

double? _gpsDecimal(dynamic tag, String? ref) {
  if (tag == null) return null;
  try {
    // tag.toString() → "[48, 51, 3429/100]"
    final parts = tag
        .toString()
        .replaceAll(RegExp(r'[\[\]]'), '')
        .split(',')
        .map((s) => s.trim())
        .toList();
    if (parts.length < 3) return null;
    double deg = _evalRatio(parts[0]);
    double min = _evalRatio(parts[1]);
    double sec = _evalRatio(parts[2]);
    double decimal = deg + min / 60 + sec / 3600;
    if (ref == 'S' || ref == 'W') decimal = -decimal;
    return decimal;
  } catch (_) {
    return null;
  }
}

double _evalRatio(String s) {
  if (s.contains('/')) {
    final p = s.split('/');
    return double.parse(p[0]) / double.parse(p[1]);
  }
  return double.parse(s);
}

class Mp4MetadataReader {
  final RandomAccessFile _file;
  final Map<String, dynamic> metadata = {};
  final List<String> _qtKeys = [];

  Mp4MetadataReader._(this._file);

  static Future<Map<String, dynamic>> fromPath(String path) async {
    final file = await File(path).open();
    final reader = Mp4MetadataReader._(file);
    await reader._parse();
    await file.close();

    final duration = reader.metadata['duration_seconds'] as double?;
    if (duration != null && duration > 0) {
      final fileSize = await File(path).length();
      reader.metadata['bitrate_kbps'] ??=
          ((fileSize * 8) / duration / 1000).round();
    }

    return reader.metadata;
  }

  Future<void> _parse() async {
    await _readBoxes(0, await _file.length());
  }

  Future<void> _readBoxes(int offset, int end) async {
    int pos = offset;
    while (pos < end - 8) {
      await _file.setPosition(pos);
      final header = await _file.read(8);
      if (header.length < 8) break;

      final hData = ByteData.sublistView(Uint8List.fromList(header));
      int boxSize = hData.getUint32(0);
      final boxType = latin1.decode(header.sublist(4, 8));

      if (boxSize == 1) {
        final ext = await _file.read(8);
        boxSize = ByteData.sublistView(Uint8List.fromList(ext)).getUint64(0);
      }
      if (boxSize < 8) break;

      await _handleBox(boxType, pos + 8, pos + boxSize);
      pos += boxSize;
    }
  }

  Future<void> _handleBox(String type, int start, int end) async {
    switch (type) {
      case 'moov':
      case 'trak':
      case 'mdia':
      case 'minf':
      case 'stbl':
      case 'udta':
        await _readBoxes(start, end);
      case 'meta':  await _parseMetaBox(start, end);
      case 'xml ':  await _parseNrtmXml(start, end);
      case 'ilst':
        _qtKeys.isNotEmpty
            ? await _parseQtIlst(start, end)
            : await _readBoxes(start, end);
      case 'mvhd':  await _parseMvhd(start);
      case 'tkhd':  await _parseTkhd(start);
      case 'stsd':  await _parseStsd(start, end);
      case 'stts':  await _parseStts(start);
      case 'keys':  await _parseQtKeys(start, end);
      case 'smhd':  metadata['has_audio'] = true;
      case 'vmhd':  metadata['has_video'] = true;
      case 'uuid':  await _parseUuidBox(start, end);
      case '\xa9xyz': await _parseStringTag('location', start);
      case '\xa9nam': await _parseStringTag('title', start);
      case '\xa9too': await _parseStringTag('encoder', start);
      case '\xa9mak': await _parseStringTag('make', start);
      case '\xa9mod': await _parseStringTag('model', start);
      case '\xa9day': await _parseStringTag('creation_date', start);
      case '\xa9cmt': await _parseStringTag('comment', start);
      case 'cprt':    await _parseStringTag('copyright', start);
      case 'make':    await _parseStringTag('make', start);
      case 'modl':    await _parseStringTag('model', start);
      case 'sftw':    await _parseStringTag('software', start);
    }
  }

  Future<void> _parseMetaBox(int start, int end) async {
    await _file.setPosition(start);
    final probe = await _file.read(4);
    if (probe.length < 4) return;
    // Fullbox has version byte = 0 at start
    final skip = probe[0] == 0 ? 4 : 0;
    await _readBoxes(start + skip, end);
  }

  Future<void> _parseNrtmXml(int start, int end) async {
    await _file.setPosition(start);
    final bytes = await _file.read(end - start);
    if (bytes.length < 4) return;
    final xml = utf8.decode(bytes.sublist(4), allowMalformed: true);

    void extract(String attr, String key) {
      final m = RegExp('$attr="([^"]+)"').firstMatch(xml);
      if (m != null) metadata.putIfAbsent(key, () => m.group(1)!.trim());
    }

    extract('manufacturer', 'make');
    extract('modelName',    'model');
    extract('serialNo',     'serial_number');
    extract('aspectRatio',  'aspect_ratio');
  }

  Future<void> _parseMvhd(int start) async {
    await _file.setPosition(start);
    final bytes = await _file.read(108);
    if (bytes.length < 20) return;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final version = data.getUint8(0);

    final int creationTime, timescale, durationUnits;
    if (version == 1) {
      creationTime  = data.getUint64(4);
      timescale     = data.getUint32(20);
      durationUnits = data.getUint64(24);
    } else {
      creationTime  = data.getUint32(4);
      timescale     = data.getUint32(12);
      durationUnits = data.getUint32(16);
    }

    if (timescale > 0) {
      metadata['duration_seconds'] = durationUnits / timescale;
      metadata['duration_ms'] = (durationUnits / timescale * 1000).round();
    }

    if (creationTime > 2082844800) {
      final unixSec = creationTime - 2082844800;
      metadata['creation_date'] =
          DateTime.fromMillisecondsSinceEpoch(unixSec * 1000, isUtc: true)
              .toIso8601String();
    }
  }

  Future<void> _parseTkhd(int start) async {
    await _file.setPosition(start);
    final bytes = await _file.read(92);
    if (bytes.length < 72) return;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final offset = data.getUint8(0) == 1 ? 76 : 64;
    if (bytes.length >= offset + 8) {
      final width  = data.getUint32(offset) >> 16;
      final height = data.getUint32(offset + 4) >> 16;
      if (width > 0 && height > 0) {
        metadata['width']  = width;
        metadata['height'] = height;
      }
    }
  }

  Future<void> _parseStsd(int start, int end) async {
    await _file.setPosition(start);
    final bytes = await _file.read(end - start);
    if (bytes.length < 16) return;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final codec = latin1.decode(bytes.sublist(12, 16)).trim();

    const videoCodecs = {'avc1', 'hvc1', 'hev1', 'mp4v', 'dvh1', 'av01', 'vp09'};
    const audioCodecs = {'mp4a', 'ac-3', 'ec-3', 'Opus', 'twos', 'sowt', 'lpcm'};

    if (videoCodecs.contains(codec)) {
      metadata['video_codec'] = codec;
      if (bytes.length >= 92) {
        final w = data.getUint16(40);
        final h = data.getUint16(42);
        if (w > 0) metadata['width']  = w;
        if (h > 0) metadata['height'] = h;
        metadata['bit_depth'] = switch (data.getUint16(90)) {
          24 => 8, 32 => 8, 40 => 10, 48 => 16,
          final d => d > 0 ? d : 8,
        };
      }
      if (bytes.length > 94) _parseCodecConfigBox(bytes, data);
    } else if (audioCodecs.contains(codec)) {
      metadata['audio_codec'] =
          (codec == 'twos' || codec == 'sowt' || codec == 'lpcm') ? 'PCM' : codec;
      if (bytes.length >= 44) {
        final channels   = data.getUint16(32);
        final sampleSize = data.getUint16(34);
        final sampleRate = data.getUint32(40) >> 16;
        if (channels > 0)   metadata['audio_channels']    = channels;
        if (sampleSize > 0) metadata['audio_bit_depth']   = sampleSize;
        if (sampleRate > 0) metadata['audio_sample_rate'] = sampleRate;
      }
    }
  }

  void _parseCodecConfigBox(List<int> bytes, ByteData data) {
    int pos = 94;
    while (pos + 8 < bytes.length) {
      final boxSize = data.getUint32(pos);
      if (boxSize < 8 || pos + boxSize > bytes.length) break;
      final boxType = latin1.decode(bytes.sublist(pos + 4, pos + 8));

      if (boxType == 'avcC' && bytes.length >= pos + 10) {
        final p = bytes[pos + 9];
        metadata['h264_profile'] = switch (p) {
          66 => 'Baseline', 77 => 'Main', 100 => 'High',
          110 => 'High 10', 122 => 'High 4:2:2', 244 => 'High 4:4:4',
          _ => 'profile_$p',
        };
        if (p == 110 || p == 122) metadata['bit_depth'] = 10;
        if (p == 244) metadata['bit_depth'] = 14;
      } else if (boxType == 'hvcC' && bytes.length >= pos + 23) {
        metadata['bit_depth'] = 8 + ((bytes[pos + 22] & 0x0E) >> 1);
      } else if (boxType == 'av1C' && bytes.length >= pos + 10) {
        final cfg = bytes[pos + 9];
        metadata['bit_depth'] = (cfg & 0x20) != 0 ? 12 : (cfg & 0x40) != 0 ? 10 : 8;
      }

      pos += boxSize;
    }
  }

  Future<void> _parseStts(int start) async {
    await _file.setPosition(start);
    final bytes = await _file.read(8);
    if (bytes.length < 8) return;
    final entryCount = ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(4);
    if (entryCount == 0 || entryCount > 10000) return;

    await _file.setPosition(start + 8);
    final entryBytes = await _file.read(entryCount * 8);
    final eData = ByteData.sublistView(Uint8List.fromList(entryBytes));

    int totalSamples = 0;
    for (int i = 0; i < entryCount && (i * 8 + 8) <= entryBytes.length; i++) {
      totalSamples += eData.getUint32(i * 8);
    }

    final durationSec = metadata['duration_seconds'] as double?;
    if (totalSamples > 0 && durationSec != null && durationSec > 0) {
      metadata['frame_rate'] =
          double.parse((totalSamples / durationSec).toStringAsFixed(3));
    }
  }

  Future<void> _parseUuidBox(int start, int end) async {
    await _file.setPosition(start);
    final bytes = await _file.read(end - start);
    if (bytes.length < 16) return;
    final uuid = _formatUuid(bytes.sublist(0, 16));
    final content = bytes.sublist(16);

    switch (uuid) {
      case '50524f46-21d2-4fce-bb88-695cfac9c740': _parseSonyProf(content);
      case 'be7acfcb-97a9-42e8-9c71-999491e3afac': _parseXmp(content);
      case 'ffcc8263-f855-4a93-8814-587a02521fdd': metadata['spherical_video'] = true;
    }
  }

  void _parseSonyProf(List<int> bytes) {
    if (bytes.length < 8) return;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    int pos = 8;
    while (pos + 8 <= bytes.length) {
      final boxSize = data.getUint32(pos);
      if (boxSize < 8 || pos + boxSize > bytes.length) break;
      final boxType = latin1.decode(bytes.sublist(pos + 4, pos + 8));
      final bd = bytes.sublist(pos + 8, pos + boxSize);
      final bdData = ByteData.sublistView(Uint8List.fromList(bd));
      if (boxType == 'APRF') {
        _parseSonyAprf(bd, bdData);
      } else if (boxType == 'VPRF') {
        _parseSonyVprf(bd, bdData);
      }
      pos += boxSize;
    }
  }

  void _parseSonyAprf(List<int> bytes, ByteData data) {
    if (bytes.length < 28) return;
    final codec = latin1.decode(bytes.sublist(8, 12)).trim();
    final channels   = data.getUint16(20);
    final sampleSize = data.getUint16(22);
    final sampleRate = data.getUint32(24) >> 16;
    metadata['audio_codec'] = codec == 'twos' ? 'PCM' : codec;
    if (channels > 0)   metadata['audio_channels']    = channels;
    if (sampleSize > 0) metadata['audio_bit_depth']   = sampleSize;
    if (sampleRate > 0) metadata['audio_sample_rate'] = sampleRate;
  }

  void _parseSonyVprf(List<int> bytes, ByteData data) {
    if (bytes.length < 32) return;
    final codec      = latin1.decode(bytes.sublist(8, 12)).trim();
    final profileIdc = bytes[12];
    final levelIdc   = bytes[14];
    final avgBitrate = data.getUint32(16);
    final maxBitrate = data.getUint32(20);
    final width      = data.getUint16(28);
    final height     = data.getUint16(30);

    metadata['video_codec'] = codec;
    metadata['video_profile'] = switch (profileIdc) {
      66 => 'Baseline', 77 => 'Main', 100 => 'High',
      110 => 'High 10', 122 => 'High 4:2:2', 244 => 'High 4:4:4',
      _ => 'profile_$profileIdc',
    };
    metadata['video_level'] = '${levelIdc ~/ 10}.${levelIdc % 10}';
    if (avgBitrate > 0) metadata['bitrate_kbps']     = avgBitrate ~/ 1000;
    if (maxBitrate > 0) metadata['max_bitrate_kbps'] = maxBitrate ~/ 1000;
    if (width > 0)      metadata['width']            = width;
    if (height > 0)     metadata['height']           = height;

    if (bytes.length >= 38) {
      final parW = data.getUint16(34);
      final parH = data.getUint16(36);
      if (parW > 0 && parH > 0) metadata['aspect_ratio'] = '$parW:$parH';
    }
  }

  void _parseXmp(List<int> bytes) {
    final xml = utf8.decode(bytes, allowMalformed: true);
    void extract(String tag, String key) {
      for (final p in [
        RegExp('<[^>:]+:$tag[^>]*>([^<]+)<', caseSensitive: false),
        RegExp('$tag="([^"]+)"', caseSensitive: false),
      ]) {
        final m = p.firstMatch(xml);
        if (m != null) {
          final val = m.group(1)!.trim();
          if (val.isNotEmpty) { metadata.putIfAbsent(key, () => val); return; }
        }
      }
    }

    extract('Make',                  'make');
    extract('Model',                 'model');
    extract('SerialNumber',          'serial_number');
    extract('LensModel',             'lens_model');
    extract('FocalLength',           'focal_length_mm');
    extract('FocalLengthIn35mmFilm', 'focal_length_35mm');
    extract('FNumber',               'aperture');
    extract('ExposureTime',          'shutter_speed');
    extract('ISOSpeedRatings',       'iso');
    extract('WhiteBalance',          'white_balance');
    extract('CreateDate',            'creation_date');
    extract('CreatorTool',           'software');
    extract('GPSLatitude',           'gps_latitude');
    extract('GPSLongitude',          'gps_longitude');
    extract('GPSAltitude',           'gps_altitude');
  }

  Future<void> _parseQtKeys(int start, int end) async {
    await _file.setPosition(start);
    final bytes = await _file.read(end - start);
    if (bytes.length < 8) return;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final entryCount = data.getUint32(4);
    int pos = 8;
    for (int i = 0; i < entryCount && pos + 8 <= bytes.length; i++) {
      final keySize = data.getUint32(pos);
      if (keySize < 8 || pos + keySize > bytes.length) break;
      _qtKeys.add(utf8.decode(bytes.sublist(pos + 8, pos + keySize), allowMalformed: true).trim());
      pos += keySize;
    }
  }

  Future<void> _parseQtIlst(int start, int end) async {
    int pos = start;
    int keyIndex = 0;
    while (pos < end - 8) {
      await _file.setPosition(pos);
      final header = await _file.read(8);
      if (header.length < 8) break;
      final boxSize = ByteData.sublistView(Uint8List.fromList(header)).getUint32(0);
      if (boxSize < 8) break;

      if (keyIndex < _qtKeys.length) {
        final friendlyKey = _friendlyKeyName(_qtKeys[keyIndex]);
        if (friendlyKey != null) {
          await _file.setPosition(pos + 8);
          final inner = await _file.read(boxSize - 8);
          if (inner.length >= 16) {
            final iData = ByteData.sublistView(Uint8List.fromList(inner));
            switch (iData.getUint32(8)) {
              case 0 || 1 || 12:
                final v = utf8.decode(inner.sublist(16), allowMalformed: true).trim();
                if (v.isNotEmpty) metadata[friendlyKey] = v;
              case 21:
                if (inner.length >= 17) metadata[friendlyKey] = inner[16];
              case 23:
                if (inner.length >= 20) metadata[friendlyKey] = iData.getFloat32(16);
              case 67:
                if (inner.length >= 24) metadata[friendlyKey] = iData.getFloat64(16);
            }
          }
        }
      }
      keyIndex++;
      pos += boxSize;
    }
  }

  String? _friendlyKeyName(String key) {
    final stripped = key
        .replaceFirst('com.apple.quicktime.', '')
        .replaceFirst('com.apple.photos.', '')
        .replaceFirst('com.android.', '')
        .replaceFirst('com.camera.', '')
        .replaceFirst('org.mp4ra.', '');

    const map = {
      'make': 'make', 'DeviceMake': 'make', 'DeviceManufacturer': 'make',
      'model': 'model', 'DeviceModelName': 'model',
      'DeviceSerialNumber': 'serial_number',
      'software': 'software',
      'creationdate': 'creation_date',
      'lens.model': 'lens_model', 'LensModel': 'lens_model',
      'focal.length': 'focal_length_mm', 'FocalLength': 'focal_length_mm',
      'focal.length.35mm': 'focal_length_35mm', 'FocalLength35mm': 'focal_length_35mm',
      'exposure.time': 'shutter_speed', 'ExposureTime': 'shutter_speed',
      'f.number': 'aperture', 'FNumber': 'aperture',
      'iso': 'iso', 'ISO': 'iso', 'ISOSpeedRatings': 'iso',
      'white.balance': 'white_balance', 'WhiteBalance': 'white_balance',
      'color.temperature': 'color_temperature_k', 'ColorTemperature': 'color_temperature_k',
      'location.ISO6709': 'location', 'location': 'location',
      'location.accuracy.horizontal': 'gps_accuracy_m',
      'flash': 'flash', 'Flash': 'flash',
      'video.stabilization': 'stabilization',
      'content.identifier': 'content_id',
      'description': 'description', 'title': 'title',
      'comment': 'comment',
    };

    return map[stripped] ?? (stripped.length > 2 ? stripped : null);
  }

  Future<void> _parseStringTag(String key, int start) async {
    await _file.setPosition(start);
    final bytes = await _file.read(512);
    if (bytes.length < 16) return;
    final value = utf8.decode(bytes.sublist(16), allowMalformed: true).trim();
    if (value.isNotEmpty) metadata[key] = value;
  }

  String _formatUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}