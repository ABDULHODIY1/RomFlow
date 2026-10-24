import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/exchange_rate.dart';
import 'package:romflow/price_sources.dart';
import 'package:romflow/store.dart';

void main() {
  fallbackTests();
  test('reads the Central Bank answer', () {
    final r = parseCbuRate(jsonEncode([
      {
        'id': 69,
        'Code': '840',
        'Ccy': 'USD',
        'CcyNm_UZ': 'AQSH dollari',
        'Nominal': '1',
        'Rate': '12650.50',
        'Diff': '-12.34',
        'Date': '24.10.2026'
      }
    ]));
    expect(r.rate, 12650.5);
    expect(r.date, '24.10.2026');
    // A rate per 10 units and a comma decimal read the same way.
    expect(
        parseCbuRate(
                jsonEncode({'Ccy': 'USD', 'Nominal': '10', 'Rate': '126505,0'}))
            .rate,
        closeTo(12650.5, 1e-9));
    expect(() => parseCbuRate('[]'), throwsFormatException);
    expect(() => parseCbuRate('<html>'), throwsFormatException);
    expect(
        () => parseCbuRate(jsonEncode([
              {'Ccy': 'EUR', 'Rate': '14000'}
            ])),
        throwsFormatException);
  });

  test('dollar prices follow the official rate', () async {
    final dir = Directory.systemTemp.createTempSync('romflow-rate-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    final profile = s.profiles.first;
    await s.setUsdRate(12000);
    // A dealer list in dollars: frame 1.5 $/m, glass in so‘m.
    final list = parsePriceList('material;narx;valyuta\n'
        'frame;1.5;USD\n'
        'glass;95000;\n');
    final changes =
        priceChanges(s.profiles, list, {profile['id']}, usdRate: s.usdRate);
    await s.applyPriceChanges(changes, 'Diler');
    num price(String key) =>
        (s.profiles.first['drawingRecipe']['prices'] as Map)[key] as num;
    expect(price('frame'), 18000);
    expect(price('glass'), 95000);
    expect(s.profiles.first['drawingRecipe']['usdPrices'], {'frame': 1.5});

    // Today's Central Bank rate: the dollar price moves, so‘m stays.
    final note = await s.refreshOfficialRate(
        force: true,
        fetch: () async => const OfficialRate(12650.5, '24.10.2026'));
    expect(note, contains('12650.50'));
    expect(s.usdRate, 12650.5);
    expect(s.usdRateSource, 'cbu');
    expect(s.usdRateDate, '24.10.2026');
    expect(price('frame'), 18976);
    expect(price('glass'), 95000);
    // The same rate again changes nothing.
    expect(
        await s.refreshOfficialRate(
            force: true,
            fetch: () async => const OfficialRate(12650.5, '24.10.2026')),
        isNull);
    // Switched off, it does not ask the bank.
    await s.setUsdRateAuto(false);
    expect(
        await s.refreshOfficialRate(
            fetch: () async => throw StateError('no network')),
        isNull);
    // A later list in so‘m takes the material off the dollar.
    final local = priceChanges(s.profiles,
        parsePriceList('material;narx\nframe;20000\n'), {profile['id']},
        usdRate: s.usdRate);
    await s.applyPriceChanges(local, 'Diler');
    expect(s.profiles.first['drawingRecipe']['usdPrices'], isNull);
    await s.setUsdRate(13000);
    expect(price('frame'), 20000);

    // Settings survive a restart.
    final again = Store(directory: dir);
    await again.init();
    expect(again.usdRateAuto, isFalse);
    expect(again.usdRate, 13000);
    expect(recipeFor(again.profiles.first)['prices']['frame'], 20000);
  });
}

void fallbackTests() {
  test('the international rate stands in when the bank is silent', () {
    final r = parseOpenRate(jsonEncode({
      'result': 'success',
      'provider': 'https://www.exchangerate-api.com',
      'time_last_update_utc': 'Fri, 24 Oct 2026 00:02:31 +0000',
      'base_code': 'USD',
      'rates': {'USD': 1, 'UZS': 12645.8, 'EUR': .92},
    }));
    expect(r.rate, 12645.8);
    expect(r.date, '24 Oct 2026');
    expect(r.source, 'open');
    expect(() => parseOpenRate(jsonEncode({'result': 'error'})),
        throwsFormatException);
    expect(Store.rateSourceName('open'), contains('xalqaro'));
  });
}
