import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/PolygonMap/polygon_loader.dart';

void main() {
  test('loadPolygons parses inline GeoJSON', () async {
    const sample = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": { "type": "Polygon", "coordinates": [[[0,0],[0,1],[1,1],[1,0],[0,0]]] },
          "properties": { "ADM1_EN": "TestRegion" }
        }
      ]
    }
    ''';

    final polygons = await loadPolygons(overrideGeoJson: sample);
    expect(polygons, isNotNull);
    expect(polygons.length, equals(1));
    expect(polygons.first.regionName, equals('TestRegion'));
    expect(polygons.first.points.length, greaterThan(0));
  });
}
