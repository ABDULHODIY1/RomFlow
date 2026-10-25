import 'dart:math' as math;
import 'dart:convert';

typedef DMap = Map<String, dynamic>;
const openingNames = <String, String>{
  'fixed': 'Yopiq',
  'left': 'Chapga',
  'right': 'O‘ngga',
  'top': 'Tepaga',
  'bottom': 'Pastga',
  'tiltTurn': 'Burilma / qayrilma',
  'slideLeft': 'Chapga surilma',
  'slideRight': 'O‘ngga surilma',
  'doorLeft': 'Eshik: chap',
  'doorRight': 'Eshik: o‘ng',
  'passive': 'Passiv eshik qanoti',
};
const shapeNames = <String, String>{
  'rect': 'To‘rtburchak',
  'arch': 'Oysimon / arka',
  'circle': 'Dumaloq',
  'ellipse': 'Oval',
  'triangle': 'Uchburchak',
  'trapezoid': 'Trapetsiya',
  'custom': 'Qo‘lda kontur (qavariq)',
};
const materialNames = <String, String>{
  'frame': 'Tashqi rama',
  'sash': 'Qanot profili',
  'mullion': 'Impost',
  'sashMullion': 'Qanot ichki ajratgichi',
  'bead': 'Shtapik',
  'uGasket': 'U-rezina',
  'sealInner': 'Ichki qanot rezinasi',
  'sealOuter': 'Tashqi qanot rezinasi',
  'glass': 'Shisha',
  'spacer': 'Shishapaket alyuminiy ajratgichi',
  'shpros': 'Shishalar orasidagi bezak shpros',
  'shprosJoint': 'Shpros kesishma ulagichi',
  'shprosRosette': 'Shpros bezak tuguni',
  'spacerCorner': 'Ajratgich burchagi',
  'butyl': 'Shishapaket butili',
  'iguSeal': 'Shishapaket chet germetigi',
  'desiccant': 'Ajratgich nam yutgichi',
  'panel': 'Sendvich panel',
  'lambris': 'Lambir',
  'handle': 'Deraza tutqichi',
  'hinge': 'Deraza petlyasi',
  'windowLock': 'Deraza qulfi / zapor',
  'tiltKit': 'Qayrilma qo‘shimcha mexanizm',
  'doorHandle': 'Eshik tutqichi to‘plami',
  'doorHinge': 'Eshik petlyasi',
  'doorLock': 'Eshik qulfi',
  'cylinder': 'Qulf silindri',
  'passiveBolt': 'Passiv qanot shpingaleti',
  'roller': 'Surilma rolik',
  'slideLock': 'Surilma qulfi',
  'rail': 'Surilma relsi',
  'corner': 'Archa • rama / qanot burchak qotirgichi',
  'mullionJoint': 'Impost ulagichi',
  'cornerProfile': '90° burchak ulash profili',
  'screw': 'Samorez',
  'anchor': 'Montaj ankeri',
  'foam': 'Montaj ko‘pigi',
  'silicone': 'Silikon',
  'mesh': 'Setka matosi',
  'meshFrame': 'Setka profili',
  'meshRubber': 'Setka rezinasi',
  'meshCorner': 'Setka burchagi',
  'threshold': 'Eshik ostonasi',
  'closer': 'Eshik dovodchigi',
  'labor': 'Ish haqi',
  'bending': 'Profil bukish xizmati',
};
const linearStock = [
  'frame',
  'sash',
  'mullion',
  'sashMullion',
  'bead',
  'cornerProfile',
  'rail',
  'meshFrame',
  'threshold',
];
const areaMaterials = ['glass', 'panel', 'lambris', 'mesh', 'labor'];
const meterMaterials = [
  'uGasket',
  'sealInner',
  'sealOuter',
  'meshRubber',
  'bending',
  'spacer',
  'shpros',
  'butyl',
  'iguSeal',
];
const recipeLabels = <String, String>{
  'frameFace': 'Rama yuzi (mm)',
  'beadFaceMm': 'Shtapik eni (mm)',
  'beadDepthMm': 'Shtapik chuqurligi (mm)',
  'frameDepth': '3D rama chuqurligi (mm)',
  'sashDepth': '3D qanot chuqurligi (mm)',
  'glassThickness': 'Bitta shisha qalinligi (mm)',
  'glassGapMm': 'Ikki shisha oralig‘i (mm)',
  'spacerInsetMm': 'Ajratgich chetdan ichkariga (mm)',
  'desiccantGPerM': 'Ajratgich nam yutgichi (gramm / m)',
  'profileWallMm': '3D profil devori (mm, namuna)',
  'profileChambers': '3D profil kameralari (1–4, namuna)',
  'sashFace': 'Qanot yuzi (mm)',
  'mullionFace': 'Impost yuzi (mm)',
  'glassGap': 'Shisha chegirmasi / chet (mm)',
  'glassRebateMm': 'Shisha profil labi ostiga kirishi (mm)',
  'cutAllowance': 'Har bir detal kesish qo‘shimchasi (mm)',
  'bendAllowance': 'Egri profil blanki qo‘shimchasi (mm)',
  'stockMm': 'Profil tayoq uzunligi (mm)',
  'kerfMm': 'Arra izi / kesish (mm)',
  'reusableMm': 'Qayta ishlatiladigan qoldiq chegarasi (mm)',
  'sheetW': 'Shisha list eni (mm)',
  'sheetH': 'Shisha list bo‘yi (mm)',
  'sheetGap': 'List kesish oralig‘i (mm)',
  'panelSheetW': 'Panel/lambir list eni (mm)',
  'panelSheetH': 'Panel/lambir list bo‘yi (mm)',
  'uLoops': 'U-rezina kontur soni',
  'innerLoops': 'Ichki rezina kontur soni',
  'outerLoops': 'Tashqi rezina kontur soni',
  'gasketReservePct': 'Rezina zaxirasi (%)',
  'windowHinges': 'Deraza petlyasi / qanot',
  'doorHinges': 'Eshik petlyasi / qanot',
  'screwPerM': 'Samorez / profil metr',
  'anchorSpacing': 'Anker oralig‘i (mm)',
  'foamCoverage': 'Bir ballon ko‘pik / rama metr',
  'siliconeCoverage': 'Bir tub silikon / to‘ldirma metr',
  'markupPct': 'Tannarx ustamasi (%)',
  'lambrisStripMm': 'Lambir ishchi eni (mm)',
  'lambrisStockMm': 'Lambir tayoq uzunligi (mm)',
  'wastePct': 'Narxga qo‘shiladigan chiqindi (%)',
};

/// Values used when an older saved recipe predates a parameter.
const recipeFallbacks = <String, num>{
  'beadFaceMm': 18,
  'beadDepthMm': 16,
  'profileWallMm': 1.8,
  'profileChambers': 2,
  'glassGapMm': 12,
  'spacerInsetMm': 6,
  'desiccantGPerM': 20,
  'wastePct': 7,
  'glassRebateMm': 0,
};

/// Profile colours. The surcharge applies to profile materials only.
const finishNames = <String, String>{
  'white': 'Oq',
  'silver': 'Kumushrang',
  'mokri': 'Mokri / to‘q kulrang',
  'brown': 'Jigarrang',
  'anthracite': 'Antratsit',
  'black': 'Qora',
  'goldenOak': 'Oltin eman',
  'walnut': 'Yong‘oq',
};
const finishColors = <String, int>{
  'white': 0xfff4f6f8,
  'silver': 0xffd7dee7,
  'mokri': 0xff655e57,
  'brown': 0xff69422e,
  'anthracite': 0xff3b4249,
  'black': 0xff22262b,
  'goldenOak': 0xffb27a3e,
  'walnut': 0xff5e3b24,
};
const colouredMaterials = {
  'frame',
  'sash',
  'mullion',
  'sashMullion',
  'bead',
  'cornerProfile',
  'rail',
  'meshFrame',
  'threshold',
};

/// Edge of the sash that carries the hinges; the handle sits opposite. The
/// opening symbol's lines meet at the handle and open toward the hinges.
String? hingeSide(String opening) => switch (opening) {
      'fixed' || 'slideLeft' || 'slideRight' => null,
      'right' || 'doorRight' => 'right',
      'top' => 'top',
      'bottom' => 'bottom',
      _ => 'left',
    };

/// Sides of a rectangular construction joined to the next one at 90°
/// through the corner ("qayt") connector profile.
List<String> cornerJoins(DMap d) => d['shape'] != 'rect'
    ? const []
    : [
        for (final side in const ['left', 'right'])
          if ((d['joins'] as List? ?? const []).contains(side)) side,
      ];

bool isDoorOpening(String opening) =>
    opening.startsWith('door') || opening == 'passive';

/// Opening symbol inside the sash box [b] (x0, y0, x1, y1) as polylines.
List<List<V>> openingSymbolLines(String opening, List<double> b) {
  final cx = (b[0] + b[2]) / 2, cy = (b[1] + b[3]) / 2;
  List<V> apex(String side) => switch (side) {
        'right' => [V(b[0], b[1]), V(b[2], cy), V(b[0], b[3])],
        'top' => [V(b[0], b[3]), V(cx, b[1]), V(b[2], b[3])],
        'bottom' => [V(b[0], b[1]), V(cx, b[3]), V(b[2], b[1])],
        _ => [V(b[2], b[1]), V(b[0], cy), V(b[2], b[3])],
      };
  if (opening.startsWith('slide')) {
    final dir = opening == 'slideLeft' ? -1.0 : 1.0,
        half = (b[2] - b[0]) * .28,
        head = math.min(half * .4, (b[3] - b[1]) * .08),
        tip = V(cx + dir * half, cy);
    return [
      [V(cx - dir * half, cy), tip],
      [
        V(tip.x - dir * head, cy - head * .8),
        tip,
        V(tip.x - dir * head, cy + head * .8),
      ],
    ];
  }
  final side = hingeSide(opening);
  if (side == null) return [];
  const handleSide = {
    'left': 'right',
    'right': 'left',
    'top': 'bottom',
    'bottom': 'top',
  };
  return [
    apex(handleSide[side]!),
    if (opening == 'tiltTurn') apex('top'),
  ];
}

/// Where the handle sits on a sash box: opposite the hinges.
V? handlePoint(String opening, List<double> b) {
  final cx = (b[0] + b[2]) / 2, cy = (b[1] + b[3]) / 2;
  if (opening == 'slideLeft') return V(b[2], cy);
  if (opening == 'slideRight') return V(b[0], cy);
  return switch (hingeSide(opening)) {
    null => null,
    'right' => V(b[0], cy),
    'top' => V(cx, b[3]),
    'bottom' => V(cx, b[1]),
    _ => V(b[2], cy),
  };
}

DMap defaultRecipe(DMap p) => {
      'frameFace': p['frameFaceMm'] ?? 50,
      'frameDepth': 60,
      'beadFaceMm': 18, 'beadDepthMm': 16,
      'sashDepth': 65,
      'glassThickness': 6,
      'glazingType': 'single',
      'glassGapMm': 12,
      'spacerInsetMm': 6,
      'desiccantGPerM': 20,
      'sectionStyle': 'chambered',
      'profileDetail': 'rebated',
      'hardwareFinish': 'black',
      'handleStyle': 'plate',
      // Simple aluminium casements are fitted with the dolphin handle.
      'windowHandle': p['material'] == 'aluminium' ? 'dolphin' : 'pull',
      'finish': 'silver',
      // Customers are billed for the metres and square metres a construction
      // uses plus a waste allowance; whole bars and sheets are still listed
      // for purchasing. 'purchase' bills the whole bars and sheets instead.
      'pricingMode': 'net',
      'wastePct': p['wastePct'] ?? 7,
      'colorPct': <String, dynamic>{
        'white': 0,
        'silver': 0,
        'mokri': 0,
        'brown': 0,
        'anthracite': ((((p['anthraciteFactor'] ?? 1.2) as num) - 1) * 100)
            .roundToDouble(),
        'black': ((((p['anthraciteFactor'] ?? 1.2) as num) - 1) * 100)
            .roundToDouble(),
        'goldenOak':
            ((((p['oakFactor'] ?? 1.3) as num) - 1) * 100).roundToDouble(),
        'walnut':
            ((((p['oakFactor'] ?? 1.3) as num) - 1) * 100).roundToDouble(),
      },
      'profileWallMm': 1.8,
      'profileChambers': 2,
      'sashFace': p['sashFaceMm'] ?? 50,
      'mullionFace': 50,
      'glassGap': 3,
      // How far glass and panels reach under the profile lip on each side.
      // 0 keeps them inside the visible opening.
      'glassRebateMm': 0,
      'cutAllowance': 0,
      'bendAllowance': 100,
      'stockMm': 6000,
      'kerfMm': 3,
      'reusableMm': 500,
      'sheetW': 3210,
      'sheetH': 2250,
      'sheetGap': 3,
      'panelSheetW': 1500,
      'panelSheetH': 3000,
      'uLoops': 1,
      'innerLoops': 1,
      'outerLoops': 1,
      'gasketReservePct': 3,
      'windowHinges': 2,
      'doorHinges': 3,
      'screwPerM': 4,
      'anchorSpacing': 600,
      'foamCoverage': 12,
      'siliconeCoverage': 12,
      'markupPct': p['markupPct'] ?? 25,
      'lambrisStripMm': 100,
      'lambrisStockMm': 6000,
      'priceDate': '',
      'priceSource': 'Sex narxi — tekshirilmagan namuna',
      'prices': {
        for (final k in materialNames.keys) k: 0,
        'frame': p['framePrice'] ?? 45000,
        'sash': p['sashPrice'] ?? 50000,
        'mullion': p['mullionPrice'] ?? 42000,
        'sashMullion': p['mullionPrice'] ?? 42000,
        'glass': p['glassPrice'] ?? 130000,
        'uGasket': p['gasketPrice'] ?? 3500,
        'sealInner': 3500,
        'sealOuter': 3500,
        'bead': 15000,
        'panel': 140000,
        'lambris': 100000,
        'handle': 25000,
        'hinge': 12000,
        'windowLock': 35000,
        'tiltKit': 150000,
        'doorHandle': 65000,
        'doorHinge': 35000,
        'doorLock': 80000,
        'cylinder': 45000,
        'passiveBolt': 15000,
        'roller': 20000,
        'slideLock': 25000,
        'rail': 30000,
        'corner': 3000,
        'mullionJoint': 5000,
        'cornerProfile': p['mullionPrice'] ?? 42000,
        'screw': 300,
        'anchor': 2500,
        'foam': 45000,
        'silicone': 35000,
        'mesh': p['meshPrice'] ?? 75000,
        'meshFrame': 18000,
        'meshRubber': 2000,
        'meshCorner': 1500,
        'threshold': 40000,
        'closer': 180000,
        'labor': p['laborPrice'] ?? 50000,
        'bending': 25000,
      },
      'stockOverrides': <String, dynamic>{},
      'customMaterials': <dynamic>[],
    };
DMap recipeFor(DMap p) {
  final d = defaultRecipe(p),
      saved = Map<String, dynamic>.from(p['drawingRecipe'] ?? {});
  return {
    ...d,
    ...saved,
    'prices': <String, dynamic>{
      ...Map<String, dynamic>.from(d['prices']),
      ...Map<String, dynamic>.from(saved['prices'] ?? {}),
    },
    'colorPct': <String, dynamic>{
      ...Map<String, dynamic>.from(d['colorPct']),
      ...Map<String, dynamic>.from(saved['colorPct'] ?? {}),
    },
  };
}

class GlazingSpec {
  final bool doubleGlazed;
  final double paneMm, gapMm, insetMm;
  GlazingSpec(DMap r)
      : doubleGlazed = r['glazingType'] == 'double',
        paneMm = (r['glassThickness'] as num? ?? 6).toDouble(),
        gapMm = (r['glassGapMm'] as num? ?? 12).toDouble(),
        insetMm = (r['spacerInsetMm'] as num? ?? 6).toDouble();
  int get panes => doubleGlazed ? 2 : 1;
  double get totalMm => paneMm * panes + (doubleGlazed ? gapMm : 0);
  String get label => doubleGlazed
      ? '${paneMm.toStringAsFixed(0)}–${gapMm.toStringAsFixed(0)}–${paneMm.toStringAsFixed(0)}'
      : '${paneMm.toStringAsFixed(0)} mm';
}

DMap newLeaf(String id) => {
      'id': id,
      'opening': 'fixed',
      'fill': 'glass',
      'mesh': false,
      'outward': false,
      'locks': 1,
      'closer': false,
      'threshold': true,
    };
DMap newDrawing() => {
      'version': 1,
      'shape': 'rect',
      'riseMm': 500,
      'widthMm': 1500,
      'heightMm': 1500,
      'root': newLeaf('1'),
      'vertices': [
        [0, 0],
        [1, 0],
        [1, 1],
        [0, 1],
      ],
    };

class V {
  final double x, y;
  const V(this.x, this.y);
  V operator +(V b) => V(x + b.x, y + b.y);
  V operator -(V b) => V(x - b.x, y - b.y);
  V operator *(double f) => V(x * f, y * f);
  double get length => math.sqrt(x * x + y * y);
}

double cross(V a, V b) => a.x * b.y - a.y * b.x;
double signedArea(List<V> p) {
  double s = 0;
  for (var i = 0; i < p.length; i++) {
    s += cross(p[i], p[(i + 1) % p.length]);
  }
  return s / 2;
}

double polygonArea(List<V> p) => signedArea(p).abs();
double perimeter(List<V> p) {
  double s = 0;
  for (var i = 0; i < p.length; i++) {
    s += (p[i] - p[(i + 1) % p.length]).length;
  }
  return s;
}

List<double> bounds(List<V> p) => [
      p.map((v) => v.x).reduce(math.min),
      p.map((v) => v.y).reduce(math.min),
      p.map((v) => v.x).reduce(math.max),
      p.map((v) => v.y).reduce(math.max),
    ];
List<V> outline(DMap d) {
  final w = (d['widthMm'] as num).toDouble(),
      h = (d['heightMm'] as num).toDouble();
  final shape = d['shape'];
  List<V> p;
  if (shape == 'circle' || shape == 'ellipse') {
    if (shape == 'circle' && (w - h).abs() > 0.01) {
      throw Exception('Dumaloq romda eni va bo‘yi teng bo‘lsin');
    }
    p = [
      for (var i = 0; i < 128; i++)
        V(
          w / 2 + w / 2 * math.cos(i * math.pi / 64),
          h / 2 + h / 2 * math.sin(i * math.pi / 64),
        ),
    ];
  } else if (shape == 'arch') {
    final rise = (d['riseMm'] as num).toDouble();
    if (rise < 30 || rise > h) {
      throw Exception('Arka balandligi 30 mm dan rom bo‘yigacha bo‘lsin');
    }
    p = [
      for (var i = 0; i <= 64; i++)
        V(
          w / 2 + w / 2 * math.cos(math.pi + i * math.pi / 64),
          rise + rise * math.sin(math.pi + i * math.pi / 64),
        ),
      V(w, h),
      V(0, h),
    ];
  } else if (shape == 'triangle') {
    p = [V(w / 2, 0), V(w, h), V(0, h)];
  } else if (shape == 'trapezoid') {
    p = [V(w * .2, 0), V(w * .8, 0), V(w, h), V(0, h)];
  } else if (shape == 'custom') {
    final a = d['vertices'] as List;
    if (a.length < 3 || a.length > 24) {
      throw Exception('Kontur 3–24 nuqtadan iborat bo‘lsin');
    }
    p = [
      for (final v in a)
        V((v[0] as num).toDouble() * w, (v[1] as num).toDouble() * h),
    ];
    if (p.any(
      (v) =>
          !v.x.isFinite ||
          !v.y.isFinite ||
          v.x < 0 ||
          v.y < 0 ||
          v.x > w ||
          v.y > h,
    )) {
      throw Exception('Kontur nuqtalari chizma ichida bo‘lsin');
    }
  } else {
    p = [const V(0, 0), V(w, 0), V(w, h), V(0, h)];
  }
  if (signedArea(p) < 0) p = p.reversed.toList();
  if (polygonArea(p) < 10000) throw Exception('Kontur maydoni juda kichik');
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    if ((b - a).length < 0.01) throw Exception('Takroriy kontur nuqtasi');
    for (final v in p) {
      if (cross(b - a, v - a) < -0.01) {
        throw Exception('Kontur qavariq, kesishmaydigan tartibda chizilsin');
      }
    }
  }
  return p;
}

List<V> halfClip(List<V> p, V a, V b) {
  final out = <V>[];
  if (p.isEmpty) return out;
  for (var i = 0; i < p.length; i++) {
    final s = p[i], e = p[(i + 1) % p.length];
    final ds = cross(b - a, s - a), de = cross(b - a, e - a);
    if (ds >= -1e-7) out.add(s);
    if ((ds >= 0) != (de >= 0)) {
      out.add(s + (e - s) * (ds / (ds - de)));
    }
  }
  return out;
}

List<V> inset(List<V> p, double mm) {
  if (_isStepped(p)) return _insetStepped(p, mm);
  var out = p.toList();
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length], e = b - a;
    final n = V(-e.y, e.x) * (mm / e.length);
    out = halfClip(out, a + n, b + n);
  }
  return out;
}

/// A non-convex outline made only of horizontal and vertical edges: a
/// frame stepped around a section that was pulled on its own.
bool _isStepped(List<V> p) {
  if (p.length < 6 || signedArea(p) <= 0) return false;
  var concave = false;
  for (var i = 0; i < p.length; i++) {
    final e1 = p[i] - p[(i + p.length - 1) % p.length],
        e2 = p[(i + 1) % p.length] - p[i];
    if (e2.x.abs() > 1e-6 && e2.y.abs() > 1e-6) return false;
    if (cross(e1, e2) < -1e-6) concave = true;
  }
  return concave;
}

/// Inset of a stepped outline: each edge moves in by [mm] and meets its
/// neighbours at a mitre. Empty when an edge would turn over.
List<V> _insetStepped(List<V> p, double mm) {
  final n = p.length;
  V normal(V e) => V(-e.y, e.x) * (1 / e.length);
  final out = [
    for (var i = 0; i < n; i++)
      p[i] +
          (normal(p[i] - p[(i + n - 1) % n]) + normal(p[(i + 1) % n] - p[i])) *
              mm,
  ];
  for (var i = 0; i < n; i++) {
    final a = p[(i + 1) % n] - p[i], b = out[(i + 1) % n] - out[i];
    if (a.x * b.x + a.y * b.y < 1) return const [];
  }
  return out;
}

/// Outline of a union of boxes [x0, y0, x1, y1], turning the same way as
/// [outline]. Throws when the boxes are not one piece without holes.
List<V> boxUnion(List<List<double>> boxes) {
  double snap(num v) => (v * 100).round() / 100;
  final b = [
    for (final x in boxes) [for (final v in x) snap(v)],
  ];
  final xs = {
        for (final x in b) ...[x[0], x[2]],
      }.toList()
        ..sort(),
      ys = {
        for (final x in b) ...[x[1], x[3]],
      }.toList()
        ..sort();
  final nx = xs.length - 1, ny = ys.length - 1;
  final filled = [
    for (var j = 0; j < ny; j++)
      [
        for (var i = 0; i < nx; i++)
          b.any(
            (x) =>
                (xs[i] + xs[i + 1]) / 2 > x[0] &&
                (xs[i] + xs[i + 1]) / 2 < x[2] &&
                (ys[j] + ys[j + 1]) / 2 > x[1] &&
                (ys[j] + ys[j + 1]) / 2 < x[3],
          ),
      ],
  ];
  bool at(int i, int j) => i >= 0 && j >= 0 && i < nx && j < ny && filled[j][i];
  final next = <(int, int), (int, int)>{};
  void edge((int, int) from, (int, int) to) {
    if (next.containsKey(from)) {
      throw Exception('Kesilgan joylar romni ikkiga bo‘lmasin');
    }
    next[from] = to;
  }

  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      if (!filled[j][i]) continue;
      if (!at(i, j - 1)) edge((i, j), (i + 1, j));
      if (!at(i + 1, j)) edge((i + 1, j), (i + 1, j + 1));
      if (!at(i, j + 1)) edge((i + 1, j + 1), (i, j + 1));
      if (!at(i - 1, j)) edge((i, j + 1), (i, j));
    }
  }
  if (next.isEmpty) throw Exception('Kontur maydoni juda kichik');
  final start = next.keys.first, loop = <(int, int)>[];
  var at0 = start;
  do {
    loop.add(at0);
    at0 = next[at0]!;
  } while (at0 != start && loop.length <= next.length);
  if (loop.length != next.length) {
    throw Exception('Kesilgan joylar romni ikkiga bo‘lmasin');
  }
  return [
    for (var k = 0; k < loop.length; k++)
      if (() {
        final a = loop[(k + loop.length - 1) % loop.length],
            c = loop[(k + 1) % loop.length],
            m = loop[k];
        return !((a.$1 == m.$1 && m.$1 == c.$1) ||
            (a.$2 == m.$2 && m.$2 == c.$2));
      }())
        V(xs[loop[k].$1], ys[loop[k].$2]),
  ];
}

/// Moves every edge of a convex outline outward by [mm], mitring corners.
List<V> outset(List<V> p, double mm) {
  final pts = <V>[
    for (var i = 0; i < p.length; i++)
      if ((p[(i + 1) % p.length] - p[i]).length > 1e-6) p[i],
  ];
  if (mm <= 0 || pts.length < 3) return p;
  // inset() keeps the left side of each edge, so outward is to the right.
  final starts = <V>[], dirs = <V>[];
  for (var i = 0; i < pts.length; i++) {
    final e = pts[(i + 1) % pts.length] - pts[i];
    starts.add(pts[i] + V(e.y, -e.x) * (mm / e.length));
    dirs.add(e);
  }
  return [
    for (var i = 0; i < pts.length; i++)
      () {
        final j = (i + pts.length - 1) % pts.length,
            d = cross(dirs[j], dirs[i]);
        if (d.abs() < 1e-9) return starts[i];
        return starts[j] +
            dirs[j] * (cross(starts[i] - starts[j], dirs[i]) / d);
      }(),
  ];
}

/// Inset for positive [mm], outset for negative.
List<V> offsetOutline(List<V> p, double mm) =>
    mm >= 0 ? inset(p, mm) : outset(p, -mm);

/// The glass or panel actually ordered for a filling: the visible opening
/// less the edge gap, plus what reaches under the profile lip.
List<V> glassOutline(List<V> filling, DMap r) => offsetOutline(
      filling,
      (r['glassGap'] as num).toDouble() -
          ((r['glassRebateMm'] ?? 0) as num).toDouble(),
    );

List<V> rectClip(List<V> p, List<double> b) {
  var q = p;
  final r = [V(b[0], b[1]), V(b[2], b[1]), V(b[2], b[3]), V(b[0], b[3])];
  for (var i = 0; i < 4; i++) {
    q = halfClip(q, r[i], r[(i + 1) % 4]);
  }
  return q;
}

class DrawingCell {
  final DMap node;
  final List<double> box;
  final List<V> polygon;

  /// Sides of the section on the frame ('left', 'top', 'right', 'bottom').
  final Set<String> frame;
  DrawingCell(this.node, this.box, this.polygon, {this.frame = const {}});
}

class DrawingSplit {
  final DMap node;
  final List<double> box;
  final V a, b;
  DrawingSplit(this.node, this.box, this.a, this.b);
}

class DrawingLayout {
  final List<DrawingCell> cells = [];
  final List<DrawingSplit> splits = [];

  /// Each node's box before its own trim.
  final Map<String, List<double>> boxes = {};
  late List<V> outer, inner;
}

const _sideIndex = {'left': 0, 'top': 1, 'right': 2, 'bottom': 3};

/// A section's box with its "trim" taken off the frame sides in [free]:
/// the frame steps in there (a wall under side windows, say).
List<double> _trimmed(DMap n, List<double> b, Set<String> free) {
  final t = n['trim'];
  if (t is! Map || t.isEmpty) return b;
  final out = List<double>.from(b);
  for (final MapEntry(:key, :value) in t.entries) {
    final i = _sideIndex[key];
    if (i == null || !free.contains(key) || value is! num || value == 0) {
      continue;
    }
    if (!value.isFinite || value < 0) throw Exception('Kesish o‘lchami xato');
    out[i] += i < 2 ? value : -value;
  }
  return out;
}

bool _hasTrim(DMap n) =>
    (n['trim'] is Map && (n['trim'] as Map).values.any((v) => v != 0)) ||
    (n['axis'] != null && (_hasTrim(n['a'] as DMap) || _hasTrim(n['b'])));

DrawingLayout layoutDrawing(DMap d, DMap r) {
  final rect = _layoutTree(d, r, outline(d), null);
  if (d['shape'] != 'rect' || !_hasTrim(d['root'] as DMap)) return rect;
  // A trimmed section takes the frame with it: the outline is every
  // section grown by the frame face (to an impost centre at least).
  final f = (r['frameFace'] as num).toDouble(),
      e = math.max(f, (r['mullionFace'] as num).toDouble() / 2);
  final outer = boxUnion([
    for (final c in rect.cells)
      [
        for (final (i, side) in const [
          (0, 'left'),
          (1, 'top'),
          (2, 'right'),
          (3, 'bottom'),
        ])
          c.box[i] + (c.frame.contains(side) ? f : e) * (i < 2 ? -1 : 1),
      ],
  ]);
  return _layoutTree(d, r, outer, bounds(rect.inner));
}

DrawingLayout _layoutTree(DMap d, DMap r, List<V> outer, List<double>? root) {
  final l = DrawingLayout();
  l.outer = outer;
  l.inner = inset(l.outer, (r['frameFace'] as num).toDouble());
  if (l.inner.length < 3) throw Exception('Rama yuzi uchun joy yetarli emas');
  final trims = d['shape'] == 'rect', stepped = root != null;
  var count = 0;
  void visit(
    DMap n,
    List<double> b,
    int depth,
    Set<String> frame,
    Set<String> free,
  ) {
    if (depth > 12 || ++count > 127) {
      throw Exception('Ko‘pi bilan 64 bo‘lim, 12 daraja');
    }
    if (n['id'] is String) l.boxes[n['id'] as String] = b;
    if (trims && n['trim'] is Map) {
      final t = n['trim'] as Map;
      b = _trimmed(n, b, free);
      // A trimmed side is not trimmed again further down.
      free = {
        for (final side in free)
          if (t[side] is! num || t[side] == 0) side,
      };
      if (b[2] - b[0] < 80 || b[3] - b[1] < 80) {
        throw Exception('Bo‘lim ichki o‘lchami kamida 80 mm');
      }
    }
    var poly = rectClip(l.inner, b);
    if (poly.length < 3 || polygonArea(poly) < 2500) {
      throw Exception('Bo‘lim konturdan tashqarida yoki juda kichik');
    }
    if (n['axis'] == null) {
      if (stepped) {
        if ((polygonArea(poly) - (b[2] - b[0]) * (b[3] - b[1])).abs() > 50) {
          throw Exception('Kesilgan bo‘lim qo‘shnisiga mos kelmadi');
        }
        poly = [V(b[0], b[1]), V(b[2], b[1]), V(b[2], b[3]), V(b[0], b[3])];
      }
      final cell = DrawingCell(n, b, poly, frame: frame);
      if (n['infill'] != null) layoutInfill(cell, r);
      l.cells.add(cell);
      return;
    }
    final vertical = n['axis'] == 'v', ratio = (n['ratio'] as num).toDouble();
    if (!ratio.isFinite || ratio <= 0 || ratio >= 1) {
      throw Exception('Bo‘lish nisbati xato');
    }
    final f = (r['mullionFace'] as num).toDouble(), k = vertical ? 0 : 1;
    final pos = b[k] + (b[k + 2] - b[k]) * ratio;
    final strip = List<double>.from(b);
    strip[k] = pos - .001;
    strip[k + 2] = pos + .001;
    final linePoly = rectClip(l.inner, strip);
    if (linePoly.length < 3) throw Exception('Impost konturdan tashqarida');
    final lb = bounds(linePoly);
    l.splits.add(
      DrawingSplit(
        n,
        b,
        vertical ? V(pos, lb[1]) : V(lb[0], pos),
        vertical ? V(pos, lb[3]) : V(lb[2], pos),
      ),
    );
    final left = List<double>.from(b), right = List<double>.from(b);
    left[k + 2] = pos - f / 2;
    right[k] = pos + f / 2;
    if (left[k + 2] - left[k] < 80 || right[k + 2] - right[k] < 80) {
      throw Exception('Bo‘lim ichki o‘lchami kamida 80 mm');
    }
    final before = vertical ? 'right' : 'bottom',
        after = vertical ? 'left' : 'top';
    visit(
      Map<String, dynamic>.from(n['a']),
      left,
      depth + 1,
      {...frame}..remove(before),
      {...free}..remove(before),
    );
    visit(
      Map<String, dynamic>.from(n['b']),
      right,
      depth + 1,
      {...frame}..remove(after),
      {...free}..remove(after),
    );
  }

  const all = {'left', 'top', 'right', 'bottom'};
  visit(
    Map<String, dynamic>.from(d['root']),
    root ?? bounds(l.inner),
    0,
    all,
    all,
  );
  return l;
}

DrawingLayout layoutInfill(DrawingCell cell, DMap r) {
  final out = DrawingLayout();
  out.outer = cell.polygon;
  out.inner = cell.node['opening'] != 'fixed'
      ? inset(cell.polygon, (r['sashFace'] as num).toDouble())
      : cell.polygon;
  if (out.inner.length < 3) throw Exception('Qanot ichida joy yetmaydi');
  final root = Map<String, dynamic>.from(
    cell.node['infill'] ??
        {'id': 'fill-${cell.node['id']}', 'fill': cell.node['fill'] ?? 'glass'},
  );
  var count = 0;
  void visit(DMap n, List<double> box, int depth) {
    if (++count > 63 || depth > 8) {
      throw Exception('Qanot ichida ko‘pi bilan 32 to‘ldirma');
    }
    final poly = rectClip(out.inner, box);
    if (poly.length < 3 || polygonArea(poly) < 2500) {
      throw Exception('Ichki to‘ldirma juda kichik');
    }
    if (n['axis'] == null) {
      out.cells.add(DrawingCell(n, box, poly));
      return;
    }
    final k = n['axis'] == 'v' ? 0 : 1, ratio = (n['ratio'] as num).toDouble();
    if (!ratio.isFinite || ratio <= 0 || ratio >= 1) {
      throw Exception('Ichki bo‘lish nisbati xato');
    }
    final pos = box[k] + (box[k + 2] - box[k]) * ratio,
        f = (r['mullionFace'] as num).toDouble();
    final strip = List<double>.from(box);
    strip[k] = pos - .001;
    strip[k + 2] = pos + .001;
    final line = rectClip(out.inner, strip);
    if (line.length < 3) {
      throw Exception('Ichki ajratgich konturdan tashqarida');
    }
    final b = bounds(line);
    out.splits.add(
      DrawingSplit(
        n,
        box,
        k == 0 ? V(pos, b[1]) : V(b[0], pos),
        k == 0 ? V(pos, b[3]) : V(b[2], pos),
      ),
    );
    final a = List<double>.from(box), z = List<double>.from(box);
    a[k + 2] = pos - f / 2;
    z[k] = pos + f / 2;
    if (a[k + 2] - a[k] < 50 || z[k + 2] - z[k] < 50) {
      throw Exception('Ichki bo‘lim kamida 50 mm');
    }
    visit(Map<String, dynamic>.from(n['a']), a, depth + 1);
    visit(Map<String, dynamic>.from(n['b']), z, depth + 1);
  }

  visit(root, bounds(out.inner), 0);
  return out;
}

class DecorativeBar {
  final V a, b;
  DecorativeBar(this.a, this.b);
}

List<DecorativeBar> decorativeBars(
  List<V> glass,
  DMap node,
  GlazingSpec glazing,
) {
  if (!glazing.doubleGlazed || node['shpros'] != true) return [];
  final poly = inset(glass, glazing.insetMm + 5);
  if (poly.length < 3) return [];
  final box = bounds(poly), result = <DecorativeBar>[];
  final cols = (node['shprosV'] as num? ?? 1).toInt().clamp(0, 8),
      rows = (node['shprosH'] as num? ?? 3).toInt().clamp(0, 8);
  for (final vertical in [true, false]) {
    final axis = vertical ? 0 : 1, count = vertical ? cols : rows;
    for (var j = 1; j <= count; j++) {
      final at = box[axis] + (box[axis + 2] - box[axis]) * j / (count + 1),
          hits = <V>[];
      for (var k = 0; k < poly.length; k++) {
        final a = poly[k],
            b = poly[(k + 1) % poly.length],
            av = vertical ? a.x : a.y,
            bv = vertical ? b.x : b.y;
        if ((bv - av).abs() < 1e-7) continue;
        final t = (at - av) / (bv - av);
        if (t >= 0 && t <= 1) hits.add(a + (b - a) * t);
      }
      if (hits.length < 2) continue;
      hits.sort(
        (a, b) => (vertical ? a.y : a.x).compareTo(vertical ? b.y : b.x),
      );
      if ((hits.last - hits.first).length > 1) {
        result.add(DecorativeBar(hits.first, hits.last));
      }
    }
  }
  return result;
}

List<V> decorativeJoints(List<DecorativeBar> bars) {
  final result = <V>[];
  for (final a in bars.where((b) => (b.a.x - b.b.x).abs() < .01)) {
    for (final b in bars.where((b) => (b.a.y - b.b.y).abs() < .01)) {
      final p = V(a.a.x, b.a.y);
      if (p.y > math.min(a.a.y, a.b.y) &&
          p.y < math.max(a.a.y, a.b.y) &&
          p.x > math.min(b.a.x, b.b.x) &&
          p.x < math.max(b.a.x, b.b.x)) {
        result.add(p);
      }
    }
  }
  return result;
}

void validateRecipe(DMap r) {
  for (final k in recipeLabels.keys) {
    final v = r[k] ?? recipeFallbacks[k];
    if (v is! num || !v.isFinite || v < 0 || v > 1e7) {
      throw Exception('${recipeLabels[k]} noto‘g‘ri');
    }
  }
  if (!const {'single', 'double'}.contains(r['glazingType'] ?? 'single') ||
      !const {
        'plainHollow',
        'chambered',
      }.contains(r['sectionStyle'] ?? 'chambered')) {
    throw Exception('Profil yoki shisha turi xato');
  }
  if (!const {'net', 'purchase'}.contains(r['pricingMode'] ?? 'net') ||
      ((r['wastePct'] ?? 7) as num) > 60) {
    throw Exception('Narx usuli yoki chiqindi foizi (0–60%) xato');
  }
  if (r['finish'] != null && !finishNames.containsKey(r['finish'])) {
    throw Exception('Profil rangi noma’lum');
  }
  for (final v in (r['colorPct'] as Map? ?? {}).values) {
    if (v is! num || !v.isFinite || v < 0 || v > 300) {
      throw Exception('Rang ustamasi 0–300% bo‘lsin');
    }
  }
  if ((r['beadFaceMm'] ?? 18) < 5 ||
      (r['beadFaceMm'] ?? 18) > 40 ||
      (r['beadDepthMm'] ?? 16) < 5 ||
      (r['beadDepthMm'] ?? 16) > 40) {
    throw Exception('Shtapik o‘lchami 5–40 mm bo‘lsin');
  }
  final glazing = GlazingSpec(r);
  if (glazing.paneMm < 2 ||
      glazing.paneMm > 20 ||
      glazing.gapMm < 4 ||
      glazing.gapMm > 30 ||
      glazing.insetMm < 2 ||
      glazing.insetMm > 30 ||
      (r['desiccantGPerM'] ?? 20) > 200) {
    throw Exception('Shishapaket o‘lchamlarini tekshiring');
  }
  if ((r['profileWallMm'] ?? 1.8) < .5 ||
      (r['profileWallMm'] ?? 1.8) > 5 ||
      (r['profileChambers'] ?? 2) < 1 ||
      (r['profileChambers'] ?? 2) > 4 ||
      (r['profileChambers'] ?? 2) % 1 != 0 ||
      r['frameFace'] < 5 ||
      r['sashFace'] < 5 ||
      r['mullionFace'] < 5 ||
      r['stockMm'] < 500 ||
      r['stockMm'] > 20000 ||
      r['kerfMm'] > 20 ||
      (r['glassRebateMm'] ?? 0) > 40 ||
      r['anchorSpacing'] < 50 ||
      r['foamCoverage'] <= 0 ||
      r['siliconeCoverage'] <= 0 ||
      r['sheetW'] < 100 ||
      r['sheetH'] < 100 ||
      r['panelSheetW'] < 100 ||
      r['panelSheetH'] < 100 ||
      r['lambrisStripMm'] <= 0 ||
      r['markupPct'] > 500 ||
      r['reusableMm'] > r['stockMm']) {
    throw Exception('Texnik me’yorlarni tekshiring');
  }
  for (final v in (r['prices'] as Map).values) {
    if (v is! num || !v.isFinite || v < 0 || v > 1e10) {
      throw Exception('Narx manfiy yoki cheksiz bo‘lmasin');
    }
  }
}

DMap packBars(List<double> pieces, double stock, double kerf, double reusable) {
  final bars = <DMap>[];
  final sorted = pieces.map((e) => e.ceilToDouble()).toList()
    ..sort((a, b) => b.compareTo(a));
  if (stock < 100 ||
      kerf < 0 ||
      kerf > 20 ||
      reusable < 0 ||
      sorted.length > 10000) {
    throw Exception('Raskroy parametrlari xato');
  }
  for (final len in sorted) {
    if (!len.isFinite || len <= 0 || len + kerf > stock) {
      throw Exception(
        '${len.round()} mm detal ${stock.round()} mm tayoqqa sig‘maydi; egri detal yoki tayoq uzunligini tekshiring',
      );
    }
    DMap? chosen;
    for (final b in bars) {
      if (b['remaining'] + 1e-7 >= len + kerf &&
          (chosen == null || b['remaining'] < chosen['remaining'])) {
        chosen = b;
      }
    }
    chosen ??= {'pieces': <double>[], 'remaining': stock};
    if (!bars.contains(chosen)) bars.add(chosen);
    (chosen['pieces'] as List).add(len);
    chosen['remaining'] -= len + kerf;
  }
  final net = sorted.fold<double>(0, (s, v) => s + v),
      saw = sorted.length * kerf;
  final remain = bars.fold<double>(0, (s, b) => s + (b['remaining'] as num));
  final keep = bars
      .where((b) => b['remaining'] >= reusable)
      .fold<double>(0, (s, b) => s + (b['remaining'] as num));
  return {
    'bars': bars,
    'stockMm': stock,
    'netMm': net,
    'purchasedMm': bars.length * stock,
    'sawMm': saw,
    'offcutMm': remain,
    'reusableMm': keep,
    'scrapMm': remain - keep,
    'optimal': false,
  };
}

// Conservative shelf packing of bounding rectangles. Rotation allowed; no nesting of shaped glass.
DMap packSheets(List<DMap> parts, double sw, double sh, double gap) {
  final sheets = <DMap>[];
  double net = 0;
  final sorted = parts.toList()
    ..sort(
      (a, b) => ((b['w'] as num) * (b['h'] as num)).compareTo(
        (a['w'] as num) * (a['h'] as num),
      ),
    );
  for (final p in sorted) {
    final w = (p['w'] as num).toDouble(), h = (p['h'] as num).toDouble();
    net += (p['area'] as num);
    if (!((w <= sw && h <= sh) || (h <= sw && w <= sh))) {
      throw Exception(
        'To‘ldirma ${w.ceil()}×${h.ceil()} mm list ${sw.round()}×${sh.round()} mm ga sig‘maydi',
      );
    }
    var placed = false;
    for (final sheet in sheets) {
      for (final rotate in [false, true]) {
        final a = rotate ? h : w, b = rotate ? w : h;
        for (final row in sheet['rows'] as List) {
          if (b <= row['height'] && row['x'] + a <= sw) {
            (row['parts'] as List).add({'w': a, 'h': b, 'id': p['id']});
            row['x'] += a + gap;
            placed = true;
            break;
          }
        }
        if (!placed && a <= sw && sheet['y'] + b <= sh) {
          (sheet['rows'] as List).add({
            'height': b,
            'x': a + gap,
            'parts': [
              {'w': a, 'h': b, 'id': p['id']},
            ],
          });
          sheet['y'] += b + gap;
          placed = true;
        }
        if (placed) break;
      }
      if (placed) break;
    }
    if (!placed) {
      final rotate = w > sw || h > sh;
      final a = rotate ? h : w, b = rotate ? w : h;
      sheets.add({
        'y': b + gap,
        'rows': [
          {
            'height': b,
            'x': a + gap,
            'parts': [
              {'w': a, 'h': b, 'id': p['id']},
            ],
          },
        ],
      });
    }
  }
  final bought = sheets.length * sw * sh;
  return {
    'sheets': sheets,
    'sheetW': sw,
    'sheetH': sh,
    'netM2': net / 1e6,
    'purchaseM2': bought / 1e6,
    'offcutM2': math.max(0, bought - net) / 1e6,
    'optimal': false,
  };
}

DMap calculateDrawing(DMap i, DMap profile) {
  final d = Map<String, dynamic>.from(jsonDecode(jsonEncode(i['drawing']))),
      r = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(i['recipe'] ?? recipeFor(profile))),
      );
  validateRecipe(r);
  final qty = i['quantity'];
  final w = d['widthMm'], h = d['heightMm'];
  if (qty is! int ||
      qty < 1 ||
      qty > 100 ||
      w is! num ||
      h is! num ||
      !w.isFinite ||
      !h.isFinite ||
      w < 300 ||
      h < 300 ||
      w > 6000 ||
      h > 6000) {
    throw Exception('O‘lcham 300–6000 mm, soni 1–100');
  }
  final glazing = GlazingSpec(r);
  final l = layoutDrawing(d, r),
      lens = <String, List<double>>{},
      amount = <String, double>{},
      sheets = <String, List<DMap>>{};
  final specs = <DMap>[], warnings = <String>[];
  final allowance = (r['cutAllowance'] as num).toDouble();
  void add(String k, num v) {
    amount[k] = (amount[k] ?? 0) + v;
  }

  void cut(String k, double len) {
    if (len <= 0) throw Exception('Detal uzunligi xato');
    (lens[k] ??= []).add(len + allowance);
  }

  /// Cuts for one closed contour. On a curved one only the curve is bent;
  /// its straight sides (the legs and sill of an arch) are ordinary
  /// straight pieces. Returns the number of corner joints.
  int polyCuts(String k, List<V> p, {bool curved = false}) {
    if (!curved) {
      for (var j = 0; j < p.length; j++) {
        cut(k, (p[j] - p[(j + 1) % p.length]).length);
      }
      return p.length;
    }
    final total = perimeter(p);
    bool bent(int j) => (p[j] - p[(j + 1) % p.length]).length < total * .04;
    final straight = [
      for (var j = 0; j < p.length; j++)
        if (!bent(j)) (p[j] - p[(j + 1) % p.length]).length,
    ];
    if (straight.isEmpty) {
      cut(k, total + (r['bendAllowance'] as num));
      add('bending', total / 1000);
      return 0;
    }
    // Each unbroken run of short edges is one bent piece.
    final start = List.generate(p.length, (j) => j).firstWhere((j) => !bent(j));
    var run = 0.0, pieces = straight.length;
    for (var i = 1; i <= p.length; i++) {
      final j = (start + i) % p.length;
      if (i < p.length && bent(j)) {
        run += (p[j] - p[(j + 1) % p.length]).length;
      } else if (run > 0) {
        cut(k, run + (r['bendAllowance'] as num));
        add('bending', run / 1000);
        run = 0;
        pieces++;
      }
    }
    for (final len in straight) {
      cut(k, len);
    }
    return pieces;
  }

  final curved = ['circle', 'ellipse', 'arch'].contains(d['shape']);
  if (curved) {
    warnings.add(
      'Egri rama/egri qanot: kontur 128 nuqtali yaqinlashuv. Bukish blanki kontur + qo‘shimcha; sex texnologi radius, tutashuv va bukilishni tasdiqlasin.',
    );
  }
  if (d['shape'] != 'rect') {
    warnings.add(
      'Shaklli shisha/panel uchun listning to‘rtburchak gabariti band qilinadi; ichki qoldiqlar qayta joylashtirilmaydi.',
    );
  }
  add('corner', polyCuts('frame', l.outer, curved: curved));
  // One connector per joined corner; mark the corner on one of the two
  // constructions only.
  for (final side in cornerJoins(d)) {
    // As long as that side of the frame (shorter on a stepped frame).
    final x = side == 'left' ? 0.0 : (d['widthMm'] as num).toDouble();
    var run = 0.0;
    for (var j = 0; j < l.outer.length; j++) {
      final p = l.outer[j], q = l.outer[(j + 1) % l.outer.length];
      if ((p.x - x).abs() < .5 && (q.x - x).abs() < .5) run += (q - p).length;
    }
    cut('cornerProfile', run > 0 ? run : (d['heightMm'] as num).toDouble());
  }
  for (final s in l.splits) {
    cut('mullion', (s.b - s.a).length);
    add('mullionJoint', 2);
  }
  var open = 0, doors = 0;
  double glassPerim = 0, glassArea = 0, panelArea = 0, sashPerim = 0;
  for (final cell in l.cells) {
    final n = cell.node, o = n['opening'] ?? 'fixed';
    if (!openingNames.containsKey(o)) throw Exception('Ochilish turi xato');
    final active = o != 'fixed',
        door = o.toString().startsWith('door') || o == 'passive',
        slide = o.toString().startsWith('slide');
    var glassPoly = cell.polygon;
    final box = bounds(cell.polygon);
    if (active) {
      open++;
      if (door) doors++;
      final isShaped = cell.polygon.length != 4 ||
          cell.polygon.any(
            (v) => (v.x - box[0]).abs() > .01 && (v.x - box[2]).abs() > .01,
          );
      add('corner', polyCuts('sash', cell.polygon, curved: curved && isShaped));
      sashPerim += perimeter(cell.polygon) / 1000;
      glassPoly = inset(cell.polygon, (r['sashFace'] as num).toDouble());
      final locks = n['locks'] ?? 1;
      if (locks is! num ||
          locks < 0 ||
          locks > 10 ||
          locks != locks.roundToDouble()) {
        throw Exception('Qulf soni 0–10');
      }
      if (door) {
        add('doorHinge', r['doorHinges']);
        if (o == 'passive') {
          add('passiveBolt', 2);
        } else {
          add('doorHandle', 1);
          add('doorLock', locks);
          add('cylinder', locks);
        }
        if (n['closer'] == true) add('closer', 1);
        if (n['threshold'] != false) cut('threshold', box[2] - box[0]);
      } else if (slide) {
        add('roller', 2);
        add('slideLock', locks);
        cut('rail', box[2] - box[0]);
      } else {
        add('hinge', r['windowHinges']);
        add('handle', 1);
        add('windowLock', locks);
        if (o == 'tiltTurn') add('tiltKit', 1);
      }
      if (n['mesh'] == true) {
        final a = polygonArea(cell.polygon) / 1e6;
        add('mesh', a);
        add('meshRubber', perimeter(cell.polygon) / 1000);
        add('meshCorner', 4);
        for (final len in [
          box[2] - box[0],
          box[2] - box[0],
          box[3] - box[1],
          box[3] - box[1],
        ]) {
          cut('meshFrame', len);
        }
      }
    }
    final infill = layoutInfill(cell, r);
    for (final split in infill.splits) {
      cut('sashMullion', (split.b - split.a).length);
      add('mullionJoint', 2);
    }
    for (final filling in infill.cells) {
      glassPoly = glassOutline(filling.polygon, r);
      if (glassPoly.length < 3 || polygonArea(glassPoly) < 2500) {
        throw Exception('${n['id']}: shisha/panel uchun joy yetmaydi');
      }
      final gb = bounds(glassPoly),
          gp = perimeter(glassPoly) / 1000,
          ga = polygonArea(glassPoly) / 1e6;
      final fill = (filling.node['fill'] ?? 'glass') as String;
      if (!['glass', 'panel', 'lambris', 'empty'].contains(fill)) {
        throw Exception('To‘ldirma turi xato');
      }
      if (fill != 'empty') {
        glassPerim += gp;
        polyCuts('bead', glassPoly, curved: curved && glassPoly.length > 6);
        if (fill == 'glass') {
          glassArea += ga * glazing.panes;
          final bars = decorativeBars(glassPoly, n, glazing);
          if (bars.isNotEmpty && glazing.gapMm < 8) {
            throw Exception('Shpros uchun shisha oralig‘i kamida 8 mm bo‘lsin');
          }
          if (bars.isNotEmpty) {
            add(
              'shpros',
              bars.fold<double>(0, (sum, b) => sum + (b.b - b.a).length / 1000),
            );
            final joints = decorativeJoints(bars);
            add('shprosJoint', joints.length);
            if (n['rosettes'] == true) add('shprosRosette', joints.length);
          }
          if (glazing.doubleGlazed) {
            final spacerPoly = inset(glassPoly, glazing.insetMm);
            if (spacerPoly.length < 3) {
              throw Exception('Ajratgich uchun joy yetmaydi');
            }
            final spacerM = perimeter(spacerPoly) / 1000;
            add('spacer', spacerM);
            add(
              'spacerCorner',
              curved && glassPoly.length > 6 ? 0 : spacerPoly.length,
            );
            add('butyl', spacerM * 2);
            add('iguSeal', gp);
            add(
              'desiccant',
              spacerM * (r['desiccantGPerM'] as num? ?? 20) / 1000,
            );
          }
        } else {
          panelArea += ga;
        }
        for (var pane = 0;
            pane < (fill == 'glass' ? glazing.panes : 1);
            pane++) {
          (sheets[fill] ??= []).add({
            'w': gb[2] - gb[0],
            'h': gb[3] - gb[1],
            'area': ga * 1e6,
            'id': '${filling.node['id']}-$pane',
          });
        }
      }
      specs.add({
        'id': filling.node['id'],
        'opening': openingNames[o],
        'outward': n['outward'] == true,
        'fill': fill,
        if (fill == 'glass') 'panes': glazing.panes,
        if (fill == 'glass') 'packageThicknessMm': glazing.totalMm,
        'widthMm': gb[2] - gb[0],
        'heightMm': gb[3] - gb[1],
        'areaM2': ga,
        'perimeterM': gp,
        'polygon': [
          for (final v in glassPoly) [v.x, v.y],
        ],
        if (fill == 'lambris')
          'lambrisStrips':
              ((gb[2] - gb[0]) / (r['lambrisStripMm'] as num)).ceil(),
      });
    }
  }
  final reserve = 1 + (r['gasketReservePct'] as num) / 100;
  add('uGasket', glassPerim * (r['uLoops'] as num) * reserve);
  add('sealInner', sashPerim * (r['innerLoops'] as num) * reserve);
  add('sealOuter', sashPerim * (r['outerLoops'] as num) * reserve);
  final profileM =
      lens.values.expand((x) => x).fold<double>(0, (s, v) => s + v) / 1000;
  add('screw', (profileM * (r['screwPerM'] as num)).ceil());
  add('anchor', (perimeter(l.outer) / (r['anchorSpacing'] as num)).ceil());
  add('foam', (perimeter(l.outer) / 1000 / (r['foamCoverage'] as num)).ceil());
  add('silicone', (glassPerim / (r['siliconeCoverage'] as num)).ceil());
  final area = polygonArea(l.outer) / 1e6;
  add('labor', area);
  final cuts = <String, dynamic>{}, sheetPlans = <String, dynamic>{};
  final lines = <DMap>[];
  final prices = Map<String, dynamic>.from(r['prices']);
  final billNet = (r['pricingMode'] ?? 'net') == 'net',
      waste = 1 + ((r['wastePct'] ?? 7) as num) / 100,
      colour = ((r['colorPct'] as Map?)?[r['finish']] ?? 0) as num;
  if (billNet) {
    warnings.add(
      'Narx: profil va shisha sof sarfi + ${((waste - 1) * 100).toStringAsFixed(0)}% chiqindi bo‘yicha. Xarid uchun butun tayoq/list soni alohida ko‘rsatilgan.',
    );
  }
  // [stock] lines come in whole bars or sheets: with net billing the customer
  // pays for what the construction uses, never more than the purchase.
  void line(
    String key,
    String unit,
    double net,
    double purchase, {
    String? title,
    bool stock = false,
  }) {
    var price = (prices[key] ?? 0) as num;
    if (colour > 0 && colouredMaterials.contains(key)) {
      price = price * (1 + colour / 100);
    }
    final charged =
        stock && billNet ? math.min(purchase, net * waste) : purchase;
    if (price == 0 && purchase > 0) {
      warnings.add(
        '${title ?? materialNames[key] ?? key}: narx 0 — narx kiriting',
      );
    }
    lines.add({
      'name': title ?? materialNames[key] ?? key,
      'key': key,
      'unit': unit,
      'net': net,
      'quantity': purchase,
      'charged': charged,
      'price': price,
      'cost': (charged * price).round(),
    });
  }

  for (final e in lens.entries) {
    final override = Map<String, dynamic>.from(
      (r['stockOverrides'] as Map?)?[e.key] ?? {},
    );
    final stock = (override['stockMm'] ?? r['stockMm']) as num;
    final plan = packBars(
      [for (var q = 0; q < qty; q++) ...e.value],
      stock.toDouble(),
      (r['kerfMm'] as num).toDouble(),
      (r['reusableMm'] as num).toDouble(),
    );
    cuts[e.key] = plan;
    line(
      e.key,
      'm',
      plan['netMm'] / 1000,
      plan['purchasedMm'] / 1000,
      stock: true,
    );
  }
  for (final e in sheets.entries) {
    if (e.key == 'lambris') {
      final strips = <double>[];
      for (final piece in e.value) {
        final count =
            ((piece['w'] as num) / (r['lambrisStripMm'] as num)).ceil();
        for (var copy = 0; copy < qty; copy++) {
          strips.addAll(
            List<double>.filled(count, (piece['h'] as num).toDouble()),
          );
        }
      }
      final plan = packBars(
        strips,
        (r['lambrisStockMm'] as num).toDouble(),
        (r['kerfMm'] as num).toDouble(),
        (r['reusableMm'] as num).toDouble(),
      );
      cuts[e.key] = plan;
      final net =
          e.value.fold<double>(0, (a, b) => a + (b['area'] as num)) * qty / 1e6;
      line(
        e.key,
        'm²',
        net,
        plan['purchasedMm'] * (r['lambrisStripMm'] as num) / 1e6,
        stock: true,
      );
      continue;
    }
    final isGlass = e.key == 'glass';
    final plan = packSheets(
      [for (var q = 0; q < qty; q++) ...e.value],
      (r[isGlass ? 'sheetW' : 'panelSheetW'] as num).toDouble(),
      (r[isGlass ? 'sheetH' : 'panelSheetH'] as num).toDouble(),
      (r['sheetGap'] as num).toDouble(),
    );
    sheetPlans[e.key] = plan;
    line(e.key, 'm²', plan['netM2'], plan['purchaseM2'], stock: true);
  }
  for (final e in amount.entries) {
    line(
      e.key,
      areaMaterials.contains(e.key)
          ? 'm²'
          : e.key == 'desiccant'
              ? 'kg'
              : meterMaterials.contains(e.key)
                  ? 'm'
                  : 'dona',
      e.value * qty,
      e.value * qty,
    );
  }
  final bases = <String, double>{
    'frameM': perimeter(l.outer) / 1000,
    'sashM': sashPerim,
    'mullionM': l.splits.fold(0, (s, v) => s + (v.b - v.a).length / 1000),
    'glassPerimeterM': glassPerim,
    'glassM2': glassArea,
    'panelM2': panelArea,
    'areaM2': area,
    'opening': open.toDouble(),
    'door': doors.toDouble(),
    'piece': 1,
  };
  final custom = r['customMaterials'] as List? ?? [];
  if (custom.length > 100) {
    throw Exception('Qo‘shimcha materiallar ko‘pi bilan 100 ta');
  }
  for (final raw in custom) {
    final m = Map<String, dynamic>.from(raw);
    final rate = m['rate'], price = m['price'];
    if (rate is! num ||
        price is! num ||
        !rate.isFinite ||
        !price.isFinite ||
        rate < 0 ||
        price < 0 ||
        !bases.containsKey(m['basis'])) {
      throw Exception('Qo‘shimcha material formulasi xato');
    }
    final amount = bases[m['basis']]! * rate * qty;
    prices['extra-${lines.length}'] = price;
    line(
      'extra-${lines.length}',
      m['unit'] ?? 'dona',
      amount,
      amount,
      title: m['name'] ?? 'Qo‘shimcha',
    );
  }
  final cost = lines.fold<int>(0, (s, v) => s + (v['cost'] as int));
  final total = (cost * (1 + (r['markupPct'] as num) / 100)).round();
  warnings.add(
    'Me’yorlar sozlanadigan sex retsepti; zavodning tasdiqlangan kesish formulasi emas. Raskroy har bir smeta pozitsiyasi bo‘yicha; global optimal kafolatlanmaydi.',
  );
  return {
    ...i,
    'template': 'drawing',
    'widthMm': w,
    'heightMm': h,
    'drawing': d,
    'recipe': r,
    'profileName': profile['name'],
    'brand': profile['brand'],
    'material': profile['material'],
    'demo': true,
    'parts': lines,
    'cost': cost,
    'costForAll': true,
    'unitPrice': total / qty,
    'total': total,
    'areaM2': area,
    'specs': specs,
    'cuts': cuts,
    'sheetPlans': sheetPlans,
    'openingCount': open,
    'doorCount': doors,
    'priceDate': r['priceDate'],
    'warning': warnings.toSet().join('\n'),
    'calculationVersion': 'drawing-v1',
  };
}

String drawingSvg(DMap drawing, DMap recipe) {
  final l = layoutDrawing(drawing, recipe),
      w = drawing['widthMm'],
      h = drawing['heightMm'];
  String polygon(
    List<V> p,
    String fill, {
    String stroke = '#8796a6',
    num width = 6,
  }) =>
      '<polygon points="${p.map((v) => '${v.x},${v.y}').join(' ')}" fill="$fill" stroke="$stroke" stroke-width="$width"/>';
  final out = StringBuffer(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-90 -60 ${w + 180} ${h + 180}">',
  );
  out.write(polygon(l.outer, '#d8dee6'));
  for (final side in cornerJoins(drawing)) {
    final x = side == 'left' ? -28 : (w as num) + 6;
    out.write(
      '<rect x="$x" y="0" width="22" height="$h" fill="#3d4650"/><text x="${x + 11}" y="-14" font-size="34" text-anchor="middle" fill="#3d4650">90°</text>',
    );
  }
  for (var j = 0; j < l.cells.length; j++) {
    final c = l.cells[j],
        open = c.node['opening'] != 'fixed',
        p = open
            ? inset(c.polygon, (recipe['sashFace'] as num).toDouble())
            : c.polygon;
    out.write(polygon(c.polygon, '#fefefa'));
    if (p.length < 3) continue;
    out.write(
      polygon(
        p,
        c.node['fill'] == 'glass'
            ? '#83d6dd'
            : c.node['fill'] == 'empty'
                ? '#eef3f7'
                : '#d4b794',
      ),
    );
    if (c.node['infill'] != null) {
      final infill = layoutInfill(c, recipe);
      for (final sub in infill.cells) {
        out.write(
          polygon(
            sub.polygon,
            sub.node['fill'] == 'glass'
                ? '#83d6dd'
                : sub.node['fill'] == 'empty'
                    ? '#eef3f7'
                    : '#d4b794',
          ),
        );
      }
      for (final split in infill.splits) {
        out.write(
          '<line x1="${split.a.x}" y1="${split.a.y}" x2="${split.b.x}" y2="${split.b.y}" stroke="#cbd5df" stroke-width="${recipe['mullionFace']}"/>',
        );
      }
    }
    for (final fill in layoutInfill(c, recipe).cells) {
      if (fill.node['fill'] != 'glass') continue;
      final poly = inset(fill.polygon, (recipe['glassGap'] as num).toDouble());
      for (final bar in decorativeBars(poly, c.node, GlazingSpec(recipe))) {
        out.write(
          '<line x1="${bar.a.x}" y1="${bar.a.y}" x2="${bar.b.x}" y2="${bar.b.y}" stroke="#b49742" stroke-width="8"/>',
        );
      }
    }
    final b = bounds(p),
        cy = (b[1] + b[3]) / 2,
        cx = (b[0] + b[2]) / 2,
        o = c.node['opening'] as String;
    for (final line in openingSymbolLines(o, b)) {
      out.write(
        '<polyline points="${line.map((v) => '${v.x},${v.y}').join(' ')}" fill="none" stroke="#206bc4" stroke-width="6"/>',
      );
    }
    final handle = handlePoint(o, b);
    if (handle != null) {
      final vertical = hingeSide(o) == 'top' || hingeSide(o) == 'bottom';
      out.write(
        '<line x1="${handle.x - (vertical ? 45 : 0)}" y1="${handle.y - (vertical ? 0 : 45)}" x2="${handle.x + (vertical ? 45 : 0)}" y2="${handle.y + (vertical ? 0 : 45)}" stroke="#33485e" stroke-width="16"/>',
      );
    }
    out.write(
      '<text x="$cx" y="${cy + 40}" text-anchor="middle" font-size="36">${j + 1}</text>',
    );
  }
  for (final s in l.splits) {
    out.write(
      '<line x1="${s.a.x}" y1="${s.a.y}" x2="${s.b.x}" y2="${s.b.y}" stroke="#cbd5df" stroke-width="${recipe['mullionFace']}"/>',
    );
  }
  out.write(
    '<text x="${w / 2}" y="${h + 80}" text-anchor="middle" font-size="44">$w x $h mm</text></svg>',
  );
  return out.toString();
}

/// A ready-made construction. [root] builds a fresh section tree each time.
class DrawingPreset {
  final String id, name;

  /// Catalog tab: 'Deraza', 'Eshik', 'Arka' or 'Boshqa'.
  final String group;
  final num widthMm, heightMm;
  final String shape;
  final num riseMm;
  final DMap Function() root;
  const DrawingPreset(
    this.id,
    this.name,
    this.group,
    this.widthMm,
    this.heightMm,
    this.root, {
    this.shape = 'rect',
    this.riseMm = 500,
  });

  /// The design at its own size, or at [width] × [height]. An arch keeps
  /// its proportions, so a semicircle stays a semicircle.
  DMap drawing({num? width, num? height}) {
    final w = width ?? widthMm, h = height ?? heightMm;
    return {
      ...newDrawing(),
      'shape': shape,
      'riseMm': shape == 'arch'
          ? math.min(h * .9, (riseMm * w / widthMm).roundToDouble())
          : riseMm,
      'widthMm': w,
      'heightMm': shape == 'circle' ? w : h,
      'root': reidTree(root(), id),
    };
  }
}

DMap _leaf(String opening, {String fill = 'glass', DMap? infill}) => {
      ...newLeaf('n'),
      'opening': opening,
      'fill': fill,
      if (infill != null) 'infill': infill,
    };
DMap _split(String axis, num ratio, DMap a, DMap b) => {
      'id': 's',
      'axis': axis,
      'ratio': ratio,
      'a': a,
      'b': b,
    };
DMap _row(List<DMap> cells) => cells.length == 1
    ? cells.first
    : _split('v', 1 / cells.length, cells.first, _row(cells.sublist(1)));

/// Columns (or, with [axis] 'h', rows) of the given relative sizes.
DMap _sized(List<(num, DMap)> cells, [String axis = 'v']) {
  if (cells.length == 1) return cells.first.$2;
  final total = cells.fold<num>(0, (s, c) => s + c.$1);
  return _split(
    axis,
    cells.first.$1 / total,
    cells.first.$2,
    _sized(cells.sublist(1), axis),
  );
}

DMap _rows(List<(num, DMap)> cells) => _sized(cells, 'h');
DMap _fixed() => _leaf('fixed');
DMap _panel() => _leaf('fixed', fill: 'panel');
DMap _glassOverPanel(num glassShare) => _split(
      'h',
      glassShare,
      {'id': 'g', 'fill': 'glass'},
      {'id': 'p', 'fill': 'panel'},
    );

/// A transom row of [count] fixed panes over [below].
DMap _transom(int count, DMap below, [num share = .24]) => _rows([
      (share, _row([for (var i = 0; i < count; i++) _fixed()])),
      (1 - share, below),
    ]);

/// Glazed row over a row of sandwich panels (balcony parapet).
DMap _parapet(int top, List<DMap> middle) => _rows([
      (.2, _row([for (var i = 0; i < top; i++) _fixed()])),
      (.55, _row(middle)),
      (.25, _row([for (var i = 0; i < middle.length; i++) _panel()])),
    ]);

DMap _door(String opening, [num glass = .6]) =>
    _leaf(opening, infill: _glassOverPanel(glass));

final drawingPresets = <DrawingPreset>[
  // Windows
  DrawingPreset('fixed', 'Yopiq oyna', 'Deraza', 1200, 1400, _fixed),
  DrawingPreset(
    'single',
    'Bir tabaqali',
    'Deraza',
    700,
    1400,
    () => _leaf('tiltTurn'),
  ),
  DrawingPreset(
    'two',
    '2 bo‘limli',
    'Deraza',
    1400,
    1400,
    () => _row([_leaf('tiltTurn'), _fixed()]),
  ),
  DrawingPreset(
    'twoOpen',
    '2 tabaqali',
    'Deraza',
    1400,
    1400,
    () => _row([_leaf('left'), _leaf('right')]),
  ),
  DrawingPreset(
    'three',
    '3 bo‘limli',
    'Deraza',
    2100,
    1400,
    () => _row([_leaf('left'), _fixed(), _leaf('right')]),
  ),
  DrawingPreset(
    'transom',
    'Fortochkali',
    'Deraza',
    1400,
    1600,
    () =>
        _split('h', .28, _leaf('bottom'), _row([_leaf('tiltTurn'), _fixed()])),
  ),
  DrawingPreset(
    'singleTransom',
    'Fortochka + tabaqa',
    'Deraza',
    800,
    1700,
    () => _transom(1, _leaf('tiltTurn'), .22),
  ),
  DrawingPreset(
    'twoTransom',
    'Fortochka + 2',
    'Deraza',
    1400,
    1700,
    () => _transom(1, _row([_leaf('tiltTurn'), _fixed()])),
  ),
  DrawingPreset(
    'threeTransom2',
    '2 fortochka + 3',
    'Deraza',
    2100,
    1700,
    () => _transom(2, _row([_leaf('left'), _fixed(), _leaf('right')])),
  ),
  DrawingPreset(
    'threeMiddle',
    '3, o‘rtasi bo‘lingan',
    'Deraza',
    2100,
    1600,
    () => _transom(
      1,
      _row([
        _fixed(),
        _rows([(.3, _leaf('bottom')), (.7, _leaf('tiltTurn'))]),
        _fixed(),
      ]),
    ),
  ),
  DrawingPreset(
    'twoLeftTransom',
    '2, chapda fortochka',
    'Deraza',
    1400,
    1500,
    () => _row([
      _rows([(.3, _leaf('bottom')), (.7, _leaf('tiltTurn'))]),
      _fixed(),
    ]),
  ),
  DrawingPreset(
    'twoRightTransom',
    '2, o‘ngda fortochka',
    'Deraza',
    1400,
    1500,
    () => _row([
      _fixed(),
      _rows([(.3, _leaf('bottom')), (.7, _leaf('tiltTurn'))]),
    ]),
  ),
  DrawingPreset(
    'threeSideTransoms',
    '3, yonlarida fortochka',
    'Deraza',
    2100,
    1500,
    () => _row([
      _rows([(.3, _fixed()), (.7, _leaf('left'))]),
      _fixed(),
      _rows([(.3, _fixed()), (.7, _leaf('right'))]),
    ]),
  ),
  DrawingPreset(
    'four',
    '4 bo‘limli',
    'Deraza',
    2600,
    1400,
    () => _row([_leaf('left'), _fixed(), _fixed(), _leaf('right')]),
  ),
  DrawingPreset(
    'five',
    '5 bo‘limli',
    'Deraza',
    3200,
    1400,
    () => _row([
      _leaf('left'),
      _fixed(),
      _leaf('tiltTurn'),
      _fixed(),
      _leaf('right'),
    ]),
  ),
  DrawingPreset(
    'fourTransom3',
    '3 fortochka + 4',
    'Deraza',
    2600,
    1700,
    () =>
        _transom(3, _row([_leaf('left'), _fixed(), _fixed(), _leaf('right')])),
  ),
  DrawingPreset(
    'fourTransom2',
    '2 fortochka + 4',
    'Deraza',
    2600,
    1700,
    () =>
        _transom(2, _row([_leaf('left'), _fixed(), _fixed(), _leaf('right')])),
  ),
  DrawingPreset(
    'fiveTransom3',
    '3 fortochka + 5',
    'Deraza',
    3200,
    1700,
    () => _transom(
      3,
      _row([
        _leaf('left'),
        _fixed(),
        _leaf('tiltTurn'),
        _fixed(),
        _leaf('right'),
      ]),
    ),
  ),
  DrawingPreset(
    'grid3x4',
    'Vitraj 3×4',
    'Deraza',
    2600,
    2200,
    () => _rows([
      (.2, _row([for (var i = 0; i < 4; i++) _fixed()])),
      (.55, _row([_leaf('left'), _fixed(), _fixed(), _leaf('right')])),
      (.25, _row([for (var i = 0; i < 4; i++) _fixed()])),
    ]),
  ),
  DrawingPreset(
    'grid3x5',
    'Vitraj 3×5',
    'Deraza',
    3200,
    2400,
    () => _rows([
      (.2, _row([for (var i = 0; i < 5; i++) _fixed()])),
      (
        .55,
        _row([
          _leaf('left'),
          _fixed(),
          _leaf('tiltTurn'),
          _fixed(),
          _leaf('right'),
        ]),
      ),
      (.25, _row([for (var i = 0; i < 5; i++) _fixed()])),
    ]),
  ),
  DrawingPreset(
    'balconyParapet4',
    'Balkon, 4 + panel',
    'Deraza',
    2600,
    2200,
    () => _parapet(3, [_leaf('left'), _fixed(), _fixed(), _leaf('right')]),
  ),
  DrawingPreset(
    'balconyParapet3',
    'Balkon, 3 + panel',
    'Deraza',
    2000,
    2200,
    () => _parapet(2, [_leaf('left'), _fixed(), _leaf('right')]),
  ),
  DrawingPreset(
    'balconyParapet5',
    'Balkon, 5 + panel',
    'Deraza',
    3200,
    2200,
    () => _parapet(3, [
      _leaf('left'),
      _fixed(),
      _leaf('tiltTurn'),
      _fixed(),
      _leaf('right'),
    ]),
  ),
  DrawingPreset(
    'vitraj',
    'Vitraj 3×3',
    'Deraza',
    2400,
    2400,
    () => _row([
      for (var c = 0; c < 3; c++)
        _split(
          'h',
          1 / 3,
          _fixed(),
          _split('h', .5, _leaf(c == 1 ? 'bottom' : 'fixed'), _fixed()),
        ),
    ]),
  ),
  DrawingPreset(
    'sliding',
    'Surilma',
    'Deraza',
    2000,
    1500,
    () => _row([_leaf('slideRight'), _leaf('slideLeft')]),
  ),
  DrawingPreset(
    'sliding3',
    'Surilma, 3 qanot',
    'Deraza',
    2700,
    1500,
    () => _row([_leaf('slideRight'), _fixed(), _leaf('slideLeft')]),
  ),
  DrawingPreset(
    'sliding4',
    'Surilma, 4 qanot',
    'Deraza',
    3400,
    1500,
    () => _row([
      _leaf('slideRight'),
      _leaf('slideLeft'),
      _leaf('slideRight'),
      _leaf('slideLeft'),
    ]),
  ),

  // Doors
  DrawingPreset(
    'door',
    'Eshik',
    'Eshik',
    900,
    2100,
    () => _door('doorLeft', .55),
  ),
  DrawingPreset(
    'doorPanel',
    'Kirish eshigi',
    'Eshik',
    900,
    2100,
    () => _leaf('doorLeft', fill: 'panel'),
  ),
  DrawingPreset(
    'doorGlass',
    'Shisha eshik',
    'Eshik',
    900,
    2100,
    () => _leaf('doorRight'),
  ),
  DrawingPreset(
    'doorTransom',
    'Eshik+fortochka',
    'Eshik',
    950,
    2550,
    () => _split('h', .18, _fixed(), _leaf('doorLeft', fill: 'lambris')),
  ),
  DrawingPreset(
    'doorTransomGlass',
    'Fortochka + eshik',
    'Eshik',
    950,
    2500,
    () => _transom(1, _door('doorLeft'), .18),
  ),
  DrawingPreset(
    'doubleDoor',
    '2 tabaqali eshik',
    'Eshik',
    1500,
    2100,
    () => _row([_door('passive', .55), _door('doorRight', .55)]),
  ),
  DrawingPreset(
    'doorNarrowWide',
    'Tor + keng',
    'Eshik',
    1300,
    2100,
    () => _sized([(.36, _leaf('passive')), (.64, _leaf('doorRight'))]),
  ),
  DrawingPreset(
    'doorWideNarrow',
    'Keng + tor',
    'Eshik',
    1300,
    2100,
    () => _sized([(.64, _leaf('doorLeft')), (.36, _leaf('passive'))]),
  ),
  DrawingPreset(
    'doorNarrowWidePanel',
    'Tor + keng, panelli',
    'Eshik',
    1300,
    2100,
    () => _sized([(.36, _door('passive')), (.64, _door('doorRight'))]),
  ),
  DrawingPreset(
    'doorTransomPair',
    'Fortochka + tor + keng',
    'Eshik',
    1300,
    2500,
    () => _transom(
      1,
      _sized([(.36, _door('passive')), (.64, _door('doorRight'))]),
      .18,
    ),
  ),
  DrawingPreset(
    'doorSidelights',
    'Yon oynali eshik',
    'Eshik',
    2200,
    2100,
    () => _sized([
      (.2, _fixed()),
      (.22, _door('passive')),
      (.38, _door('doorRight')),
      (.2, _fixed()),
    ]),
  ),
  DrawingPreset(
    'doorSidelight',
    'Bir yon oynali eshik',
    'Eshik',
    1400,
    2100,
    () => _sized([(.36, _fixed()), (.64, _door('doorRight'))]),
  ),
  DrawingPreset(
    'doorPortal',
    'Portal: fortochka + yon oynalar',
    'Eshik',
    2200,
    2600,
    () => _transom(
      3,
      _sized([
        (.2, _rows([(.7, _fixed()), (.3, _panel())])),
        (.22, _door('passive')),
        (.38, _door('doorRight')),
        (.2, _rows([(.7, _fixed()), (.3, _panel())])),
      ]),
      .18,
    ),
  ),
  DrawingPreset(
    'balcony',
    'Balkon bloki',
    'Eshik',
    2100,
    2150,
    () => _split(
      'v',
      .38,
      _leaf('doorLeft', infill: _glassOverPanel(.6)),
      _split(
        'h',
        .66,
        _row([_leaf('tiltTurn'), _fixed()]),
        _leaf('fixed', fill: 'panel'),
      ),
    ),
  ),
  DrawingPreset(
    'balconyRight',
    'Balkon bloki, o‘ngda eshik',
    'Eshik',
    2100,
    2150,
    () => _split(
      'v',
      .62,
      _split('h', .66, _row([_fixed(), _leaf('tiltTurn')]), _panel()),
      _leaf('doorRight', infill: _glassOverPanel(.6)),
    ),
  ),
  DrawingPreset(
    'slidingDoor',
    'Surilma eshik',
    'Eshik',
    2400,
    2200,
    () => _row([_leaf('slideRight'), _leaf('slideLeft')]),
  ),

  // Arches
  DrawingPreset(
    'archFixed',
    'Arka',
    'Arka',
    1200,
    1600,
    _fixed,
    shape: 'arch',
    riseMm: 600,
  ),
  DrawingPreset(
    'archTop1',
    'Arka + tabaqa',
    'Arka',
    1000,
    1800,
    () => _split('h', .28, _fixed(), _leaf('tiltTurn')),
    shape: 'arch',
    riseMm: 500,
  ),
  DrawingPreset(
    'arch',
    'Arka + 2',
    'Arka',
    1200,
    1500,
    () =>
        _split('h', .3, _leaf('fixed'), _row([_leaf('left'), _leaf('right')])),
    shape: 'arch',
    riseMm: 380,
  ),
  DrawingPreset(
    'archTop3',
    'Arka + 3',
    'Arka',
    1800,
    1900,
    () => _split(
      'h',
      .3,
      _fixed(),
      _row([_leaf('left'), _fixed(), _leaf('right')]),
    ),
    shape: 'arch',
    riseMm: 560,
  ),
  DrawingPreset(
    'archSplitTop3',
    'Bo‘lingan arka + 3',
    'Arka',
    1800,
    1900,
    () => _split(
      'h',
      .3,
      _row([_fixed(), _fixed()]),
      _row([_leaf('left'), _fixed(), _leaf('right')]),
    ),
    shape: 'arch',
    riseMm: 560,
  ),
  DrawingPreset(
    'archMiddle',
    'Arka + 3, o‘rtasi bo‘lingan',
    'Arka',
    1800,
    1900,
    () => _split(
      'h',
      .3,
      _fixed(),
      _row([
        _fixed(),
        _rows([(.3, _leaf('bottom')), (.7, _leaf('tiltTurn'))]),
        _fixed(),
      ]),
    ),
    shape: 'arch',
    riseMm: 560,
  ),
  DrawingPreset(
    'archSplitTop2',
    'Bo‘lingan arka + 2',
    'Arka',
    1400,
    1800,
    () => _split(
      'h',
      .3,
      _row([_fixed(), _fixed()]),
      _row([_leaf('tiltTurn'), _fixed()]),
    ),
    shape: 'arch',
    riseMm: 520,
  ),
  DrawingPreset(
    'archFlat2',
    'Yassi arka + 2',
    'Arka',
    1400,
    1500,
    () => _split('h', .18, _fixed(), _row([_leaf('tiltTurn'), _fixed()])),
    shape: 'arch',
    riseMm: 260,
  ),
  DrawingPreset(
    'archFlat3',
    'Yassi arka + 3',
    'Arka',
    2000,
    1600,
    () => _split(
      'h',
      .18,
      _fixed(),
      _row([_leaf('left'), _fixed(), _leaf('right')]),
    ),
    shape: 'arch',
    riseMm: 290,
  ),
  DrawingPreset(
    'archFlatSplit3',
    'Yassi bo‘lingan arka + 3',
    'Arka',
    2000,
    1600,
    () => _split(
      'h',
      .18,
      _row([_fixed(), _fixed()]),
      _row([_leaf('left'), _fixed(), _leaf('right')]),
    ),
    shape: 'arch',
    riseMm: 290,
  ),
  DrawingPreset(
    'archFlatSides',
    'Yassi arka, yonlarida fortochka',
    'Arka',
    2000,
    1700,
    () => _split(
      'h',
      .17,
      _fixed(),
      _row([
        _rows([(.3, _fixed()), (.7, _leaf('left'))]),
        _fixed(),
        _rows([(.3, _fixed()), (.7, _leaf('right'))]),
      ]),
    ),
    shape: 'arch',
    riseMm: 290,
  ),
  DrawingPreset(
    'archDoor',
    'Arkali eshik',
    'Arka',
    1000,
    2400,
    () => _split('h', .22, _fixed(), _door('doorLeft')),
    shape: 'arch',
    riseMm: 500,
  ),

  // Other shapes
  DrawingPreset(
    'circle',
    'Dumaloq',
    'Boshqa',
    900,
    900,
    _fixed,
    shape: 'circle',
  ),
  DrawingPreset('oval', 'Oval', 'Boshqa', 1200, 800, _fixed, shape: 'ellipse'),
  DrawingPreset(
    'triangle',
    'Uchburchak',
    'Boshqa',
    1500,
    900,
    _fixed,
    shape: 'triangle',
  ),
  DrawingPreset(
    'trapezoid',
    'Trapetsiya',
    'Boshqa',
    1500,
    1200,
    () => _row([_fixed(), _fixed()]),
    shape: 'trapezoid',
  ),
];

/// Catalog tabs in order, with their titles.
const presetGroups = {
  'Deraza': 'Derazalar',
  'Eshik': 'Eshiklar',
  'Arka': 'Arkalar',
  'Boshqa': 'Boshqa',
};

int _reidSerial = 0;

/// Deep copy of a section tree with fresh, unique ids (including infills).
DMap reidTree(DMap node, String prefix) {
  final copy = Map<String, dynamic>.from(jsonDecode(jsonEncode(node)));
  void visit(DMap n) {
    n['id'] =
        '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_reidSerial++}';
    for (final k in ['a', 'b', 'infill']) {
      if (n[k] is Map) visit(n[k] as DMap);
    }
  }

  visit(copy);
  return copy;
}

DMap? findNode(DMap root, String id) {
  if (root['id'] == id) return root;
  for (final k in ['a', 'b', 'infill']) {
    if (root[k] is Map) {
      final hit = findNode(root[k] as DMap, id);
      if (hit != null) return hit;
    }
  }
  return null;
}

int _segments(DMap n, String axis) => n['axis'] == axis
    ? _segments(n['a'] as DMap, axis) + _segments(n['b'] as DMap, axis)
    : 1;

/// Makes every run of same-direction sections equally wide (or tall),
/// measured between frame edges and impost centre lines.
/// With [rootId] only that subtree is changed.
/// Which sides of section [id] can be dragged: a side on an impost always,
/// every frame side on rectangles, the bottom and right frame sides on
/// arches. Keys 'left', 'right', 'top', 'bottom'; the value is the impost
/// id, or null for the frame.
Map<String, String?> sectionSides(DMap drawing, String id) {
  final path = <(DMap, String)>[];
  bool find(DMap n) {
    if (n['id'] == id) return true;
    if (n['axis'] == null) return false;
    for (final branch in const ['a', 'b']) {
      path.add((n, branch));
      if (find(n[branch] as DMap)) return true;
      path.removeLast();
    }
    return false;
  }

  if (!find(drawing['root'] as DMap)) return const {};
  final out = <String, String?>{};
  for (final (side, axis, branch) in const [
    ('right', 'v', 'a'),
    ('left', 'v', 'b'),
    ('bottom', 'h', 'a'),
    ('top', 'h', 'b'),
  ]) {
    final hit = path.reversed
        .where((e) => e.$1['axis'] == axis && e.$2 == branch)
        .firstOrNull;
    if (hit != null) {
      out[side] = hit.$1['id'] as String;
    } else if (drawing['shape'] == 'rect' ||
        ((side == 'right' || side == 'bottom') && drawing['shape'] == 'arch')) {
      out[side] = null;
    }
  }
  return out;
}

/// Section [id] with its [side] moved by [deltaMm] (positive is right or
/// down). On an impost the impost moves and the neighbour gives or takes
/// the difference. On a frame side of a rectangle only this section
/// moves: the frame steps around it and every other section stays where
/// it is (a door to the floor between windows over a wall). On an arch the
/// window grows. Returns the new drawing; throws when the result is too
/// small or too big.
DMap resizeSection(
  DMap drawing,
  DMap recipe,
  String id,
  String side,
  double deltaMm,
) {
  final d = Map<String, dynamic>.from(jsonDecode(jsonEncode(drawing)));
  final sides = sectionSides(d, id);
  if (!sides.containsKey(side)) throw Exception('Bu tomonni surib bo‘lmaydi');
  final layout = layoutDrawing(d, recipe);
  if (sides[side] == null && d['shape'] == 'rect') {
    final boxes = {
      for (final c in layout.cells) c.node['id'] as String: [...c.box],
    };
    final i = _sideIndex[side]!;
    boxes[id]![i] += deltaMm;
    _refit(d, recipe, layout, boxes);
    layoutDrawing(d, recipe);
    return d;
  }
  final k = side == 'left' || side == 'right' ? 0 : 1;
  List<double> boxOf(String splitId) =>
      layout.splits.firstWhere((s) => s.node['id'] == splitId).box;
  final impost = sides[side];
  if (impost != null) {
    final n = findNode(d['root'] as DMap, impost)!, box = boxOf(impost);
    final span = box[k + 2] - box[k];
    final at = box[k] + span * (n['ratio'] as num) + deltaMm;
    n['ratio'] = (at - box[k]) / span;
    if (n['ratio'] <= 0 || n['ratio'] >= 1) {
      throw Exception('Bo‘lim ichki o‘lchami kamida 80 mm');
    }
  } else {
    final key = k == 0 ? 'widthMm' : 'heightMm';
    final size = (d[key] as num).toDouble() + deltaMm;
    if (size < 300 || size > 6000) throw Exception('O‘lcham 300–6000 mm');
    // Every impost of this direction above (or left of) the section keeps
    // its distance from the frame.
    final axis = k == 0 ? 'v' : 'h';
    void keep(DMap n) {
      if (n['axis'] == null || findNode(n, id) == null) return;
      if (n['axis'] == axis) {
        final box = boxOf(n['id'] as String), span = box[k + 2] - box[k];
        n['ratio'] = span * (n['ratio'] as num) / (span + deltaMm);
      }
      keep(n['a'] as DMap);
      keep(n['b'] as DMap);
    }

    keep(d['root'] as DMap);
    final rounded = (size * 10).round() / 10;
    d[key] = rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
  }
  layoutDrawing(d, recipe);
  return d;
}

/// Rebuilds [d] so that every section has the clear box in [boxes] (from
/// [layout], one of them changed): the frame goes round them all, every
/// impost stays where it was and sections short of the frame are trimmed.
void _refit(
  DMap d,
  DMap recipe,
  DrawingLayout layout,
  Map<String, List<double>> boxes,
) {
  final f = (recipe['frameFace'] as num).toDouble(),
      face = (recipe['mullionFace'] as num).toDouble();
  final all = boxes.values;
  double edge(int i, double Function(double, double) pick) =>
      all.map((b) => b[i]).reduce(pick);
  final x0 = edge(0, math.min), y0 = edge(1, math.min);
  final w = edge(2, math.max) - x0 + 2 * f, h = edge(3, math.max) - y0 + 2 * f;
  if (w < 300 || h < 300 || w > 6000 || h > 6000) {
    throw Exception('O‘lcham 300–6000 mm');
  }
  num round(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toInt() : r;
  }

  final shift = [x0 - f, y0 - f];
  d['widthMm'] = round(w);
  d['heightMm'] = round(h);
  final positions = {
    for (final s in layout.splits)
      s.node['id']: s.node['axis'] == 'v' ? s.a.x : s.a.y,
  };
  void walk(DMap n, List<double> b) {
    if (n['axis'] == null) {
      final want = boxes[n['id']]!;
      final trim = <String, num>{};
      for (final MapEntry(key: side, value: i) in _sideIndex.entries) {
        final cut = (want[i] - shift[i % 2] - b[i]) * (i < 2 ? 1 : -1);
        // Within a centimetre of the frame it stays on the frame.
        if (cut > 10) trim[side] = round(cut);
      }
      if (trim.isEmpty) {
        n.remove('trim');
      } else {
        n['trim'] = trim;
      }
      return;
    }
    n.remove('trim');
    final k = n['axis'] == 'v' ? 0 : 1,
        at = positions[n['id']]! - shift[k],
        ratio = (at - b[k]) / (b[k + 2] - b[k]);
    if (!(ratio > 0 && ratio < 1)) {
      throw Exception('Bo‘lim ichki o‘lchami kamida 80 mm');
    }
    n['ratio'] = ratio;
    final a = [...b], z = [...b];
    a[k + 2] = at - face / 2;
    z[k] = at + face / 2;
    walk(n['a'] as DMap, a);
    walk(n['b'] as DMap, z);
  }

  walk(d['root'] as DMap, [f, f, w - f, h - f]);
}

/// The trim one section needs to stand in for subtree [id] (when an impost
/// is removed): the subtree's sections' outer extent.
Map<String, num> subtreeTrim(DMap drawing, DMap recipe, String id) {
  final layout = layoutDrawing(drawing, recipe),
      node = findNode(drawing['root'] as DMap, id),
      box = layout.boxes[id];
  if (node == null || box == null) return const {};
  final cells = [
    for (final c in layout.cells)
      if (findNode(node, c.node['id'] as String) != null) c,
  ];
  if (cells.isEmpty) return const {};
  final outer = bounds([
    for (final c in cells) ...[V(c.box[0], c.box[1]), V(c.box[2], c.box[3])],
  ]);
  return {
    for (final MapEntry(key: side, value: i) in _sideIndex.entries)
      if ((outer[i] - box[i]).abs() > 10)
        side: ((outer[i] - box[i]).abs() * 10).round() / 10,
  };
}

void equalizeSections(DMap drawing, DMap recipe, {String? rootId}) {
  final root = rootId == null
      ? drawing['root'] as DMap
      : findNode(drawing['root'] as DMap, rootId);
  if (root == null) return;
  final face = (recipe['mullionFace'] as num).toDouble();
  // Child boxes depend on the parent split, so settle top-down.
  for (var pass = 0; pass < 8; pass++) {
    final layout = layoutDrawing(drawing, recipe);
    final boxes = {for (final s in layout.splits) s.node['id']: s.box},
        inner = bounds(layout.inner);
    var moved = 0.0;
    void walk(
      DMap n,
      String? parentAxis,
      double start,
      double end,
      int before,
      int total,
    ) {
      final axis = n['axis'] as String?;
      if (axis == null) return;
      final box = boxes[n['id']];
      if (box == null) return;
      final k = axis == 'v' ? 0 : 1;
      if (axis != parentAxis) {
        // Gross sizes run from the outer frame edge or an impost centre line.
        final extent =
            (drawing[k == 0 ? 'widthMm' : 'heightMm'] as num).toDouble();
        start = (box[k] - inner[k]).abs() < .5 ? 0 : box[k] - face / 2;
        end = (box[k + 2] - inner[k + 2]).abs() < .5
            ? extent
            : box[k + 2] + face / 2;
        before = 0;
        total = _segments(n, axis);
      }
      final left = _segments(n['a'] as DMap, axis),
          want = start + (end - start) * (before + left) / total,
          ratio = ((want - box[k]) / (box[k + 2] - box[k])).clamp(.05, .95);
      moved = math.max(moved, (ratio - (n['ratio'] as num)).abs());
      n['ratio'] = ratio;
      walk(n['a'] as DMap, axis, start, end, before, total);
      walk(n['b'] as DMap, axis, start, end, before + left, total);
    }

    walk(root, null, 0, 0, 0, 1);
    if (moved < 1e-6) break;
  }
  layoutDrawing(drawing, recipe);
}

/// Nearest "nice" fraction for a dragged divider, or null when not close.
double? snapRatio(double ratio, double spanMm, {double toleranceMm = 25}) {
  const fractions = [1 / 2, 1 / 3, 2 / 3, 1 / 4, 3 / 4];
  double? best;
  for (final f in fractions) {
    final distance = (ratio - f).abs() * spanMm;
    if (distance <= toleranceMm &&
        (best == null || distance < (ratio - best).abs() * spanMm)) {
      best = f;
    }
  }
  return best;
}
