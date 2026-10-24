import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_catalog.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/main.dart';
import 'package:romflow/store.dart';

Future<Store> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dir = Directory.systemTemp.createTempSync('romflow-smeta-');
  addTearDown(() => dir.deleteSync(recursive: true));
  final store = Store(directory: dir);
  await tester.runAsync(store.init);
  return store;
}

void main() {
  testWidgets(
      'a new smeta window starts in the catalog: kind, design, size and room',
      (tester) async {
    final store = await phone(tester);
    CatalogChoice? picked;
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () async => picked = await openDesignCatalog(
                            context,
                            recipe: catalogRecipe(store)),
                        child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Tayyor dizaynlar'), findsOneWidget);
    // Every kind has its own designs.
    for (final g in presetGroups.keys) {
      expect(drawingPresets.where((p) => p.group == g), isNotEmpty);
    }
    await tester.tap(find.byKey(const ValueKey('group-Eshik')));
    await tester.pumpAndSettle();
    // Tiles are built as they scroll into view.
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('design-doorNarrowWide')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('design-doorNarrowWide')), findsOneWidget);
    expect(find.byKey(const ValueKey('design-two')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('group-Deraza')));
    await tester.pumpAndSettle();
    // Pressing and holding picks a design without opening it.
    await tester.longPress(find.byKey(const ValueKey('design-two')));
    await tester.pump();
    String field(String key) => tester
        .widget<TextFormField>(find.byKey(ValueKey(key)))
        .controller!
        .text;
    // A design brings its usual size until one is typed.
    expect(field('catalog-width'), '1400');
    await tester.enterText(find.byKey(const ValueKey('catalog-width')), '1600');
    await tester.longPress(find.byKey(const ValueKey('design-three')));
    await tester.pump();
    expect(field('catalog-width'), '1600');
    await tester.tap(find.byTooltip('Ko‘paytirish'));
    await tester.tap(find.byKey(const ValueKey('catalog-room')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Oshxona'));
    await tester.pumpAndSettle();
    // A tap on a card opens it straight away.
    await tester.tap(find.byKey(const ValueKey('design-two')));
    await tester.pumpAndSettle();
    expect(picked!.preset!.id, 'two');
    expect(picked!.count, 2);
    final item = picked!.item();
    expect(item['label'], 'Oshxona');
    expect(item['drawing']['widthMm'], 1600);
    expect(item['drawing']['heightMm'], 1400);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the desk shows the chosen window, mirrors it and adds it to the smeta',
      (tester) async {
    final store = await phone(tester);
    Json? added;
    final start = CatalogChoice(drawingPresets.firstWhere((p) => p.id == 'two'),
            1600, 1400, 1, 'Oshxona')
        .item();
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () async => added = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DrawingEditor(
                                    store: store, initial: start))),
                        child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    Json drawing() =>
        (tester.widget<CustomPaint>(canvas).painter! as DrawingPainter).drawing;
    expect(drawing()['widthMm'], 1600);
    expect(drawing()['root']['a']['opening'], 'tiltTurn');
    expect(drawing()['root']['b']['opening'], 'fixed');
    expect(find.text('Oshxona • 1600×1400'), findsOneWidget);
    // The chosen section is described above the canvas.
    expect(find.byKey(const ValueKey('section-bar')), findsOneWidget);
    await tester.tap(find.text('Ko‘zgu'));
    await tester.pumpAndSettle();
    expect(drawing()['root']['a']['opening'], 'fixed');
    expect(drawing()['root']['b']['opening'], 'tiltTurn');
    // A ready design from the desk keeps the size already entered.
    await tester.tap(find.text('Andoza'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('3 bo‘limli'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 bo‘limli'));
    await tester.pumpAndSettle();
    expect(drawing()['root']['b']['axis'], 'v');
    expect(drawing()['widthMm'], 1600);
    expect(drawing()['heightMm'], 1400);
    await tester.ensureVisible(find.byKey(const ValueKey('open-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-Arka')));
    await tester.pumpAndSettle();
    // The AI camera card sits above the designs here.
    expect(find.byKey(const ValueKey('design-camera')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('design-archTop3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('design-archTop3')));
    await tester.pumpAndSettle();
    expect(drawing()['shape'], 'arch');
    expect(drawing()['widthMm'], 1600);
    await tester.tap(find.byKey(const ValueKey('add-to-smeta')));
    await tester.pumpAndSettle();
    expect(added!['label'], 'Oshxona');
    expect(added!['widthMm'], 1600);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the material list keeps its add button in reach',
      (tester) async {
    final store = await phone(tester);
    Json? added;
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () async => added = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DrawingEditor(store: store))),
                        child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calculate-drawing')));
    await tester.pumpAndSettle();
    expect(find.text('Materiallar va sarf'), findsOneWidget);
    final button = find.byKey(const ValueKey('report-add'));
    expect(tester.getRect(button).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(added, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mirroring swaps door hands and 90° joins', (tester) async {
    final store = await phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DrawingEditor(store: store, initial: {
          'profileId': store.profiles.first['id'],
          'quantity': 1,
          'drawing': {
            'widthMm': 900,
            'heightMm': 2100,
            'shape': 'rect',
            'riseMm': 300,
            'joins': ['left'],
            'root': {
              'id': 'd',
              'opening': 'doorLeft',
              'fill': 'glass',
            },
          },
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ko‘zgu'));
    await tester.pumpAndSettle();
    final d = (tester
            .widget<CustomPaint>(find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is DrawingPainter))
            .painter! as DrawingPainter)
        .drawing;
    expect(d['root']['opening'], 'doorRight');
    expect(d['joins'], ['right']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('smeta page: window cards, count, copy, room and live total',
      (tester) async {
    final store = await phone(tester);
    final item = {
      'profileId': 'series-akfa-simple-hollow',
      'template': 'drawing',
      'quantity': 1,
      'widthMm': 1200,
      'heightMm': 1400,
      'label': 'Zal',
      'drawing': {
        'widthMm': 1200,
        'heightMm': 1400,
        'shape': 'rect',
        'riseMm': 300,
        'root': {'id': 'w', 'opening': 'left', 'fill': 'glass'},
      },
    };
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: BuilderPage(store: store, initialItem: item)));
    await tester.pumpAndSettle();
    expect(find.text('Zal'), findsOneWidget);
    String total() =>
        tester.widget<Text>(find.byKey(const ValueKey('smeta-total'))).data!;
    final one = total();
    expect(one, endsWith('so‘m'));
    await tester.tap(find.byTooltip('Ko‘paytirish'));
    await tester.pumpAndSettle();
    expect(total(), isNot(one));
    await tester.tap(find.byKey(const ValueKey('window-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nusxa olish'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('window-1')), findsOneWidget);
    expect(find.text('2-rom'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('window-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Joyini yozish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Balkon'));
    await tester.pumpAndSettle();
    expect(find.text('Balkon'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('window-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olib tashlash'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('window-1')), findsNothing);
    expect(find.text('Qaytarish'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
