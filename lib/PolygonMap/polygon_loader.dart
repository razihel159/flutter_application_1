import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/data/fake_data.dart'; 
import 'polygon_model.dart';

Future<List<TappablePolygon>> loadPolygons({
  String assetPath = 'assets/philippines.json',
  String? overrideGeoJson, 
  String level = 'region',
}) async {
  try {
    final geoJsonString = overrideGeoJson ?? await rootBundle.loadString(assetPath);
    return _parseGeoJson(geoJsonString, assetPath, level);
  } catch (e) {
    debugPrint("Error loading $assetPath: $e");
    return [];
  }
}

List<TappablePolygon> _parseGeoJson(String geoJsonString, String assetPath, String level) {
  final polygons = <TappablePolygon>[];
  final geoJson = json.decode(geoJsonString);
  final features = geoJson['features'] as List<dynamic>;

  // Extract ID from filename (e.g., "ph01" from "provinces-region-ph01.json")
  final RegExp idRegex = RegExp(r'(ph\d+)');
  String? filenameId;
  final match = idRegex.firstMatch(assetPath);
  if (match != null) {
    filenameId = match.group(1);
  }

  for (var i = 0; i < features.length; i++) {
    final feature = features[i];
    final int featureIndex = i;
    final properties = feature['properties'] as Map<String, dynamic>?;
    String areaName = properties?['NAME_2'] ?? 
                           properties?['NAME_1'] ?? 
                           properties?['REGION'] ?? 
                           'Unknown';

    // Use filename ID if name is not found in properties
    if ((areaName == 'Unknown' || areaName == 'NOT_FOUND') && filenameId != null) {
      areaName = filenameId;
    }

    // Create a unique ID for each individual polygon to ensure unique data
    final String individualId = '${areaName}_$featureIndex';

    final int users = getSimulatedUserCount(individualId, level);
    Color areaColor;

    if (level == 'region') {
      // Absolute thresholds for Region level to ensure full color range
      if (users > 11000) {
        areaColor = Colors.red.withOpacity(0.6);
      } else if (users > 8000) {
        areaColor = Colors.orange.withOpacity(0.6);
      } else if (users > 5000) {
        areaColor = Colors.green.withOpacity(0.6);
      } else {
        areaColor = Colors.blue.withOpacity(0.6);
      }
    } else {
      // Relative thresholds for Province and Municity levels
      int redThreshold = (level == 'province') ? 5000 : 800;
      if (users > redThreshold) areaColor = Colors.red.withOpacity(0.6);
      else if (users > redThreshold * 0.7) areaColor = Colors.orange.withOpacity(0.6);
      else if (users > redThreshold * 0.35) areaColor = Colors.green.withOpacity(0.6);
      else areaColor = Colors.blue.withOpacity(0.6);
    }

    final geom = feature['geometry'] as Map<String, dynamic>?;
    if (geom == null) continue;

    final type = geom['type'] as String?;
    final coordinates = geom['coordinates'] as List<dynamic>?;

    void addRegionPolygon(List<dynamic> polygonCoords) {
      final points = <LatLng>[];
      for (final p in polygonCoords) {
        points.add(LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()));
      }

      polygons.add(TappablePolygon(
        regionName: individualId, // Use the unique ID for tapping
        properties: properties,
        points: points,
        color: areaColor,
        borderColor: Colors.white.withOpacity(0.5),
        borderStrokeWidth: 1.0,
        isFilled: true,
      ));
    }

    if (type == 'Polygon') {
      for (final polygon in coordinates!) addRegionPolygon(polygon as List<dynamic>);
    } else if (type == 'MultiPolygon') {
      for (final multi in coordinates!) {
        for (final polygon in multi) addRegionPolygon(polygon as List<dynamic>);
      }
    }
  }
  return polygons;
}