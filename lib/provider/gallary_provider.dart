import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/services/api_service.dart';

final immichServiceProvider = Provider<ImmichService>(
  (_) => ImmichService(),
);


class GalleryNotifier extends AsyncNotifier<List<GalleryItem>> {
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  ImmichService get _service => ref.read(immichServiceProvider);

  @override
  Future<List<GalleryItem>> build() => _fetch();

  Future<List<GalleryItem>> _fetch() async {
    _page = 1;
    _hasMore = true;
    final results = await _service.fetchImages(page: _page);
    _hasMore = results.length == 60;
    return _stackDngJpgPairs(results);  
}

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;

    final currentList = state.value ?? [];
    final next = await _service.fetchImages(page: ++_page);

    _hasMore = next.length == 60;
    _loadingMore = false;

    state = AsyncData([...currentList, ..._stackDngJpgPairs(next)]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
  static List<GalleryItem> _stackDngJpgPairs(List<ImmichAsset> assets) {
    final Map<String, List<ImmichAsset>> groups = {};

    for (final asset in assets) {
      final key = asset.pixelRawPairKey ?? asset.baseName;
      groups.putIfAbsent(key, () => []).add(asset);
    }

    final List<GalleryItem> result = [];
    for (final group in groups.values) {
      if (group.length == 1) {
        result.add(SingleAsset(group.first));
        continue;
      }

      final hasDng = group.any((a) => a.isDng);
      final jpg = group.where((a) => a.isJpg).firstOrNull;

      if (hasDng && jpg != null) {
        final dngs = group.where((a) => a.isDng).toList();
        result.add(StackedAssets(primary: jpg, children: dngs));
      } else {
        result.addAll(group.map((a) => SingleAsset(a)));
      }
    }

  return result;
} 

  bool get hasMore => _hasMore;
}

final galleryProvider =
    AsyncNotifierProvider<GalleryNotifier, List<GalleryItem>>(
  GalleryNotifier.new,
);