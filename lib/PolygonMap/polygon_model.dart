import 'package:flutter_map/flutter_map.dart';

/// Simple model that represents a tappable polygon on the map.
class TappablePolygon extends Polygon {
  final String regionName;
  final String id;
  final Map<String, dynamic>? properties;
  final int userCount;

  TappablePolygon({
    required this.regionName,
    required this.id,
    this.properties,
    required this.userCount,
    required super.points,
    required super.color,
    required super.borderColor,
    required super.borderStrokeWidth,
    required super.isFilled,
  });
}
