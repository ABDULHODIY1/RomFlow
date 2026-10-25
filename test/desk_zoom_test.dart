import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/store.dart';

void main() {
  testWidgets('two fingers zoom the desk; fit brings the window back',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-zoom-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DrawingEditor(store: store)));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    final before =
        (tester.widget<CustomPaint>(canvas).painter! as DrawingPainter)
            .drawing
            .toString();
    final center = tester.getCenter(canvas);
    final a = await tester.startGesture(center - const Offset(30, 0));
    final b =
        await tester.startGesture(center + const Offset(30, 0), pointer: 7);
    await tester.pump();
    for (var i = 1; i <= 6; i++) {
      await a.moveTo(center - Offset(30.0 + i * 15, 0));
      await b.moveTo(center + Offset(30.0 + i * 15, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    // Zoomed, and the pinch drew nothing.
    expect(find.byKey(const ValueKey('fit-desk')), findsOneWidget);
    expect(
        (tester.widget<CustomPaint>(canvas).painter! as DrawingPainter)
            .drawing
            .toString(),
        before);
    await tester.tap(find.byKey(const ValueKey('fit-desk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fit-desk')), findsNothing);
    // Two taps on a section open its settings.
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.text('Ochilishi (xonadan ko‘rinish)'), findsOneWidget);
  });
}
