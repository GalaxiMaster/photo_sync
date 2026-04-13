import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';

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

  const ImmichAsset({
    required this.id,
    required this.type,
    required this.originalFileName,
    required this.fileCreatedAt,
    required this.mimeType,
  });

  factory ImmichAsset.fromJson(Map<String, dynamic> json) {
    return ImmichAsset(
      id: json['id'] as String,
      type: json['type'] as String,
      originalFileName: json['originalFileName'] as String? ?? '',
      fileCreatedAt: DateTime.tryParse(json['fileCreatedAt'] as String? ?? '') ??
          DateTime.now(),
      mimeType: json['originalMimeType'] as String?,
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
      // 'withStacked': false,
    });

    final items = response.data['assets']['items'] as List;
    return items.map((e) => ImmichAsset.fromJson(e)).toList();
  }

  Future<void> deleteAssets(List<String> assetIds) async {
    final futures = assetIds.map((id) => deleteAsset(id));
    await Future.wait(futures);
  }

  Future<void> deleteAsset(String assetId) async {
    await _dio.delete('/assets', data: {
      'ids': [assetId],
      'force': true,
    });
  }
  Future<List<ImmichAsset>> smartSearch(String query, {int page = 1, int pageSize = 80}) async {
    final response = await _dio.post('/search/smart', data: {
      'query': query,
      'type': 'IMAGE',
      'page': page,
      'size': pageSize,
    });

    final items = response.data['assets']['items'] as List;
    return items.map((e) => ImmichAsset.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getAssetMetadata(String assetId) async {
    final response = await _dio.get('/assets/$assetId');
    return response.data as Map<String, dynamic>;
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