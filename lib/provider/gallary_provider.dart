import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/progress_popups.dart';
import 'package:photo_sync/Widgets/search_popup.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:photo_sync/services/tools.dart';

final immichServiceProvider = Provider<ImmichService>(
  (_) => ImmichService(),
);

class GalleryNotifier extends AsyncNotifier<List<GalleryItem>> {
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  int pulledItems = 80;
  bool isLocal = false;
  final Map<String, List<ImmichAsset>> _groupedAssets = {};
  List<ImmichAsset> fullLocal = [];
  ImmichService get _service => ref.read(immichServiceProvider);
  List<GalleryItem>? originalContent;
  SearchOptions searchOptions = SearchOptions(query: '', searchType: SearchType.fileName);
  Set<ImmichAsset> uploadQueue = {};

  bool get hasMore => _hasMore;

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
      late List<ImmichAsset>? results;
      if (isLocal) {
        final start = _page * pulledItems;
        // Guard against start exceeding the list after deletions.
        if (start >= fullLocal.length) {
          _hasMore = false;
          return;
        }
        final end = min(++_page * pulledItems, fullLocal.length);
        results = fullLocal.sublist(start, end);
        checkImmichStatusInBackground(results);
      } else {
        results = await smartSearch(searchOptions, fetchMore: true);
      }

      if (results == null) return;

      _hasMore = results.length >= pulledItems;

      _updateGroupedMap(results);
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

  // Reconstructs the GalleryItem list from the map
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

  Future<void> deleteAssets(List<String> assetIds, {bool isTrashed = false}) async {
    try {
      if (isLocal) {
        final assetsToDelete = fullLocal.where((a) => assetIds.contains(a.id)).toList();
        for (final asset in assetsToDelete) {
          fullLocal.remove(asset);
          if (asset.localPath != null) {
            final file = File(asset.localPath!);
            if (file.existsSync()) file.deleteSync();
          }
        }
      } else {
        await _service.deleteAssets(assetIds, force: isTrashed);
      }

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
      throw Exception('Failed to delete assets: $e'); // rethrow cleanly
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

  Future<void> loadLocal(List<ImmichAsset> assets) async {
    originalContent ??= state.value;
    fullLocal = assets..sort((a, b) => b.fileCreatedAt.compareTo(a.fileCreatedAt));

    _hasMore = fullLocal.length > pulledItems;
    _page = 1;
    isLocal = true;

    _groupedAssets.clear();
    final end = min(pulledItems, fullLocal.length);
    final sublist = fullLocal.sublist(0, end);
    _updateGroupedMap(sublist);
    state = AsyncData(_buildGalleryItems());
    checkImmichStatusInBackground(sublist);
  }

  Future<void> loadCloud() async {
    if (!isLocal && state.value != null && searchOptions.isEmpty()) return;

    state = const AsyncLoading();

    _page = 1;
    _groupedAssets.clear();
    isLocal = false;
    searchOptions = SearchOptions(query: '', searchType: SearchType.fileName);
    final results = await _service.fetchImages(page: _page);
    _hasMore = results.length == pulledItems;

    _updateGroupedMap(results);
    fullLocal = [];
    state = AsyncData(_buildGalleryItems());
    originalContent ??= state.value;
  }

  void toggleFavorite(ImmichAsset asset) async {
    final newValue = !asset.isFavorite;
    final updatedAsset = asset.copyWith(isFavorite: newValue);
    final key = asset.pixelPairKey ?? asset.baseName;

    if (_groupedAssets.containsKey(key)) {
      final index = _groupedAssets[key]!.indexWhere((a) => a.id == asset.id);
      if (index != -1) {
        _groupedAssets[key]![index] = updatedAsset;
      }
    }

    state = AsyncData(_buildGalleryItems());
    await _service.favoriteImmichAsset(asset.id, newValue);
  }

  void searchFromOptions(SearchOptions options, {bool force = false}) async {
    final results = await smartSearch(options, force: force);
    if (results == null) return;

    _hasMore = results.length >= pulledItems;
    _updateGroupedMap(results);
    state = AsyncData(_buildGalleryItems());
  }

  Future<List<ImmichAsset>?> smartSearch(SearchOptions options, {bool fetchMore = false, bool force = false}) async {
    searchOptions = options;

    if (options.isEmpty() && options.searchType == SearchType.context && !force) {
      if (originalContent == null) return null;
      state = AsyncData(originalContent!);
      _hasMore = originalContent!.length >= pulledItems;
      originalContent = null;
      return null;
    }
    
    originalContent ??= state.value;
    if (fetchMore) {
      ++_page;
    } else {
      _page = 1;
      _groupedAssets.clear();
      state = const AsyncLoading();
    }
    final results = isLocal 
      ? localSearch(searchOptions: options, page: _page)
      : await _service.search(searchOptions: options, page: _page);

    return results;
  }

  List<ImmichAsset> localSearch({required SearchOptions searchOptions, required int page}) {
    return fullLocal.sorted((a, b) {
      final cmp = a.fileCreatedAt.compareTo(b.fileCreatedAt);
      return searchOptions.sortOrder == SortOrder.desc ? -cmp : cmp;
    }).where((asset) {
      final matchesQuery = searchOptions.query.isEmpty || asset.baseName.toLowerCase().contains(searchOptions.query.toLowerCase());
      final matchesMediaType = searchOptions.mediaType == null || asset.isOfType(searchOptions.mediaType!);
      final matchesDate = (searchOptions.startDate == null || asset.fileCreatedAt.isAfter(searchOptions.startDate!)) &&
                          (searchOptions.endDate == null || asset.fileCreatedAt.isBefore(searchOptions.endDate!));
      final matchesMake = (searchOptions.cameraFilter?.isEmpty() ?? true) || (asset.exifInfo['make'] != null && asset.exifInfo['make']!.toLowerCase() == searchOptions.cameraFilter!.make!.toLowerCase());
      final matchesModel = (searchOptions.cameraFilter?.isEmpty() ?? true) || (asset.exifInfo['model'] != null && asset.exifInfo['model']!.toLowerCase() == searchOptions.cameraFilter!.model!.toLowerCase());
      final matchesLensModel = (searchOptions.cameraFilter?.isEmpty() ?? true) || (asset.exifInfo['lensModel'] != null && asset.exifInfo['lensModel']!.toLowerCase() == searchOptions.cameraFilter!.lens!.toLowerCase());

      return matchesQuery && matchesMediaType && matchesDate && matchesMake && matchesModel && matchesLensModel;
    }).skip((page - 1) * pulledItems).take(pulledItems).toList();
  }

  Future<void> uploadToImmich(ImmichAsset asset, {UploadProgressController? popupController}) async {
    final cleanPath = asset.localPath?.replaceAll(r'\\', r'\');

    if (cleanPath == null || uploadQueue.contains(asset)) return;

    uploadQueue.add(asset);
    final newId = await _service.uploadToImmich(cleanPath, onProgress: (popupController != null ? (int sent, int total) {
        popupController.update(
          filename: asset.originalFileName.split('/').last,
          sent: sent,
          total: total,
        );
    } : null));

    if (newId != null) {
      final newAsset = asset.copyWith(imageSources: {...asset.imageSources, ImageSource.immich}, id: newId);
      final key = asset.pixelPairKey ?? asset.baseName;

      // Update map directly
      if (_groupedAssets.containsKey(key)) {
        final index = _groupedAssets[key]!.indexWhere((a) => a.id == asset.id);
        if (index != -1) {
          _groupedAssets[key]![index] = newAsset;
        }
      }

      state = AsyncData(_buildGalleryItems());
    }
    uploadQueue.remove(asset);
  }

  Future<Map<String, Map>?> checkExisting(List<ImmichAsset> asset) async {
    Map<String, Map> result = {};
    for (final a in asset) {
      final res = await _service.findExistingByMetadata(asset: a);
      
      if (res != null) {
        result[a.id] = res;
      }
    }
    return result;
  }

  Future<void> updateSources(String assetId, ImageSource newSource) async {
    // Update map directly
    for (final group in _groupedAssets.values) {
      final index = group.indexWhere((a) => a.id == assetId);
      if (index != -1) {
        final asset = group[index];
        final updatedAsset = asset.copyWith(imageSources: {...asset.imageSources, newSource});
        group[index] = updatedAsset;
        break;
      }
    }

    state = AsyncData(_buildGalleryItems());
  }
  
  Future<void> checkImmichStatusInBackground(List<ImmichAsset> assets) async {
    const batchSize = 50;

    for (var i = 0; i < assets.length; i += batchSize) {
      final batch = assets.sublist(i, (i + batchSize).clamp(0, assets.length));

      final results = await Future.wait(
        batch.map((a) => _service.findExistingByMetadata(asset: a)),
      );

      for (final (i, asset) in batch.enumerate) {
        if (results[i] == null) continue;
        final newAsset = asset.copyWith(
          imageSources: {...asset.imageSources, ImageSource.immich}, 
          id: results[i]!['id'] as String,
          isFavorite: results[i]!['isFavorite'] as bool
        );
        final key = asset.pixelPairKey ?? asset.baseName;
        if (_groupedAssets.containsKey(key)) {
          final index = _groupedAssets[key]!.indexWhere((a) => a.localPath == asset.localPath);
          if (index != -1) {
            _groupedAssets[key]![index] = newAsset;
          }
        }
      }
      state = AsyncData(_buildGalleryItems());
    }
  }
}

final galleryProvider = AsyncNotifierProvider<GalleryNotifier, List<GalleryItem>>(
  GalleryNotifier.new,
);