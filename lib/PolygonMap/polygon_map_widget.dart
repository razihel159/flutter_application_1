import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'polygon_model.dart';
import '../utils/geometry.dart';

class PolygonMapWidget extends StatefulWidget {
  final void Function(String name)? onRegionSelected;
  const PolygonMapWidget({super.key, this.onRegionSelected});

  @override
  State<PolygonMapWidget> createState() => _PolygonMapWidgetState();
}

class _PolygonMapWidgetState extends State<PolygonMapWidget> {
  final MapController _mapController = MapController();

  // 1. State Variables
  List<TappablePolygon> _polygons = [];
  bool _isLoading = true;
  String _currentLevel = 'regions';
  String? _parentId;
  int _userCount = 0;
  String _selectedAreaName = 'Philippines';
  final List<Map<String, dynamic>> _navigationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPolygons(_currentLevel, _parentId);
  }

  // 1. Data & Color Logic
  Color _getAreaColor(int count) {
    if (count > 100) {
      return Colors.red.withAlpha((0.7 * 255).round());
    } else if (count >= 50) {
      return Colors.blue.withAlpha((0.7 * 255).round());
    } else {
      return Colors.green.withAlpha((0.7 * 255).round());
    }
  }

  // 2. Asset Loading Logic & 3. Feature Parsing
  Future<void> _loadPolygons(String level, String? parentId) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // 1. Path Logic: Define the file location WITHOUT the 'assets/' prefix first.
    String fileName;
    switch (level) {
      case 'provinces':
        fileName = 'provinces_lowres/provinces-region-${parentId?.toLowerCase()}.0.001.json';
        break;
      case 'municities':
        fileName = 'municities_lowres/municities-province-${parentId?.toLowerCase()}.0.001.json';
        break;
      case 'barangays':
        // 1. File Naming Rules
        fileName = 'barangays_lowres/barangays-municity-${parentId?.toLowerCase()}.0.001.json';
        break;
      case 'regions':
      default:
        // For the root: String fileName = 'philippines.json';
        fileName = 'philippines.json';
        break;
    }

    String path = ''; // Declare path here to make it accessible in the catch block
    try {
      // 2. The Safe Loader: Use this exact logic to load the file so Flutter Web doesn't double the prefix:
      // Instead of adding 'assets/' manually in the string,
      // let the variable contain the full path only once.
      path = fileName.startsWith('assets/') ? fileName : 'assets/$fileName';
      // ignore: avoid_print
      print('Loading: $path');
      final String response = await rootBundle.loadString(path);
      final geoJson = json.decode(response);
      final features = geoJson['features'] as List<dynamic>;
      final List<TappablePolygon> newPolygons = [];
      final random = Random();

      for (var feature in features) {
        final properties = feature['properties'] as Map<String, dynamic>?;

        final String areaName = properties?['name']?.toString() ??
            properties?['NAME_3']?.toString() ??
            properties?['NAME_2']?.toString() ??
            properties?['NAME_1']?.toString() ??
            'Unknown';

        // 4. Data Parsing
        final String areaId = properties?['code']?.toString() ?? 
            properties?['ID_3']?.toString() ??
            properties?['ADM4_PCODE']?.toString() ??
            properties?['ADM3_PCODE']?.toString() ??
            properties?['ADM2_PCODE']?.toString() ??
            properties?['ADM1_PCODE']?.toString() ??
            '';

        final geom = feature['geometry'] as Map<String, dynamic>?;
        if (geom == null) continue;

        final type = geom['type'] as String?;
        final coordinates = geom['coordinates'] as List<dynamic>?;

        final int mockCount = 1 + random.nextInt(150);

        void addPolygon(List<dynamic> polygonCoords) {
          final points = <LatLng>[];
          for (final p in polygonCoords) {
            points.add(LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()));
          }

          newPolygons.add(TappablePolygon(
            id: areaId,
            regionName: areaName,
            userCount: mockCount,
            properties: properties,
            points: points,
            color: _getAreaColor(mockCount),
            borderColor: Colors.white.withAlpha((0.5 * 255).round()),
            borderStrokeWidth: 0.5,
            isFilled: true,
          ));
        }

        if (type == 'Polygon') {
          for (final polygon in coordinates!) {
            addPolygon(polygon as List<dynamic>);
          }
        } else if (type == 'MultiPolygon') {
          for (final multi in coordinates!) {
            for (final polygon in multi) {
              addPolygon(polygon as List<dynamic>);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _polygons = newPolygons; // Clear old data by replacing
          _currentLevel = level;
          _parentId = parentId;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 5. Safety
      debugPrint("Error loading asset $path: $e");
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading indicator but don't clear map
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map data for this area is not available yet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 4. Visuals & Interaction
  void _handleAreaTap(TapPosition tapPosition, LatLng point) {
    TappablePolygon? tappedPolygon;
    for (final polygon in _polygons.reversed) {
      if (isPointInPolygon(point, polygon.points)) {
        tappedPolygon = polygon;
        break;
      }
    }

    if (tappedPolygon == null) return;

    // 4. Selection Logic
    setState(() {
      _selectedAreaName = tappedPolygon!.regionName;
      _userCount = tappedPolygon.userCount;
    });
    widget.onRegionSelected?.call(tappedPolygon.regionName);

    // 4. Final Level Check
    if (_currentLevel == 'barangays') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Barangay: ${tappedPolygon.regionName} | Users: ${tappedPolygon.userCount}'),
        ),
      );
      return;
    }

    // 3. Level Sequence
    String nextLevel;

    _navigationHistory.add({
      'level': _currentLevel,
      'parentId': _parentId,
      'name': _selectedAreaName,
      'count': _userCount,
    });
    switch (_currentLevel) {
      case 'regions':
        nextLevel = 'provinces';
        break;
      case 'provinces':
        nextLevel = 'municities';
        break;
      case 'municities':
        nextLevel = 'barangays';
        break;
      default:
        return;
    }

    _loadPolygons(nextLevel, tappedPolygon.id);
  }

  // 2. Back Navigation
  void _handleBack() {
    if (_navigationHistory.isEmpty) return;

    final prevState = _navigationHistory.removeLast();
    final prevLevel = prevState['level'] as String;
    final prevParentId = prevState['parentId'] as String?;
    final prevName = prevState['name'] as String;
    final prevCount = prevState['count'] as int;

    setState(() {
      _selectedAreaName = prevName;
      _userCount = prevCount;
    });

    _loadPolygons(prevLevel, prevParentId);
  }

  void _resetMap() {
    _navigationHistory.clear();
    setState(() {
      _selectedAreaName = 'Philippines';
      _userCount = 0;
    });
    _loadPolygons('regions', null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(12.8797, 121.7740),
            initialZoom: 6, // Start with a view of the whole country
            onTap: _handleAreaTap,
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            PolygonLayer(
              polygons: _polygons,
              polygonCulling: true,
            ),
          ],
        ),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        // 3. UI Overlay
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '$_selectedAreaName\nRegistered Users: $_userCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        if (_currentLevel != 'regions')
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'backButton',
              onPressed: _handleBack,
              child: const Icon(Icons.arrow_back),
            ),
          ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            heroTag: 'resetButton',
            onPressed: _resetMap,
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}