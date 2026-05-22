import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  final String? localPath;
  final bool isFavorite;
  final Set<ImageSource> imageSources;
  final String? deviceId;
  final bool? isTrashed;
  final Set<String> people;
  
  const ImmichAsset({
    required this.id,
    required this.type,
    required this.originalFileName,
    required this.fileCreatedAt,
    required this.mimeType, 
    required this.exifInfo, 
    this.isFavorite = false,
    this.localPath, 
    this.imageSources = const {ImageSource.immich}, 
    this.deviceId,
    this.isTrashed,
    this.people = const {},
  });
  
  factory ImmichAsset.fromJson(Map<String, dynamic> json) {
    final localPath = (json['deviceAssetId'] ?? '').contains('.')
        ? json['deviceAssetId'] as String?
        : null;

    return ImmichAsset(
      id: json['id'] as String,
      type: json['type'] as String,
      originalFileName: json['originalFileName'] as String? ?? '',
      fileCreatedAt: DateTime.tryParse(json['fileCreatedAt'] as String? ?? '') ?? DateTime.now(),
      mimeType: json['originalMimeType'] as String?,
      exifInfo: json['exifInfo'],
      isFavorite: json['isFavorite'] ?? false,
      deviceId: json['deviceId'] as String?,
      isTrashed: json['isTrashed'] as bool?,
      localPath: localPath,
      imageSources: {
        ImageSource.immich,
        if (localPath != null) ImageSource.local,
      },
    people: (json['people'])
      .map<String>((e) => e['id'] as String)
      .toSet(),
    );
  }

  ImmichAsset copyWith({
    String? id,
    String? type,
    String? originalFileName,
    DateTime? fileCreatedAt,
    String? mimeType,
    Map? exifInfo,
    String? localPath,
    bool? isFavorite,
    Set<ImageSource>? imageSources,
    String? deviceId,
    bool? isTrashed,
    Set<String>? people,
  }) {
    return ImmichAsset(
      id: id ?? this.id,
      type: type ?? this.type,
      originalFileName: originalFileName ?? this.originalFileName,
      fileCreatedAt: fileCreatedAt ?? this.fileCreatedAt,
      mimeType: mimeType ?? this.mimeType, 
      exifInfo: exifInfo ?? this.exifInfo,
      localPath: localPath ?? this.localPath,
      isFavorite: isFavorite ?? this.isFavorite,
      imageSources: imageSources ?? this.imageSources,
      deviceId: deviceId ?? this.deviceId,
      isTrashed: isTrashed ?? this.isTrashed,
      people: people ?? this.people,
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
  bool isOfType(MediaType mediaType) {
    return switch (mediaType) {
      MediaType.image => isJpg || isRaw,
      MediaType.video => isVideo,
      MediaType.all => true,
    };
  }
  String thumbnailUrl({String size = 'thumbnail'}) => '${ImmichConfig.baseUrl}/api/assets/$id/thumbnail?size=$size';

  String get originalUrl => localPath == null 
    ? '${ImmichConfig.baseUrl}/api/assets/$id/original' 
    : localPath!;

  bool get isRaw => 
      (['image/dng', 'image/arw', 'image/cr2'].contains(mimeType?.toLowerCase())) ||
      ['.dng', '.arw', '.cr2'].contains(originalFileName.toLowerCase().split('.').last);
      
  bool get isVideo => (mimeType?.toLowerCase().startsWith('video/')) == true || originalFileName.toLowerCase().split('.').last == 'mp4';

  bool get isJpg =>
      (mimeType?.toLowerCase() == 'image/jpeg') ||
      originalFileName.toLowerCase().endsWith('.jpg') ||
      originalFileName.toLowerCase().endsWith('.jpeg');

  String? get pixelPairKey { // TODO fix to not break with other naming conventions
    return originalFileName.split('-').first;
  }

  bool get isLocal => !imageSources.contains(ImageSource.immich);

  String get baseName {
    final dot = originalFileName.lastIndexOf('.');
    return dot != -1
        ? originalFileName.substring(0, dot).toLowerCase()
        : originalFileName.toLowerCase();
  }
}

enum ImageSource {
  immich,
  local,
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
class ImmichPerson {
  final String id;
  final String name;
  final String? birthDate;
  final bool isHidden;
  final bool isFavorite;

  ImmichPerson({
    required this.id,
    required this.name,
    this.birthDate,
    required this.isHidden, 
    required this.isFavorite,
  });

  factory ImmichPerson.fromJson(Map<String, dynamic> json) => ImmichPerson(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    birthDate: json['birthDate'] as String?,
    isHidden: json['isHidden'] as bool? ?? false,
    isFavorite: json['isFavorite'] as bool? ?? false,
  );

  String thumbnailUrl(String baseUrl) => '$baseUrl/api/people/$id/thumbnail';
}

class ImmichPlace {
  final String city;
  final String? country;
  final String? state;
  final double? lat;
  final double? lon;

  ImmichPlace({
    required this.city,
    this.country,
    this.state,
    this.lat,
    this.lon,
  });

  factory ImmichPlace.fromJson(Map<String, dynamic> json) => ImmichPlace(
    city: json['city'] as String,
    country: json['country'] as String?,
    state: json['state'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
  );

  String thumbnailUrl(String baseUrl) =>
      '$baseUrl/api/places/${Uri.encodeComponent(city)}/thumbnail';
}

