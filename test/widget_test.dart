import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synccanvas/main.dart';

void main() {
  testWidgets('SyncCanvas app smoke test', (WidgetTester tester) async {
    // Build SyncCanvas app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the initial loading or screen renders without exceptions.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(RootGateScreen), findsOneWidget);
  });
}
