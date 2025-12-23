import 'package:latlong2/latlong.dart';
import 'dart:math';

/// Returns true if [point] is inside the polygon defined by [polygon] points.
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  int intersectCount = 0;
  for (int j = 0; j < polygon.length - 1; j++) {
    if (rayCast(point, polygon[j], polygon[j + 1])) {
      intersectCount++;
    }
  }
  return (intersectCount % 2) == 1;
}

/// Helper for the ray-casting algorithm between vertices A and B.
bool rayCast(LatLng point, LatLng vertA, LatLng vertB) {
  double pLat = point.latitude;
  double pLng = point.longitude;
  double aLat = vertA.latitude;
  double aLng = vertA.longitude;
  double bLat = vertB.latitude;
  double bLng = vertB.longitude;

  if (aLng > bLng) {
    final double tempLng = aLng;
    aLng = bLng;
    bLng = tempLng;
    final double tempLat = aLat;
    aLat = bLat;
    bLat = tempLat;
  }

  if (pLng == aLng || pLng == bLng) pLng += 1e-12;

  if (pLng < aLng || pLng > bLng) {
    return false;
  } else if (pLat > max(aLat, bLat)) {
    return false;
  } else if (pLat < min(aLat, bLat)) {
    return true;
  } else {
    final double mRed = (bLat - aLat) / (bLng - aLng);
    final double mBlue = (pLat - aLat) / (pLng - aLng);
    return mBlue >= mRed;
  }
}
