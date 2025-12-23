import 'dart:convert';
import 'dart:math';
import 'dart:async';
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

class _PolygonMapWidgetState extends State<PolygonMapWidget> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // 1. State Variables
  List<TappablePolygon> _polygons = [];
  String _currentLevel = 'regions';
  String? _parentId;
  int _userCount = 0;
  String _selectedAreaName = 'Philippines';
  final List<Map<String, dynamic>> _navigationHistory = [];

  // Hover state
  TappablePolygon? _hoveredPolygon;
  Offset? _lastMouseOffset;
  Timer? _hoverTimer;
  final Duration _hoverDelay = const Duration(milliseconds: 150);

  // Cache of generated user counts per logical area id
  final Map<String, int> _userCountCache = {}; // key: lowercased areaId -> userCount

  // Animation controllers for a brief pulse when a polygon's value is newly assigned
  final Map<String, AnimationController> _animControllers = {};
  final Duration _updatePulseDuration = const Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _loadPolygons(_currentLevel, _parentId);
  }

  // 1. Data & Color Logic
  // Determine color for a count relative to the current view (list of counts)
  // If no counts list is provided, fall back to the absolute thresholds used previously.
  Color _getAreaColor(int count, [List<int>? allCounts]) {
    final int alpha = (0.7 * 255).round();
    if (allCounts == null || allCounts.isEmpty) {
      // fallback behavior
      if (count > 100) return Colors.red.withAlpha(alpha);
      if (count >= 50) return Colors.blue.withAlpha(alpha);
      return Colors.green.withAlpha(alpha);
    }

    final int minCount = allCounts.reduce((a, b) => a < b ? a : b);
    final int maxCount = allCounts.reduce((a, b) => a > b ? a : b);
    if (minCount == maxCount) {
      // No spread; use middle color
      return Colors.blue.withAlpha(alpha);
    }

    final double range = (maxCount - minCount).toDouble();
    final double lowCut = minCount + range / 3.0; // bottom third
    final double midCut = minCount + 2.0 * range / 3.0; // top third

    if (count >= midCut) {
      return Colors.red.withAlpha(alpha);
    } else if (count >= lowCut) {
      return Colors.blue.withAlpha(alpha);
    } else {
      return Colors.green.withAlpha(alpha);
    }
  }

  // 2. Asset Loading Logic & 3. Feature Parsing
  Future<void> _loadPolygons(String level, String? parentId) async {
    if (!mounted) return;

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

      // Build a map of distinct logical areas (areaId -> {name, rings}) where each ring is a List<LatLng>
      final Map<String, Map<String, dynamic>> areas = {}; // id -> {'name': String, 'rings': List<List<LatLng>>}
      int generatedIndex = 0;
      for (var feature in features) {
        final properties = feature['properties'] as Map<String, dynamic>?;

        final String areaName = properties?['name']?.toString() ??
            properties?['NAME_3']?.toString() ??
            properties?['NAME_2']?.toString() ??
            properties?['NAME_1']?.toString() ??
            'Unknown';

        String areaId = properties?['code']?.toString() ??
            properties?['ID_3']?.toString() ??
            properties?['ADM4_PCODE']?.toString() ??
            properties?['ADM3_PCODE']?.toString() ??
            properties?['ADM2_PCODE']?.toString() ??
            properties?['ADM1_PCODE']?.toString() ??
            '';

        if (areaId.isEmpty) {
          areaId = 'gen-${areaName.toLowerCase().replaceAll(RegExp(r"\\s+"), '-')}-${generatedIndex++}';
        } else {
          areaId = areaId.toLowerCase();
        }

        final geom = feature['geometry'] as Map<String, dynamic>?;
        if (geom == null) continue;

        final type = geom['type'] as String?;
        final coordinates = geom['coordinates'] as List<dynamic>?;

        void collectRing(List<dynamic> polygonCoords) {
          final points = <LatLng>[];
          for (final p in polygonCoords) {
            points.add(LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()));
          }
          if (!areas.containsKey(areaId)) {
            areas[areaId] = {'name': areaName, 'rings': <List<LatLng>>[]};
          }
          (areas[areaId]!['rings'] as List<List<LatLng>>).add(points);
        }

        if (type == 'Polygon') {
          for (final polygon in coordinates!) {
            collectRing(polygon as List<dynamic>);
          }
        } else if (type == 'MultiPolygon') {
          for (final multi in coordinates!) {
            for (final polygon in multi) {
              collectRing(polygon as List<dynamic>);
            }
          }
        }
      }

      // Now assign user counts according to rules
      final areaIds = areas.keys.toList();
      if (level == 'regions') {
        // Regions get large random totals between 1000 and 5000 (cached)
        for (final id in areaIds) {
          if (!_userCountCache.containsKey(id)) {
            final value = 1000 + random.nextInt(4001); // 1000..5000
            _userCountCache[id] = value;
            if (value > 0) _startUpdatePulseFor(id);
          }
        }
      } else {
        // Drill-down: distribute parent's total among children, respecting existing cache
        final parentKey = parentId?.toLowerCase();
        final parentCount = _userCountCache[parentKey] ?? 0;

        int existingSum = 0;
        final uncached = <String>[];
        for (final id in areaIds) {
          if (_userCountCache.containsKey(id)) {
            existingSum += _userCountCache[id]!;
          } else {
            uncached.add(id);
          }
        }

        int remaining = parentCount - existingSum;
        if (remaining < 0) remaining = 0;

        if (uncached.isNotEmpty && remaining > 0) {
          // Ensure minimum floor (1) per child when possible
          if (remaining >= uncached.length) {
            const int floorPerChild = 1;
            final int reserved = floorPerChild * uncached.length;
            int leftover = remaining - reserved;

            final weights = uncached.map((_) => random.nextDouble()).toList();
            final totalWeight = weights.fold<double>(0, (a, b) => a + b);

            int allocatedSum = 0;
            for (int i = 0; i < uncached.length; i++) {
              final id = uncached[i];
              int extra = 0;
              if (leftover > 0) {
                extra = (leftover * (weights[i] / (totalWeight == 0 ? 1 : totalWeight))).round();
              }
              int value = floorPerChild + extra;
              // last item gets remaining rounding difference
              if (i == uncached.length - 1) {
                value = remaining - allocatedSum;
              }
              _userCountCache[id] = value;
              allocatedSum += value;
              if (value > 0) _startUpdatePulseFor(id);
            }
          } else {
            // Not enough remaining to give everyone the floor: randomly select `remaining` items to receive 1
            final shuffled = List<String>.from(uncached)..shuffle(random);
            for (int i = 0; i < uncached.length; i++) {
              final id = shuffled[i];
              final value = i < remaining ? 1 : 0;
              _userCountCache[id] = value;
              if (value > 0) _startUpdatePulseFor(id);
            }
          }
        } else {
          // No remaining budget: set uncached children to 0 to keep deterministic behavior
          for (final id in uncached) {
            _userCountCache[id] = 0;
          }
        }
      }

      // Create TappablePolygon objects for all rings, using the cached counts
      // Compute the visible counts list to determine dynamic color tiers
      final countsList = areaIds.map((id) => _userCountCache[id] ?? 0).toList();

      for (final id in areaIds) {
        final info = areas[id]!;
        final count = _userCountCache[id] ?? 0;
        final baseColor = _getAreaColor(count, countsList);
        final controller = _animControllers[id];
        final color = controller != null
            ? baseColor.withAlpha((baseColor.alpha + (80 * controller.value)).clamp(0, 255).round())
            : baseColor;
        final border = controller != null
            ? Colors.yellow.withAlpha((0.95 * 255 * controller.value).round())
            : Colors.white.withAlpha((0.5 * 255).round());
        final borderWidth = controller != null ? 2.0 + (1.0 * controller.value) : 0.5;
        final rings = info['rings'] as List<List<LatLng>>;
        for (final points in rings) {
          newPolygons.add(TappablePolygon(
            id: id,
            regionName: info['name'] as String,
            userCount: count,
            properties: null,
            points: points,
            color: color,
            borderColor: border,
            borderStrokeWidth: borderWidth,
            isFilled: true,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _polygons = newPolygons; // Clear old data by replacing
          _currentLevel = level;
          _parentId = parentId;
        });
      }
    } catch (e) {
      // 5. Safety
      debugPrint("Error loading asset $path: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map data for this area is not available yet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Convert local pointer position (in map widget coordinates) to LatLng using Web Mercator projection
  LatLng _pixelToLatLng(Offset local, Size mapSize) {
    final center = _mapController.camera.center;
    final zoom = _mapController.camera.zoom;
    final scale = 256 * pow(2, zoom);

    double lonToX(double lon) => (lon + 180) / 360 * scale;
    double latToY(double lat) {
      final rad = lat * pi / 180.0;
      final y = (1 - (log(tan(rad) + (1 / cos(rad))) / pi)) / 2 * scale;
      return y;
    }

    final centerX = lonToX(center.longitude);
    final centerY = latToY(center.latitude);

    final topLeftX = centerX - (mapSize.width / 2);
    final topLeftY = centerY - (mapSize.height / 2);

    final x = topLeftX + local.dx;
    final y = topLeftY + local.dy;

    final lon = x / scale * 360 - 180;
    final n = pi - 2 * pi * y / scale;
    final lat = atan((exp(n) - exp(-n)) / 2).toDouble();
    final latDeg = lat * 180.0 / pi;
    return LatLng(latDeg, lon);
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

      // Delegate selection and drilling to shared helper so sidebar can reuse it
    _selectPolygon(tappedPolygon);
  }

  void _selectPolygon(TappablePolygon tappedPolygon) {
    // Update selection state
    setState(() {
      _selectedAreaName = tappedPolygon.regionName;
      _userCount = tappedPolygon.userCount;
    });
    widget.onRegionSelected?.call(tappedPolygon.regionName);

    // If at final level, just show info
    if (_currentLevel == 'barangays') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barangay: ${tappedPolygon.regionName} | Users: ${tappedPolygon.userCount}'),
        ),
      );
      return;
    }

    // Save for Back
    _navigationHistory.add({
      'level': _currentLevel,
      'parentId': _parentId,
      'name': _selectedAreaName,
      'count': _userCount,
    });

    // Determine next level and drill
    String nextLevel;
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
    // Clear cached user counts so a fresh set will be generated on next load
    _userCountCache.clear();
    setState(() {
      _selectedAreaName = 'Philippines';
      _userCount = 0;
    });
    _loadPolygons('regions', null);
  }

  // Start a short pulse animation for an updated polygon id
  void _startUpdatePulseFor(String id) {
    if (_animControllers.containsKey(id)) return;
    final controller = AnimationController(vsync: this, duration: _updatePulseDuration)
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..repeat(reverse: true);
    _animControllers[id] = controller;
    // Stop and dispose after a short time so the pulse is subtle
    Timer(const Duration(milliseconds: 900), () {
      final c = _animControllers.remove(id);
      if (c != null) {
        c.stop();
        c.dispose();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // MouseRegion to detect hover over the map and show tooltip
        LayoutBuilder(builder: (context, constraints) {
          return MouseRegion(
            onHover: (PointerHoverEvent e) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(e.position);
              _lastMouseOffset = local;
              final latlng = _pixelToLatLng(local, constraints.biggest);

              TappablePolygon? found;
              for (final poly in _polygons.reversed) {
                if (isPointInPolygon(latlng, poly.points)) {
                  found = poly;
                  break;
                }
              }

              // Debounce tooltip changes to avoid flicker
              _hoverTimer?.cancel();
              _hoverTimer = Timer(_hoverDelay, () {
                if (!mounted) return;
                if (_hoveredPolygon?.id != found?.id) {
                  setState(() {
                    _hoveredPolygon = found;
                  });
                }
              });
            },
            onExit: (_) {
              _hoverTimer?.cancel();
              if (_hoveredPolygon != null) setState(() => _hoveredPolygon = null);
            },
            child: FlutterMap(
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
          );
        }),
        // Tooltip that follows the mouse when hovering polygons
        if (_hoveredPolygon != null && _lastMouseOffset != null)
          Positioned(
            left: (_lastMouseOffset!.dx + 12).clamp(8.0, MediaQuery.of(context).size.width - 220.0),
            top: (_lastMouseOffset!.dy + 12).clamp(8.0, MediaQuery.of(context).size.height - 80.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.75 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxWidth: 200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_hoveredPolygon!.regionName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Users: ${_userCountCache[_hoveredPolygon!.id] ?? _hoveredPolygon!.userCount}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),

        // Sidebar (top-left)
        Positioned(
          top: 40,
          left: 20,
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Philippines Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _polygons.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('No data')))
                      : Builder(builder: (context) {
                          final sorted = List<TappablePolygon>.from(_polygons)
                            ..sort((a, b) => b.userCount.compareTo(a.userCount));
                          return ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: sorted.length,
                            itemBuilder: (context, index) {
                              final poly = sorted[index];
                              return InkWell(
                                onTap: () => _selectPolygon(poly),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(poly.regionName, style: TextStyle(color: poly.color)),
                                      Text('${poly.userCount}', style: TextStyle(color: poly.color)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                ),
              ],
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

  @override
  void dispose() {
    _hoverTimer?.cancel();
    for (final c in _animControllers.values) {
      c.dispose();
    }
    _animControllers.clear();
    super.dispose();
  }
}