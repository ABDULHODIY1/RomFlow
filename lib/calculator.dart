import 'dart:math';
import 'design_engine.dart';

typedef Json = Map<String, dynamic>;
const templates = <Json>[
  {'id': 'fixed', 'name': 'Yopiq rom', 'columns': 1, 'rows': 1, 'opening': 0},
  {
    'id': 'casement',
    'name': 'Bir tabaqali rom',
    'columns': 1,
    'rows': 1,
    'opening': 1,
  },
  {
    'id': 'double',
    'name': 'Ikki bo‘limli rom',
    'columns': 2,
    'rows': 1,
    'opening': 1,
  },
  {
    'id': 'triple',
    'name': 'Uch bo‘limli rom',
    'columns': 3,
    'rows': 1,
    'opening': 1,
  },
  {
    'id': 'transom',
    'name': 'Fortochkali rom',
    'columns': 2,
    'rows': 2,
    'opening': 1,
  },
  {
    'id': 'door',
    'name': 'Bir tabaqali eshik',
    'columns': 1,
    'rows': 1,
    'opening': 1,
  },
  {
    'id': 'double_door',
    'name': 'Ikki tabaqali eshik',
    'columns': 2,
    'rows': 1,
    'opening': 2,
  },
  {
    'id': 'sliding',
    'name': 'Surilma tizim',
    'columns': 2,
    'rows': 1,
    'opening': 2,
  },
];
const statuses = {
  'draft': 'Smeta',
  'accepted': 'Tasdiqlangan',
  'production': 'Ishlab chiqarishda',
  'ready': 'Tayyor',
  'installed': 'O‘rnatilgan',
  'cancelled': 'Bekor qilingan',
};
const transitions = <String, List<String>>{
  'draft': ['accepted', 'cancelled'],
  'accepted': ['production', 'cancelled'],
  'production': ['ready'],
  'ready': ['installed'],
  'installed': [],
  'cancelled': [],
};
List<Json> _baseProfiles() => [
      for (final b in [
        'AKFA',
        'Alubest',
        'Umumiy PVX',
        'Yog‘och',
        'Metall',
        'MDF'
      ])
        {
          'id': 'sample-$b',
          'name': '$b — NAMUNA',
          'brand': b,
          'material': b == 'Umumiy PVX'
              ? 'pvc'
              : b == 'Yog‘och'
                  ? 'wood'
                  : b == 'Metall'
                      ? 'steel'
                      : b == 'MDF'
                          ? 'mdf'
                          : 'aluminium',
          'framePrice': 45000,
          'sashPrice': 50000,
          'mullionPrice': 42000,
          'glassPrice': 130000,
          'hardwarePrice': 95000,
          'gasketPrice': 3500,
          'laborPrice': 50000,
          'wastePct': 7,
          'markupPct': 25,
          'frameFaceMm': 50,
          'sashFaceMm': 50,
          'demo': true,
        },
    ];

/// Officially listed system names; prices and machining values remain editable examples.
List<Json> sampleProfiles() => [
      ..._baseProfiles(),
      {
        ..._baseProfiles().first,
        'id': 'series-akfa-simple-thick',
        'brand': 'AKFA',
        'name': 'Qalin oddiy alyuminiy • sozlanadigan namuna',
        'material': 'aluminium',
        'demo': true,
        'frameFaceMm': 70,
        'sashFaceMm': 65,
        'drawingRecipe': {
          'sectionStyle': 'plainHollow',
          'profileChambers': 1,
          'profileWallMm': 2.2,
          'frameFace': 70,
          'sashFace': 65,
          'mullionFace': 70,
          'frameDepth': 60,
          'sashDepth': 65,
          'beadFaceMm': 18,
          'beadDepthMm': 16,
          'glassThickness': 4,
          'glazingType': 'single',
          'finish': 'mokri',
          'glassRebateMm': 12,
          'priceSource':
              'Qalin rom namunasi; zavod artikuli va narxlari tasdiqlanmagan.'
        }
      },
      {
        ..._baseProfiles().first,
        'id': 'series-akfa-simple-hollow',
        'brand': 'AKFA',
        'name': 'AKFA oddiy alyuminiy • ichi bo‘sh',
        'material': 'aluminium',
        'demo': true,
        'catalogUrl': 'https://akfaaluminium.com/aldox',
        'drawingRecipe': {
          'sectionStyle': 'plainHollow',
          'profileChambers': 1,
          'profileWallMm': 1.5,
          'frameDepth': 45.5,
          'sashDepth': 45.5,
          'glassThickness': 4,
          'glazingType': 'single',
          'finish': 'mokri',
          // Glass reaches under the lip, as in the workshop photos.
          'glassRebateMm': 12,
          'priceSource':
              'O‘lchamlar sozlanadigan namuna; profil turi foydalanuvchi videosidan. ALDOX umumiy montaj chuqurligi rasmiy sahifadan; artikul kesimi tasdiqlanmagan.'
        }
      },
      for (final entry in <Json>[
        {
          'id': 'series-akfa-aldox',
          'brand': 'AKFA',
          'name': 'AKFA ALDOX',
          'catalogUrl': 'https://akfagroup.com/eng/aldox'
        },
        {
          'id': 'series-akfa-thermo65',
          'brand': 'AKFA',
          'name': 'AKFA THERMO 65',
          'catalogUrl': 'https://akfagroup.com/eng/thermo-65'
        },
        {
          'id': 'series-alubest-aldox',
          'brand': 'Alubest',
          'name': 'Alubest Aldoks',
          'catalogUrl':
              'https://alubest.uz/profiles-catalogs/1-alyuminievye-profili'
        },
        {
          'id': 'series-alubest-thermo70',
          'brand': 'Alubest',
          'name': 'Alubest AluThermo-70',
          'catalogUrl':
              'https://alubest.uz/profiles-catalogs/3-termoseriya-aluthermo-70'
        },
      ])
        {
          ..._baseProfiles().first,
          ...entry,
          'name': '${entry['name']} — SOZLANADIGAN NAMUNA',
          'material': 'aluminium',
          'demo': true
        },
    ];
Json calculate(Json i, Json p) {
  if (i['drawing'] != null) return calculateDrawing(i, p);
  final w = (i['widthMm'] as num).toDouble(),
      h = (i['heightMm'] as num).toDouble(),
      qty = i['quantity'] as int;
  if (w < 300 || w > 6000 || h < 300 || h > 6000 || qty < 1 || qty > 100) {
    throw Exception('O‘lcham: 300–6000 mm; soni: 1–100');
  }
  final t = templates.firstWhere((t) => t['id'] == i['template']);
  final cols = t['columns'] as int,
      rows = t['rows'] as int,
      opening = t['opening'] as int;
  final f = (p['frameFaceMm'] as num).toDouble(),
      s = (p['sashFaceMm'] as num).toDouble();
  final iw = w - 2 * f,
      ih = h - 2 * f,
      pw = (iw - (cols - 1) * f) / cols,
      ph = (ih - (rows - 1) * f) / rows;
  if (pw <= 2 * s + 20 || ph <= 2 * s + 20) {
    throw Exception('Bo‘lim o‘lchami juda kichik');
  }
  final factor = {
        'white': 1.0,
        'anthracite': (p['anthraciteFactor'] ?? 1.2) as num,
        'oak': (p['oakFactor'] ?? 1.3) as num,
      }[i['color']]!,
      waste = 1 + (p['wastePct'] as num) / 100;
  final frame = 2 * (w + h) / 1000,
      mullion = ((cols - 1) * ih + (rows - 1) * iw) / 1000,
      sash = opening * 2 * (pw + ph) / 1000;
  final glass = ((cols * rows - opening) * pw * ph +
              opening * (pw - 2 * s) * (ph - 2 * s)) /
          1e6,
      area = w * h / 1e6,
      gasket = 2 * (pw + ph) * cols * rows / 1000;
  final raw = <List<dynamic>>[
    ['Tashqi rama', 'm', frame, (p['framePrice'] as num) * factor * waste],
    ['Tabaqa profili', 'm', sash, (p['sashPrice'] as num) * factor * waste],
    ['Impost', 'm', mullion, (p['mullionPrice'] as num) * factor * waste],
    ['Shisha / panel', 'm²', glass, p['glassPrice']],
    ['Furnitura to‘plami', 'dona', opening, p['hardwarePrice']],
    ['Zichlagich', 'm', gasket, p['gasketPrice']],
    ['Mehnat', 'm²', area, p['laborPrice']],
  ];
  final parts = <Json>[
    for (final r in raw)
      {
        'name': r[0],
        'unit': r[1],
        'quantity': ((r[2] as num) * 10000).round() / 10000,
        'price': (r[3] as num).round(),
        'cost': ((r[2] as num) * (r[3] as num)).round(),
      },
  ];
  if (i['mosquito'] == true) {
    parts.add({
      'name': 'Setka (namuna narx)',
      'unit': 'm²',
      'quantity': area,
      'price': p['meshPrice'] ?? 75000,
      'cost': (area * ((p['meshPrice'] ?? 75000) as num)).round(),
    });
  }
  final cost = parts.fold<int>(0, (s, p) => s + (p['cost'] as int)),
      unit = (cost * (1 + (p['markupPct'] as num) / 100)).round();
  return {
    ...i,
    'profileName': p['name'],
    'brand': p['brand'],
    'material': p['material'],
    'demo': p['demo'],
    'parts': parts,
    'cost': cost,
    'unitPrice': unit,
    'total': unit * qty,
    'areaM2': area,
    'warning': 'Taxminiy smeta. Kesish kartasi emas.',
  };
}

/// Work and goods sold with the windows: (name, unit, sample price).
const extraCatalog = <String, (String, String, int)>{
  'sill': ('Podokonnik', 'm', 120000),
  'ebb': ('Otliv (tashqi tunuka)', 'm', 45000),
  'slope': ('Otkos (ichki pardoz)', 'm', 60000),
  'dismantle': ('Eski romni demontaj qilish', 'dona', 50000),
  'delivery': ('Yetkazib berish', 'marta', 100000),
  'trash': ('Chiqindini olib chiqish', 'marta', 50000),
  'mesh': ('Qo‘shimcha setka', 'dona', 80000),
  'other': ('Boshqa ish / mahsulot', 'dona', 0),
};

int extraLine(Json e) => ((e['qty'] as num) * (e['price'] as num)).round();

Json totals(List<Json> items, int discount, int installation,
    [List extras = const []]) {
  final sub = items.fold<int>(0, (s, i) => s + (i['total'] as num).toInt());
  var extra = 0;
  for (final e in extras) {
    final qty = e['qty'], price = e['price'];
    if ('${e['name'] ?? ''}'.trim().isEmpty ||
        qty is! num ||
        price is! num ||
        !qty.isFinite ||
        !price.isFinite ||
        qty <= 0 ||
        qty > 10000 ||
        price < 0 ||
        price > 1e9) {
      throw Exception('Qo‘shimcha ish: nomi, miqdori va narxi to‘g‘ri bo‘lsin');
    }
    extra += extraLine(Map<String, dynamic>.from(e));
  }
  if (discount < 0 ||
      installation < 0 ||
      discount > sub + installation + extra) {
    throw Exception('Chegirma yoki montaj summasi noto‘g‘ri');
  }
  return {
    'subtotal': sub,
    'discount': discount,
    'installation': installation,
    'extras': [for (final e in extras) Map<String, dynamic>.from(e)],
    'extrasTotal': extra,
    'total': sub + installation + extra - discount,
    'currency': 'UZS',
  };
}

String money(dynamic value) {
  final s = ((value ?? 0) as num).round().toString();
  return '${s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} so‘m';
}

/// "≈ 271 $" for a so‘m amount at [rate] so‘m per dollar; empty without a rate.
String dollars(num amount, num rate) => rate <= 0
    ? ''
    : '≈ ${(amount / rate).toStringAsFixed(amount / rate < 100 ? 1 : 0)} \$';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';

Json optimizeCuts(int stockMm, num kerfMm, List<Json> pieces) {
  if (stockMm < 500 ||
      stockMm > 20000 ||
      kerfMm < 0 ||
      kerfMm > 20 ||
      pieces.isEmpty) {
    throw Exception('Profil 500–20000 mm, arra izi 0–20 mm bo‘lsin');
  }
  final lengths = <int>[];
  for (final p in pieces) {
    final length = p['lengthMm'] as int, count = p['quantity'] as int;
    if (length <= 0 || count <= 0 || count > 100 || length + kerfMm > stockMm) {
      throw Exception('Detal yoki soni noto‘g‘ri');
    }
    lengths.addAll(List.filled(count, length));
  }
  if (lengths.length > 2000) throw Exception('Ko‘pi bilan 2000 detal');
  lengths.sort((a, b) => b.compareTo(a));
  final bars = <Json>[];
  for (final length in lengths) {
    Json? selected;
    for (final bar in bars) {
      if (bar['remainingMm'] >= length + kerfMm) {
        selected = bar;
        break;
      }
    }
    selected ??= {'pieces': <int>[], 'remainingMm': stockMm};
    if (!bars.contains(selected)) bars.add(selected);
    (selected['pieces'] as List).add(length);
    selected['remainingMm'] -= length + kerfMm;
  }
  return {'bars': bars, 'stockMm': stockMm, 'kerfMm': kerfMm, 'optimal': false};
}
