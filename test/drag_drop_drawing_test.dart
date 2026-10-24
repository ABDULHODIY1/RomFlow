import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/store.dart';

void main() {
  testWidgets(
      'drag divider preview is read-only; drop edits document and supports undo/redo',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-drag-');
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
    Offset at(V v) {
      final rect = tester.getRect(canvas);
      return rect.topLeft +
          CanvasTransform(rect.size, painter().drawing, sectionDimensions: true)
              .to(v);
    }

    final before = jsonEncode(painter().drawing);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tik bo‘lish')));
    await gesture.moveBy(const Offset(0, 28));
    await tester.pump();
    await gesture.moveTo(at(const V(650, 750)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draft-drop-preview')), findsOneWidget);
    expect(jsonEncode(painter().drawing), before);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(layoutDrawing(painter().drawing, painter().recipe).cells.length, 2);
    expect(painter().drawing['root']['ratio'], lessThan(.5));
    expect(find.byKey(const ValueKey('draft-drop-preview')), findsNothing);
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(jsonEncode(painter().drawing), before);
    await tester.tap(find.byTooltip('Qaytarish'));
    await tester.pumpAndSettle();
    expect(layoutDrawing(painter().drawing, painter().recipe).cells.length, 2);
    final divided = jsonEncode(painter().drawing);
    // Releasing over canvas whitespace must not create a phantom frame part.
    final cancel =
        await tester.startGesture(tester.getCenter(find.text('Tik bo‘lish')));
    await cancel.moveBy(const Offset(0, 28));
    await tester.pump();
    await cancel.moveTo(tester.getTopLeft(canvas) + const Offset(5, 5));
    await tester.pumpAndSettle();
    await cancel.up();
    await tester.pumpAndSettle();
    expect(jsonEncode(painter().drawing), divided);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'drag window, door and infill onto separate cells; bill uses resulting drawing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-drag-parts-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    final drawing = newDrawing();
    drawing['root'] = {
      'id': 'split',
      'axis': 'v',
      'ratio': .5,
      'a': {
        ...newLeaf('left'),
        'infill': {
          'id': 'inner',
          'axis': 'h',
          'ratio': .5,
          'a': {'id': 'inner-top', 'fill': 'glass'},
          'b': {'id': 'inner-bottom', 'fill': 'glass'}
        }
      },
      'b': newLeaf('right')
    };
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.dark),
        home: DrawingEditor(store: store, initial: {'drawing': drawing})));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    DrawingPainter painter() =>
        tester.widget<CustomPaint>(canvas).painter! as DrawingPainter;
    Offset at(V v) {
      final rect = tester.getRect(canvas);
      return rect.topLeft +
          CanvasTransform(rect.size, painter().drawing, sectionDimensions: true)
              .to(v);
    }

    Future<void> drag(String label, V position) async {
      final gesture =
          await tester.startGesture(tester.getCenter(find.text(label).first));
      await gesture.moveBy(const Offset(0, 28));
      await tester.pump();
      await gesture.moveTo(at(position));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Deraza'));
    await tester.pumpAndSettle();
    await drag('Chapga', const V(350, 750));
    expect(painter().drawing['root']['a']['opening'], 'left');
    expect(painter().drawing['root']['b']['opening'], 'fixed');
    await tester.tap(find.text('Eshik'));
    await tester.pumpAndSettle();
    await drag('Eshik: o‘ng', const V(1100, 750));
    expect(painter().drawing['root']['b']['opening'], 'doorRight');
    await tester.tap(find.text('To‘ldirma'));
    await tester.pumpAndSettle();
    await drag('Lambir', const V(1100, 750));
    expect(painter().drawing['root']['b']['fill'], 'lambris');
    expect(painter().drawing['root']['a']['fill'], 'glass');
    await drag('Panel', const V(350, 1100));
    expect(painter().drawing['root']['a']['infill']['b']['fill'], 'panel');
    expect(painter().drawing['root']['a']['infill']['a']['fill'], 'glass');
    await tester.tap(find.byKey(const ValueKey('calculate-drawing')));
    await tester.pumpAndSettle();
    expect(find.text('Materiallar va sarf'), findsOneWidget);
    expect(find.text('Materiallar va xarid summasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
