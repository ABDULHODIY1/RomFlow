import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/model_quality.dart';
import 'package:romflow/model_textures.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/design_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'material atlas has deterministic distinct finish tiles and opaque pixels',
      () {
    final a = makeModelAtlas(128).materialize().asUint8List();
    final b = makeModelAtlas(128).materialize().asUint8List();
    expect(a, b);
    final signatures = <String>{};
    for (var tile = 0; tile < 4; tile++) {
      final values = <int>[];
      for (var y = 0; y < 12; y++) {
        for (var x = 0; x < 12; x++) {
          final i = ((y + (tile ~/ 2) * 64) * 128 + x + (tile % 2) * 64) * 4;
          values.add(a[i]);
          expect(a[i + 1], a[i]);
          expect(a[i + 2], a[i]);
          expect(a[i + 3], 255);
        }
      }
      signatures.add(values.join(','));
    }
    expect(signatures.length, 4);
  });
  test('atlas UVs stay in material tiles and survive camera rotation', () {
    final model = WindowModel(newDrawing(), defaultRecipe({}));
    for (final face in model.faces) {
      final tile =
          ModelFinish.forMaterial(model.parts[face.partId]?.materialKey)
              .atlasTile;
      final uv = model.textureUV(face, 4096, cinematic: true);
      expect(
          identical(uv, model.textureUV(face, 4096, cinematic: true)), isTrue);
      for (final p in uv) {
        expect(
            p.dx, inExclusiveRange((tile % 2) * 2048, (tile % 2 + 1) * 2048));
        expect(
            p.dy, inExclusiveRange((tile ~/ 2) * 2048, (tile ~/ 2 + 1) * 2048));
      }
    }
  });
  test('style changes discard stale in-flight images; 4K atlas stays bounded',
      () async {
    final textures = ModelTextures();
    final pending = textures.request(128);
    textures.setCinematic(true);
    await pending;
    expect(textures.best(128)!.cinematic, isTrue);
    await textures.request(4096);
    final atlas = textures.best(4096)!;
    expect(atlas.size, 4096);
    expect(atlas.cinematic, isTrue);
    expect(textures.residentBytes,
        lessThanOrEqualTo(ModelTexturePolicy.budgetBytes));
    textures.setCinematic(false);
    expect(atlas.disposed, isTrue);
    await textures.request(128);
    expect(textures.best(128)!.cinematic, isFalse);
    textures.dispose();
  });
  test('filmic shoulder preserves increasing highlights and bounds black', () {
    expect(ModelFinish.filmic(0), 0);
    var previous = -1.0;
    for (final value in [0.0, .01, .1, .5, 1.0, 2.0, 4.0, 8.0]) {
      final mapped = ModelFinish.filmic(value);
      expect(mapped, inInclusiveRange(0, 1));
      expect(mapped, greaterThan(previous));
      previous = mapped;
    }
    expect(ModelFinish.filmic(1), lessThan(1));
    expect(ModelFinish.filmic(4), greaterThan(ModelFinish.filmic(1)));
  });
  test('thicker and grazing glass transmits less light', () {
    expect(ModelFinish.glassTransmission(12, 1),
        lessThan(ModelFinish.glassTransmission(4, 1)));
    expect(ModelFinish.glassTransmission(6, .2),
        lessThan(ModelFinish.glassTransmission(6, 1)));
    expect(ModelFinish.glassTransmission(6, 0), inExclusiveRange(0, 1));
  });
  test('atlas renders opened mechanism and rotating view after cache disposal',
      () async {
    final textures = ModelTextures()..setCinematic(true);
    await textures.request(128);
    final model = WindowModel(
        drawingPresets.firstWhere((p) => p.id == 'twoOpen').drawing(),
        defaultRecipe({}));
    for (final yaw in [-1.1, -.35, .45]) {
      final recorder = ui.PictureRecorder();
      ModelPainter(model, yaw, .15, 1, .65, 'all', false,
              moving: true,
              quality: ModelQuality.studio4K,
              texture: textures.best(128))
          .paint(ui.Canvas(recorder), const ui.Size(320, 440));
      final picture = recorder.endRecording();
      if (yaw == .45) textures.dispose();
      final image = await picture.toImage(320, 440);
      expect(await image.toByteData(format: ui.ImageByteFormat.png), isNotNull);
      image.dispose();
      picture.dispose();
    }
    textures.dispose();
  });
}
