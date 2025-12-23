import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/utils/geometry.dart';

void main() {
  test('point in polygon - inside and outside', () {
    const polygon = [
      LatLng(0, 0),
      LatLng(0, 10),
      LatLng(10, 10),
      LatLng(10, 0),
      LatLng(0, 0), // closed ring
    ];

    const inside = LatLng(5, 5);
    const outside = LatLng(20, 20);

    expect(isPointInPolygon(inside, polygon), isTrue);
    expect(isPointInPolygon(outside, polygon), isFalse);
  });
}
