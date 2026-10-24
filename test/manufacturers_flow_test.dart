import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/manufacturers.dart';
import 'package:romflow/manufacturers_page.dart';
import 'package:romflow/store.dart';

String catalogText() => File('assets/manufacturers_uz.json').readAsStringSync();

late Directory lastDir;

Future<Store> freshStore() async {
  Store.bundledCatalog = () async => catalogText();
  final dir = lastDir = Directory.systemTemp.createTempSync('romflow-makers-');
  addTearDown(() => dir.deleteSync(recursive: true));
  final store = Store(directory: dir);
  await store.init();
  return store;
}

/// Lets the store's real file writes finish inside a widget test.
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

num price(Store s, String id, String key) =>
    (s.profiles.firstWhere((p) => p['id'] == id)['drawingRecipe']['prices']
        as Map)[key] as num;

void main() {
  test('a new workshop starts with the popular systems, in dollars', () async {
    final s = await freshStore();
    expect(s.catalog, isNotNull);
    for (final id in defaultCatalogSystems) {
      expect(s.profiles.where((p) => p['catalogId'] == id), hasLength(1));
    }
    // Before the bank's rate, the catalog's reference rate prices them.
    final system = s.catalog!.system('akfa-thermo65')!;
    expect(price(s, 'mf-akfa-thermo65', 'frame'),
        (system.usd['frame']! * s.catalog!.referenceUsdRate).round());
    // Today's rate moves them.
    await s.setUsdRate(13000, source: 'cbu', date: '24.10.2026');
    expect(price(s, 'mf-akfa-thermo65', 'frame'),
        (system.usd['frame']! * 13000).round());
    // Seeding happens once: a deleted system does not come back.
    await s.deleteProfile('mf-akfa-quattro60');
    final again = Store(directory: lastDir);
    await again.init();
    expect(again.profiles.any((p) => p['id'] == 'mf-akfa-quattro60'), isFalse);
    expect(again.profiles.any((p) => p['id'] == 'mf-akfa-thermo65'), isTrue);
  });

  test('a newer catalog moves catalog prices, never the workshop’s own',
      () async {
    final s = await freshStore();
    await s.setUsdRate(12000, source: 'cbu', date: '24.10.2026');
    // The workshop types its own frame price for ALDOX.
    final aldox = Map<String, dynamic>.from(
        s.profiles.firstWhere((p) => p['id'] == 'mf-akfa-aldox'));
    await s.saveProfile({...aldox, 'framePrice': 40000});
    expect(price(s, 'mf-akfa-aldox', 'frame'), 40000);

    final newer = catalogText()
        .replaceFirst('"version": 1', '"version": 2')
        .replaceAll('"frame": 2.6,', '"frame": 3.0,')
        .replaceAll('"frame": 5.0,', '"frame": 6.0,');
    final note = await s.refreshCatalog(force: true, fetch: () async => newer);
    expect(note, contains('katalogi'));
    expect(s.catalog!.version, 2);
    // THERMO 65 followed the catalog; ALDOX kept the typed frame price but
    // its other prices followed.
    expect(price(s, 'mf-akfa-thermo65', 'frame'), 6.0 * 12000);
    // Sash bars and corner profiles follow the mullion's new price too.
    final newer2 = catalogText()
        .replaceFirst('"version": 1', '"version": 3')
        .replaceAll('"mullion": 5.3,', '"mullion": 7.0,');
    await s.refreshCatalog(force: true, fetch: () async => newer2);
    expect(price(s, 'mf-akfa-thermo65', 'sashMullion'), 7.0 * 12000);
    expect(price(s, 'mf-akfa-thermo65', 'cornerProfile'), 7.0 * 12000);
    expect(price(s, 'mf-akfa-aldox', 'frame'), 40000);
    // The same version again changes nothing.
    expect(
        await s.refreshCatalog(force: true, fetch: () async => newer), isNull);
    // A broken download leaves everything as it was.
    await expectLater(
        s.refreshCatalog(force: true, fetch: () async => '<html>'),
        throwsFormatException);
    expect(s.catalog!.version, 3);

    // The downloaded catalog is kept for the next start.
    final again = Store(directory: lastDir);
    await again.init();
    expect(again.catalog!.version, 3);
    expect(price(again, 'mf-akfa-aldox', 'frame'), 40000);
  });

  test('typed prices take over; untouched ones keep following the rate',
      () async {
    final s = await freshStore();
    await s.setUsdRate(12000, source: 'cbu', date: '24.10.2026');
    Map<String, dynamic> thermo() => Map<String, dynamic>.from(
        s.profiles.firstWhere((p) => p['id'] == 'mf-akfa-thermo65'));
    final system = s.catalog!.system('akfa-thermo65')!;
    final hardware = thermo()['hardwarePrice'] as num;
    // The editor opens; meanwhile the bank's rate moves.
    final opened = thermo();
    await s.setUsdRate(13000, source: 'cbu', date: '25.10.2026');
    expect(thermo()['hardwarePrice'], greaterThan(hardware));
    // Only the glass price was typed.
    await s
        .saveProfile({...opened, 'glassPrice': 70000}, typed: {'glassPrice'});
    expect(price(s, 'mf-akfa-thermo65', 'glass'), 70000);
    expect(price(s, 'mf-akfa-thermo65', 'frame'),
        (system.usd['frame']! * 13000).round());
    expect(thermo()['framePrice'], (system.usd['frame']! * 13000).round());
    // Frame still follows the rate, glass no longer does.
    await s.setUsdRate(14000, source: 'cbu', date: '26.10.2026');
    expect(price(s, 'mf-akfa-thermo65', 'frame'),
        (system.usd['frame']! * 14000).round());
    expect(price(s, 'mf-akfa-thermo65', 'glass'), 70000);
    expect(thermo()['hardwareFollows'], isTrue);
  });

  testWidgets('the manufacturers page lists every maker and adds a system',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = (await tester.runAsync(freshStore))!;
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: ManufacturersPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('O‘zbekiston zavodlari narxi'), findsOneWidget);
    final list = find.byKey(const ValueKey('manufacturers-list'));
    for (final m in store.catalog!.manufacturers) {
      await tester.scrollUntilVisible(
          find.byKey(ValueKey('maker-${m.id}')), 300,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first);
      expect(find.byKey(ValueKey('maker-${m.id}')), findsOneWidget);
    }
    // PVC only, then add ENGELBERG 8000 to the profiles.
    await tester.drag(list, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mf-filter-pvc')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('maker-alubest')), findsNothing);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mf-add-engelberg-8000')), 200,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)).first);
    expect(find.byKey(const ValueKey('m2-engelberg-8000')), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('mf-add-engelberg-8000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mf-add-engelberg-8000')));
    await settleIo(tester);
    expect(
        store.profiles.any((p) => p['catalogId'] == 'engelberg-8000'), isTrue);
    expect(
        find.byKey(const ValueKey('mf-used-engelberg-8000')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the desk prices its window with every maker and switches',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = (await tester.runAsync(freshStore))!;
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DrawingEditor(store: store, initial: {
          'profileId': 'mf-akfa-aldox',
          'quantity': 2,
          'drawing': drawingPresets
              .firstWhere((p) => p.id == 'two')
              .drawing(width: 1500, height: 1400),
        })));
    await tester.pumpAndSettle();
    expect(find.text('AKFA ALDOX'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('compare-prices')));
    await tester.pumpAndSettle();
    expect(find.text('Zavodlar narxi'), findsWidgets);
    final quotes = compareSystems(
        store.catalog!,
        store.profiles,
        drawingPresets
            .firstWhere((p) => p.id == 'two')
            .drawing(width: 1500, height: 1400),
        2);
    expect(quotes, hasLength(store.catalog!.systems.length));
    for (var i = 1; i < quotes.length; i++) {
      if (quotes[i].total == null) continue;
      expect(quotes[i].total!, greaterThanOrEqualTo(quotes[i - 1].total!));
    }
    // Pick Alubest AluThermo-70: it joins the profiles and the desk uses it.
    await tester.tap(find.byKey(const ValueKey('compare-filter-aluminium')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('compare-alubest-thermo70')), 200,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('compare-list')),
                matching: find.byType(Scrollable))
            .first);
    await tester
        .ensureVisible(find.byKey(const ValueKey('compare-alubest-thermo70')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compare-alubest-thermo70')));
    await settleIo(tester);
    expect(store.profiles.any((p) => p['catalogId'] == 'alubest-thermo70'),
        isTrue);
    expect(find.text('Alubest AluThermo-70'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
