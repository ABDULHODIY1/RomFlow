import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/store.dart';

void main() {
  testWidgets(
      'phone drawing editor: split, drag divider, undo, redo, exact dimensions and BOM',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-drawing-ui-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await tester.runAsync(s.init);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: DrawingEditor(startInVisualMode: false, store: s)));
    await tester.pumpAndSettle();
    final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    DrawingPainter painter() =>
        tester.widget<CustomPaint>(paint).painter! as DrawingPainter;
    await tester.scrollUntilVisible(paint, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(layoutDrawing(painter().drawing, painter().recipe).cells.length, 1);
    await tester.scrollUntilVisible(find.text('Tik ½'), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tik ½'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(paint, -240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final oldRatio = painter().drawing['root']['ratio'] as num;
    final area = tester.getRect(paint),
        t = CanvasTransform(area.size, painter().drawing),
        split = layoutDrawing(painter().drawing, painter().recipe).splits.first;
    final mid = (t.to(split.a) + t.to(split.b)) / 2 + area.topLeft;
    await tester.dragFrom(mid, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(painter().drawing['root']['ratio'], greaterThan(oldRatio));
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(painter().drawing['root']['ratio'], oldRatio);
    await tester.tap(find.byTooltip('Qaytarish'));
    await tester.pumpAndSettle();
    expect(painter().drawing['root']['ratio'], greaterThan(oldRatio));
    await tester.scrollUntilVisible(find.text('Aniq bo‘lim o‘lchami (mm)'), 220,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aniq bo‘lim o‘lchami (mm)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '500');
    await tester.tap(find.text('Qo‘llash'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(paint, -240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final l = layoutDrawing(painter().drawing, painter().recipe);
    expect(l.cells.first.box[2] - l.cells.first.box[0], closeTo(500, 1e-6));
    await tester.scrollUntilVisible(
        find.text('Material va chiqindini hisoblash'), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material va chiqindini hisoblash'));
    await tester.pumpAndSettle();
    expect(find.text('Materiallar va xarid summasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reference three-leaf drawing renders without clipping errors',
      (tester) async {
    tester.view.physicalSize = const Size(430, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drawing = newDrawing();
    drawing['root'] = {
      'id': 's1',
      'axis': 'v',
      'ratio': 1 / 3,
      'a': {...newLeaf('a'), 'opening': 'left'},
      'b': {
        'id': 's2',
        'axis': 'v',
        'ratio': .5,
        'a': newLeaf('b'),
        'b': {...newLeaf('c'), 'opening': 'right'}
      }
    };
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            backgroundColor: const Color(0xffedf4fb),
            appBar: AppBar(title: const Text('RomFlow • Chizma')),
            body: RepaintBoundary(
                key: key,
                child: CustomPaint(
                    size: const Size(430, 450),
                    painter: DrawingPainter(drawing, defaultRecipe({}),
                        selected: 'a'))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${Directory.systemTemp.path}/romflow-drawing-test.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
