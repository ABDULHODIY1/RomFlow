import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/brands.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/glass_page.dart';
import 'package:romflow/manufacturers.dart';
import 'package:romflow/store.dart';

Future<Store> freshStore(WidgetTester tester) async {
  Store.bundledCatalog =
      () async => File('assets/manufacturers_uz.json').readAsStringSync();
  final dir = Directory.systemTemp.createTempSync('romflow-glass-');
  addTearDown(() => dir.deleteSync(recursive: true));
  final store = Store(directory: dir);
  await tester.runAsync(store.init);
  return store;
}

void main() {
  test('the catalog lists glass with prices; a bad entry is refused', () {
    final text = File('assets/manufacturers_uz.json').readAsStringSync();
    final catalog = ManufacturerCatalog.parse(text);
    expect(catalog.glass.length, greaterThanOrEqualTo(6));
    final sheet = catalog.glassType('clear35')!;
    expect(sheet.estimate, isFalse);
    // Thicker clear glass costs more.
    expect(catalog.glassType('clear6')!.usd,
        greaterThan(catalog.glassType('clear4')!.usd));
    // Window prices use 4 mm glass.
    expect(catalog.common['glass'], catalog.glassType('clear4')!.usd);
    expect(
        () => ManufacturerCatalog.parse(
            text.replaceFirst('"id": "clear4"', '"id": "clear35"')),
        throwsFormatException);
  });

  test('AKFA and ENGELBERG systems fall under their brands', () {
    expect(brandKey('AKFA Aluminium'), 'akfa');
    expect(brandKey('AKFA Plast'), 'akfa');
    expect(brandKey('ENGELBERG'), 'engelberg');
    expect(brandKey('Alubest'), 'alubest');
    expect(brandKey('Yog‘och'), 'yog‘och');
  });

  testWidgets('the glass page shows every kind with its price', (tester) async {
    final store = await freshStore(tester);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light), home: GlassPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Oyna (shisha) narxlari'), findsOneWidget);
    for (final g in store.catalog!.glass.take(3)) {
      expect(find.byKey(ValueKey('glass-row-${g.id}')), findsOneWidget);
    }
    expect(glassPriceSom(store, store.catalog!.glassType('clear35')!),
        closeTo(48000, 300));
  });

  testWidgets('a profile is picked by brand, then by series', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await freshStore(tester);
    String? picked;
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Scaffold(
            body: Center(
                child: ProfilePickTile(
                    store: store,
                    profile: store.profiles.first['id'] as String,
                    onChanged: (v) => picked = v)))));
    await tester.tap(find.byKey(const ValueKey('pick-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Brendni tanlang'), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-akfa')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('brand-engelberg')));
    await tester.pumpAndSettle();
    final series = find.byKey(const ValueKey('series-mf-engelberg-7000'));
    await tester.ensureVisible(series);
    await tester.pumpAndSettle();
    await tester.tap(series);
    await tester.pumpAndSettle();
    expect(picked, 'mf-engelberg-7000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass chosen on the desk sets thickness and price',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await freshStore(tester);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DrawingEditor(store: store)));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(DrawingEditor)) as dynamic;
    final g = store.catalog!.glassType('clear6')!;
    final next = state.withGlass(g) as Map;
    expect(next['glassKind'], 'clear6');
    expect(next['glassThickness'], 6);
    expect((next['prices'] as Map)['glass'], glassPriceSom(store, g));
  });
}
