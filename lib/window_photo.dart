import 'dart:math' as math;
import 'dart:typed_data';
import 'design_engine.dart';

/// A window read from a photo: the main bars split it into parts (columns
/// side by side, or rows one above the other) and each part is split the
/// other way into cells. Positions are fractions of the frame, 0–1.
class WindowGrid {
  /// 'columns' or 'rows'.
  String layout;

  /// Bars between the parts, along the main direction.
  List<double> cuts;

  /// Bars inside each part, along the other direction.
  List<List<double>> inner;
  List<List<String>> openings, fills;
  String shape;

  WindowGrid(this.layout, List<double> cuts, List<List<double>> inner,
      {List<List<String>>? openings,
      List<List<String>>? fills,
      this.shape = 'rect'})
      : cuts = List.of(cuts),
        inner = [for (final p in inner) List.of(p)],
        openings = openings ??
            [
              for (final p in inner)
                List.filled(p.length + 1, 'fixed', growable: true)
            ],
        fills = fills ??
            [
              for (final p in inner)
                List.filled(p.length + 1, 'glass', growable: true)
            ] {
    // Lists from the AI are fixed; edits need growable ones.
    this.openings = [for (final o in this.openings) List.of(o)];
    this.fills = [for (final f in this.fills) List.of(f)];
  }

  bool get columns => layout == 'columns';
  int get partCount => cuts.length + 1;

  /// Edges of part [i] along the main direction.
  (double, double) part(int i) =>
      (i == 0 ? 0.0 : cuts[i - 1], i == cuts.length ? 1.0 : cuts[i]);

  int partAt(double main) {
    for (var i = 0; i < cuts.length; i++) {
      if (main < cuts[i]) return i;
    }
    return cuts.length;
  }

  /// Adds a bar through the whole frame at [main] (0–1 along the main
  /// direction); the part it cuts keeps its inner bars on both sides.
  void addCut(double main) {
    final i = partAt(main);
    final (a, b) = part(i);
    if (main - a < .06 || b - main < .06) return;
    cuts.insert(i, main);
    inner.insert(i, List.of(inner[i]));
    openings.insert(i, List.of(openings[i]));
    fills.insert(i, List.of(fills[i]));
  }

  void removeCut(int i) {
    // The merged part keeps the inner bars of the side that had more.
    final keep = inner[i].length >= inner[i + 1].length ? i : i + 1;
    final kept = (inner[keep], openings[keep], fills[keep]);
    cuts.removeAt(i);
    for (final list in [inner, openings, fills]) {
      list.removeAt(i + 1);
    }
    inner[i] = kept.$1;
    openings[i] = kept.$2;
    fills[i] = kept.$3;
  }

  /// Adds a bar inside the part at [main], across it at [other].
  void addInner(double main, double other) {
    final i = partAt(main), bars = inner[i];
    var j = 0;
    while (j < bars.length && bars[j] < other) {
      j++;
    }
    final lo = j == 0 ? 0.0 : bars[j - 1],
        hi = j == bars.length ? 1.0 : bars[j];
    if (other - lo < .06 || hi - other < .06) return;
    bars.insert(j, other);
    openings[i].insert(j, openings[i][j]);
    fills[i].insert(j, fills[i][j]);
  }

  void removeInner(int i, int j) {
    inner[i].removeAt(j);
    openings[i].removeAt(j + 1);
    fills[i].removeAt(j + 1);
  }

  /// The section tree of the drawing engine.
  DMap tree() {
    var serial = 0;
    DMap chain(String axis, List<double> stops, DMap Function(int) leaf,
        [int from = 0, double start = 0]) {
      if (from == stops.length) return leaf(from);
      final end = 1.0;
      return {
        'id': 'ph${serial++}',
        'axis': axis,
        'ratio': (stops[from] - start) / (end - start),
        'a': leaf(from),
        'b': chain(axis, stops, leaf, from + 1, stops[from]),
      };
    }

    final mainAxis = columns ? 'v' : 'h', otherAxis = columns ? 'h' : 'v';
    return chain(
        mainAxis,
        cuts,
        (i) => chain(
            otherAxis,
            inner[i],
            (j) => {
                  ...newLeaf('ph${serial++}'),
                  'opening': openings[i][j],
                  'fill': fills[i][j],
                }));
  }

  /// A drawing of [width] × [height] mm. An arch takes its curve from the
  /// top row when the photo has one.
  DMap drawing(num width, num height) {
    final d = {
      ...newDrawing(),
      'widthMm': width,
      'heightMm': height,
      'root': tree(),
    };
    if (shape == 'arch') {
      final top = !columns && cuts.isNotEmpty ? cuts.first : .3;
      d['shape'] = 'arch';
      d['riseMm'] = math.min(width / 2, height * top).roundToDouble();
    }
    return d;
  }

  /// Reads the JSON returned by the AI (see [windowGridSchema]).
  factory WindowGrid.fromJson(Map json) {
    final layout = json['layout'] == 'rows' ? 'rows' : 'columns';
    List<double> stops(List shares) {
      final total = shares.fold<double>(0, (s, v) => s + (v as num).toDouble());
      if (total <= 0) return const [];
      var at = 0.0;
      return [
        for (final v in shares.sublist(0, shares.length - 1))
          at += (v as num).toDouble() / total
      ];
    }

    final parts = [
      for (final p in json['parts'] as List? ?? const [])
        if (p is Map && (p['cells'] as List?)?.isNotEmpty == true) p
    ];
    if (parts.isEmpty) throw const FormatException('Rasmda rom topilmadi');
    const openings = {
      'fixed',
      'left',
      'right',
      'tiltTurn',
      'top',
      'bottom',
      'slideLeft',
      'slideRight',
      'doorLeft',
      'doorRight',
      'passive'
    };
    return WindowGrid(
      layout,
      stops([for (final p in parts) p['share'] ?? 1]),
      [
        for (final p in parts)
          stops([for (final c in p['cells'] as List) c['share'] ?? 1])
      ],
      openings: [
        for (final p in parts)
          [
            for (final c in p['cells'] as List)
              openings.contains(c['opening']) ? c['opening'] as String : 'fixed'
          ]
      ],
      fills: [
        for (final p in parts)
          [
            for (final c in p['cells'] as List)
              c['fill'] == 'panel' ? 'panel' : 'glass'
          ]
      ],
      shape: json['shape'] == 'arch' ? 'arch' : 'rect',
    );
  }
}

/// JSON schema the AI answers with (no recursion, so two levels).
const windowGridSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['isWindow', 'shape', 'layout', 'parts', 'notes'],
  'properties': {
    'isWindow': {'type': 'boolean'},
    'shape': {
      'type': 'string',
      'enum': ['rect', 'arch']
    },
    'layout': {
      'type': 'string',
      'enum': ['columns', 'rows']
    },
    'parts': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['share', 'cells'],
        'properties': {
          'share': {'type': 'number'},
          'cells': {
            'type': 'array',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'required': ['share', 'opening', 'fill'],
              'properties': {
                'share': {'type': 'number'},
                'opening': {
                  'type': 'string',
                  'enum': [
                    'fixed',
                    'left',
                    'right',
                    'tiltTurn',
                    'top',
                    'bottom',
                    'slideLeft',
                    'slideRight',
                    'doorLeft',
                    'doorRight',
                    'passive'
                  ]
                },
                'fill': {
                  'type': 'string',
                  'enum': ['glass', 'panel']
                },
              },
            },
          },
        },
      },
    },
    'notes': {'type': 'string'},
  },
};

/// Maps the unit square onto the quadrilateral [q] (top-left, top-right,
/// bottom-right, bottom-left): the perspective of a photographed frame.
class Homography {
  late final double a, b, c, d, e, f, g, h;
  Homography(List<(double, double)> q) {
    final (x0, y0) = q[0];
    final (x1, y1) = q[1];
    final (x2, y2) = q[2];
    final (x3, y3) = q[3];
    final dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
    final dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
    if (dx3.abs() < 1e-9 && dy3.abs() < 1e-9) {
      a = x1 - x0;
      b = x2 - x1;
      c = x0;
      d = y1 - y0;
      e = y2 - y1;
      f = y0;
      g = 0;
      h = 0;
    } else {
      final det = dx1 * dy2 - dx2 * dy1;
      g = (dx3 * dy2 - dx2 * dy3) / det;
      h = (dx1 * dy3 - dx3 * dy1) / det;
      a = x1 - x0 + g * x1;
      b = x3 - x0 + h * x3;
      c = x0;
      d = y1 - y0 + g * y1;
      e = y3 - y0 + h * y3;
      f = y0;
    }
  }

  (double, double) map(double u, double v) {
    final w = g * u + h * v + 1;
    return ((a * u + b * v + c) / w, (d * u + e * v + f) / w);
  }
}

/// A grey image, one byte per pixel.
class Gray {
  final int width, height;
  final Uint8List pixels;
  Gray(this.width, this.height, this.pixels);

  factory Gray.fromRgba(Uint8List rgba, int width, int height) {
    final out = Uint8List(width * height);
    for (var i = 0; i < out.length; i++) {
      final p = i * 4;
      out[i] =
          (rgba[p] * .299 + rgba[p + 1] * .587 + rgba[p + 2] * .114).round();
    }
    return Gray(width, height, out);
  }

  double at(double x, double y) {
    final x0 = x.floor().clamp(0, width - 1),
        y0 = y.floor().clamp(0, height - 1);
    final x1 = math.min(x0 + 1, width - 1), y1 = math.min(y0 + 1, height - 1);
    final fx = (x - x0).clamp(0.0, 1.0), fy = (y - y0).clamp(0.0, 1.0);
    final top =
        pixels[y0 * width + x0] * (1 - fx) + pixels[y0 * width + x1] * fx;
    final bottom =
        pixels[y1 * width + x0] * (1 - fx) + pixels[y1 * width + x1] * fx;
    return top * (1 - fy) + bottom * fy;
  }

  /// The frame inside [quad] seen straight on, [outWidth] × [outHeight].
  Gray rectify(List<(double, double)> quad, int outWidth, int outHeight) {
    final m = Homography(quad), out = Uint8List(outWidth * outHeight);
    for (var y = 0; y < outHeight; y++) {
      for (var x = 0; x < outWidth; x++) {
        final (sx, sy) = m.map((x + .5) / outWidth, (y + .5) / outHeight);
        out[y * outWidth + x] = at(sx, sy).round().clamp(0, 255);
      }
    }
    return Gray(outWidth, outHeight, out);
  }

  /// RGBA bytes of this image, for showing it.
  Uint8List rgba() {
    final out = Uint8List(width * height * 4);
    for (var i = 0; i < pixels.length; i++) {
      out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = pixels[i];
      out[i * 4 + 3] = 255;
    }
    return out;
  }
}

/// The colour photo [rgba] ([width] × [height]) straightened like
/// [Gray.rectify], for showing it.
Uint8List rectifyRgba(Uint8List rgba, int width, int height,
    List<(double, double)> quad, int outWidth, int outHeight) {
  final m = Homography(quad), out = Uint8List(outWidth * outHeight * 4);
  for (var y = 0; y < outHeight; y++) {
    for (var x = 0; x < outWidth; x++) {
      final (sx, sy) = m.map((x + .5) / outWidth, (y + .5) / outHeight);
      final px = sx.round().clamp(0, width - 1),
          py = sy.round().clamp(0, height - 1),
          i = (py * width + px) * 4,
          o = (y * outWidth + x) * 4;
      out[o] = rgba[i];
      out[o + 1] = rgba[i + 1];
      out[o + 2] = rgba[i + 2];
      out[o + 3] = 255;
    }
  }
  return out;
}

/// Finds the frame's bars in a straight-on photo [img] of the frame:
/// long straight edges that cross most of a part. Imposts are dark or
/// light bands with an edge on each side; sash frames next to them are
/// merged into the same bar.
///
/// With the straightened colour photo [colour] (RGBA, same size), even,
/// light grey parts are taken for sandwich panels; glass stays glass.
WindowGrid detectGrid(Gray img, {Uint8List? colour}) {
  final w = img.width, h = img.height, p = img.pixels;
  final gx = Float32List(w * h), gy = Float32List(w * h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      gx[i] = (p[i + 1] - p[i - 1]).abs().toDouble();
      gy[i] = (p[i + w] - p[i - w]).abs().toDouble();
    }
  }
  // Edge threshold from the picture itself: strong but not only the
  // strongest edges.
  final sample = <double>[
    for (var i = 0; i < gx.length; i += 7) math.max(gx[i], gy[i])
  ]..sort();
  final threshold = math.max(
      12.0, sample[(sample.length * .85).floor().clamp(0, sample.length - 1)]);

  /// Positions (0–1 within [from, to)) of bars across a band, scanning
  /// along x when [vertical].
  List<double> bars(bool vertical, int from, int to, int crossFrom, int crossTo,
      double minRun) {
    final length = to - from;
    if (length < 20 || crossTo - crossFrom < 10) return const [];
    final score = List<double>.filled(length, 0);
    for (var k = 0; k < length; k++) {
      final along = from + k;
      var hits = 0;
      for (var c = crossFrom; c < crossTo; c++) {
        final v = vertical ? gx[c * w + along] : gy[along * w + c];
        if (v > threshold) hits++;
      }
      score[k] = hits / (crossTo - crossFrom);
    }
    final smooth = [
      for (var k = 0; k < length; k++)
        [
          for (var j = math.max(0, k - 1);
              j <= math.min(length - 1, k + 1);
              j++)
            score[j]
        ].reduce(math.max)
    ];
    // Strong positions, away from the outer frame.
    final margin = (length * .09).ceil();
    final strong = [
      for (var k = margin; k < length - margin; k++)
        if (smooth[k] >= minRun) k
    ];
    // Neighbouring strong positions are one bar (edges of the impost and
    // of the sashes beside it).
    final groups = <List<int>>[];
    for (final k in strong) {
      if (groups.isNotEmpty && k - groups.last.last <= length * .05) {
        groups.last.add(k);
      } else {
        groups.add([k]);
      }
    }
    final found = <double>[];
    for (final g in groups) {
      final at = (g.first + g.last) / 2 / length;
      if (found.isEmpty || at - found.last >= .1) found.add(at);
    }
    return found.where((a) => 1 - a >= .1).toList();
  }

  int px(double f, int size) => (f * size).round().clamp(0, size);
  List<List<double>> innerBars(List<double> cuts, bool columns) {
    final stops = [0.0, ...cuts, 1.0];
    return [
      for (var i = 0; i + 1 < stops.length; i++)
        () {
          // Look only at the middle of the part, clear of its own bars.
          final a = stops[i], b = stops[i + 1], pad = (b - a) * .15;
          return columns
              ? bars(false, 0, h, px(a + pad, w), px(b - pad, w), .5)
              : bars(true, 0, w, px(a + pad, h), px(b - pad, h), .5);
        }()
    ];
  }

  // A full-width transom makes rows; otherwise the frame is columns.
  final rows = bars(false, 0, h, px(.05, w), px(.95, w), .55);
  final cols = rows.isEmpty
      ? bars(true, 0, w, px(.05, h), px(.95, h), .55)
      : const <double>[];
  final grid = rows.isNotEmpty
      ? WindowGrid('rows', rows, innerBars(rows, false))
      : WindowGrid('columns', cols, innerBars(cols, true));
  // Even, light, colourless parts are panels; glass shows the sky, the
  // room or reflections.
  final c = colour;
  if (c != null && c.length == w * h * 4) {
    for (var i = 0; i < grid.partCount; i++) {
      final (a, b) = grid.part(i);
      final stops = [0.0, ...grid.inner[i], 1.0];
      for (var j = 0; j + 1 < stops.length; j++) {
        final m0 = a + (b - a) * .25, m1 = b - (b - a) * .25;
        final o0 = stops[j] + (stops[j + 1] - stops[j]) * .25,
            o1 = stops[j + 1] - (stops[j + 1] - stops[j]) * .25;
        final x0 = px(grid.columns ? m0 : o0, w),
            x1 = px(grid.columns ? m1 : o1, w);
        final y0 = px(grid.columns ? o0 : m0, h),
            y1 = px(grid.columns ? o1 : m1, h);
        var sum = 0.0, sq = 0.0, sat = 0.0, n = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            final v = p[y * w + x].toDouble(), k = (y * w + x) * 4;
            final hi = math.max(c[k], math.max(c[k + 1], c[k + 2])),
                lo = math.min(c[k], math.min(c[k + 1], c[k + 2]));
            sum += v;
            sq += v * v;
            sat += hi == 0 ? 0 : (hi - lo) / hi;
            n++;
          }
        }
        if (n == 0) continue;
        final mean = sum / n, sd = math.sqrt(math.max(0, sq / n - mean * mean));
        if (mean > 165 && sd < 9 && sat / n < .08) grid.fills[i][j] = 'panel';
      }
    }
  }
  return grid;
}

/// A first guess at the opening a window or door goes into, on a photo
/// taken at it: long vertical edges left and right of the middle, long
/// horizontal ones above and below it, the outermost strong one on each
/// side (the outer edge of an old frame rather than its bars). Corners
/// top-left first, as fractions of the photo.
List<(double, double)> guessOpening(Gray g) {
  final w = g.width, h = g.height, p = g.pixels;
  final cols = List<double>.filled(w, 0), rows = List<double>.filled(h, 0);
  final y0 = (h * .15).round(),
      y1 = (h * .85).round(),
      x0 = (w * .15).round(),
      x1 = (w * .85).round();
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      if (y >= y0 && y < y1) cols[x] += (p[i + 1] - p[i - 1]).abs();
      if (x >= x0 && x < x1) rows[y] += (p[i + w] - p[i - w]).abs();
    }
  }
  List<double> smooth(List<double> v) => [
        for (var i = 0; i < v.length; i++)
          (v[math.max(0, i - 2)] +
                  v[math.max(0, i - 1)] +
                  v[i] +
                  v[math.min(v.length - 1, i + 1)] +
                  v[math.min(v.length - 1, i + 2)]) /
              5
      ];
  final c = smooth(cols), r = smooth(rows);
  // The outermost edge at least 60 % as strong as the strongest one
  // between [from] and [to], searching from [from].
  int edge(List<double> v, int from, int to) {
    final step = from < to ? 1 : -1;
    var best = 0.0;
    for (var i = from; i != to; i += step) {
      best = math.max(best, v[i]);
    }
    for (var i = from; i != to; i += step) {
      if (v[i] >= best * .6 && best > 0) return i;
    }
    return from;
  }

  final left = edge(c, (w * .03).round(), (w * .45).round()),
      right = edge(c, (w * .97).round(), (w * .55).round()),
      top = edge(r, (h * .03).round(), (h * .45).round()),
      bottom = edge(r, (h * .98).round(), (h * .55).round());
  final l = left / w, rt = right / w, t = top / h, b = bottom / h;
  return [(l, t), (rt, t), (rt, b), (l, b)];
}

/// A small upright grey picture from a camera frame's brightness plane
/// ([luma], [rowStride] bytes a row): every [step]-th pixel, turned by
/// [rotation] degrees clockwise (the camera's sensor orientation) so it
/// stands the way the phone is held.
Gray grayFromLuma(Uint8List luma, int width, int height, int rowStride,
    {int step = 1, int rotation = 0}) {
  final sw = width ~/ step, sh = height ~/ step;
  final turned = rotation % 180 != 0;
  final w = turned ? sh : sw, h = turned ? sw : sh, out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final (sx, sy) = switch (rotation % 360) {
        90 => (y, sh - 1 - x),
        180 => (sw - 1 - x, sh - 1 - y),
        270 => (sw - 1 - y, x),
        _ => (x, y),
      };
      final i = sy * step * rowStride + sx * step;
      out[y * w + x] = i < luma.length ? luma[i] : 0;
    }
  }
  return Gray(w, h, out);
}
