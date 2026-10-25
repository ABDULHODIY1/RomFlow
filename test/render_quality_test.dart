import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';

void main() {
  final recipe = recipeFor(sampleProfiles().first),
      drawing = drawingPresets.firstWhere((p) => p.id == 'twoOpen').drawing();

  void paintOnce(ModelPainter p) {
    final recorder = ui.PictureRecorder();
    p.paint(ui.Canvas(recorder), const ui.Size(400, 520));
    recorder.endRecording().dispose();
  }

  test('turning the model reuses the scene and preserves tiny details', () {
    final model = WindowModel(drawing, recipe);
    final still = ModelPainter(model, -.35, .15, 1, 0, 'all', false);
    paintOnce(still);
    final scene = model.world;
    expect(scene, isNotNull);
    // Another angle: the same opened, placed scene is reused.
    paintOnce(ModelPainter(model, .2, .3, 1, 0, 'all', false));
    expect(identical(model.world, scene), isTrue);
    // Finger rotation keeps screws and caps, with no detail popping.
    String? key(ModelFace f) => model.parts[f.partId]?.materialKey;
    final moving =
        ModelPainter(model, .2, .3, 1, 0, 'all', false, moving: true);
    paintOnce(moving);
    expect(still.transformed.any((f) => key(f.$1) == 'screw'), isTrue);
    expect(moving.transformed.any((f) => key(f.$1) == 'screw'), isTrue);
    expect(moving.transformed.length, still.transformed.length);
    expect(identical(model.world, scene), isTrue);
    // Opening a sash places the scene again.
    paintOnce(ModelPainter(model, .2, .3, 1, .5, 'all', false));
    expect(identical(model.world, scene), isFalse);
  });

  test('buttons over the picture keep their strip free', () {
    final model = WindowModel(drawing, recipe);
    final p = ModelPainter(model, 0, 0, 1, 0, 'all', false, rightInset: 50);
    const size = ui.Size(400, 520);
    var maxX = 0.0;
    for (final f in p.transformed) {
      for (final v in f.$2) {
        final x = p.project(v, size).dx;
        if (x > maxX) maxX = x;
      }
    }
    expect(maxX, lessThan(size.width - 50));
  });
}
