import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:photo_sync/services/app_settings_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final settingsProvider = FutureProvider<SettingsTableData?>((ref) async {
  return ref.watch(databaseProvider).getSettings();
});

class DownloadedPhotosNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => setupPhotoCache();

  void add(String filename) => state = AsyncData({...state.value ?? {}, filename});
  void remove(String filename) => state = AsyncData({...state.value ?? {}}..remove(filename));
  bool contains(String filename) => state.value?.contains(filename) ?? false;
}

final downloadedPhotosProvider = AsyncNotifierProvider<DownloadedPhotosNotifier, Set<String>>(
  DownloadedPhotosNotifier.new,
);

// final photoCacheProvider = FutureProvider<List<PhotoCacheTableData>>((ref) {
//   return ref.watch(databaseProvider).getAllPhotos();
// });

class ServerInfoNotifier extends AsyncNotifier<ServerStorageInfo> {
  ImmichService get _service => ref.read(immichServiceProvider);

  @override
  Future<ServerStorageInfo> build() => _service.getServerStorage();
}

final serverInfoProvider = AsyncNotifierProvider<ServerInfoNotifier, ServerStorageInfo>(
  ServerInfoNotifier.new,
);