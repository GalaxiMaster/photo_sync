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

  ImmichPerson({
    required this.id,
    required this.name,
    this.birthDate,
    required this.isHidden,
  });

  factory ImmichPerson.fromJson(Map<String, dynamic> json) => ImmichPerson(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    birthDate: json['birthDate'] as String?,
    isHidden: json['isHidden'] as bool? ?? false,
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