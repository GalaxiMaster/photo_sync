import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:photo_sync/models/blob_store.dart';
import 'package:photo_sync/models/db/ref_dao.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/capture_screen.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/model.dart';
import 'package:photo_sync/provider/ref_providers.dart';
import 'package:uuid/uuid.dart';

class FrameSaver {
  FrameSaver(this.dao, this.openBlobStore);
  final RefDao dao;
  final Future<BlobStore> Function() openBlobStore;
  final _uuid = const Uuid();

  Future<void> save(
      ResolvedVideo video, String url, List<CapturedFrame> frames) async {
    final store = await openBlobStore();

    final stored = <StoredImage>[];
    for (final f in frames) {
      stored.add(await store.ingestImage(f.file));
    }

    await dao.transaction(() async {
      final now = DateTime.now();

      for (var i = 0; i < frames.length; i++) {
        final s = stored[i];
        await dao.insertItem(RefItemsCompanion.insert(
          id: _uuid.v4(), kind: 'image', createdAt: now, updatedAt: now,
          blobHash: Value(s.hash),
          mime: Value(s.mime),
          width: Value(s.width),
          height: Value(s.height),
          sourceUrl: Value(url),
          sourceTimestampMs: Value(frames[i].position.inMilliseconds),
        ));
      }
    });
  }
}

final frameSaverProvider = Provider((ref) => FrameSaver(
      ref.read(refDaoProvider),
      BlobStore.open,
    ));