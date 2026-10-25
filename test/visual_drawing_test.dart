import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/store.dart';

void main() {
  testWidgets(
      'video workflow: tap split, place sash, edit dimension and calculate same document',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-visual-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DrawingEditor(store: store)));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    DrawingPainter painter() =>
        tester.widget<CustomPaint>(canvas).painter! as DrawingPainter;
    Offset onDrawing(V v) {
      final rect = tester.getRect(canvas);
      return rect.topLeft +
          CanvasTransform(rect.size, painter().drawing, sectionDimensions: true)
              .to(v);
    }

    expect(find.text('Yangi smeta'), findsOneWidget);
    expect(tester.getSize(canvas).height, greaterThan(300));
    await tester.tap(find.byTooltip('Tik bo‘lish'));
    await tester.pumpAndSettle();
    await tester.tapAt(onDrawing(const V(750, 750)));
    await tester.pumpAndSettle();
    expect(layoutDrawing(painter().drawing, painter().recipe).cells.length, 2);
    await tester.tap(find.byTooltip('Deraza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chapga'));
    await tester.pumpAndSettle();
    await tester.tapAt(onDrawing(const V(350, 750)));
    await tester.pumpAndSettle();
    expect(painter().drawing['root']['a']['opening'], 'left');
    expect(painter().drawing['root']['b']['opening'], 'fixed');
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(painter().drawing['root']['a']['opening'], 'fixed');
    await tester.tap(find.byTooltip('Qaytarish'));
    await tester.pumpAndSettle();
    expect(painter().drawing['root']['a']['opening'], 'left');
    // The inner dimension chain edits the actual divider, not a display-only label.
    final sectionRect = tester.getRect(canvas),
        sectionTransform = CanvasTransform(sectionRect.size, painter().drawing,
            sectionDimensions: true);
    final sectionCorner = sectionTransform.to(const V(1500, 1500));
    final sectionStart = sectionTransform.to(const V(0, 0));
    final splitAt = sectionTransform.to(const V(750, 1500));
    await tester.tapAt(sectionRect.topLeft +
        Offset((sectionStart.dx + splitAt.dx) / 2, sectionCorner.dy + 24));
    await tester.pumpAndSettle();
    expect(find.text('Bo‘lim eni'), findsOneWidget);
    for (final digit in ['6', '0', '0']) {
      await tester.tap(find.widgetWithText(OutlinedButton, digit));
      await tester.pump();
    }
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    final stops = sectionStops(
        layoutDrawing(painter().drawing, painter().recipe), true, 1500);
    expect(stops[1], closeTo(600, .001));
    expect(painter().drawing['widthMm'], 1500);
    final rect = tester.getRect(canvas),
        transform = CanvasTransform(rect.size, painter().drawing,
            sectionDimensions: true);
    final corner = transform.to(const V(1500, 1500));
    final begin = transform.to(const V(0, 0));
    await tester.tapAt(
        rect.topLeft + Offset((begin.dx + corner.dx) / 2, corner.dy + 50));
    await tester.pumpAndSettle();
    expect(find.text('Rom eni'), findsOneWidget);
    for (final digit in ['3', '0', '0', '0']) {
      await tester.tap(find.widgetWithText(OutlinedButton, digit));
      await tester.pump();
    }
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(painter().drawing['widthMm'], 3000);
    expect(painter().drawing['root']['a']['opening'], 'left');
    await tester.tap(find.byKey(const ValueKey('calculate-drawing')));
    await tester.pumpAndSettle();
    expect(find.text('Materiallar va sarf'), findsOneWidget);
    expect(find.text('Materiallar va xarid summasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small dark canvas mode keeps tools and details accessible',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-small-visual-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.dark),
        home: DrawingEditor(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Batafsil sozlash'));
    await tester.pumpAndSettle();
    expect(find.text('Batafsil sozlash'), findsOneWidget);
    await tester.tap(find.byTooltip('Chizma stoliga qaytish'));
    await tester.pumpAndSettle();
    expect(find.text('Yangi smeta'), findsOneWidget);
    expect(find.text('Smetaga qo‘shish'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
