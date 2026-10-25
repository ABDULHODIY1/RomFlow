import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/model_textures.dart';
import 'package:romflow/model_motion.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/design_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('pixel demand and motion select bounded mip levels', () {
    expect(ModelTexturePolicy.resolution(300), 512);
    expect(ModelTexturePolicy.resolution(1300), 2048);
    expect(ModelTexturePolicy.resolution(8000), 2048);
    expect(ModelTexturePolicy.resolution(8000, moving: true), 2048);
    expect(ModelTexturePolicy.resolution(1300, moving: true),
        ModelTexturePolicy.resolution(1300));
    expect(ModelTexturePolicy.resolution(300, export4K: true), 4096);
    expect(ModelTexturePolicy.bytesFor(4096), 64 * 1024 * 1024);
  });
  test(
      'real 4K image stays within decoded cache budget; motion never samples it',
      () async {
    final textures = ModelTextures();
    await textures.request(4096);
    final high = textures.best(4096);
    expect(high, isNotNull);
    expect(high!.image.width, 4096);
    expect(high.image.height, 4096);
    expect(textures.residentBytes,
        lessThanOrEqualTo(ModelTexturePolicy.budgetBytes));
    expect(textures.best(512), isNull);
    await textures.request(512);
    expect(textures.best(512)!.size, 512);
    textures.trim(memoryPressure: true);
    expect(high.disposed, isTrue);
    await textures.request(4096);
    expect(textures.best(4096)!.size, 1024);
    expect(textures.residentBytes, lessThanOrEqualTo(8 * 1024 * 1024));
    textures.dispose();
    expect(textures.residentBytes, 0);
  });
  test('orbit response is stable at 60 and 120 Hz and bounds pitch', () {
    final at60 = ModelOrbit(0, 0)..drag(100, 25);
    final at120 = ModelOrbit(0, 0)..drag(100, 25);
    for (var i = 0; i < 30; i++) {
      at60.step(1 / 60);
    }
    for (var i = 0; i < 60; i++) {
      at120.step(1 / 120);
    }
    expect(at60.yaw, closeTo(at120.yaw, .00005));
    expect(at60.pitch, closeTo(at120.pitch, .00005));
    at60.drag(0, -10000);
    expect(at60.targetPitch, 1.4);
    at60.reset(0, 0);
    at60.drag(100, 0);
    at60.step(5);
    expect(at60.yaw, lessThan(at60.targetYaw));
  });
  test('recorded textured geometry survives cache disposal', () async {
    final textures = ModelTextures();
    await textures.request(128);
    final model = WindowModel(newDrawing(), defaultRecipe({}));
    final painter = ModelPainter(model, -.35, .15, 1, 0, 'all', false,
        texture: textures.best(128));
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), const ui.Size(320, 440));
    final picture = recorder.endRecording();
    textures.dispose();
    final image = await picture.toImage(320, 440);
    expect(image.width, 320);
    expect(await image.toByteData(format: ui.ImageByteFormat.png), isNotNull);
    image.dispose();
    picture.dispose();
  });
  test('texture coordinates are reused across rotation and respect mip scale',
      () {
    final model = WindowModel(newDrawing(), defaultRecipe({}));
    final face = model.faces.first;
    final at512 = model.textureUV(face, 512);
    expect(identical(at512, model.textureUV(face, 512)), isTrue);
    final at1024 = model.textureUV(face, 1024);
    for (var i = 0; i < at512.length; i++) {
      expect(at1024[i].dx, closeTo(at512[i].dx * 2, 1e-6));
      expect(at1024[i].dy, closeTo(at512[i].dy * 2, 1e-6));
    }
  });
  test('closing a view safely drops in-flight texture work', () async {
    final textures = ModelTextures();
    final pending = textures.request(128);
    textures.dispose();
    await pending;
    expect(textures.levelCount, 0);
    expect(textures.revision, 0);
  });
  test('paint and picking share projection; unchanged painters do not repaint',
      () {
    final model = WindowModel(newDrawing(), defaultRecipe({}));
    ModelPainter painter() =>
        ModelPainter(model, -.35, .15, 1, 0, 'all', false);
    final p = painter();
    final recorder = ui.PictureRecorder();
    p.paint(ui.Canvas(recorder), const ui.Size(400, 520));
    recorder.endRecording().dispose();
    expect(p.sceneBuilds, 1);
    p.pick(const ui.Offset(200, 260), const ui.Size(400, 520));
    expect(p.sceneBuilds, 1);
    expect(painter().shouldRepaint(p), isFalse);
    expect(ModelPainter(model, -.3, .15, 1, 0, 'all', false).shouldRepaint(p),
        isTrue);
  });
}
