import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/store.dart';

/// A transom across the top and two sashes below it.
DMap transomWindow() => {
      ...newDrawing(),
      'widthMm': 1400,
      'heightMm': 1600,
      'root': {
        'id': 'top-split',
        'axis': 'h',
        'ratio': .3,
        'a': {...newLeaf('top'), 'opening': 'bottom'},
        'b': {
          'id': 'mid-split',
          'axis': 'v',
          'ratio': .5,
          'a': {...newLeaf('bl'), 'opening': 'left'},
          'b': {...newLeaf('br'), 'opening': 'right'},
        },
      },
    };

void main() {
  final recipe = recipeFor(sampleProfiles().first);
  List<double> box(DMap d, String id) =>
      layoutDrawing(d, recipe).cells.firstWhere((c) => c.node['id'] == id).box;
  double tall(DMap d, String id) => box(d, id)[3] - box(d, id)[1];
  double wide(DMap d, String id) => box(d, id)[2] - box(d, id)[0];

  test('each side of a section is an impost or the frame', () {
    final sides = sectionSides(transomWindow(), 'bl');
    expect(sides, {
      'right': 'mid-split',
      'left': null,
      'top': 'top-split',
      'bottom': null
    });
    expect(sectionSides(transomWindow(), 'top'),
        {'right': null, 'left': null, 'top': null, 'bottom': 'top-split'});
    // On an arch only the bottom and right frame sides grow the window.
    expect(sectionSides({...transomWindow(), 'shape': 'arch'}, 'top'),
        {'right': null, 'bottom': 'top-split'});
  });

  test('pulling a side on an impost resizes exactly that section', () {
    final d = transomWindow();
    final up = resizeSection(d, recipe, 'bl', 'top', -100);
    expect(tall(up, 'bl'), closeTo(tall(d, 'bl') + 100, .01));
    expect(tall(up, 'top'), closeTo(tall(d, 'top') - 100, .01));
    expect(up['heightMm'], 1600);
    final right = resizeSection(d, recipe, 'bl', 'right', 150);
    expect(wide(right, 'bl'), closeTo(wide(d, 'bl') + 150, .01));
    expect(wide(right, 'br'), closeTo(wide(d, 'br') - 150, .01));
    // The original drawing is untouched.
    expect(d['root']['ratio'], .3);
  });

  test('pulling a frame side moves only that section, the rest stay put', () {
    final d = transomWindow();
    final down = resizeSection(d, recipe, 'bl', 'bottom', 200);
    expect(down['heightMm'], 1800);
    expect(down['heightMm'], isA<int>());
    expect(tall(down, 'top'), closeTo(tall(d, 'top'), .01));
    expect(tall(down, 'bl'), closeTo(tall(d, 'bl') + 200, .01));
    // The other sash keeps its bottom: the frame steps round it.
    expect(tall(down, 'br'), closeTo(tall(d, 'br'), .01));
    expect(down['root']['b']['b']['trim'], {'bottom': 200});
    final wider = resizeSection(d, recipe, 'br', 'right', 300);
    expect(wider['widthMm'], 1700);
    expect(wide(wider, 'bl'), closeTo(wide(d, 'bl'), .01));
    expect(wide(wider, 'br'), closeTo(wide(d, 'br') + 300, .01));
  });

  test('a section cannot be pulled below 80 mm or past 6 m', () {
    final d = transomWindow();
    expect(
        () => resizeSection(d, recipe, 'top', 'bottom', -500), throwsException);
    expect(
        () => resizeSection(d, recipe, 'bl', 'bottom', 5000), throwsException);
    expect(
        () => resizeSection(
            {...d, 'shape': 'arch', 'riseMm': 300}, recipe, 'bl', 'left', 10),
        throwsException);
  });

  testWidgets(
      'the chosen section has grips; pulling the bottom one makes it taller',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-resize-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DrawingEditor(store: store, initial: {
          'profileId': store.profiles.first['id'],
          'quantity': 1,
          'drawing': transomWindow(),
        })));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    DMap drawing() =>
        (tester.widget<CustomPaint>(canvas).painter! as DrawingPainter).drawing;
    final rect = tester.getRect(canvas);
    Offset at(V v) =>
        rect.topLeft +
        CanvasTransform(rect.size, drawing(), sectionDimensions: true).to(v);
    await tester.tapAt(at(const V(350, 1100)));
    await tester.pumpAndSettle();
    final grips = (tester
            .widget<CustomPaint>(find.byKey(const ValueKey('section-handles')))
            .painter! as HandlesPainter)
        .handles;
    expect({for (final g in grips) g.side}, {'left', 'right', 'top', 'bottom'});
    final bottom = grips.firstWhere((g) => g.side == 'bottom');
    final before = tall(drawing(), 'bl');
    final gesture = await tester.startGesture(
        tester.getTopLeft(find.byKey(const ValueKey('section-handles'))) +
            bottom.at);
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(drawing()['heightMm'], greaterThan(1600));
    expect(tall(drawing(), 'bl'), greaterThan(before));
    expect(tall(drawing(), 'top'), closeTo(tall(transomWindow(), 'top'), .5));
    expect(tall(drawing(), 'br'), closeTo(tall(transomWindow(), 'br'), .5));
    // One undo brings the size back.
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(drawing()['heightMm'], 1600);
    expect(tester.takeException(), isNull);
  });
}
