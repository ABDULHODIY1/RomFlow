import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';

DMap doorDrawing() {
  final d = newDrawing();
  d['widthMm'] = 1000;
  d['heightMm'] = 2100;
  d['root'] = {
    ...newLeaf('door'),
    'opening': 'doorLeft',
    'fill': 'glass',
    'infill': {
      'id': 's',
      'axis': 'h',
      'ratio': .55,
      'a': {'id': 'g', 'fill': 'glass'},
      'b': {'id': 'l', 'fill': 'lambris'}
    }
  };
  return d;
}

void main() {
  test('3D hinged solids keep hinge axis fixed, slide correctly, remain finite',
      () {
    final model = WindowModel(doorDrawing(), defaultRecipe({}));
    expect(model.groups.length, 1);
    expect(model.faces.length, greaterThan(100));
    final group = model.groups.values.single;
    final hinge = P3(group.hingeX, 500, group.hingeZ),
        still = group.transform(hinge, 1);
    expect((still - hinge).length, closeTo(0, 1e-9));
    final tip = P3(group.hingeX + 800, 500, group.hingeZ),
        open = group.transform(tip, 1);
    expect((open - hinge).length, closeTo((tip - hinge).length, 1e-6));
    expect((open.z - tip.z).abs(), greaterThan(700));
    expect(
        model.faces
            .expand((f) => f.vertices)
            .every((p) => p.x.isFinite && p.y.isFinite && p.z.isFinite),
        isTrue);
    expect(model.faces.any((f) => f.glass), isTrue);
  });
  test(
      'one door with internal panel stays one door in BOM and PDF accepts vector drawing',
      () async {
    final drawing = doorDrawing(), r = defaultRecipe({});
    final out = calculateDrawing({'drawing': drawing, 'quantity': 1}, {});
    expect(out['doorCount'], 1);
    expect(out['openingCount'], 1);
    expect((out['specs'] as List).length, 2);
    expect(
        (out['parts'] as List)
            .firstWhere((p) => p['key'] == 'doorLock')['quantity'],
        1);
    expect(out['cuts']['sashMullion']['bars'], isNotEmpty);
    final doc = pw.Document();
    doc.addPage(
        pw.Page(build: (_) => pw.SvgImage(svg: drawingSvg(drawing, r))));
    final bytes = await doc.save();
    expect(bytes.length, greaterThan(1000));
  });
  testWidgets('interactive 3D rotates, animates and draws real depth',
      (tester) async {
    tester.view.physicalSize = const Size(430, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: View3D(drawing: doorDrawing(), recipe: defaultRecipe({}))));
    await tester.pump();
    final target = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ModelPainter);
    ModelPainter p() =>
        tester.widget<CustomPaint>(target).painter! as ModelPainter;
    final old = p().yaw;
    await tester.drag(target, const Offset(60, 10));
    await tester.pump();
    expect(p().yaw, isNot(old));
    await tester.tap(find.byTooltip('Ochish / yopish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(p().progress, greaterThan(0));
    await tester.tap(find.byTooltip('To‘xtatish'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(of: target, matching: find.byType(RepaintBoundary))
        .first);
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${Directory.systemTemp.path}/romflow-door-test.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
