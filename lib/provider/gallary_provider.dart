import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';

final immichServiceProvider = Provider<ImmichService>(
  (_) => ImmichService(),
);


class GalleryNotifier extends AsyncNotifier<List<GalleryItem>> {
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  int pulledItems = 80;
  ImmichService get _service => ref.read(immichServiceProvider);

  List<GalleryItem>? originalContent;

  @override
  Future<List<GalleryItem>> build() => _fetch();

  Future<List<GalleryItem>> _fetch() async {
    _page = 1;
    _hasMore = true;
    final results = await _service.fetchImages(page: _page);
    _hasMore = results.length == pulledItems;
    return _stackPairs(results);  
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;

    final currentList = state.value ?? [];
    final next = await _service.fetchImages(page: ++_page);

    _hasMore = next.length == pulledItems;
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

  Future<void> deleteAssets(List<String> assetIds) async {
    try {
      // Delete from server first, should cancel out if there's an issue and not delete locally
      await _service.deleteAssets(assetIds);

      // Delete Locally
      state = AsyncData(state.value?.where((item) {
        if (item is SingleAsset) {
          return !assetIds.contains(item.asset.id);
        } else if (item is StackedAssets) {
          return !assetIds.contains(item.primary.id) && !item.children.any((child) => assetIds.contains(child.id));
        }
        return true;
      }).toList() ?? []);

      // clear selection after deletion
      ref.read(selectionProvider.notifier).clear();
    } catch (e) {
      throw Exception('Failed to delete assets: $e');
    }
  }
  Future<void> changeAssetDate(ImmichAsset asset, String dateString) async {
    final oldState = state.value ?? [];
    ImmichAsset newAsset = asset.copyWith(fileCreatedAt: DateTime.parse(dateString));
    state = AsyncData(updateAssetInList(oldState, asset.id, newAsset));
    await _service.changeAssetDate(asset.id, dateString);
  }

  ImmichAsset? findAssetById(List<GalleryItem> assets, String targetId) {
    for (final item in assets) {
      final asset = switch (item) {
        SingleAsset(:final asset) => asset,
        StackedAssets(:final primary) => primary,
      };
      if (asset.id == targetId) return asset;
    }
    return null;
  }

  List<GalleryItem> updateAssetInList(List<GalleryItem> assets, String targetId, ImmichAsset updated) {
    return assets.map<GalleryItem>((item) => switch (item) {
      SingleAsset(:final asset) when asset.id == targetId =>
          SingleAsset(updated),

      StackedAssets(:final primary) when primary.id == targetId =>
        StackedAssets(
          primary: updated,
          children: item.children,
          containsRaw: item.containsRaw,
        ),

      StackedAssets() when item.children.any((c) => c.id == targetId) =>
        StackedAssets(
          primary: item.primary,
          children: item.children.map((c) => c.id == targetId ? updated : c).toList(),
          containsRaw: item.containsRaw,
        ),
      _ => item,
    }).toList();
  }

  Future<void> smartSearch(String query) async {
    if (query.isEmpty) { // smart search doesnt have support for blank query so just exit out early
      if (originalContent == null) return;
      state = AsyncData(originalContent!);
      originalContent = null;
      return;
    }

    originalContent = state.value;
    state = const AsyncLoading();
    final results = await _service.smartSearch(query);
    _hasMore = results.length == pulledItems;
    state = AsyncData(_stackPairs(results));
  }

  bool get hasMore => _hasMore;
}

final galleryProvider = AsyncNotifierProvider<GalleryNotifier, List<GalleryItem>>(
  GalleryNotifier.new,
);