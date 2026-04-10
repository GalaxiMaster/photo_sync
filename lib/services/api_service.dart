import 'package:flutter_dotenv/flutter_dotenv.dart';
  import 'dart:convert';
  import 'package:http/http.dart' as http;

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

    String thumbnailUrl({String size = 'thumbnail'}) => '${ImmichConfig.baseUrl}/api/assets/$id/thumbnail?size=$size';

    String get originalUrl => '${ImmichConfig.baseUrl}/api/assets/$id/original';

    bool get isDng =>
        (mimeType?.toLowerCase() == 'image/dng') ||
        originalFileName.toLowerCase().endsWith('.dng');

    bool get isJpg =>
        (mimeType?.toLowerCase() == 'image/jpeg') ||
        originalFileName.toLowerCase().endsWith('.jpg') ||
        originalFileName.toLowerCase().endsWith('.jpeg');
    String? get pixelRawPairKey {
      // Match everything up to and including ".RAW"
      final match = RegExp(r'^(.+\.RAW)-', caseSensitive: false)
          .firstMatch(originalFileName);
      return match?.group(1)?.toLowerCase();
    }
    String get baseName {
      final dot = originalFileName.lastIndexOf('.');
      return dot != -1
          ? originalFileName.substring(0, dot).toLowerCase()
          : originalFileName.toLowerCase();
    }
  }


  class ImmichService {
    static final _headers = {
      'x-api-key': ImmichConfig.apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    Future<List<ImmichAsset>> fetchImages({
      int page = 1,
      int pageSize = 60,
    }) async {
      final uri = Uri.parse('${ImmichConfig.baseUrl}/api/search/metadata');

      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'type': 'IMAGE',
          'page': page,
          'size': pageSize,
          'withArchived': false,
          'withStacked': false,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Immich error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['assets']['items'] as List<dynamic>);
      return items
          .map((e) => ImmichAsset.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }


sealed class GalleryItem {
  const GalleryItem();
}

class SingleAsset extends GalleryItem {
  final ImmichAsset asset;
  const SingleAsset(this.asset);
}

class StackedAssets extends GalleryItem {
  final ImmichAsset primary;
  final List<ImmichAsset> children;
  const StackedAssets({required this.primary, required this.children});
}