import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:photo_sync/Widgets/progress_popups.dart';
import 'package:photo_sync/Widgets/search_popup.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/database_providers.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:photo_sync/services/tools.dart';

class MonthBucket {
  final String timeBucket;
  final String key;
  final int year;
  final int month;
  final int count;
  final List<GalleryItem>? assets;
  final bool loading;

  const MonthBucket({
    required this.timeBucket,
    required this.key,
    required this.year,
    required this.month,
    required this.count,
    this.assets,
    this.loading = false,
  });

  MonthBucket copyWith({List<GalleryItem>? assets, bool? loading, int? count}) =>
    MonthBucket(
      timeBucket: timeBucket,
      key: key,
      year: year,
      month: month,
      count: count ?? this.count,
      assets: assets ?? this.assets,
      loading: loading ?? this.loading,
    );
}

class GalleryBucketState {
  final List<MonthBucket> buckets;
  final bool initialising;
  final String? error;

  const GalleryBucketState({
    this.buckets = const [],
    this.initialising = false,
    this.error,
  });

  GalleryBucketState copyWith({
    List<MonthBucket>? buckets,
    bool? initialising,
    String? error,
  }) => GalleryBucketState(
    buckets: buckets ?? this.buckets,
    initialising: initialising ?? this.initialising,
    error: error ?? this.error,
  );
}

final immichServiceProvider = Provider<ImmichService>((_) => ImmichService());

final galleryBucketProvider = NotifierProvider<GalleryBucketNotifier, GalleryBucketState>(
  GalleryBucketNotifier.new,
);

final flatGalleryProvider = Provider<List<GalleryItem>>( // not really used
  (ref) => ref.watch(galleryBucketProvider).buckets.expand<GalleryItem>((b) => b.assets ?? []).toList(),
);

class SearchOptionsNotifier extends Notifier<SearchOptions> {
  @override
  SearchOptions build() {
    return SearchOptions(query: '', searchType: SearchType.context);
  }

  void updateState(SearchOptions options) {
    state = options;
  }

  SearchOptions updateQuery(String query) {
    state = state.copyWith(query: query);
    return state;
  }
}

final searchOptionsProvider = NotifierProvider<SearchOptionsNotifier, SearchOptions>(
  SearchOptionsNotifier.new,
);

class GalleryBucketNotifier extends Notifier<GalleryBucketState> {
  ImmichService get _service => ref.read(immichServiceProvider);
  bool isLocal = false;
  List<ImmichAsset> fullLocal = [];

  SearchOptions get _activeOptions => ref.read(searchOptionsProvider);
  CancelToken _cancelToken = CancelToken();

  bool get hasMore => _hasMore;
  bool _hasMore = false;

  Set<ImmichAsset> uploadQueue = {};

  int pulledItems = 80;

  final Set<String> _inflight = {};
  int _page = 1;

  List<MonthBucket>? _priorBuckets;
  // The fetcher used by the current flat mode - kept so loadMore() can request the next page without knowing which mode is active.
  Future<List<ImmichAsset>> Function(int page)? _flatFetcher;

  @override
  GalleryBucketState build() {
    Future.microtask(_initRemote);
    return const GalleryBucketState(initialising: true);
  }

  Future<void> refresh() async {
    if (isLocal) {
      state = GalleryBucketState(buckets: _bucketiseLocal(fullLocal));
    } else {
      await _initRemote();
      ref.invalidate(downloadedPhotosProvider);
    }
  }

  Future<void> loadCloud({bool? isFavorite, bool? isTrashed, bool? isArchived, String? personId}) async {
    cancel();
    isLocal = false;
    fullLocal = [];
    _priorBuckets = null;
    _flatFetcher = null;
    final newOptions = SearchOptions(query: '', searchType: SearchType.context, isFavorite: isFavorite, isTrashed: isTrashed, personIds: {?personId});
    ref.read(searchOptionsProvider.notifier).updateState(newOptions);
    await _initRemote();
  }

  Future<void> loadLocal(List<ImmichAsset> assets) async {
    isLocal = true;
    fullLocal = [...assets]
      ..sort((a, b) => b.fileCreatedAt.compareTo(a.fileCreatedAt));
    _hasMore = fullLocal.length > pulledItems;
    _page = 1;
    _priorBuckets = null;
    _flatFetcher = null;

    state = GalleryBucketState(buckets: _bucketiseLocal(fullLocal));
    checkImmichStatusInBackground(fullLocal.take(pulledItems).toList());
  }

  void searchFromOptions(SearchOptions options, {bool force = false}) async {
    final results = await smartSearch(options, force: force);
    if (results == null) return;
    _hasMore = results.length >= pulledItems;
    _setFlatBucket(_groupAssets(await _applyLocalPaths(results)), hasMore: _hasMore);
  }

  Future<List<ImmichAsset>?> smartSearch(
    SearchOptions options, {
    bool fetchMore = false,
    bool force = false,
  }) async {
    ref.read(searchOptionsProvider.notifier).updateState(options);

    // Empty context search -> restore prior
    if (options.isEmpty() && !force) {
      _restorePrior();
      return null;
    }

    if (!fetchMore) {
      _priorBuckets ??= state.buckets;
      _page = 1;
      state = state.copyWith(initialising: true);
    } else {
      _page++;
    }

    final results = isLocal
      ? localSearch(searchOptions: options, page: _page)
      : (await _service.search(searchOptions: options, page: _page, cancelToken: _cancelToken)).$1;

    return results;
  }

  List<ImmichAsset> localSearch({
    required SearchOptions searchOptions,
    required int page,
  }) {
    return fullLocal.sorted((a, b) {
      final cmp = a.fileCreatedAt.compareTo(b.fileCreatedAt);
      return searchOptions.sortOrder == SortOrder.desc ? -cmp : cmp;
    })
    .where((asset) {
      final matchesQuery = searchOptions.query.isEmpty 
        || asset.baseName.toLowerCase().contains(searchOptions.query.toLowerCase());
      final matchesMediaType = searchOptions.mediaType == null 
        || asset.isOfType(searchOptions.mediaType!);
      final matchesDate = (searchOptions.startDate == null 
        || asset.fileCreatedAt.isAfter(searchOptions.startDate!)) &&
          (searchOptions.endDate == null || asset.fileCreatedAt.isBefore(searchOptions.endDate!));
      final matchesMake = (searchOptions.cameraFilter.isEmpty()) 
        ||  (asset.exifInfo['make'] != null && asset.exifInfo['make']!.toLowerCase() == searchOptions.cameraFilter.make!.toLowerCase());
      final matchesModel = (searchOptions.cameraFilter.isEmpty()) 
        ||  (asset.exifInfo['model'] != null && asset.exifInfo['model']!.toLowerCase() == searchOptions.cameraFilter.model!.toLowerCase());
      final matchesLensModel = (searchOptions.cameraFilter.isEmpty()) 
        ||  (asset.exifInfo['lensModel'] != null && asset.exifInfo['lensModel']!.toLowerCase() == searchOptions.cameraFilter.lens!.toLowerCase());

      return matchesQuery && matchesMediaType && matchesDate && matchesMake && matchesModel && matchesLensModel;
    }).skip((page - 1) * pulledItems).take(pulledItems).toList();
  }

  Future<void> loadBucket(String key) async {
    // Flat modes have no buckets to lazy-load.
    if (isLocal || _priorBuckets != null) return;
    final idx = state.buckets.indexWhere((b) => b.key == key);
    if (idx == -1) return;
    final bucket = state.buckets[idx];
    if (bucket.assets != null || bucket.loading || _inflight.contains(key)) {
      return;
    }
    _inflight.add(key);
    _replaceBucket(idx, bucket.copyWith(loading: true));
    try {
      final raw = await _service.fetchBucketAssets(bucket.timeBucket, initOptions: _activeOptions, cancelToken: _cancelToken);
      final newIdx = state.buckets.indexWhere((b) => b.key == key);
      if (newIdx != -1) {
        _replaceBucket(
          newIdx,
          state.buckets[newIdx].copyWith(
            assets: _groupAssets(await _applyLocalPaths(raw)),
            loading: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Gallery] loadBucket error $key: $e');
      final newIdx = state.buckets.indexWhere((b) => b.key == key);
      if (newIdx != -1) {
        _replaceBucket(newIdx, state.buckets[newIdx].copyWith(loading: false));
      }
    } finally {
      _inflight.remove(key);
    }
  }

  void prefetchAround(int centreIndex, {int radius = 1}) {
    if (isLocal || _priorBuckets != null) return;
    final start = max(0, centreIndex - radius);
    final end = min(state.buckets.length - 1, centreIndex + radius);
    for (var i = start; i <= end; i++) {
      loadBucket(state.buckets[i].key);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;

    List<ImmichAsset> results;
    if (_flatFetcher != null) {
      _page++;
      results = await _flatFetcher!(_page);
    } else {
      final r = await smartSearch(_activeOptions, fetchMore: true);
      if (r == null) return;
      results = r;
    }

    _hasMore = results.length >= pulledItems;
    final newItems = _groupAssets(await _applyLocalPaths(results));
    final existing =
        state.buckets.isNotEmpty ? (state.buckets.first.assets ?? []) : <GalleryItem>[];
    _setFlatBucket([...existing, ...newItems], hasMore: _hasMore);
  }

  void removeAssets(Set<ImmichAsset> toRemove) {
    final updated = state.buckets.map((b) {
      if (b.assets == null) return b;
      final filtered =
          b.assets!.where((i) => !toRemove.contains(i.leadAsset)).toList();
      return b.copyWith(assets: filtered, count: filtered.length);
    }).toList();
    state = state.copyWith(buckets: updated);
    fullLocal.removeWhere(toRemove.contains);
  }

  void updateAsset(ImmichAsset updated) {
    final newBuckets = state.buckets.map((b) {
      if (b.assets == null) return b;
      final idx = b.assets!.indexWhere((i) => i.leadAsset.id == updated.id);
      if (idx == -1) return b;
      final list = List<GalleryItem>.of(b.assets!);
      list[idx] = SingleAsset(updated);
      return b.copyWith(assets: list);
    }).toList();
    state = state.copyWith(buckets: newBuckets);
  }

  void toggleFavorite(ImmichAsset asset) async {
    final newValue = !asset.isFavorite;
    updateAsset(asset.copyWith(isFavorite: newValue));
    await _service.favoriteImmichAsset(asset.id, newValue);
  }

  Future<bool> restoreFromTrash(ImmichAsset asset) async {
    removeAssets({asset});
    return _service.restoreFromTrash([asset.id]);
  }

  Future<void> deleteAssets(
    Set<ImmichAsset> assets, {
    bool isTrashed = false,
    Function(List<ImmichAsset>)? deleteFromExternalSource,
  }) async {
    List<ImmichAsset> externalSourceAssets = [];
    try {
      if (isLocal) {
        final toDelete = fullLocal.where(assets.contains).toList();
        for (final asset in toDelete) {
          fullLocal.remove(asset);
          if (asset.localPath != null) {
            final f = File(asset.localPath!);
            if (f.existsSync()) f.deleteSync();
            if (asset.imageSources.contains(ImageSource.immich)) {
              externalSourceAssets.add(asset);
            }
          }
        }
        if (externalSourceAssets.isNotEmpty &&
            deleteFromExternalSource != null) {
          final confirmed =
              await deleteFromExternalSource(externalSourceAssets);
          await _service.deleteAssets(
            confirmed.map((e) => e.id).toList(),
            force: true,
          );
        }
      } else {
        await _service.deleteAssets(
          assets.map((e) => e.id).toList(),
          force: isTrashed,
        );
        for (final asset in assets) {
          if (asset.localPath != null) {
            final f = File(asset.localPath!);
            if (!f.existsSync()) continue;
            externalSourceAssets.add(asset);
          }
        }
        if (externalSourceAssets.isNotEmpty &&
            deleteFromExternalSource != null) {
          final confirmed =
              await deleteFromExternalSource(externalSourceAssets);
          for (final a in confirmed) {
            final f = File(a.localPath!);
            if (f.existsSync()) f.deleteSync();
          }
        }
      }
      removeAssets(assets);
      ref.read(selectionProvider.notifier).clear();
    } catch (e) {
      throw Exception('Failed to delete assets: $e');
    }
  }

  Future<void> uploadToImmich(
    ImmichAsset asset, {
    ProgressController? popupController,
  }) async {
    final cleanPath = asset.localPath?.replaceAll(r'\\', r'\');
    if (cleanPath == null || uploadQueue.contains(asset)) return;
    uploadQueue.add(asset);
    try {
      final newId = await _service.uploadToImmich(
        cleanPath,
        onProgress: popupController != null
          ? (sent, total) => popupController.update(
                filename: asset.originalFileName.split('/').last,
                sent: sent,
                total: total,
              )
          : null,
      );
      if (newId != null) {
        updateAsset(asset.copyWith(
          imageSources: {...asset.imageSources, ImageSource.immich},
          id: newId,
        ));
      }
    } finally {
      uploadQueue.remove(asset);
    }
  }

  Future<Map<String, Map>?> checkExisting(List<ImmichAsset> assets) async {
    final result = <String, Map>{};
    for (final a in assets) {
      final res = await _service.findExistingByMetadata(asset: a);
      if (res != null) result[a.id] = res;
    }
    return result;
  }

  Future<void> updateSources(String assetId, ImageSource newSource) async {
    final newBuckets = state.buckets.map((b) {
      if (b.assets == null) return b;
      final idx = b.assets!.indexWhere((i) => i.leadAsset.id == assetId);
      if (idx == -1) return b;
      final asset = b.assets![idx].leadAsset;
      final list = List<GalleryItem>.of(b.assets!);
      list[idx] = SingleAsset(
        asset.copyWith(imageSources: {...asset.imageSources, newSource}),
      );
      return b.copyWith(assets: list);
    }).toList();
    state = state.copyWith(buckets: newBuckets);
  }

  Future<void> changeAssetDate(ImmichAsset asset, String dateString) async {
    updateAsset(asset.copyWith(fileCreatedAt: DateTime.parse(dateString)));
    await _service.changeAssetDate(asset.id, dateString);
  }

  Future<List<ImmichPerson>> getPeople() => _service.getPeople();

  Future<void> checkImmichStatusInBackground(List<ImmichAsset> assets) async {
    const batchSize = 50;
    for (var i = 0; i < assets.length; i += batchSize) {
      final batch = assets.sublist(i, min(i + batchSize, assets.length));
      final results = await Future.wait(
        batch.map((a) => _service.findExistingByMetadata(asset: a)),
      );
      for (final (j, asset) in batch.indexed) {
        final match = results[j];
        if (match == null) continue;
        final enriched = asset.copyWith(
          imageSources: {...asset.imageSources, ImageSource.immich},
          id: match['id'] as String,
          isFavorite: match['isFavorite'] as bool,
        );
        final li =
            fullLocal.indexWhere((a) => a.localPath == asset.localPath);
        if (li != -1) fullLocal[li] = enriched;
        updateAsset(enriched);
      }
    }
  }

  Future<void> _initRemote() async {
    _inflight.clear();
    isLocal = false;
    state = const GalleryBucketState(initialising: true);
    try {
      final raw = await _service.fetchMonthBuckets(
        isFavorite: _activeOptions.isFavorite, 
        isTrashed: _activeOptions.isTrashed, 
        personId: _activeOptions.personIds.elementAtOrNull(0), 
        cancelToken: _cancelToken
      );

      final buckets = raw.entries.map((e) {
        final parts = e.key.split('-');
        return MonthBucket(
          timeBucket: '${e.key}-01T00:00:00.000Z',
          key: e.key,
          year: int.parse(parts[0]),
          month: int.parse(parts[1]),
          count: e.value,
        );
      }).toList()..sort((a, b) {
        final cmp = b.year.compareTo(a.year);
        return cmp != 0 ? cmp : b.month.compareTo(a.month);
      });
      state = GalleryBucketState(buckets: buckets);
    } catch (e) {
      state = state.copyWith(initialising: false, error: e.toString());
    }
  }

  void _setFlatBucket(List<GalleryItem> items, {required bool hasMore}) {
    state = GalleryBucketState(
      buckets: [
        MonthBucket(
          timeBucket: '',
          key: '_flat',
          year: 0,
          month: 0,
          count: items.length,
          assets: items,
        ),
      ],
    );
    _hasMore = hasMore;
  }
  Future<List<ImmichAsset>> _applyLocalPaths(List<ImmichAsset> assets) async {
    final downloaded = await ref.read(downloadedPhotosProvider.future);
    if (downloaded.isEmpty) return assets;

    final dir = getLocalPhotoDirectory();
    return assets.map((asset) {
      if (!downloaded.contains(asset.originalFileName)) return asset;
      final localPath = '$dir/${asset.originalFileName}';
      return asset.copyWith(
        localPath: localPath,
        imageSources: {...asset.imageSources, ImageSource.local},
      );
    }).toList();
  }
  void _restorePrior() {
    if (_priorBuckets != null) {
      state = GalleryBucketState(buckets: _priorBuckets!);
      _priorBuckets = null;
    }
    _flatFetcher = null;
    _hasMore = false;
  }

  List<GalleryItem> _groupAssets(List<ImmichAsset> assets) {
    final Map<String, List<ImmichAsset>> grouped = {};
    for (final asset in assets) {
      grouped.putIfAbsent(asset.pixelPairKey ?? asset.baseName, () => [])
          .add(asset);
    }
    final result = <GalleryItem>[];
    for (final group in grouped.values) {
      if (group.isEmpty) continue;
      if (group.length == 1) {
        result.add(SingleAsset(group.first));
      } else {
        final primary = group.firstWhere(
          (a) {
            final name = a.originalFileName.toLowerCase().split('-').last;
            return name.contains('01') || name.contains('cover');
          },
          orElse: () =>
              group.firstWhere((a) => a.isJpg, orElse: () => group.first),
        );
        result.add(StackedAssets(
          primary: primary,
          containsRaw: group.any((a) => a.isRaw),
          children: group.where((a) => a.id != primary.id).toList(),
        ));
      }
    }
    return result;
  }

  List<MonthBucket> _bucketiseLocal(List<ImmichAsset> sorted) {
    final Map<String, List<ImmichAsset>> byMonth = {};
    for (final asset in sorted) {
      final d = asset.fileCreatedAt;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(asset);
    }
    return byMonth.entries.map((e) {
      final parts = e.key.split('-');
      return MonthBucket(
        timeBucket: '${e.key}-01T00:00:00.000Z',
        key: e.key,
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
        count: e.value.length,
        assets: _groupAssets(e.value),
      );
    }).toList()
      ..sort((a, b) {
        final cmp = b.year.compareTo(a.year);
        return cmp != 0 ? cmp : b.month.compareTo(a.month);
      });
  }

  void _replaceBucket(int idx, MonthBucket updated) {
    final list = List<MonthBucket>.of(state.buckets);
    list[idx] = updated;
    state = state.copyWith(buckets: list);
  }

  void cancel() {
    _cancelToken.cancel();
    _cancelToken = CancelToken();
    _inflight.clear();
  }

  Future<File> downloadAsset(ImmichAsset asset, ProgressController? popupController) async {
    Directory? dir = await getLocalPhotoDirectory();

    final String sanitizedName = asset.originalFileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final String fullSavePath = p.join(dir.path, sanitizedName);
    
    final File file =  await _service.downloadAsset(asset.id, fullSavePath, onProgress: popupController != null
      ? (received, total) => popupController.update(
            filename: asset.originalFileName.split('/').last,
            sent: received,
            total: total,
          )
      : null,
    );
    updateSources(asset.id, ImageSource.local);
    return file;
  }
}