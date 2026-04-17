import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PhotoMapView extends ConsumerStatefulWidget {
  final double lat;
  final double lng;
    
  const PhotoMapView({super.key, required this.lat, required this.lng});

  @override
  ConsumerState<PhotoMapView> createState() => _PhotoMapViewState();
}
class _PhotoMapViewState extends ConsumerState<PhotoMapView> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(PhotoMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _mapController.move(LatLng(widget.lat, widget.lng), _mapController.camera.zoom);
    }
  }
  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.lat, widget.lng);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: point,
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png?api_key=ab78a2b9-3437-49c5-a461-00a4155cddd3', //'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yourapp.name',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 36,
              height: 36,
              child: const _PhotoPin(),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoPin extends StatelessWidget {
  const _PhotoPin();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, color: Colors.red,);
  }
}

Future<String?> getPlaceName(double lat, double lng) async {
  final uri = Uri.parse(
    'https://nominatim.openstreetmap.org/reverse'
    '?lat=$lat&lon=$lng&format=json&zoom=15',
  );

  final response = await http.get(uri, headers: {
    'User-Agent': 'com.yourapp.name',
  });

  if (response.statusCode != 200) return null;

  final data = jsonDecode(response.body);
  final address = data['address'];
  return [
    address['suburb'] ?? address['city_district'] ?? address['town'],
    address['city'],
    address['state'],
    address['country'],
  ].nonNulls.join(', ');
}