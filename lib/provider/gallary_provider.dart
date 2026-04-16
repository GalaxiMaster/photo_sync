import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/search_popup.dart';
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

  final Map<String, List<ImmichAsset>> _groupedAssets = {};

  ImmichService get _service => ref.read(immichServiceProvider);
  List<GalleryItem>? originalContent;

  @override
  Future<List<GalleryItem>> build() => _fetch();

  Future<List<GalleryItem>> _fetch() async {
    _page = 1;
    _hasMore = true;
    _groupedAssets.clear();

    final results = await _service.fetchImages(page: _page);
    _hasMore = results.length == pulledItems;

    _updateGroupedMap(results);
    return _buildGalleryItems();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;

    try {
      final next = await _service.fetchImages(page: ++_page);
      _hasMore = next.length == pulledItems;

      _updateGroupedMap(next);
      state = AsyncData(_buildGalleryItems());
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    _groupedAssets.clear();
    state = const AsyncLoading();
    await loadMore();
  }

  void _updateGroupedMap(List<ImmichAsset> assets) {
    for (final asset in assets) {
      final key = asset.pixelPairKey ?? asset.baseName;
      _groupedAssets.putIfAbsent(key, () => []).add(asset);
    }
  }

  /// Reconstructs the GalleryItem list from the map
  List<GalleryItem> _buildGalleryItems() {
    final List<GalleryItem> result = [];

    for (final group in _groupedAssets.values) {
      if (group.isEmpty) continue;

      if (group.length == 1) {
        result.add(SingleAsset(group.first));
      } else {
        final ImmichAsset primary = group.firstWhere(
          (a) {
            final name = a.originalFileName.toLowerCase().split('-').last;
            return name.contains('01') || name.contains('cover');
          },
          orElse: () => group.firstWhere(
            (a) => a.isJpg,
            orElse: () => group.first,
          ),
        );

        final containsRaw = group.any((a) => a.isRaw);
        final other = group.where((a) => a.id != primary.id).toList();

        result.add(StackedAssets(
          primary: primary,
          containsRaw: containsRaw,
          children: other,
        ));
      }
    }

    // Sort by createdAt descending
    // ..sort((a, b) {
    //   final dateA = a is SingleAsset ? a.asset.createdAt : (a as StackedAssets).primary.createdAt;
    //   final dateB = b is SingleAsset ? b.asset.createdAt : (b as StackedAssets).primary.createdAt;
    //   return dateB.compareTo(dateA);
    // });
    return result;
  }

  Future<void> deleteAssets(List<String> assetIds) async {
    try {
      await _service.deleteAssets(assetIds);

      final idSet = assetIds.toSet();

      // Update the map by removing targeted IDs
      final keysToRemove = <String>[];
      _groupedAssets.forEach((key, list) {
        list.removeWhere((asset) => idSet.contains(asset.id));
        if (list.isEmpty) keysToRemove.add(key);
      });

      // Cleanup empty groups
      for (final key in keysToRemove) {
        _groupedAssets.remove(key);
      }

      state = AsyncData(_buildGalleryItems());
      ref.read(selectionProvider.notifier).clear();
    } catch (e) {
      throw Exception('Failed to delete assets: $e');
    }
  }

  Future<void> changeAssetDate(ImmichAsset asset, String dateString) async {
    final newAsset = asset.copyWith(fileCreatedAt: DateTime.parse(dateString));
    final key = asset.pixelPairKey ?? asset.baseName;

    // Update map directly
    if (_groupedAssets.containsKey(key)) {
      final index = _groupedAssets[key]!.indexWhere((a) => a.id == asset.id);
      if (index != -1) {
        _groupedAssets[key]![index] = newAsset;
      }
    }

    state = AsyncData(_buildGalleryItems());
    await _service.changeAssetDate(asset.id, dateString);
  }

  Future<void> smartSearch(SearchOptions options) async {
    if (options.query.isEmpty && options.searchType == SearchType.context) {
      if (originalContent == null) return;
      state = AsyncData(originalContent!);
      originalContent = null;
      return;
    }
    
    originalContent ??= state.value;
    state = const AsyncLoading();
    
    // Search is treated as a transient state and does not modify the persistent map
    final results = await _service.search(searchOptions: options);
    state = AsyncData(_stackPairs(results));
  }

  static List<GalleryItem> _stackPairs(List<ImmichAsset> assets) {
    final Map<String, List<ImmichAsset>> groups = {};
    for (final asset in assets) {
      final key = asset.pixelPairKey ?? asset.baseName;
      groups.putIfAbsent(key, () => []).add(asset);
    }

    final List<GalleryItem> result = [];
    for (final group in groups.values) {
      if (group.length == 1) {
        result.add(SingleAsset(group.first));
      } else {
        final ImmichAsset primary = group.firstWhere(
          (a) => a.originalFileName.toLowerCase().contains('01') || a.originalFileName.toLowerCase().contains('cover'),
          orElse: () => group.firstWhere((a) => a.isJpg, orElse: () => group.first),
        );
        final other = group.where((a) => a.id != primary.id).toList();
        result.add(StackedAssets(
          primary: primary, 
          containsRaw: group.any((a) => a.isRaw), 
          children: other
        ));
      }
    }
    return result;
  }

  bool get hasMore => _hasMore;
}

final galleryProvider = AsyncNotifierProvider<GalleryNotifier, List<GalleryItem>>(
  GalleryNotifier.new,
);