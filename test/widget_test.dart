import 'package:flutter/material.dart';
import 'package:flutter_application_1/page1/Registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Analysis map smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Registration()));
  });
}