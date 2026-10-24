import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/manufacturers.dart';

void main() {
  final catalog = ManufacturerCatalog.parse(
      File('assets/manufacturers_uz.json').readAsStringSync());

  test('the catalog covers the makers and every system prices', () {
    expect(catalog.manufacturers.length, greaterThanOrEqualTo(10));
    expect(catalog.systems.length, greaterThanOrEqualTo(14));
    expect({for (final s in catalog.systems) s.material}, {'aluminium', 'pvc'});
    for (final id in defaultCatalogSystems) {
      expect(catalog.system(id), isNotNull, reason: id);
    }
    for (final m in catalog.manufacturers) {
      expect(manufacturerRoles.containsKey(m.role), isTrue, reason: m.id);
    }
  });

  // A "from" price is the cheapest window a seller shows; the reference
  // window (two sections, one tilt-and-turn sash) may cost more, never far
  // more and never less than the cheapest.
  test('every system prices near what the market asks', () {
    const rate = 12100;
    var checked = 0;
    for (final s in catalog.systems) {
      final m2 = referenceSquareMetre(s, catalog.profileFor(s, rate));
      expect(m2, inInclusiveRange(300000, 2000000), reason: s.name);
      for (final m in s.market.where((m) => m.unit == 'm2')) {
        expect(m2 / m.som(rate), inInclusiveRange(.85, 1.35),
            reason: '${s.name}: ${m.source}');
        checked++;
      }
    }
    expect(checked, greaterThanOrEqualTo(5));
  });

  test('prices stay in dollars and follow the rate', () {
    final s = catalog.system('akfa-thermo65')!;
    final a = catalog.profileFor(s, 12000), b = catalog.profileFor(s, 13000);
    expect(a['drawingRecipe']['usdPrices']['frame'], s.usd['frame']);
    expect(b['framePrice'] / a['framePrice'], closeTo(13 / 12, .01));
    // Without a rate the catalog's own reference rate stands in.
    expect(catalog.profileFor(s, 0)['framePrice'],
        (s.usd['frame']! * catalog.referenceUsdRate).round());
  });

  test('the comparison keeps the desk’s colour and glazing', () {
    final drawing = drawingPresets.firstWhere((p) => p.id == 'two').drawing();
    num aldox(List<SystemQuote> q) =>
        q.firstWhere((x) => x.system.id == 'akfa-aldox').total!;
    final own = compareSystems(catalog, const [], drawing, 1, usdRate: 12100);
    final twoPanes = compareSystems(catalog, const [], drawing, 1,
        keep: {'glazingType': 'double'}, usdRate: 12100);
    final dark = compareSystems(catalog, const [], drawing, 1,
        keep: {'finish': 'anthracite'}, usdRate: 12100);
    expect(aldox(twoPanes), greaterThan(aldox(own)));
    expect(aldox(dark), greaterThan(aldox(own)));
    expect(own.every((q) => q.error == null), isTrue);
    // A big order is priced per hundred and scaled, never refused.
    final big = compareSystems(catalog, const [], drawing, 250, usdRate: 12100);
    expect(big.every((q) => q.error == null), isTrue);
    expect(
        aldox(big) /
            aldox(compareSystems(catalog, const [], drawing, 100,
                usdRate: 12100)),
        closeTo(2.5, .001));
  });

  test('a broken download is refused', () {
    expect(() => ManufacturerCatalog.parse('<html>'), throwsFormatException);
    expect(() => ManufacturerCatalog.parse('{"format": "other"}'),
        throwsFormatException);
    final text = File('assets/manufacturers_uz.json').readAsStringSync();
    expect(
        () => ManufacturerCatalog.parse(
            text.replaceFirst('"frame": 2.6', '"frame": -1')),
        throwsFormatException);
    expect(
        () => ManufacturerCatalog.parse(
            text.replaceFirst('"frameFace": 50', '"frameFace": 2')),
        throwsA(anything));
  });
}
