import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:photo_sync/pages/ref_board/core/db/ref_paths.dart';

class StoredImage {
  const StoredImage({required this.hash, required this.mime, this.width, this.height});
  final String hash;
  final String mime;
  final int? width;
  final int? height;
}

/// Content-addressed file store: files are named by the SHA-256 of their bytes.
/// Lives in the app *support* dir (not cache) so the OS never wipes offline adds.
class BlobStore {
  BlobStore(this.root);
  final Directory root;

  static const thumbSize = 512;

  static Future<BlobStore> open() async =>
    BlobStore((await RefPaths.get()).root);

  File originalFile(String hash) => File(p.join(
      root.path, 'originals', hash.substring(0, 2), hash.substring(2, 4), hash));

  File thumbFile(String hash) => File(p.join(
      root.path, 'thumbs', '$thumbSize', hash.substring(0, 2), '$hash.jpg'));

  /// Hash, copy into the store immediately (share-sheet handles are temporary),
  /// and generate a thumbnail off the UI thread.
  Future<StoredImage> ingestImage(File source) async {
    final hash = (await sha256.bind(source.openRead()).first).toString();

    final dest = originalFile(hash);
    if (!await dest.exists()) {
      await dest.parent.create(recursive: true);
      await source.copy(dest.path);
    }

    int? w, h;
    final thumb = thumbFile(hash);
    if (!await thumb.exists()) {
      final size = await Isolate.run(
          () => _makeThumbSync(dest.path, thumb.path, thumbSize));
      w = size?.$1;
      h = size?.$2;
    }
    return StoredImage(hash: hash, mime: _mimeFor(source.path), width: w, height: h);
  }
}

// Runs in a background isolate. Note: the `image` package cannot decode HEIC;
// those items get no thumbnail until the server derives one (planned).
(int, int)? _makeThumbSync(String src, String dst, int maxSide) {
  final decoded = img.decodeImage(File(src).readAsBytesSync());
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final fits = oriented.width <= maxSide && oriented.height <= maxSide;
  final resized = fits
      ? oriented
      : oriented.width >= oriented.height
          ? img.copyResize(oriented, width: maxSide)
          : img.copyResize(oriented, height: maxSide);
  File(dst)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodeJpg(resized, quality: 82));
  return (oriented.width, oriented.height);
}

String _mimeFor(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.bmp':
      return 'image/bmp';
    case '.heic':
    case '.heif':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}
