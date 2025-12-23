import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../PolygonMap/polygon_loader.dart';
import '../PolygonMap/polygon_model.dart';
import '../data/fake_data.dart';
import '../utils/geometry.dart';

enum MapLevel { region, province, municipality, barangay }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  MapLevel _currentLevel = MapLevel.region;
  String? _currentParentId;
  bool _isLoading = false;

  // cache for sidebar hierarchical lists
  final Map<MapLevel, Map<String, List<TappablePolygon>>> _cache = {
    MapLevel.region: {},
    MapLevel.province: {},
    MapLevel.municipality: {},
    MapLevel.barangay: {},
  };

  // history for Back
  final List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadPolygons(MapLevel.region, null);
  }

  String _fileNameFor(MapLevel level, String? parentId) {
    if (level == MapLevel.region) return 'philippines.json';
    if (parentId == null) throw ArgumentError('parentId required for $level');
    final id = parentId.toLowerCase();
    switch (level) {
      case MapLevel.province:
        return 'provinces_lowres/provinces-region-$id.0.001.json';
      case MapLevel.municipality:
        return 'municities_lowres/municities-province-$id.0.001.json';
      case MapLevel.barangay:
        return 'barangays_lowres/barangays-municity-$id.0.001.json';
      default:
        return 'philippines.json';
    }
  }

  Future<void> _loadPolygons(MapLevel level, String? parentId,
      {LatLngBounds? bounds}) async {
    if (!mounted) return;

    // Prevent deadlock: if requesting same data, return
    if (level == _currentLevel && parentId == _currentParentId) {
      debugPrint('Load request repeated for same level/parent -> ignoring');
      return;
    }

    if (_isLoading) {
      debugPrint('Load skipped because another load is in progress');
      return;
    }

    setState(() => _isLoading = true);

    List<TappablePolygon> polygons = [];
    String assetPath = '';

    try {
      final fileName = _fileNameFor(level, parentId);
      assetPath = 'assets/$fileName'; // ensure single assets/ prefix

      debugPrint('Attempting to load $assetPath');

      polygons = await loadPolygons(assetPath: assetPath, level: level.name);
    } catch (e) {
      debugPrint('Error loading polygons: $e');
      polygons = [];
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    if (polygons.isEmpty) {
      debugPrint('No polygons found for level=$level parentId=$parentId (tried $assetPath)');
      return;
    }

    // recolor polygons using _getAreaColor and store in cache using parentId (or 'root' for region)
    final recolored = polygons.map((p) {
      final cnt = getSimulatedUserCount(p.id, level.name);
      return TappablePolygon(
        regionName: p.regionName,
        id: p.id,
        properties: p.properties,
        userCount: cnt,
        points: p.points,
        color: _getAreaColor(cnt),
        borderColor: p.borderColor,
        borderStrokeWidth: p.borderStrokeWidth,
        isFilled: p.isFilled,
      );
    }).toList();

    final key = parentId ?? 'root';
    _cache[level]![key] = recolored;

    // update current level/parent and optionally zoom to bounds
    setState(() {
      _currentLevel = level;
      _currentParentId = parentId;
    });

    if (bounds != null) {
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(25)));
    }
  }

  Color _getAreaColor(int count) {
    if (count > 100) return Colors.red;
    if (count >= 50) return Colors.blue;
    return Colors.green;
  }

  LatLngBounds _boundsForPolygon(TappablePolygon poly) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in poly.points) {
      minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(LatLng(minLat!, minLng!), LatLng(maxLat!, maxLng!));
  }

  void _onSidebarItemTap(TappablePolygon poly) {
    final bounds = _boundsForPolygon(poly);
    final ne = bounds.northEast;
    final sw = bounds.southWest;
    final center = LatLng((ne.latitude + sw.latitude) / 2, (ne.longitude + sw.longitude) / 2);

    // Save current state for Back
    _history.add({'level': _currentLevel, 'parentId': _currentParentId});

    // Move map and load next level
    _mapController.move(center, _zoomForNextLevel(_currentLevel));

    MapLevel? next;
    if (_currentLevel == MapLevel.region) next = MapLevel.province;
    else if (_currentLevel == MapLevel.province) next = MapLevel.municipality;
    else if (_currentLevel == MapLevel.municipality) next = MapLevel.barangay;

    if (next != null) _loadPolygons(next, poly.id, bounds: bounds);
  }

  double _zoomForNextLevel(MapLevel level) {
    switch (level) {
      case MapLevel.region:
        return 9.0;
      case MapLevel.province:
        return 11.0;
      case MapLevel.municipality:
        return 13.0;
      default:
        return 14.0;
    }
  }

  void _goBack() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    final prevLevel = last['level'] as MapLevel;
    final prevParent = last['parentId'] as String?;
    _loadPolygons(prevLevel, prevParent);
  }

  void _reset() {
    _history.clear();
    _loadPolygons(MapLevel.region, null);
    _mapController.move(const LatLng(12.8797, 121.7740), 6);
  }

  List<Widget> _buildSidebarContent() {
    // Region level list
    final regions = _cache[MapLevel.region]!['root'] ?? [];
    // For demo purposes, if regions is empty, show a placeholder that will trigger load
    if (regions.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No region data loaded'),
        )
      ];
    }

    return regions.map((region) {
      final regionCount = getSimulatedUserCount(region.id, 'region');
      final provinces = _cache[MapLevel.province]![region.id] ?? [];

      return ExpansionTile(
        title: InkWell(
          onTap: () => _onSidebarItemTap(region),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(region.regionName, style: TextStyle(color: _getAreaColor(regionCount))),
              Text('$regionCount', style: TextStyle(color: _getAreaColor(regionCount))),
            ],
          ),
        ),
        children: provinces.isEmpty
            ? [ListTile(title: Text('Load provinces for this region'), onTap: () => _loadPolygons(MapLevel.province, region.id))]
            : provinces.map((prov) {
                final pcount = getSimulatedUserCount(prov.id, 'province');
                final munis = _cache[MapLevel.municipality]![prov.id] ?? [];
                return ExpansionTile(
                  title: InkWell(
                    onTap: () => _onSidebarItemTap(prov),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(prov.regionName, style: TextStyle(color: _getAreaColor(pcount))),
                        Text('$pcount', style: TextStyle(color: _getAreaColor(pcount))),
                      ],
                    ),
                  ),
                  children: munis.isEmpty
                      ? [ListTile(title: Text('Load municipalities'), onTap: () => _loadPolygons(MapLevel.municipality, prov.id))]
                      : munis.map((mun) {
                          final mcount = getSimulatedUserCount(mun.id, 'municipality');
                          final bars = _cache[MapLevel.barangay]![mun.id] ?? [];
                          return ExpansionTile(
                            title: InkWell(
                              onTap: () => _onSidebarItemTap(mun),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(mun.regionName, style: TextStyle(color: _getAreaColor(mcount))),
                                  Text('$mcount', style: TextStyle(color: _getAreaColor(mcount))),
                                ],
                              ),
                            ),
                            children: bars.isEmpty
                                ? [ListTile(title: Text('Load barangays'), onTap: () => _loadPolygons(MapLevel.barangay, mun.id))]
                                : bars.map((bar) {
                                    final bcount = getSimulatedUserCount(bar.id, 'barangay');
                                    return ListTile(
                                      title: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(bar.regionName, style: TextStyle(color: _getAreaColor(bcount))),
                                          Text('$bcount', style: TextStyle(color: _getAreaColor(bcount))),
                                        ],
                                      ),
                                      onTap: () => _onSidebarItemTap(bar),
                                    );
                                  }).toList(),
                          );
                        }).toList(),
                );
              }).toList(),
        onExpansionChanged: (expanded) {
          if (expanded && provinces.isEmpty) {
            _loadPolygons(MapLevel.province, region.id);
          }
        },
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final polygons = _cache[_currentLevel]![(_currentParentId ?? 'root')] ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Map Screen')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: const LatLng(12.8797, 121.7740), initialZoom: 6, onTap: (pos, point) async {
              // find polygon and tap
              for (final poly in polygons.reversed) {
                if (isPointInPolygon(point, poly.points)) {
                  _onSidebarItemTap(poly);
                  break;
                }
              }
            }),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              PolygonLayer(polygons: polygons),
            ],
          ),

          // Sidebar (top-left)
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 300,
              height: 500,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(6), boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ]),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: _buildSidebarContent(),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(onPressed: _goBack, icon: const Icon(Icons.arrow_back), label: const Text('Back')),
                      ElevatedButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh), label: const Text('Reset')),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Positioned(top: 12, right: 12, child: SizedBox(width: 28, height: 28, child: const CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
    );
  }
}
