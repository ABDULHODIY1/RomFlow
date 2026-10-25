import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/model_motion.dart';
import 'package:romflow/model_quality.dart';
import 'package:romflow/model_textures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WindowModel model() => WindowModel(
      drawingPresets.firstWhere((p) => p.id == 'twoOpen').drawing(),
      defaultRecipe({}));
  test('orbit and sash animation retain camera scale and centre', () {
    final m = model();
    double? scale;
    for (var i = 0; i < 48; i++) {
      final p = ModelPainter(m, i * math.pi / 24, math.sin(i / 10) * .7, 1,
          (i % 12) / 11, 'all', false,
          moving: true, rightInset: 50);
      p.fit(const ui.Size(400, 520));
      scale ??= p.fitScale;
      expect(p.fitScale, closeTo(scale, 1e-9));
      expect(p.fitX, 0);
      expect(p.fitY, 0);
      for (final face in p.transformed) {
        for (final vertex in face.$2) {
          final screen = p.project(vertex, const ui.Size(400, 520));
          expect(screen.dx, inInclusiveRange(24, 327));
          expect(screen.dy, inInclusiveRange(24, 496));
        }
      }
    }
  });
  test(
      'small profile sections frame their own geometry, not drawing dimensions',
      () {
    final m = model();
    m.faces
      ..clear()
      ..add(const ModelFace(
          [P3(0, 0, 0), P3(90, 0, 0), P3(90, 60, 0), P3(0, 60, 0)],
          ui.Color(0xffffffff),
          null));
    m.groups.clear();
    m.motions.clear();
    final p = ModelPainter(m, 0, 0, 1, 0, 'all', false);
    final points = p.transformed.first.$2;
    final a = p.project(points[0], const ui.Size(400, 520));
    final b = p.project(points[1], const ui.Size(400, 520));
    expect((b.dx - a.dx).abs(), greaterThan(200));
    expect((a.dx + b.dx) / 2, closeTo(200, 1e-6));
  });
  test('reflection has no hard transition at the former cutoff', () {
    for (final boundary in [.35, .5, .8]) {
      final before = ModelMotionQuality.reflectionOpacity(boundary - 1e-6, 100);
      final after = ModelMotionQuality.reflectionOpacity(boundary + 1e-6, 100);
      expect((before - after).abs(), lessThan(.00002));
    }
    expect(ModelMotionQuality.reflectionOpacity(.5, 100), greaterThan(0));
    for (final pixels in [6.0, 26.0, 30.0]) {
      expect(
          (ModelMotionQuality.reflectionOpacity(.1, pixels - 1e-6) -
                  ModelMotionQuality.reflectionOpacity(.1, pixels + 1e-6))
              .abs(),
          lessThan(.00002));
    }
  });
  test('perspective patches activate only for significant visible distortion',
      () {
    expect(ModelMotionQuality.perspectiveSteps(100, 160, 50), 1);
    expect(ModelMotionQuality.perspectiveSteps(100, 101, 300), 1);
    expect(ModelMotionQuality.perspectiveSteps(100, 105, 300), 2);
    expect(ModelMotionQuality.perspectiveSteps(100, 140, 300), 4);
  });
  test('slanted opaque faces receive surface-projected UV patches', () async {
    final textures = ModelTextures()..setCinematic(true);
    await textures.request(128);
    final p = ModelPainter(model(), 1.0, .3, 2, .7, 'all', false,
        quality: ModelQuality.studio4K,
        texture: textures.best(128),
        moving: true);
    final recorder = ui.PictureRecorder();
    p.paint(ui.Canvas(recorder), const ui.Size(400, 520));
    final picture = recorder.endRecording();
    expect(p.tessellatedFaces, greaterThan(0));
    final image = await picture.toImage(400, 520);
    expect(await image.toByteData(format: ui.ImageByteFormat.png), isNotNull);
    image.dispose();
    picture.dispose();
    textures.dispose();
  });
  test('zoomed render stays clipped to its viewport and restores canvas',
      () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..translate(80, 80);
    ModelPainter(model(), .8, .35, 8, .8, 'all', false, moving: true)
        .paint(canvas, const ui.Size(320, 440));
    canvas.drawRect(const ui.Rect.fromLTWH(-60, -60, 8, 8),
        ui.Paint()..color = const ui.Color(0xffff0000));
    final picture = recorder.endRecording();
    final image = await picture.toImage(500, 620);
    final bytes = (await image.toByteData())!.buffer.asUint8List();
    int alpha(int x, int y) => bytes[(y * 500 + x) * 4 + 3];
    expect(alpha(22, 22), 255); // Painter restored the caller's clip.
    for (final (x, y) in [(60, 200), (420, 200), (200, 60), (200, 540)]) {
      expect(alpha(x, y), 0);
    }
    image.dispose();
    picture.dispose();
  });
  test('moving and resting use identical geometry and raster', () async {
    final m = model();
    Future<List<int>> render(bool moving) async {
      final recorder = ui.PictureRecorder();
      ModelPainter(m, 1.45, -.4, 1, .65, 'all', false,
              quality: ModelQuality.studio4K, moving: moving)
          .paint(ui.Canvas(recorder), const ui.Size(240, 320));
      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 320);
      final pixels = (await image.toByteData())!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return pixels;
    }

    expect(await render(true), await render(false));
  });
}
