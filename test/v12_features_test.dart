import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/billing.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/installments.dart';
import 'package:romflow/price_sources.dart';
import 'package:romflow/store.dart';

void main() {
  test('price lists in workshop words, CSV or JSON, so‘m or dollars', () {
    final csv = parsePriceList('Material;Narx;Profil\n'
        'Kosa;95 000;\n'
        'Qanot;"110 000";\n'
        'Shtapik;30000;series-akfa-simple-hollow\n'
        'Noma’lum narsa;5000;\n');
    expect([for (final r in csv.rows) r.key], ['frame', 'sash', 'bead']);
    expect(csv.rows.first.price, 95000);
    expect(csv.rows.last.profile, 'series-akfa-simple-hollow');
    expect(csv.skipped.single, startsWith('Noma’lum'));
    final json = parsePriceList(
        '{"currency": "USD", "prices": {"orta": 7.5, "delfin": 4}}');
    expect([for (final r in json.rows) r.key], ['mullion', 'handle']);
    expect(json.rows.every((r) => r.usd), isTrue);
    expect(() => parsePriceList(''), throwsFormatException);
    expect(() => parsePriceList('a,b\nc,d'), throwsFormatException);
  });

  test('profile-specific rows win and dollar prices need a rate', () {
    final profiles = sampleProfiles(),
        id = 'series-akfa-simple-hollow',
        list = parsePriceList('material;narx;profil\n'
            'frame;100000;$id\n'
            'frame;90000;\n');
    final changes = priceChanges(profiles, list, {id});
    expect(changes.where((c) => c.key == 'frame').single.after, 100000);
    final usd = parsePriceList('{"currency":"USD","prices":{"frame":8}}');
    expect(() => priceChanges(profiles, usd, {id}), throwsFormatException);
    expect(
        priceChanges(profiles, usd, {id}, usdRate: 12800).single.after, 102400);
    expect(priceTemplateCsv(profiles.firstWhere((p) => p['id'] == id)),
        startsWith('material;nomi;narx;profil\nframe;'));
  });

  test('extra work adds to the total and is validated', () {
    final t = totals(
        [
          {'total': 1000000}
        ],
        50000,
        100000,
        [
          {'name': 'Podokonnik', 'qty': 2.5, 'price': 120000, 'unit': 'm'}
        ]);
    expect(t['extrasTotal'], 300000);
    expect(t['total'], 1000000 + 100000 + 300000 - 50000);
    expect(
        () => totals(
            [],
            0,
            0,
            [
              {'name': '', 'qty': 1, 'price': 1}
            ]),
        throwsException);
    expect(dollars(1280000, 12800), '≈ 100 \$');
    expect(dollars(1000, 0), '');
  });

  test('installments count payments in order and mark late ones', () {
    final q = {
      'paid': 700000,
      'schedule': {
        'paidAtStart': 400000,
        'rows': [
          {'due': '2026-01-10', 'amount': 300000},
          {'due': '2026-02-10', 'amount': 300000},
          {'due': '2026-12-10', 'amount': 300000},
        ],
      },
    };
    final rows = installmentRows(q, now: DateTime(2026, 3, 1));
    expect([
      for (final r in rows) r.$2
    ], [
      InstallmentState.paid,
      InstallmentState.late,
      InstallmentState.waiting,
    ]);
    expect(installmentRows({'paid': 0}), isEmpty);
  });

  test('every feature is open while payments are switched off', () async {
    final dir = Directory.systemTemp.createTempSync('romflow-billing-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    expect(s.activePlan.id, 'pro');
    expect(proFeatures.every(s.allows), isTrue);
    BillingConfig.paymentsEnabled = true;
    addTearDown(() => BillingConfig.paymentsEnabled = false);
    expect(s.activePlan.id, 'start');
    expect(s.allows('finance'), isFalse);
    expect(s.allows('quotes'), isTrue);
  });

  test('an arch bends only its curve; legs and sill are straight pieces', () {
    final recipe = recipeFor(sampleProfiles().first);
    final d = drawingPresets.firstWhere((p) => p.id == 'archTop3').drawing();
    final bill = calculateDrawing(
        {'drawing': d, 'recipe': recipe, 'quantity': 1},
        sampleProfiles().first);
    Map part(String k) =>
        (bill['parts'] as List).firstWhere((p) => p['key'] == k);
    // A 1800 × 1900 arch frame is longer than a 6 m bar in one piece; only
    // its curve (about 2.3 m) and the bead along it are bent.
    expect(part('bending')['net'], inInclusiveRange(4, 5));
    expect(part('corner')['net'], greaterThanOrEqualTo(4));
    for (final p in drawingPresets) {
      expect(() => layoutDrawing(p.drawing(width: 2000, height: 1800), recipe),
          returnsNormally,
          reason: p.id);
    }
  });
}
