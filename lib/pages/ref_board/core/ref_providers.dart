import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:photo_sync/pages/ref_board/core/db/ref_dao.dart';
import 'package:photo_sync/provider/database_providers.dart';

import 'services/capture_service.dart';
import 'storage/blob_store.dart';

/// Photo Ref queries, backed by the shared AppDatabase.
final refDaoProvider = Provider<RefDao>((ref) => ref.watch(databaseProvider).refDao);

/// Overridden in main() once the store directory is resolved.
final refBlobStoreProvider =
    Provider<BlobStore>((ref) => throw UnimplementedError('Override in main()'));

final refCaptureServiceProvider = Provider<CaptureService>((ref) =>
    CaptureService(ref.watch(refDaoProvider), ref.watch(refBlobStoreProvider)));

/// The text in the shared top-bar search field while a Photo Ref section is open.
class RefQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String query) => state = query.trim();
}

final refQueryProvider =
    NotifierProvider<RefQueryNotifier, String>(RefQueryNotifier.new);

/// Library contents: everything, or keyword matches when the query is non-empty.
final refItemsProvider = StreamProvider<List<RefItem>>((ref) {
  final dao = ref.watch(refDaoProvider);
  final query = ref.watch(refQueryProvider);
  return query.isEmpty ? dao.watchLibrary() : dao.watchKeywordSearch(query);
});

final refItemProvider = StreamProvider.family<RefItem?, String>(
    (ref, id) => ref.watch(refDaoProvider).watchItem(id));

final refItemTagsProvider = StreamProvider.family<List<RefTag>, String>(
    (ref, id) => ref.watch(refDaoProvider).watchTags(id));

final refNoteProvider = StreamProvider.family<RefNote?, String>(
    (ref, id) => ref.watch(refDaoProvider).watchNote(id));

final refBoardsProvider = StreamProvider<List<RefBoard>>(
    (ref) => ref.watch(refDaoProvider).watchBoards());
