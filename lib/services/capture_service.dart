import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:photo_sync/models/db/ref_dao.dart';
import 'package:photo_sync/models/blob_store.dart';
import 'package:uuid/uuid.dart';

/// Single entry point for adding things to the reference library, whether they
/// come from the picker, drag-and-drop or (later) a share intent.
class CaptureService {
  CaptureService(this._dao, this._blobs);
  final RefDao _dao;
  final BlobStore _blobs;
  static const _uuid = Uuid();

  static const imageExts = {
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif',
  };
  static bool isImagePath(String path) =>
      imageExts.contains(p.extension(path).toLowerCase());

  Future<int> addImageFiles(Iterable<File> files) async {
    var added = 0;
    for (final f in files) {
      if (!isImagePath(f.path)) continue;
      final stored = await _blobs.ingestImage(f);
      final now = DateTime.now();
      await _dao.insertItem(RefItemsCompanion.insert(
        id: _uuid.v4(),
        kind: 'image',
        createdAt: now,
        updatedAt: now,
        blobHash: Value(stored.hash),
        mime: Value(stored.mime),
        width: Value(stored.width),
        height: Value(stored.height),
      ));
      added++;
    }
    return added;
  }

  Future<void> addLink(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.contains('://')) url = 'https://$url';
    final now = DateTime.now();
    await _dao.insertItem(RefItemsCompanion.insert(
      id: _uuid.v4(),
      kind: 'link',
      createdAt: now,
      updatedAt: now,
      sourceUrl: Value(url),
      title: Value(Uri.tryParse(url)?.host),
    ));
  }

  Future<void> addText(String body) async {
    if (body.trim().isEmpty) return;
    final now = DateTime.now();
    await _dao.insertItem(RefItemsCompanion.insert(
      id: _uuid.v4(),
      kind: 'text',
      createdAt: now,
      updatedAt: now,
      bodyText: Value(body.trim()),
    ));
  }
}
