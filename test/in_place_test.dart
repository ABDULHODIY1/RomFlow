import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/ai_vision.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/in_place_page.dart';
import 'package:romflow/window_photo.dart';

/// A wall photo, [w] × [h], with a darker opening between the fractions.
Gray wallWithOpening(int w, int h, double l, double t, double r, double b) {
  final rnd = math.Random(5), px = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inside = x > l * w && x < r * w && y > t * h && y < b * h;
      final base = inside ? 120 + 40 * y / h : 200 - 20 * x / w;
      px[y * w + x] = (base + rnd.nextInt(10)).round().clamp(0, 255);
    }
  }
  return Gray(w, h, px);
}

void main() {
  frameTests();
  cameraPhotoTests();
  test('the drawing lands on the four corners in perspective', () {
    const quad = [
      Offset(40, 30),
      Offset(300, 50),
      Offset(290, 400),
      Offset(55, 380)
    ];
    final m = InPlacePainter.matrix(quad, 1500, 1400);
    Offset apply(double x, double y) {
      final w = m[3] * x + m[7] * y + m[15];
      return Offset(
          (m[0] * x + m[4] * y + m[12]) / w, (m[1] * x + m[5] * y + m[13]) / w);
    }

    for (final (x, y, i) in [
      (0.0, 0.0, 0),
      (1500.0, 0.0, 1),
      (1500.0, 1400.0, 2),
      (0.0, 1400.0, 3)
    ]) {
      expect((apply(x, y) - quad[i]).distance, lessThan(1e-6));
    }
  });

  test('the phone finds the opening on a straight photo', () {
    final corners = guessOpening(wallWithOpening(400, 300, .3, .22, .72, .8));
    final (l, t) = corners[0];
    final (r, b) = corners[2];
    expect(l, closeTo(.3, .03));
    expect(t, closeTo(.22, .03));
    expect(r, closeTo(.72, .03));
    expect(b, closeTo(.8, .03));
  });

  test('reads the AI answer about the opening', () {
    final corners = AiVision.openingCorners({
      'found': true,
      'corners': [
        {'x': .31, 'y': .22},
        {'x': .7, 'y': .24},
        {'x': .69, 'y': 1.2},
        {'x': .32, 'y': .74},
      ],
      'notes': 'Devordagi darcha',
    });
    expect(corners[2], (.69, 1.0));
    expect(
        () => AiVision.openingCorners(
            {'found': false, 'corners': [], 'notes': 'Rasmda devor yo‘q'}),
        throwsA(predicate((e) => '$e'.contains('o‘rin topilmadi'))));
  });

  testWidgets('the sample photo gets the window in its opening',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recipe = recipeFor(sampleProfiles().first);
    final drawing = {
      ...newDrawing(),
      'widthMm': 1500,
      'heightMm': 1400,
      'root': {
        'id': 's',
        'axis': 'v',
        'ratio': .5,
        'a': {...newLeaf('a'), 'opening': 'tiltTurn'},
        'b': newLeaf('b'),
      },
    };
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: InPlacePage(drawing: drawing, recipe: recipe)));
    expect(find.text('Joyida ko‘rish'), findsWidgets);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('in-place-sample')));
      for (var i = 0; i < 80; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find.byKey(const ValueKey('in-place-view')).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
    });
    await tester.pump();
    final view = find.byKey(const ValueKey('in-place-view'));
    expect(view, findsOneWidget);
    final painter = tester.widget<CustomPaint>(view).painter! as InPlacePainter;
    // The sample's opening is at about 31–70 % across, 22–74 % down.
    final size = tester.getSize(view);
    final first = painter.quad.first, third = painter.quad[2];
    expect(first.dx / size.width, closeTo(.32, .05));
    expect(first.dy / size.height, closeTo(.23, .05));
    expect(third.dx / size.width, closeTo(.7, .05));
    expect(third.dy / size.height, closeTo(.74, .06));
    expect(tester.takeException(), isNull);
  });
}

void frameTests() {
  test('a camera frame turns upright the way the phone is held', () {
    // A 4 × 2 landscape frame with 2 padding bytes a row: 0 1 2 3 / 4 5 6 7.
    final luma = Uint8List.fromList([0, 1, 2, 3, 99, 99, 4, 5, 6, 7, 99, 99]);
    List<int> pixels(Gray g) => g.pixels.toList();
    final straight = grayFromLuma(luma, 4, 2, 6);
    expect([straight.width, straight.height], [4, 2]);
    expect(pixels(straight), [0, 1, 2, 3, 4, 5, 6, 7]);
    // A back camera (90°): the left column of the frame becomes the top row.
    final portrait = grayFromLuma(luma, 4, 2, 6, rotation: 90);
    expect([portrait.width, portrait.height], [2, 4]);
    expect(pixels(portrait), [4, 0, 5, 1, 6, 2, 7, 3]);
    expect(pixels(grayFromLuma(luma, 4, 2, 6, rotation: 270)),
        [3, 7, 2, 6, 1, 5, 0, 4]);
    expect(pixels(grayFromLuma(luma, 4, 2, 6, rotation: 180)),
        [7, 6, 5, 4, 3, 2, 1, 0]);
    expect(pixels(grayFromLuma(luma, 4, 2, 6, step: 2)), [0, 2]);
  });

  test('a sideways camera frame finds the opening where the phone sees it', () {
    // The scene as held upright: an opening 30–70 % across, 25–72 % down.
    final scene = wallWithOpening(180, 240, .3, .25, .7, .72);
    // As a back camera sensor gives it: lying on its side, rows padded.
    const sw = 240, sh = 180, stride = 256;
    final luma = Uint8List(stride * sh);
    for (var sy = 0; sy < sh; sy++) {
      for (var sx = 0; sx < sw; sx++) {
        luma[sy * stride + sx] = scene.pixels[sx * scene.width + (sh - 1 - sy)];
      }
    }
    final upright = grayFromLuma(luma, sw, sh, stride, rotation: 90);
    expect(upright.pixels, scene.pixels);
    final corners = guessOpening(upright);
    expect(corners[0].$1, closeTo(.3, .03));
    expect(corners[0].$2, closeTo(.25, .03));
    expect(corners[2].$1, closeTo(.7, .03));
    expect(corners[2].$2, closeTo(.72, .03));
  });
}

void cameraPhotoTests() {
  testWidgets('a picture from the live camera keeps the corners it found',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await tester.runAsync(() async =>
        (await rootBundle.load(samplePhotoAsset)).buffer.asUint8List());
    const seen = [(.2, .25), (.8, .25), (.8, .75), (.2, .75)];
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: InPlacePage(
            drawing: newDrawing(),
            recipe: recipeFor(sampleProfiles().first),
            photo: bytes,
            corners: seen)));
    await tester.runAsync(() async {
      for (var i = 0; i < 80; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find.byKey(const ValueKey('in-place-view')).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
    });
    await tester.pump();
    final view = find.byKey(const ValueKey('in-place-view'));
    final painter = tester.widget<CustomPaint>(view).painter! as InPlacePainter;
    final size = tester.getSize(view);
    // Without an AI key nothing looks again: the camera's corners stay.
    expect(painter.quad.first.dx / size.width, closeTo(.2, .01));
    expect(painter.quad[2].dy / size.height, closeTo(.75, .01));
    expect(find.textContaining('Kamerada topilgan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
