import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:photo_sync/Widgets/search_popup.dart';

class ImmichConfig {
  static String baseUrl = dotenv.env['immich_url'] ?? '';
  static String apiKey = dotenv.env['immich_api_key'] ?? '';
}


class ImmichAsset {
  final String id;
  final String type;
  final String originalFileName;
  final DateTime fileCreatedAt;
  final String? mimeType;
  final Map exifInfo;

  const ImmichAsset({
    required this.id,
    required this.type,
    required this.originalFileName,
    required this.fileCreatedAt,
    required this.mimeType, 
    required this.exifInfo,
  });
  
  factory ImmichAsset.fromJson(Map<String, dynamic> json) {
    return ImmichAsset(
      id: json['id'] as String,
      type: json['type'] as String,
      originalFileName: json['originalFileName'] as String? ?? '',
      fileCreatedAt: DateTime.tryParse(json['fileCreatedAt'] as String? ?? '') ??
          DateTime.now(),
      mimeType: json['originalMimeType'] as String?, 
      exifInfo: json['exifInfo'],
    );
  }

  ImmichAsset copyWith({
    String? id,
    String? type,
    String? originalFileName,
    DateTime? fileCreatedAt,
    String? mimeType,
    Map? exifInfo,
  }) {
    return ImmichAsset(
      id: id ?? this.id,
      type: type ?? this.type,
      originalFileName: originalFileName ?? this.originalFileName,
      fileCreatedAt: fileCreatedAt ?? this.fileCreatedAt,
      mimeType: mimeType ?? this.mimeType, 
      exifInfo: exifInfo ?? this.exifInfo,
    );
  }

  // Map metadata = {
  //   'deviceId': '',
  //   'ownerId'
  //   'createdAt'
  //   "fileModifiedAt"
  //   'isFavorite'
  //   'people'
  //   'hasMetadata'
  // }
  String thumbnailUrl({String size = 'thumbnail'}) => '${ImmichConfig.baseUrl}/api/assets/$id/thumbnail?size=$size';

  String get originalUrl => '${ImmichConfig.baseUrl}/api/assets/$id/original';

  bool get isRaw => 
      (['image/dng', 'image/arw', 'image/cr2'].contains(mimeType?.toLowerCase())) ||
      ['.dng', '.arw', '.cr2'].contains(originalFileName.toLowerCase().split('.').last);

  bool get isJpg =>
      (mimeType?.toLowerCase() == 'image/jpeg') ||
      originalFileName.toLowerCase().endsWith('.jpg') ||
      originalFileName.toLowerCase().endsWith('.jpeg');
  String? get pixelPairKey { // TODO fix to not break with other naming conventions
    return originalFileName.split('-').first;
  }
  String get baseName {
    final dot = originalFileName.lastIndexOf('.');
    return dot != -1
        ? originalFileName.substring(0, dot).toLowerCase()
        : originalFileName.toLowerCase();
  }
}


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
      // 'withStacked': false,
    });

    final items = response.data['assets']['items'] as List;
    return items.map((e) => ImmichAsset.fromJson(e)).toList();
  }

  Future<void> deleteAssets(List<String> assetIds) async {
    await _dio.delete('/assets', data: {
      'ids': assetIds,
      // 'force': true, // skip trash
    });
  }

  Future<List<ImmichAsset>> smartSearch(String query, {int page = 1, int pageSize = 80}) async {
    final response = await _dio.post('/search/smart', data: {
      'query': query,
      'type': 'IMAGE',
      'page': page,
      'size': pageSize,
      'withExif': true,
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
  Future<List<ImmichAsset>> search({
    required SearchOptions searchOptions,
    int page = 1,
    int size = 100,
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
        if (!searchOptions.display!.contains(DisplayOption.archive)) 'isArchived': true,
        if (searchOptions.display!.contains(DisplayOption.favorites)) 'isFavorite': true,
      },
      // Place filters
      if (searchOptions.placeFilter != null) ...{
        if (searchOptions.placeFilter?.country != null) 'country': searchOptions.placeFilter?.country,
        if (searchOptions.placeFilter?.state != null) 'state': searchOptions.placeFilter?.state,
        if (searchOptions.placeFilter?.city != null) 'city': searchOptions.placeFilter?.city,
      },
      // Camera filters
      if (searchOptions.cameraFilter != null) ...{
        if (searchOptions.cameraFilter?.make != null) 'make': searchOptions.cameraFilter?.make,
        if (searchOptions.cameraFilter?.model != null) 'model': searchOptions.cameraFilter?.model,
        if (searchOptions.cameraFilter?.lens != null) 'lensModel': searchOptions.cameraFilter?.lens,
      },
      'withExif': true,
    };

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

    final response = await _dio.post(endpoint, data: body);
    final assets = response.data['assets'] as Map<String, dynamic>;
    return (assets['items'] as List)
        .map((a) => ImmichAsset.fromJson(a))
        .toList();
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

class SearchSuggestions {
  final List<String> countries;
  final List<String> states;
  final List<String> cities;
  final List<String> cameraMakes;
  final List<String> cameraModels;
  final List<String> lensModels;

  const SearchSuggestions({
    required this.countries,
    required this.states,
    required this.cities,
    required this.cameraMakes,
    required this.cameraModels, 
    required this.lensModels,
  });
}