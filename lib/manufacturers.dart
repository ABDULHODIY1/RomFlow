import 'dart:convert';
import 'design_engine.dart';

/// The catalog that ships with the app. The same file lives in the public
/// repository, so a newer one can be fetched without an app update.
const manufacturersAsset = 'assets/manufacturers_uz.json';
final manufacturersUrl = Uri.parse(
  'https://raw.githubusercontent.com/z3wax/RomFlow/main/assets/manufacturers_uz.json',
);

/// Systems a new workshop sees in its profile list from the start; the rest
/// are one tap away in the catalog and in the price comparison.
const defaultCatalogSystems = [
  'akfa-aldox',
  'akfa-thermo65',
  'akfa-quattro60',
  'engelberg-7000',
];

const manufacturerRoles = {
  'factory': 'Profil zavodi',
  'windowFactory': 'Rom zavodi',
  'supplier': 'Yetkazib beruvchi',
};
const systemMaterials = {'aluminium': 'Alyuminiy', 'pvc': 'PVX'};

/// A price someone asked for in public: a listing, a dealer page.
class MarketPrice {
  final String what, currency, unit, source, url, seen;
  final num price;
  const MarketPrice(
    this.what,
    this.price,
    this.currency,
    this.unit,
    this.source,
    this.url,
    this.seen,
  );

  factory MarketPrice.fromJson(Map m) {
    final price = m['price'];
    if (price is! num || !price.isFinite || price <= 0) {
      throw const FormatException('Bozor narxi xato');
    }
    final currency = '${m['currency'] ?? 'UZS'}';
    if (currency != 'UZS' && currency != 'USD') {
      throw const FormatException('Valyuta UZS yoki USD bo‘lsin');
    }
    return MarketPrice(
      '${m['what'] ?? ''}',
      price,
      currency,
      '${m['unit'] ?? 'm2'}',
      '${m['source'] ?? ''}',
      '${m['url'] ?? ''}',
      '${m['seen'] ?? ''}',
    );
  }

  /// The price in so‘m at [usdRate].
  num som(num usdRate) => currency == 'USD' ? price * usdRate : price;
}

class Manufacturer {
  final String id, name, group, city, role, website, about;
  final List<String> materials;
  const Manufacturer(
    this.id,
    this.name,
    this.group,
    this.city,
    this.role,
    this.website,
    this.about,
    this.materials,
  );
}

class ProfileSystem {
  final String id, manufacturer, name, material, catalogUrl, note;
  final List<String> uses;
  final bool thermal;
  final num depthMm;
  final int? chambers;
  final Map<String, dynamic> recipe;
  final Map<String, num> usd;
  final List<MarketPrice> market;
  const ProfileSystem({
    required this.id,
    required this.manufacturer,
    required this.name,
    required this.material,
    required this.uses,
    required this.thermal,
    required this.depthMm,
    required this.chambers,
    required this.recipe,
    required this.usd,
    required this.market,
    this.catalogUrl = '',
    this.note = '',
  });

  bool get sliding => uses.contains('sliding');

  /// "65 mm • 3 kamera • termo • 2 qavat shisha".
  String get specs => [
        '${depthMm % 1 == 0 ? depthMm.toInt() : depthMm} mm',
        if (chambers != null && chambers! > 1) '$chambers kamera',
        if (material == 'aluminium') thermal ? 'termo' : 'sovuq',
        recipe['glazingType'] == 'double' ? '2 qavat shisha' : '1 qavat shisha',
        if (sliding) 'surilma',
      ].join(' • ');
}

class ManufacturerCatalog {
  final int version;
  final String date, note;
  final num referenceUsdRate;
  final Map<String, num> common;
  final List<MarketPrice> materialsMarket;
  final List<Manufacturer> manufacturers;
  final List<ProfileSystem> systems;
  const ManufacturerCatalog(
    this.version,
    this.date,
    this.note,
    this.referenceUsdRate,
    this.common,
    this.materialsMarket,
    this.manufacturers,
    this.systems,
  );

  Manufacturer maker(String id) => manufacturers.firstWhere((m) => m.id == id);
  ProfileSystem? system(String id) {
    for (final s in systems) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<ProfileSystem> systemsOf(String makerId) => [
        for (final s in systems)
          if (s.manufacturer == makerId) s,
      ];

  /// Reads and checks a catalog. Every system must give a recipe the
  /// drawing desk accepts, so a bad download can never break estimates.
  static ManufacturerCatalog parse(String text) {
    final Object? data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      throw const FormatException('Katalog fayli o‘qilmadi');
    }
    if (data is! Map || data['format'] != 'romflow-manufacturers') {
      throw const FormatException('Bu ishlab chiqaruvchilar katalogi emas');
    }
    final version = data['version'], rate = data['referenceUsdRate'];
    if (version is! int || version < 1) {
      throw const FormatException('Katalog versiyasi xato');
    }
    if (rate is! num || !rate.isFinite || rate <= 0) {
      throw const FormatException('Katalog dollar kursi xato');
    }
    Map<String, num> prices(Object? raw) {
      final out = <String, num>{};
      for (final e in (raw is Map ? raw : const {}).entries) {
        final v = e.value;
        if (!materialNames.containsKey(e.key) ||
            v is! num ||
            !v.isFinite ||
            v < 0 ||
            v > 100000) {
          throw FormatException('Katalog narxi xato: ${e.key}');
        }
        out['${e.key}'] = v;
      }
      return out;
    }

    List<Map> list(Object? raw) => raw is List
        ? [
            for (final x in raw)
              if (x is Map) x,
          ]
        : const [];
    final makers = [
      for (final m in list(data['manufacturers']))
        Manufacturer(
          '${m['id'] ?? ''}',
          '${m['name'] ?? ''}',
          '${m['group'] ?? ''}',
          '${m['city'] ?? ''}',
          '${m['role'] ?? 'factory'}',
          '${m['website'] ?? ''}',
          '${m['about'] ?? ''}',
          [for (final x in (m['materials'] as List? ?? const [])) '$x'],
        ),
    ];
    final ids = {for (final m in makers) m.id};
    if (makers.isEmpty ||
        ids.length != makers.length ||
        makers.any((m) => m.id.isEmpty || m.name.trim().isEmpty)) {
      throw const FormatException('Katalogdagi ishlab chiqaruvchilar xato');
    }
    final common = prices(data['common']);
    final systems = <ProfileSystem>[];
    for (final s in list(data['systems'])) {
      final id = '${s['id'] ?? ''}', material = '${s['material'] ?? ''}';
      final depth = s['depthMm'], chambers = s['chambers'];
      if (id.isEmpty ||
          systems.any((x) => x.id == id) ||
          !ids.contains(s['manufacturer']) ||
          '${s['name'] ?? ''}'.trim().isEmpty ||
          !systemMaterials.containsKey(material) ||
          depth is! num ||
          depth <= 0 ||
          (chambers != null && chambers is! int) ||
          s['recipe'] is! Map) {
        throw FormatException('Katalogdagi tizim xato: $id');
      }
      final system = ProfileSystem(
        id: id,
        manufacturer: '${s['manufacturer']}',
        name: '${s['name']}',
        material: material,
        uses: [
          for (final x in (s['uses'] as List? ?? const ['window'])) '$x',
        ],
        thermal: s['thermal'] == true,
        depthMm: depth,
        chambers: chambers as int?,
        recipe: Map<String, dynamic>.from(s['recipe']),
        usd: prices(s['usd']),
        market: [for (final m in list(s['market'])) MarketPrice.fromJson(m)],
        catalogUrl: '${s['catalogUrl'] ?? ''}',
        note: '${s['estimateNote'] ?? ''}',
      );
      for (final k in ['frame', 'sash', 'mullion']) {
        if ((system.usd[k] ?? 0) <= 0) {
          throw FormatException('${system.name}: $k narxi yo‘q');
        }
      }
      systems.add(system);
    }
    if (systems.isEmpty) throw const FormatException('Katalogda tizim yo‘q');
    final catalog = ManufacturerCatalog(
      version,
      '${data['date'] ?? ''}',
      '${data['note'] ?? ''}',
      rate,
      common,
      [for (final m in list(data['materialsMarket'])) MarketPrice.fromJson(m)],
      makers,
      systems,
    );
    for (final s in systems) {
      validateRecipe(recipeFor(catalog.profileFor(s, rate)));
    }
    return catalog;
  }

  /// Dollar prices for [s]: the catalog's common prices under its own.
  /// Dollar prices for [s]: the catalog's common prices under its own; sash
  /// bars and corner profiles cost what its mullion does unless it says.
  Map<String, num> usdFor(ProfileSystem s) => {
        ...common,
        ...s.usd,
        'sashMullion': s.usd['sashMullion'] ?? s.usd['mullion']!,
        'cornerProfile': s.usd['cornerProfile'] ?? s.usd['mullion']!,
      };

  /// [s] as a workshop profile, priced at [usdRate]. Its prices stay in
  /// dollars so they follow the rate; a price the workshop types itself
  /// takes over.
  Map<String, dynamic> profileFor(ProfileSystem s, num usdRate) {
    final rate = usdRate > 0 ? usdRate : referenceUsdRate;
    final usd = usdFor(s);
    final som = {for (final e in usd.entries) e.key: (e.value * rate).round()};
    final maker = this.maker(s.manufacturer);
    return {
      'id': 'mf-${s.id}',
      'catalogId': s.id,
      'name': s.name,
      'brand': maker.name,
      'manufacturer': maker.name,
      'material': s.material,
      'framePrice': som['frame'],
      'sashPrice': som['sash'],
      'mullionPrice': som['mullion'],
      'glassPrice': som['glass'] ?? 0,
      'hardwarePrice': quickHardware(som, sliding: s.sliding),
      // The quick estimate's hardware set follows the dollar prices until
      // the workshop types its own.
      'hardwareFollows': true,
      'sliding': s.sliding,
      'gasketPrice': som['uGasket'] ?? 0,
      'laborPrice': som['labor'] ?? 0,
      'wastePct': 7,
      'markupPct': 25,
      'frameFaceMm': s.recipe['frameFace'] ?? 50,
      'sashFaceMm': s.recipe['sashFace'] ?? 50,
      if (s.catalogUrl.isNotEmpty) 'catalogUrl': s.catalogUrl,
      'demo': false,
      'reference': true,
      'drawingRecipe': {
        ...s.recipe,
        'prices': som,
        'usdPrices': usd,
        'catalogUsd': usd,
        'catalogVersion': version,
        'priceDate': date,
        'priceSource':
            'Ishlab chiqaruvchilar katalogi ($date): ochiq bozor narxlariga moslangan taxminiy narx',
      },
    };
  }
}

/// One opening sash's hardware for the quick estimate: handle, lock, two
/// hinges and, unless it slides, the tilt-and-turn kit.
num quickHardware(Map prices, {bool sliding = false}) =>
    ((prices['handle'] ?? 0) as num) +
    ((prices['windowLock'] ?? 0) as num) +
    2 * ((prices['hinge'] ?? 0) as num) +
    (sliding ? 0 : (prices['tiltKit'] ?? 0) as num);

/// Recipe settings of the desk that a comparison keeps, so every system is
/// priced for the same window and the pick costs what the list showed.
const comparisonKeys = [
  'finish',
  'glazingType',
  'hardwareFinish',
  'windowHandle',
  'handleStyle',
];

/// The window every system is priced on for its "per m²" figure: two
/// sections, one opening (a sliding pair for sliding systems).
DrawingPreset referencePreset(ProfileSystem s) =>
    drawingPresets.firstWhere((p) => p.id == (s.sliding ? 'sliding' : 'two'));

/// Selling price per m² of the reference window with [profile]'s prices.
num referenceSquareMetre(ProfileSystem s, Map<String, dynamic> profile) {
  final preset = referencePreset(s);
  final result = calculateDrawing({
    'drawing': preset.drawing(),
    'recipe': recipeFor(profile),
    'quantity': 1,
  }, profile);
  return (result['total'] as num) / (preset.widthMm * preset.heightMm / 1e6);
}

class SystemQuote {
  final ProfileSystem system;
  final Map<String, dynamic> profile;
  final num? total;
  final String? error;
  const SystemQuote(this.system, this.profile, this.total, this.error);
}

/// One drawing priced with every system in the catalog, cheapest first.
/// Systems the workshop already uses are priced with its own prices; the
/// desk's [comparisonKeys] settings in [keep] apply to all, so the
/// comparison is like for like.
List<SystemQuote> compareSystems(
  ManufacturerCatalog catalog,
  List<Map<String, dynamic>> profiles,
  DMap drawing,
  int quantity, {
  Map<String, dynamic> keep = const {},
  num usdRate = 0,
}) {
  // The estimator takes at most 100 pieces at once; a larger order is
  // priced per hundred and scaled.
  final priced = quantity.clamp(1, 100);
  final out = <SystemQuote>[];
  for (final s in catalog.systems) {
    final own = profiles.where((p) => p['catalogId'] == s.id);
    final profile = own.isEmpty ? catalog.profileFor(s, usdRate) : own.first;
    final recipe = recipeFor(profile);
    for (final k in comparisonKeys) {
      if (keep[k] != null) recipe[k] = keep[k];
    }
    try {
      final r = calculateDrawing({
        'drawing': drawing,
        'recipe': recipe,
        'quantity': priced,
      }, profile);
      out.add(
        SystemQuote(
          s,
          profile,
          ((r['total'] as num) * quantity / priced).round(),
          null,
        ),
      );
    } catch (e) {
      out.add(
        SystemQuote(
          s,
          profile,
          null,
          '$e'.replaceFirst(RegExp(r'^\w*Exception: '), ''),
        ),
      );
    }
  }
  out.sort(
    (a, b) => a.total == null
        ? (b.total == null ? 0 : 1)
        : b.total == null
            ? -1
            : a.total!.compareTo(b.total!),
  );
  return out;
}
