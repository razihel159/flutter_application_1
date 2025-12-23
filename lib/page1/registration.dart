import 'package:flutter/material.dart';
import 'package:flutter_application_1/widget/Button.dart';
import 'package:flutter_application_1/osm_map/osm_map_widget.dart';
import 'package:flutter_application_1/PolygonMap/polygon_map_widget.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});
  @override
  State<Registration> createState() => _RegistrationState();
}

enum MapDisplayMode { none, detailedOsm, polygon }

class _RegistrationState extends State<Registration> {
  MapDisplayMode _mapMode = MapDisplayMode.none;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFaad3df),
      body: Stack(
        children: [
          _buildBody(),
          if (_mapMode == MapDisplayMode.none)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: SimpleButton(text: 'Proceed to Registration', onPressed: () {}),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_mapMode) {
      case MapDisplayMode.none:
        return Center(
          child: SimpleButton(
            text: 'Proceed to see World Map',
            onPressed: () => setState(() => _mapMode = MapDisplayMode.detailedOsm),
          ),
        );
      case MapDisplayMode.detailedOsm:
        return Stack(
          children: [
            const MyOSMMap(),
            Positioned(
              top: 40, right: 20,
              child: SimpleButton(
                text: 'View Data Map',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Data Map')), body: const PolygonMapWidget()))),
              ),
            ),
          ],
        );
      // Map embedded in Registration has been removed. Use 'View Data Map' to open the consolidated Map screen.
      case MapDisplayMode.polygon:
        return Center(
          child: SimpleButton(
            text: 'Open Map Screen',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Data Map')), body: const PolygonMapWidget()))),
          ),
        );
    }
  }
}