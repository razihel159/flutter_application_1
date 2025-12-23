import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MyOSMMap extends StatefulWidget {
  // No longer needs data as it's just a plain map viewer.
  const MyOSMMap({super.key});

  @override
  State<MyOSMMap> createState() => _MyOSMMapState();
}

class _MyOSMMapState extends State<MyOSMMap> {
  final MapController mapController = MapController();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: const MapOptions(
            initialCenter: LatLng(20, 0),
            initialZoom: 2.0,
            minZoom: 2,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.flutter_application_1',
            ),
          ],
        ),
        Positioned(
          bottom: 90,
          right: 10,
          child: Column(
            children: <Widget>[
              FloatingActionButton(
                heroTag: "zoomInBtn",
                mini: true,
                onPressed: () => mapController.move(mapController.camera.center, mapController.camera.zoom + 1),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: "zoomOutBtn",
                mini: true,
                onPressed: () => mapController.move(mapController.camera.center, mapController.camera.zoom - 1),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }
}