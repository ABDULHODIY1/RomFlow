import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';

DMap simpleRecipe() => recipeFor(
    sampleProfiles().firstWhere((p) => p['id'] == 'series-akfa-simple-hollow'));

DMap twoSections() => newDrawing()
  ..['root'] = {
    'id': 'r',
    'axis': 'v',
    'ratio': .5,
    'a': {...newLeaf('a'), 'opening': 'fixed'},
    'b': {...newLeaf('b'), 'opening': 'left'},
  };

void main() {
  test('outset grows a convex outline with mitred corners', () {
    final square = [V(0, 0), V(100, 0), V(100, 100), V(0, 100)];
    expect(bounds(inset(square, 10)), [10, 10, 90, 90]);
    final grown = offsetOutline(square, -10);
    expect(grown.length, 4);
    final b = bounds(grown);
    for (final (got, want) in [
      (b[0], -10.0),
      (b[1], -10.0),
      (b[2], 110.0),
      (b[3], 110.0)
    ]) {
      expect(got, closeTo(want, 1e-9));
    }
    expect(polygonArea(outset(square, 5)), closeTo(110 * 110, 1e-6));
  });

  test('glass reaching under the lip is ordered larger than the opening', () {
    final d = newDrawing(), r = simpleRecipe();
    expect(r['glassRebateMm'], 12);
    double glassWidth(DMap recipe) => ((calculateDrawing(
                {'drawing': d, 'recipe': recipe, 'quantity': 1},
                {})['specs'] as List)
            .single['widthMm'] as num)
        .toDouble();
    final under = glassWidth(r),
        inside = glassWidth({...r, 'glassRebateMm': 0});
    expect(under - inside, closeTo(24, 1e-6));
    expect(() => validateRecipe({...r, 'glassRebateMm': 41}), throwsException);
    // Recipes saved before the setting keep the old glass size.
    final old = defaultRecipe({})..remove('glassRebateMm');
    expect(
        () =>
            calculateDrawing({'drawing': d, 'recipe': old, 'quantity': 1}, {}),
        returnsNormally);
  });

  test('simple aluminium 3D: glass sits on the lip, bead clips to the box', () {
    final r = simpleRecipe(), m = WindowModel(twoSections(), r);
    final depth = (r['frameDepth'] as num).toDouble();
    final glass = m.faces.where((f) => f.glass).expand((f) => f.vertices);
    final lip = m.lipHeight(depth);
    // The pane rests against the exterior lip, not in the middle.
    expect(glass.map((p) => p.z).reduce(math.min),
        closeTo(m.glassSeat(depth), 1e-6));
    expect(m.glassSeat(depth), greaterThan(lip));
    final beads = m.parts.values.where((p) => p.materialKey == 'bead').toList();
    expect(beads, isNotEmpty);
    expect(beads.every((p) => p.title.startsWith('Shtapik • U')), isTrue);
    // The fixed pane's bead ring reaches the box wall, outside the pane.
    final fixed = layoutDrawing(twoSections(), r).cells.first.polygon;
    final pane = bounds(glassOutline(fixed, r));
    final beadFaces = m.faces
        .where(
            (f) => m.parts[f.partId]?.materialKey == 'bead' && f.group == null)
        .expand((f) => f.vertices)
        .toList();
    final beadLeft = beadFaces.map((p) => p.x).reduce(math.min);
    expect(beadLeft, lessThan(pane[0]));
    expect(beadLeft, closeTo(bounds(fixed)[0] - m.rebateZone, 1));
    // Frame bars keep one part each and stay inside the drawing.
    final frame = m.parts.values.where((p) => p.materialKey == 'frame');
    expect(frame.length, 4);
    for (final part in frame) {
      expect(
          m.faces
              .where((f) => f.partId == part.id)
              .expand((f) => f.vertices)
              .every((v) => v.x >= -1e-6 && v.x <= 1500 + 1e-6),
          isTrue);
    }
  });

  test('dolphin handle is the aluminium default and turns before the swing',
      () {
    final r = simpleRecipe();
    expect(r['windowHandle'], 'dolphin');
    expect(defaultRecipe({'material': 'pvc'})['windowHandle'], 'pull');
    final m = WindowModel(twoSections(), r);
    final turn = m.motions.values.singleWhere((x) => x.mode == 'turn');
    expect(turn.ownerId, 'b');
    expect(turn.turn.abs(), closeTo(math.pi / 2, 1e-9));
    final lever = m.parts.values
        .singleWhere((p) => p.title == 'Delfin tutqich • egri dasta');
    expect(lever.group, 'b-turn');
    expect(m.parts.values.any((p) => p.title == 'Delfin tutqich • ilgak tili'),
        isTrue);
    final strike =
        m.parts.values.singleWhere((p) => p.title.startsWith('Ilgak tutgichi'));
    expect(strike.group, isNull);
    // A point on the lever below the pivot ends up beside it after the turn,
    // while the sash itself has not moved yet.
    final below = turn.pivot + const P3(0, 60, 0);
    final turned = turn.transform(below, .22);
    expect((turned - turn.pivot).length, closeTo(60, 1e-6));
    expect(turned.y, closeTo(turn.pivot.y, 1e-6));
    expect(m.groups['b']!.transform(below, .22).x, closeTo(below.x, 1e-9));
    expect(turn.transform(below, 0).y, closeTo(below.y, 1e-9));
    // Pull and lever handles stay available.
    expect(
        WindowModel(twoSections(), {...r, 'windowHandle': 'pull'})
            .motions
            .values
            .any((x) => x.mode == 'rod'),
        isTrue);
    expect(WindowModel(twoSections(), {...r, 'windowHandle': 'lever'}).motions,
        isEmpty);
  });

  test('90° corner joins add the connector to the bill, 2D, PDF and 3D', () {
    final r = simpleRecipe(), d = twoSections()..['joins'] = ['left', 'up'];
    expect(cornerJoins(d), ['left']);
    final bill =
        calculateDrawing({'drawing': d, 'recipe': r, 'quantity': 1}, {});
    final line =
        (bill['parts'] as List).firstWhere((p) => p['key'] == 'cornerProfile');
    expect(line['net'], closeTo(1.5, 1e-6));
    expect(drawingSvg(d, r), contains('90°'));
    final m = WindowModel(d, r);
    final joint =
        m.parts.values.singleWhere((p) => p.materialKey == 'cornerProfile');
    // It stands outside the frame edge, gripping the frame's faces.
    expect(joint.center.x - joint.extent.x / 2,
        lessThan(-(r['frameDepth'] as num)));
    expect(joint.center.x + joint.extent.x / 2, greaterThan(0));
    expect(joint.extent.y, closeTo(1500, 1e-6));
    // The wall opens on the joined side and the next frame is shown there.
    final plain = WindowModel(twoSections(), r);
    expect(
        plain.wallFaces.where((f) => f.vertices.every((v) => v.x < -60)).length,
        greaterThan(0));
    expect(
        m.wallFaces.where((f) => f.vertices.every((v) => v.x < -60)).length,
        lessThan(plain.wallFaces
            .where((f) => f.vertices.every((v) => v.x < -60))
            .length));
    expect(m.wallFaces.any((f) => f.glass), isTrue);
    // Shapes without straight sides ignore the setting.
    expect(cornerJoins({...d, 'shape': 'circle'}), isEmpty);
  });
}
