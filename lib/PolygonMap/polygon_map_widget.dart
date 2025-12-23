import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'polygon_model.dart';
import '../utils/geometry.dart';
import '../data/fake_data.dart';
import 'polygon_loader.dart';

enum _MapDetail { region, province, municity }

class PolygonMapWidget extends StatefulWidget {
  final void Function(String name)? onRegionSelected;
  const PolygonMapWidget({super.key, this.onRegionSelected});

  @override
  State<PolygonMapWidget> createState() => _PolygonMapWidgetState();
}

class _PolygonMapWidgetState extends State<PolygonMapWidget> {
  final MapController _mapController = MapController();
  List<TappablePolygon> _polygons = [];
  bool _isLoading = true;
  
  Timer? _debounceTimer;
  _MapDetail _currentDetail = _MapDetail.region;
  List<TappablePolygon> _provincePolygons = [];
  String? _selectedAreaInfo;
  String? _activeLocationKey;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final data = await loadPolygons(assetPath: 'assets/philippines.json', level: 'region');
    if (mounted) {
      setState(() {
        _polygons = data;
        _isLoading = false;
      });
    }
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _updatePolygonsForZoom(position.zoom ?? 6.0, position.center);
    });
  }

  Future<void> _updatePolygonsForZoom(double zoom, LatLng? center) async {
    final target = zoom < 7.5 ? _MapDetail.region : (zoom < 10.5 ? _MapDetail.province : _MapDetail.municity);
    List<TappablePolygon>? nextData;

    try {
      if (target == _MapDetail.region && _currentDetail != _MapDetail.region) {
        _currentDetail = _MapDetail.region;
        _activeLocationKey = null;
        nextData = await loadPolygons(assetPath: 'assets/philippines.json', level: 'region');
      } 
      else if (target == _MapDetail.province && _currentDetail != _MapDetail.province) {
        _currentDetail = _MapDetail.province;
        nextData = await _loadAllProvincePolygons();
      } 
      else if (target == _MapDetail.municity && center != null) {
        if (_provincePolygons.isEmpty) _provincePolygons = await _loadAllProvincePolygons();
        final province = _provincePolygons.where((p) => isPointInPolygon(center, p.points)).firstOrNull;
        
        if (province != null) {
          String? id = province.properties?['ADM2_PCODE']?.toString().toLowerCase();
          id ??= province.properties?['NAME_1']?.toString().toLowerCase().replaceAll(' ', '-');

          if (id != null && id != _activeLocationKey) {
            final path = 'assets/municities_lowres/municities-province-$id.0.001.json';
            final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
            if (manifest.listAssets().contains(path)) {
              _currentDetail = _MapDetail.municity;
              _activeLocationKey = id;
              nextData = await loadPolygons(assetPath: path, level: 'municity');
            }
          }
        }
      }

      if (nextData != null && mounted) {
        setState(() {
          _polygons = nextData!;
          _selectedAreaInfo = null;
        });
      }
    } catch (e) {
      debugPrint("Map Zoom Error: $e");
    }
  }

  Future<List<TappablePolygon>> _loadAllProvincePolygons() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest.listAssets().where((k) => k.startsWith('assets/provinces_lowres/') && k.endsWith('.json')).toList();
    List<TappablePolygon> all = [];
    for (var f in files) {
      final data = await loadPolygons(assetPath: f, level: 'province');
      all.addAll(data);
    }
    _provincePolygons = all;
    return all;
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    String? newInfo;
    String? selectedName;

    // Iterate in reverse to find the top-most polygon
    for (final polygon in _polygons.reversed) {
      if (isPointInPolygon(point, polygon.points)) {
        final String name = polygon.label ?? polygon.regionName;
        final String level = _currentDetail == _MapDetail.region ? 'region' : (_currentDetail == _MapDetail.province ? 'province' : 'municity');
        final int count = getSimulatedUserCount(name, level);

        newInfo = 'Area: $name | Users: $count';
        selectedName = name;
        break; // Found the top-most, so we can stop
      }
    }

    setState(() {
      _selectedAreaInfo = newInfo;
      if (selectedName != null) {
        widget.onRegionSelected?.call(selectedName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(12.8797, 121.7740),
            initialZoom: 6,
            onPositionChanged: (pos, gesture) => _onPositionChanged(pos, gesture),
            onTap: _handleTap,
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              PolygonLayer(
                polygons: _polygons.map((e) => e as Polygon).toList(),
                polygonCulling: true,
              ),
          ],
        ),
        if (_selectedAreaInfo != null)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                elevation: 4,
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    _selectedAreaInfo!,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}