import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/model_quality.dart';
import 'package:romflow/model_textures.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/design_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('iPhone 13 and newer select studio; SE and older stay balanced', () {
    for (final id in [
      'iPhone14,2',
      'iPhone14,3',
      'iPhone14,4',
      'iPhone14,5',
      'iPhone14,7',
      'iPhone14,8',
      'iPhone15,2',
      'iPhone18,1'
    ]) {
      expect(ModelDeviceQuality.select({'machine': id}), ModelQuality.studio4K,
          reason: id);
    }
    for (final id in [
      'iPhone13,4',
      'iPhone14,6',
      'x86_64',
      'arm64',
      'Redmi Note 13',
      '',
      'iPad14,2'
    ]) {
      expect(ModelDeviceQuality.select({'machine': id}), ModelQuality.balanced,
          reason: id);
    }
  });
  test('heat lowers quality; cooling permits studio again', () {
    for (final thermal in [0, 1, 2, 3]) {
      expect(
          ModelDeviceQuality.select(
              {'machine': 'iPhone14,5', 'thermal': thermal}),
          thermal < 2 ? ModelQuality.studio4K : ModelQuality.balanced);
    }
  });
  test('4K texture stays 4K while rotating; Android mip policy unchanged', () {
    for (final moving in [true, false]) {
      expect(
          ModelTexturePolicy.resolution(1200,
              moving: moving, quality: ModelQuality.studio4K),
          4096);
      expect(ModelTexturePolicy.resolution(1200, moving: moving), 2048);
    }
  });
  test('missing device plugin falls back; native status enables studio',
      () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        ModelDeviceQuality.channel, (_) async => null);
    expect(await ModelDeviceQuality.read(), ModelQuality.balanced);
    messenger.setMockMethodCallHandler(ModelDeviceQuality.channel,
        (call) async {
      expect(call.method, 'status');
      return {'machine': 'iPhone14,5', 'thermal': 0};
    });
    expect(await ModelDeviceQuality.read(), ModelQuality.studio4K);
    messenger.setMockMethodCallHandler(ModelDeviceQuality.channel,
        (_) async => throw PlatformException(code: 'unavailable'));
    expect(await ModelDeviceQuality.read(), ModelQuality.balanced);
    messenger.setMockMethodCallHandler(ModelDeviceQuality.channel, null);
  });
  test('rough rubber has restrained highlights; linear light stays finite', () {
    final metal = ModelFinish.forMaterial('handle');
    final rubber = ModelFinish.forMaterial('sealInner');
    expect(metal.highlight(1, 1), greaterThan(rubber.highlight(1, 1)));
    for (final value in [0.0, .02, .5, 1.0]) {
      expect(ModelFinish.channel(value, 1, 0), closeTo(value, 1e-7));
      for (final light in [.1, .9, 2.0]) {
        expect(
            ModelFinish.channel(value, light, .8), inInclusiveRange(0.0, 1.0));
      }
    }
  });
  test('studio changes actual raster and repaint invalidation', () async {
    final model = WindowModel(newDrawing(), defaultRecipe({}));
    Future<List<int>> pixels(ModelQuality quality) async {
      final recorder = ui.PictureRecorder();
      ModelPainter(model, -.35, .15, 1, 0, 'all', false, quality: quality)
          .paint(ui.Canvas(recorder), const ui.Size(320, 440));
      final picture = recorder.endRecording();
      final image = await picture.toImage(320, 440);
      final data = (await image.toByteData())!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return data;
    }

    final normal = await pixels(ModelQuality.balanced);
    final studio = await pixels(ModelQuality.studio4K);
    expect(studio, isNot(equals(normal)));
    final low = ModelPainter(model, 0, 0, 1, 0, 'all', false);
    final high = ModelPainter(model, 0, 0, 1, 0, 'all', false,
        quality: ModelQuality.studio4K);
    expect(high.shouldRepaint(low), isTrue);
    expect(high.transformed.length, low.transformed.length);
  });
}
