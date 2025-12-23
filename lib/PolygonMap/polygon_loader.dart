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
    final properties = feature['properties'] as Map<String, dynamic>?;
    String areaName = properties?['ADM4_EN']?.toString() ??
                           properties?['ADM3_EN']?.toString() ??
                           properties?['NAME_2']?.toString() ??
                           properties?['ADM2_EN']?.toString() ??
                           properties?['NAME_1']?.toString() ??
                           properties?['ADM1_EN']?.toString() ??
                           properties?['REGION']?.toString() ??
                           'Unknown';

    final String areaId = properties?['ADM4_PCODE']?.toString() ??
        properties?['ADM3_PCODE']?.toString() ??
        properties?['ADM2_PCODE']?.toString() ??
        properties?['ADM1_PCODE']?.toString() ??
        '${areaName.replaceAll(' ', '_')}_$i';

    // Use filename ID if name is not found in properties
    if ((areaName == 'Unknown' || areaName == 'NOT_FOUND') && filenameId != null) {
      areaName = filenameId;
    }

    final int users = getSimulatedUserCount(areaId, level);
    Color areaColor;

    if (level == 'region') {
      // Absolute thresholds for Region level to ensure full color range
      if (users > 11000) {
        areaColor = Colors.red.withAlpha((0.6 * 255).round());
      } else if (users > 8000) {
        areaColor = Colors.orange.withAlpha((0.6 * 255).round());
      } else if (users > 5000) {
        areaColor = Colors.green.withAlpha((0.6 * 255).round());
      } else {
        areaColor = Colors.blue.withAlpha((0.6 * 255).round());
      }
    } else {
      // Relative thresholds for Province and Municity levels
      int redThreshold = (level == 'province') ? 5000 : 800;
      if (users > redThreshold) {
        areaColor = Colors.red.withAlpha((0.6 * 255).round());
      } else if (users > redThreshold * 0.7) {
        areaColor = Colors.orange.withAlpha((0.6 * 255).round());
      } else if (users > redThreshold * 0.35) {
        areaColor = Colors.green.withAlpha((0.6 * 255).round());
      } else {
        areaColor = Colors.blue.withAlpha((0.6 * 255).round());
      }
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
        id: areaId,
        regionName: areaName,
        userCount: users,
        properties: properties,
        points: points,
        color: areaColor,
        borderColor: Colors.white.withAlpha((0.5 * 255).round()),
        borderStrokeWidth: 1.0,
        isFilled: true,
      ));
    }

    if (type == 'Polygon') {
      for (final polygon in coordinates!) {
        addRegionPolygon(polygon as List<dynamic>);
      }
    } else if (type == 'MultiPolygon') {
      for (final multi in coordinates!) {
        for (final polygon in multi) {
          addRegionPolygon(polygon as List<dynamic>);
        }
      }
    }
  }
  return polygons;
}