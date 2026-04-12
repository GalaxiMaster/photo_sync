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
    _hasMore = results.length == 80;
    return _stackPairs(results);  
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;

    final currentList = state.value ?? [];
    final next = await _service.fetchImages(page: ++_page);

    _hasMore = next.length == 60;
    _loadingMore = false;

    state = AsyncData([...currentList, ..._stackPairs(next)]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
  static List<GalleryItem> _stackPairs(List<ImmichAsset> assets) {
    final Map<String, List<ImmichAsset>> groups = {};
// PXL_20260405_201722973.LONG_EXPOSURE-01.COVER.jpg
// PXL_20260405_201722973.LONG_EXPOSURE-02.ORIGINAL.jpg

    for (final asset in assets) {
      final key = asset.pixelPairKey ?? asset.baseName;
      groups.putIfAbsent(key, () => []).add(asset);
    }

    final List<GalleryItem> result = [];
    for (final group in groups.values) {
      if (group.length == 1) {
        result.add(SingleAsset(group.first));
        continue;
      }

      if (group.length > 1) {
        final ImmichAsset primary = group.firstWhere( // TODO refactor to find the best candidate instead of just the first match, accounting for different naming conventions and not relying on 01 as 02 could be the start
          (a) => a.originalFileName.split('-').last.contains('01'),
          orElse: () => group.firstWhere(
            (a) => a.originalFileName.split('-').last.contains('cover'),
            orElse: () => group.firstWhere(
              (a) => a.isJpg,
              orElse: () => group.first,
            ),
          ),
        );
        final containsRaw = group.any((a) => a.isRaw);
        final other = group.where((a) => a.originalFileName != primary.originalFileName).toList();
        result.add(StackedAssets(primary: primary, containsRaw: containsRaw, children: other));
      }
      else {
        result.add(SingleAsset(group.first));
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