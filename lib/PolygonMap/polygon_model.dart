import 'package:flutter_map/flutter_map.dart';

/// Simple model that represents a tappable polygon on the map.
class TappablePolygon extends Polygon {
  final String regionName;
  final Map<String, dynamic>? properties;

  TappablePolygon({
    required this.regionName,
    this.properties,
    required super.points,
    required super.color,
    required super.borderColor,
    required super.borderStrokeWidth,
    required super.isFilled,
  });
}
