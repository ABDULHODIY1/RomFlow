import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/store.dart';

void main() {
  test('hollow mitred profiles retain one part per bar and respect mm envelope',
      () {
    final d = newDrawing(), r = defaultRecipe({}), m = WindowModel(d, r);
    final frame =
        m.parts.values.where((p) => p.materialKey == 'frame').toList();
    expect(frame.length, 4);
    for (final part in frame) {
      final surfaces = m.faces.where((f) => f.partId == part.id).toList();
      expect(surfaces.length, greaterThan(40));
      expect(part.extent.z, 60);
      // The cap is strips around cavities, not a single solid 50x60 block.
      expect(
          surfaces.every((f) => f.vertices.every((v) =>
              v.x >= 0 &&
              v.x <= 1500 &&
              v.y >= 0 &&
              v.y <= 1500 &&
              v.z >= 0 &&
              v.z <= 60)),
          isTrue);
    }
    r['profileChambers'] = 4;
    expect(WindowModel(d, r).faces.length, greaterThan(m.faces.length));
    final old = defaultRecipe({})
      ..remove('profileWallMm')
      ..remove('profileChambers');
    expect(
        () =>
            calculateDrawing({'drawing': d, 'recipe': old, 'quantity': 1}, {}),
        returnsNormally);
    r['profileChambers'] = 2.5;
    expect(() => validateRecipe(r), throwsException);
  });
  test('non-right corners follow polygon and match corner connector count', () {
    final d = newDrawing()..['shape'] = 'triangle';
    d['root'] = {...newLeaf('a'), 'opening': 'left'};
    final r = defaultRecipe({}), m = WindowModel(d, r);
    final bill =
        calculateDrawing({'drawing': d, 'recipe': r, 'quantity': 1}, {});
    expect(m.parts.values.where((p) => p.materialKey == 'corner').length,
        (bill['parts'] as List).firstWhere((p) => p['key'] == 'corner')['net']);
    expect(
        m.parts.values
            .where((p) => p.materialKey == 'corner' && p.group != null)
            .length,
        3);
    expect(
        m.faces
            .expand((f) => f.vertices)
            .every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
        isTrue);
  });
  testWidgets('parts palette edits the same document used by 2D, 3D and BOM',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-parts-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    await tester.pumpWidget(MaterialApp(
        home: DrawingEditor(startInVisualMode: false, store: store)));
    await tester.pumpAndSettle();
    Future<void> choose(String label) async {
      await tester.tap(find.byTooltip('Detallardan yig‘ish'));
      await tester.pumpAndSettle();
      final option = find.descendant(
          of: find.byType(BottomSheet), matching: find.text(label));
      await tester.scrollUntilVisible(option, 180,
          scrollable: find.byType(Scrollable).last);
      await Scrollable.ensureVisible(tester.element(option), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    await choose('Qanot: Eshik: chap');
    await choose('Lambir');
    final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    await tester.scrollUntilVisible(paint, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final twoD = tester.widget<CustomPaint>(paint).painter! as DrawingPainter;
    expect(twoD.drawing['root']['opening'], 'doorLeft');
    expect(twoD.drawing['root']['fill'], 'lambris');
    final model = WindowModel(twoD.drawing, twoD.recipe);
    expect(model.groups.length, 1);
    expect(model.parts.values.any((p) => p.materialKey == 'lambris'), isTrue);
    final bill = calculateDrawing(
        {'drawing': twoD.drawing, 'recipe': twoD.recipe, 'quantity': 1}, {});
    expect(bill['doorCount'], 1);
    expect((bill['parts'] as List).any((p) => p['key'] == 'lambris'), isTrue);
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(
        (tester.widget<CustomPaint>(paint).painter! as DrawingPainter)
            .drawing['root']['fill'],
        'glass');
    expect(tester.takeException(), isNull);
  });
}
