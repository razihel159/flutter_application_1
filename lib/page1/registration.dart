import 'package:flutter/material.dart';
import 'package:flutter_application_1/widget/button.dart';
import 'package:flutter_application_1/PolygonMap/polygon_map_widget.dart';
import 'package:flutter_application_1/osm_map/osm_map_widget.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});
  @override
  State<Registration> createState() => _RegistrationState();
}

enum MapDisplayMode { none, detailedOsm, polygon }

class _RegistrationState extends State<Registration> {
  MapDisplayMode _mapMode = MapDisplayMode.none;
  final TextEditingController _regionController = TextEditingController();

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
              top: 50, right: 20,
              child: SimpleButton(
                text: 'View Data Map',
                onPressed: () => setState(() => _mapMode = MapDisplayMode.polygon),
              ),
            ),
          ],
        );
      case MapDisplayMode.polygon:
        return Column(
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _regionController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Selected Area', 
                  border: OutlineInputBorder(), 
                  filled: true, 
                  fillColor: Colors.white
                ),
              ),
            ),
            Expanded(
              child: PolygonMapWidget(
                onRegionSelected: (name) => setState(() => _regionController.text = name),
              ),
            ),
          ],
        );
    }
  }
}