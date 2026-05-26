import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:photo_sync/Widgets/search_popup.dart';
import 'package:photo_sync/models/immich_models.dart';

class ImmichService {
  late final Dio _dio;

  ImmichService() {
    _dio = Dio(BaseOptions(
      baseUrl: '${ImmichConfig.baseUrl}/api',
      headers: {
        'x-api-key': ImmichConfig.apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  Future<List<ImmichAsset>> fetchImages({int page = 1, int pageSize = 80}) async {
    final response = await _dio.post('/search/metadata', data: {
      'type': 'IMAGE',
      'page': page,
      'size': pageSize,
      'withArchived': false,
      'withExif': true,
      'withPeople': true,
      // 'withStacked': false,
    });

    final items = response.data['assets']['items'] as List;
    return items.map((e) => ImmichAsset.fromJson(e)).toList();
  }

  Future<void> deleteAssets(List<String> assetIds, {force = false}) async {
    await _dio.delete('/assets', data: {
      'ids': assetIds,
      'force': force,
    });
  }

  Future<void> favoriteImmichAsset(String assetId, bool isFavorite) async {
    await _dio.put('/assets/$assetId', data: {
      'isFavorite': isFavorite,
    });
  }

  Future<bool> restoreFromTrash(List<String> assetIds) async {
    final response = await _dio.post('/trash/restore/assets', data: {
      'ids': assetIds,
    });
    return response.statusCode == 200;
  }
  
  Future<List<ImmichPerson>> getPeople() async {
    final response = await _dio.get('/people');
    final data = response.data as Map<String, dynamic>;
    return (data['people'] as List)
      .map((p) => ImmichPerson.fromJson(p))
      .toList();
  }

  Future<List<ImmichAsset>> smartSearch(String query, {int page = 1, int pageSize = 80}) async {
    final response = await _dio.post('/search/smart', data: {
      'query': query,
      'type': 'IMAGE',
      'page': page,
      'size': pageSize,
      'withExif': true,
      'withPeople': true,
    });

    final items = response.data['assets']['items'] as List;
    return items.map((e) => ImmichAsset.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getAssetMetadata(String assetId) async {
    final response = await _dio.get('/assets/$assetId');
    return response.data as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> changeAssetDate(String assetId, String dateString) async {
    final response = await _dio.put('/assets/$assetId', data: {
      "dateTimeOriginal": dateString,
      "fileCreatedAt": dateString,
      "fileModifiedAt": dateString
    });
    return response.data as Map<String, dynamic>;
  }
  
  Future<SearchSuggestions> getSearchSuggestions() async {
    final results = await Future.wait([
      _dio.get('/search/suggestions', queryParameters: {'type': 'country'}),
      _dio.get('/search/suggestions', queryParameters: {'type': 'state'}),
      _dio.get('/search/suggestions', queryParameters: {'type': 'city'}),
      _dio.get('/search/suggestions', queryParameters: {'type': 'camera-make'}),
      _dio.get('/search/suggestions', queryParameters: {'type': 'camera-model'}),
      _dio.get('/search/suggestions', queryParameters: {'type': 'camera-lens-model'}),
    ]);

    return SearchSuggestions(
      countries: List<String>.from(results[0].data),
      states: List<String>.from(results[1].data),
      cities: List<String>.from(results[2].data),
      cameraMakes: List<String>.from(results[3].data),
      cameraModels: List<String>.from(results[4].data),
      lensModels: List<String>.from(results[5].data),
    );
  }

  Future<(List<ImmichAsset>, String?)> search({
    required SearchOptions searchOptions,
    int page = 1,
    int size = 100,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{
      'page': page,
      'size': size,
      if (searchOptions.startDate != null) 'takenAfter': searchOptions.startDate!.toUtc().toIso8601String(),
      if (searchOptions.endDate != null) 'takenBefore': searchOptions.endDate!.toUtc().toIso8601String(),
      if (searchOptions.mediaType != null && searchOptions.mediaType != MediaType.all) 'type': switch (searchOptions.mediaType) {
        MediaType.image => 'IMAGE',
        MediaType.video => 'VIDEO',
        _ => null
      },
      if (searchOptions.tags != null && searchOptions.tags!.isNotEmpty) 'tagIds': searchOptions.tags!.toList(),
      if (searchOptions.untagged != null) 'isNotInAlbum': searchOptions.untagged, // closest equivalent
      // Display options
      if (searchOptions.display != null) ...{
        // if (display.contains(DisplayOption. notInAlbum)) 'withArchived': true,
        if (searchOptions.display!.contains(DisplayOption.archive)) 'isArchived': true,
        if (searchOptions.display!.contains(DisplayOption.favorites)) 'isFavorite': true,
      },
      // Place filters
      if (!searchOptions.placeFilter.isEmpty()) ...{
        if (searchOptions.placeFilter.country != null) 'country': searchOptions.placeFilter.country,
        if (searchOptions.placeFilter.state != null) 'state': searchOptions.placeFilter.state,
        if (searchOptions.placeFilter.city != null) 'city': searchOptions.placeFilter.city,
      },
      // Camera filters
      if (!searchOptions.cameraFilter.isEmpty()) ...{
        if (searchOptions.cameraFilter.make != null) 'make': searchOptions.cameraFilter.make,
        if (searchOptions.cameraFilter.model != null) 'model': searchOptions.cameraFilter.model,
        if (searchOptions.cameraFilter.lens != null) 'lensModel': searchOptions.cameraFilter.lens,
      },
      if (searchOptions.isFavorite == true) 'isFavorite': true,
      if (searchOptions.isTrashed == true) 'trashedBefore': DateTime.now().toUtc().toIso8601String(),
      "order": searchOptions.sortOrder == SortOrder.asc ? 'asc' : 'desc',
      'withExif': true,
      'withPeople': true,
      if (searchOptions.personIds.isNotEmpty) 'personIds': searchOptions.personIds.toList(),
      if (searchOptions.tags != null && searchOptions.tags!.isNotEmpty) 'tagIds': searchOptions.tags!.toList(),
    };
    if (searchOptions.searchType == SearchType.context && searchOptions.query.trim().isEmpty) {
      searchOptions = searchOptions.copyWith(searchType: SearchType.fileName);
    }
    final String endpoint = switch (searchOptions.searchType) {
      SearchType.context => '/search/smart',
      _ => '/search/metadata',
    };

    // Smart search requires a query string, metadata search doesn't
    if (searchOptions.searchType == SearchType.context) {
      body['query'] = searchOptions.query.isNotEmpty ? searchOptions.query : '*';
    } else if (searchOptions.query.isNotEmpty) {
      body['originalFileName'] = searchOptions.query;
    }

    final response = await _dio.post(endpoint, data: body, cancelToken: cancelToken);
    final assets = response.data['assets'] as Map<String, dynamic>;
    return (
      (assets['items'] as List).map((a) => ImmichAsset.fromJson(a)).toList(), 
      response.data['assets']['nextPage'] as String?
      );
  }

  Future<String?> uploadToImmich(String filePath, {Function? onProgress}) async {
    final file = File(filePath);
    final stat = await file.stat();
    final filename = p.basename(filePath);

    final formData = FormData.fromMap({
      'deviceAssetId': filePath,
      'deviceId': 'photo-sync-desktop',
      'fileCreatedAt': stat.modified.toIso8601String(),
      'fileModifiedAt': stat.modified.toIso8601String(),
      'assetData': await MultipartFile.fromFile(filePath, filename: filename),
    });

    final response = await _dio.post(
      '/assets',
      data: formData,
      onSendProgress: (sent, total) {
        onProgress?.call(sent, total);
      },
    );
    Set<int> allowedStatusCodes = {200, 201};
    if (allowedStatusCodes.contains(response.statusCode)) { // todo cache it later?
      return response.data['id'] as String;
    }
    return null;
  }

  Future<Map?> findExistingByMetadata({
    required ImmichAsset asset
  }) async {
    final createdAt = asset.fileCreatedAt.toUtc();
    final response = await _dio.post('/search/metadata', data: {
      'originalFileName': asset.originalFileName,
      'takenAfter': createdAt.subtract(Duration(seconds: 1)).toIso8601String(),
      'takenBefore': createdAt.add(Duration(seconds: 1)).toIso8601String(),
    });

    final assets = (response.data['assets']['items'] as List);
    return assets.isEmpty ? null : assets.first;
  }

  Future<Map<String, int>> fetchMonthBuckets({bool? isFavorite, bool? isTrashed, bool? isArchived, String? personId, Set<String>? tags, CancelToken? cancelToken}) async {
    final response = await _dio.get('/timeline/buckets', queryParameters: {
      'size': 'MONTH',
      'isArchived': isArchived ?? false,
      'isTrashed': isTrashed ?? false,
      'isFavorite': ?isFavorite,
      'personId': ?personId,
      'tagId': ?tags?.first,
    });

    final result = <String, int>{};
    for (final bucket in response.data as List) {
      final dt = DateTime.parse(bucket['timeBucket'] as String);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      result[key] = bucket['count'] as int;
    }
    return result; // e.g. {"2025-04": 120, "2025-03": 88, ...}
  }

  Future<List<ImmichAsset>> fetchBucketAssets(String timeBucket, {SearchOptions? initOptions, CancelToken? cancelToken, F}) async {
    // timeBucket: e.g. "2025-04-01T00:00:00.000Z"
    final dt = DateTime.parse(timeBucket);
    final start = DateTime(dt.year, dt.month, 1);
    final end = DateTime(dt.year, dt.month + 1, 1); // rolls over correctly

    List<ImmichAsset> all = [];
    String? nextPage;

    do {
      SearchOptions options = (initOptions ?? SearchOptions()).copyWith(startDate: start, endDate: end);
      final items = await search(searchOptions: options, page: nextPage != null ? int.parse(nextPage) : 1, size: 1000, cancelToken: cancelToken);
 
      all.addAll(items.$1);
      nextPage = items.$2;
    } while (nextPage != null);

    return all;
  }

  Future<File> downloadAsset(String id, String savePath, {Function(int, int)? onProgress}) async {
    await _dio.download(
      '/assets/$id/original',
      savePath,
      queryParameters: {
        'id': id,
      },
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress?.call(received, total);
        }
      },
    );
    return File(savePath);
  }

  Future<bool> addFace({
    required String assetId, 
    required String personId,
    required Map<String, double> boundingBox,
    required (int, int) imageSize,
  }) async {
    final response = await _dio.post('/faces', data: {
      'assetId': assetId,
      'imageWidth': imageSize.$1,
      'imageHeight': imageSize.$2,
      'personId': personId,
      'width': ((boundingBox['x2']! - boundingBox['x1']!) * imageSize.$1).round(),
      'height': ((boundingBox['y2']! - boundingBox['y1']!) * imageSize.$2).round(),
      'x': (boundingBox['x1']! * imageSize.$1).round(),
      'y': (boundingBox['y1']! * imageSize.$2).round(),
    });
    return {200, 201}.contains(response.statusCode);
  }
  
  Future<bool> removeFace({
    required String faceId,
    bool force = true,
  }) async {
    final response = await _dio.delete('/faces/$faceId', data: {
      'force': force,
    });
    return {200, 201, 204}.contains(response.statusCode);
  }

  Future<List<AssetFace>> getFaces({
    required String assetId, 
  }) async {
    final response = await _dio.get('/faces', queryParameters: {
      'id': assetId,
    });
    final data = response.data as List;
    return data.map((d) => AssetFace.fromJson(d)).toList();
  }

  Future<bool> reAssignFace({
    required String faceId,
    required String assetId,
    required String newPersonId,
  }) async {
    final response = await _dio.put('/faces/$newPersonId', data: {
      'id': faceId,
    });
    return {200, 201}.contains(response.statusCode);
  }

  Future<ServerStorageInfo> getServerStorage() async {
    final response = await _dio.get('/server/storage');
    return ServerStorageInfo.fromJson(response.data);
  }

  Future<List<ImmichTag>> getAllTags() async {
    final response = await _dio.get('/tags');
    return (response.data as List).map((d) => ImmichTag.fromJson(d)).toList();
  }

  Future<ImmichTag> createTag(ImmichTag tag) async {
    final response = await _dio.post('/tags', data: {
      'color': tag.color.toARGB32().toRadixString(16).padLeft(8, '0'),
      'name': tag.name,
      if (tag.parentId != null) 'parentId': tag.parentId,
    });
    return ImmichTag.fromJson(response.data);
  }

  Future<ImmichTag> deleteTag(String tag) async {
    final response = await _dio.delete('/tags/$tag');
    return ImmichTag.fromJson(response.data);
  }

  Future<ImmichTag> updateTag(ImmichTag tag) async {
    final response = await _dio.put('/tags/${tag.id}', data: {
      'color': tag.color.toARGB32().toRadixString(16).padLeft(8, '0'),
    });
    return ImmichTag.fromJson(response.data);
  }
}

sealed class GalleryItem {
  const GalleryItem();
}

extension GalleryItemX on GalleryItem {
  ImmichAsset get leadAsset => switch (this) {
    SingleAsset(asset: var a) => a,
    StackedAssets(primary: var p) => p,
  };
  bool get isRaw => switch (this) {
    SingleAsset(asset: var a) => a.isRaw,
    StackedAssets(containsRaw: var raw) => raw,
  };
  String thumbnailUrl({String size = 'thumbnail'}) => leadAsset.thumbnailUrl(size: size);
  String get originalFileName => leadAsset.originalFileName;
  String get id => leadAsset.id;
  DateTime get fileCreatedAt => leadAsset.fileCreatedAt;
  bool get isLocal => !leadAsset.imageSources.contains(ImageSource.immich);
  Set<ImageSource> get imageSources => leadAsset.imageSources;
}


class SingleAsset extends GalleryItem {
  final ImmichAsset asset;
  const SingleAsset(this.asset);
}

class StackedAssets extends GalleryItem {
  final ImmichAsset primary;
  final List<ImmichAsset> children;
  final bool containsRaw;
  const StackedAssets({required this.primary, this.containsRaw = false, required this.children});
}