import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/model_motion.dart';
import 'dart:ui' as ui;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('four low-profile fixed catches sit flush on frame or mullion faces',
      () {
    final m = WindowModel(
        drawingPresets.firstWhere((p) => p.id == 'twoOpen').drawing(),
        defaultRecipe({}));
    final catches =
        m.parts.values.where((p) => p.title.startsWith('Yelma')).toList();
    expect(catches.length, 4);
    expect(materialNames['corner'], contains('Archa'));
    expect(materialNames['cornerProfile'], isNot(contains('Archa')));
    final front = (m.recipe['frameDepth'] as num).toDouble();
    final stock = m.parts.values
        .where((p) => p.materialKey == 'frame' || p.materialKey == 'mullion');
    for (final part in catches) {
      expect(part.group, isNull);
      expect(part.extent.z, lessThanOrEqualTo(4.1));
      expect(part.extent.x, lessThanOrEqualTo(18));
      final vertices = m.faces
          .where((f) => f.partId == part.id)
          .expand((f) => f.vertices)
          .toList();
      expect(vertices.map((p) => p.z).reduce(math.min), closeTo(front, 1e-8));
      expect(
          vertices.any((v) =>
              (v.z - front).abs() < 1e-8 &&
              stock.any((p) =>
                  (v.x - p.center.x).abs() <= p.extent.x / 2 + 1e-8 &&
                  (v.y - p.center.y).abs() <= p.extent.y / 2 + 1e-8)),
          isTrue);
      final still = ModelPainter(m, 0, 0, 1, 0, 'all', false);
      final open = ModelPainter(m, 0, 0, 1, 1, 'all', false);
      for (final v in vertices) {
        expect(
            (still.world(v, part.group, part) - open.world(v, part.group, part))
                .length,
            0);
      }
    }
  });
  test('fixed keep remains visible in front of its mounting stock', () {
    final m = WindowModel(
        drawingPresets.firstWhere((p) => p.id == 'twoOpen').drawing(),
        defaultRecipe({}));
    final part = m.parts.values.firstWhere((p) => p.title.startsWith('Yelma'));
    final painter = ModelPainter(m, -.2, .12, 1, 1, 'all', false);
    const size = ui.Size(480, 480);
    final point = painter.project(
        painter.positioned(part.center, part.group, part), size);
    expect(painter.pick(point, size), part.id);
    final back = ModelPainter(m, math.pi - .2, .12, 1, 1, 'all', false);
    final behind =
        back.project(back.positioned(part.center, part.group, part), size);
    expect(back.pick(behind, size), isNot(part.id));
  });
  test('mount points stay on stock on both sides of centre mullion', () {
    final m = WindowModel(
        drawingPresets.firstWhere((p) => p.id == 'twoOpen').drawing(),
        defaultRecipe({}));
    for (final target in [const V(663, 313), const V(737, 1088)]) {
      final (point, size) = m.frameMount(target);
      expect(point.x, inInclusiveRange(675 + size / 2, 725 - size / 2));
      expect(point.y, closeTo(target.y, 1e-8));
    }
  });
  test('coverage fringe is bounded, winding-independent and finite', () {
    final p = [
      const ui.Offset(10, 10),
      const ui.Offset(100, 15),
      const ui.Offset(90, 100),
      const ui.Offset(15, 90)
    ];
    final outer = ModelEdgeCoverage.outer(p, 1 / 3);
    final reverse =
        ModelEdgeCoverage.outer(p.reversed.toList(), 1 / 3).reversed.toList();
    for (var i = 0; i < p.length; i++) {
      expect((outer[i] - p[i]).distance, inInclusiveRange(1 / 3, 2 / 3 + 1e-8));
      expect((outer[i] - reverse[i]).distance, lessThan(1e-8));
      expect(outer[i].dx.isFinite && outer[i].dy.isFinite, isTrue);
    }
  });
}
