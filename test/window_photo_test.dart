import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/ai_vision.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/window_photo.dart';

/// A straight-on picture of a white PVC window: frame, imposts, sash
/// frames and glass with a sky gradient, reflections and noise.
Gray window({
  int width = 420,
  int height = 500,
  List<double> columns = const [],
  List<double> rows = const [],
  Map<int, List<double>> transoms = const {},
  Set<int> panels = const {},
}) {
  final rnd = math.Random(7), px = Uint8List(width * height);
  const frame = 18, bar = 14, sash = 9;
  bool near(double v, double at, int half) => (v - at).abs() <= half;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var v = 60 + 90 * y / height + 30 * math.sin(x / 23) + rnd.nextInt(18);
      // Outer frame.
      if (x < frame || y < frame || x >= width - frame || y >= height - frame) {
        v = 232.0 + rnd.nextInt(8);
      }
      for (final c in columns) {
        if (near(x.toDouble(), c * width, bar ~/ 2)) {
          v = 232.0 + rnd.nextInt(8);
        }
      }
      for (final r in rows) {
        if (near(y.toDouble(), r * height, bar ~/ 2)) {
          v = 232.0 + rnd.nextInt(8);
        }
      }
      // Inner transoms inside a column.
      final stops = [0.0, ...columns, 1.0];
      for (var i = 0; i + 1 < stops.length; i++) {
        if (x < stops[i] * width || x > stops[i + 1] * width) continue;
        for (final t in transoms[i] ?? const <double>[]) {
          if (near(y.toDouble(), t * height, bar ~/ 2)) {
            v = 232.0 + rnd.nextInt(8);
          }
        }
        if (panels.contains(i) && y > height * .6 && v < 200) {
          v = 214.0 + rnd.nextInt(3);
        }
        // A sash frame a little inside each column.
        final left = stops[i] * width + frame,
            right = stops[i + 1] * width - frame;
        if ((x - left).abs() < sash || (right - x).abs() < sash) {
          if (y > frame && y < height - frame && v < 200) v = 228.0;
        }
      }
      px[y * width + x] = v.round().clamp(0, 255);
    }
  }
  return Gray(width, height, px);
}

void main() {
  test('finds the imposts of a three-part window with a transom in the middle',
      () {
    final grid = detectGrid(window(columns: [
      1 / 3,
      2 / 3
    ], transoms: {
      1: [.3]
    }));
    expect(grid.layout, 'columns');
    expect(grid.cuts.length, 2);
    expect(grid.cuts[0], closeTo(1 / 3, .04));
    expect(grid.cuts[1], closeTo(2 / 3, .04));
    expect(grid.inner[0], isEmpty);
    expect(grid.inner[1].single, closeTo(.3, .05));
    expect(grid.inner[2], isEmpty);
  });

  test('an even grey part under a transom is a panel, glass stays glass', () {
    final img = window(columns: [
      .5
    ], transoms: {
      1: [.6]
    }, panels: {
      1
    });
    // Colour like a photo: the glass is bluish, PVC and panels are grey.
    final colour = Uint8List(img.width * img.height * 4);
    for (var i = 0; i < img.pixels.length; i++) {
      final v = img.pixels[i];
      final glass = v < 200;
      colour[i * 4] = glass ? (v * .7).round() : v;
      colour[i * 4 + 1] = glass ? (v * .85).round() : v;
      colour[i * 4 + 2] = glass ? math.min(255, (v * 1.15).round()) : v;
      colour[i * 4 + 3] = 255;
    }
    final grid = detectGrid(img, colour: colour);
    expect(grid.cuts.single, closeTo(.5, .04));
    expect(grid.inner[1].single, closeTo(.6, .05));
    expect(grid.fills[0], ['glass']);
    expect(grid.fills[1], ['glass', 'panel']);
    // Without colour nothing is guessed to be a panel.
    expect(detectGrid(img).fills[1], ['glass', 'glass']);
  });

  test('a full-width transom reads as rows', () {
    final grid = detectGrid(window(rows: [.25], columns: const []));
    expect(grid.layout, 'rows');
    expect(grid.cuts.single, closeTo(.25, .04));
  });

  test('a plain fixed pane has no bars', () {
    final grid = detectGrid(window());
    expect(grid.cuts, isEmpty);
    expect(grid.inner.single, isEmpty);
  });

  test('editing the grid and turning it into a drawing', () {
    final grid = WindowGrid('columns', [.5], [[], []]);
    grid.addInner(.25, .3);
    grid.addCut(.75);
    expect(grid.cuts, [.5, .75]);
    expect(grid.inner[0], [.3]);
    grid.openings[1][0] = 'tiltTurn';
    grid.removeCut(1);
    expect(grid.cuts, [.5]);
    final d = grid.drawing(1500, 1400);
    final l = layoutDrawing(d, recipeFor(sampleProfiles().first));
    expect(l.cells.length, 3);
    expect(d['root']['axis'], 'v');
    expect(d['root']['a']['axis'], 'h');
    expect(d['root']['b']['opening'], 'tiltTurn');
  });

  test('reads the AI answer, shares in any scale', () {
    final grid = WindowGrid.fromJson({
      'isWindow': true,
      'shape': 'arch',
      'layout': 'rows',
      'parts': [
        {
          'share': 1,
          'cells': [
            {'share': 1, 'opening': 'fixed', 'fill': 'glass'}
          ]
        },
        {
          'share': 3,
          'cells': [
            {'share': 2, 'opening': 'left', 'fill': 'glass'},
            {'share': 2, 'opening': 'nonsense', 'fill': 'panel'},
          ]
        },
      ],
      'notes': '',
    });
    expect(grid.cuts.single, closeTo(.25, 1e-9));
    expect(grid.inner[1].single, closeTo(.5, 1e-9));
    expect(grid.openings[1], ['left', 'fixed']);
    expect(grid.fills[1], ['glass', 'panel']);
    final d = grid.drawing(1600, 2000);
    expect(d['shape'], 'arch');
    expect(d['riseMm'], 500);
    expect(() => layoutDrawing(d, recipeFor(sampleProfiles().first)),
        returnsNormally);
    expect(() => WindowGrid.fromJson({'parts': []}), throwsFormatException);
  });

  test('perspective maps the frame corners and straightens the photo', () {
    final quad = [(40.0, 30.0), (360.0, 60.0), (330.0, 420.0), (60.0, 400.0)];
    final m = Homography(quad);
    for (final (u, v, i) in [
      (0.0, 0.0, 0),
      (1.0, 0.0, 1),
      (1.0, 1.0, 2),
      (0.0, 1.0, 3)
    ]) {
      final (x, y) = m.map(u, v);
      expect(x, closeTo(quad[i].$1, 1e-6));
      expect(y, closeTo(quad[i].$2, 1e-6));
    }
    final img = window(columns: [.5]);
    final same = img.rectify([
      (0, 0),
      (img.width.toDouble(), 0),
      (img.width.toDouble(), img.height.toDouble()),
      (0, img.height.toDouble())
    ], img.width, img.height);
    final grid = detectGrid(same);
    expect(grid.cuts.single, closeTo(.5, .04));
  });

  test('the AI request and its answers', () {
    final body = AiVision.body(Uint8List.fromList([1, 2, 3]));
    expect(body['model'], 'claude-opus-5-5');
    expect(body['fallbacks'], 'default');
    expect(body['output_config']['format']['type'], 'json_schema');
    final content = body['messages'][0]['content'] as List;
    expect(content.first['type'], 'image');
    expect(content.first['source']['data'], 'AQID');
    final answer = jsonEncode({
      'isWindow': true,
      'shape': 'rect',
      'layout': 'columns',
      'parts': [
        {
          'share': .5,
          'cells': [
            {'share': 1, 'opening': 'tiltTurn', 'fill': 'glass'}
          ]
        },
        {
          'share': .5,
          'cells': [
            {'share': 1, 'opening': 'fixed', 'fill': 'glass'}
          ]
        },
      ],
      'notes': 'Ikki bo‘limli rom',
    });
    final grid = AiVision.parse(
        200,
        jsonEncode({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'thinking', 'thinking': ''},
            {'type': 'text', 'text': answer},
          ]
        }));
    expect(grid.cuts.single, closeTo(.5, 1e-9));
    expect(grid.openings[0], ['tiltTurn']);
    expect(
        () => AiVision.parse(
            200, jsonEncode({'stop_reason': 'refusal', 'content': []})),
        throwsA(isA<AiException>()));
    expect(() => AiVision.parse(401, '{}'),
        throwsA(predicate((e) => '$e'.contains('kaliti'))));
    expect(
        () => AiVision.parse(
            200,
            jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {
                  'type': 'text',
                  'text': jsonEncode({
                    'isWindow': false,
                    'shape': 'rect',
                    'layout': 'columns',
                    'parts': [],
                    'notes': 'Rasmda devor'
                  })
                }
              ]
            })),
        throwsA(predicate((e) => '$e'.contains('rom topilmadi'))));
  });
}
