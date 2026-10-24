import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/store.dart';

DMap exampleDrawing() {
  final d = newDrawing();
  d['root'] = {
    'id': 's',
    'axis': 'v',
    'ratio': .5,
    'a': {...newLeaf('a'), 'opening': 'left'},
    'b': newLeaf('b')
  };
  return d;
}

void main() {
  test(
      'exploded model maps faces to named components; zero explosion preserves assembly',
      () {
    final d = exampleDrawing(), r = defaultRecipe({}), m = WindowModel(d, r);
    expect(m.faces.every((f) => m.parts.containsKey(f.partId)), isTrue);
    expect(m.parts.values.any((p) => p.materialKey == 'glass'), isTrue);
    expect(m.parts.values.any((p) => p.materialKey == 'uGasket'), isTrue);
    final glass = m.parts.values.firstWhere((p) => p.materialKey == 'glass'),
        frame = m.parts.values.firstWhere((p) => p.materialKey == 'frame');
    final zero = glass.explosionOffset(0, 1500, 1500, 1500);
    expect(zero.length, 0);
    expect(glass.explosionOffset(1, 1500, 1500, 1500).z,
        greaterThan(frame.explosionOffset(1, 1500, 1500, 1500).z));
    final plain = ModelPainter(m, 0, 0, 1, 0, 'all', false),
        expanded = ModelPainter(m, 0, 0, 1, 0, 'all', false, explosion: 1);
    final assembled = plain.positioned(glass.center, glass.group, glass),
        scattered = expanded.positioned(glass.center, glass.group, glass);
    expect((scattered - assembled).length, greaterThan(500));
    expect(
        expanded.pick(expanded.project(scattered, const Size(430, 500)),
            const Size(430, 500)),
        isNotNull);
  });
  testWidgets(
      'explosion animation and selection show bill quantities for all ordered units',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = exampleDrawing(), r = defaultRecipe(sampleProfiles().first);
    final bill = calculateDrawing(
        {'drawing': d, 'recipe': r, 'quantity': 3}, sampleProfiles().first);
    await tester.pumpWidget(
        MaterialApp(home: View3D(drawing: d, recipe: r, calculation: bill)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sochish / yig‘ish'));
    await tester.pumpAndSettle();
    final target = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ModelPainter);
    ModelPainter painter() =>
        tester.widget<CustomPaint>(target).painter! as ModelPainter;
    expect(painter().explosion, closeTo(1, 1e-5));
    final p = painter(),
        part = p.model.parts.values.firstWhere((p) => p.materialKey == 'glass');
    final rect = tester.getRect(target),
        at = p.project(p.positioned(part.center, part.group, part), rect.size) +
            rect.topLeft;
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.textContaining('3 ta konstruksiya: sof'), findsOneWidget);
    expect(find.textContaining('Xarid summasi:'), findsOneWidget);
    await tester.tap(find.byTooltip('Faqat tanlangan'));
    await tester.pumpAndSettle();
    expect(painter().isolate, isTrue);
    await tester.tap(find.byTooltip('Materiallar tarkibi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ichida nima bor? • 3 ta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('back on the opening view the exploded parts come together',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = exampleDrawing(), r = defaultRecipe(sampleProfiles().first);
    await tester.pumpWidget(MaterialApp(home: View3D(drawing: d, recipe: r)));
    await tester.pumpAndSettle();
    ModelPainter painter() => tester
        .widget<CustomPaint>(find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ModelPainter))
        .painter! as ModelPainter;
    await tester.tap(find.byTooltip('Sochish / yig‘ish'));
    await tester.pumpAndSettle();
    expect(painter().explosion, closeTo(1, 1e-5));
    await tester.tap(find.byTooltip('Ochilish'));
    await tester.pumpAndSettle();
    expect(painter().explosion, 0);
  });
  testWidgets(
      'outer handle changes dimensions and undo restores the original drawing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-resize-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await tester.runAsync(s.init);
    await tester.pumpWidget(
        MaterialApp(home: DrawingEditor(startInVisualMode: false, store: s)));
    await tester.pumpAndSettle();
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('O‘lchamni tortish'), 140,
        scrollable: scroll);
    await tester.ensureVisible(find.text('O‘lchamni tortish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('O‘lchamni tortish'));
    await tester.pumpAndSettle();
    final target = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    await tester.scrollUntilVisible(target, 160, scrollable: scroll);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    DrawingPainter p() =>
        tester.widget<CustomPaint>(target).painter! as DrawingPainter;
    final rect = tester.getRect(target),
        t = CanvasTransform(rect.size, p().drawing);
    final corner = t.to(const V(1500, 1500)) + rect.topLeft;
    await tester.dragFrom(corner, const Offset(-60, -60));
    await tester.pumpAndSettle();
    expect(p().drawing['widthMm'], lessThan(1500));
    expect(p().drawing['heightMm'], lessThan(1500));
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(p().drawing['widthMm'], 1500);
    expect(p().drawing['heightMm'], 1500);
    expect(tester.takeException(), isNull);
  });
}
