import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/finance.dart';
import 'package:romflow/main.dart' show RomFlow;
import 'package:romflow/share_text.dart';
import 'package:romflow/store.dart';

DMap line(DMap result, String key) =>
    (result['parts'] as List).cast<DMap>().firstWhere((p) => p['key'] == key);

DMap calc(DMap drawing, DMap recipe, {int quantity = 1}) => calculateDrawing(
    {'drawing': drawing, 'recipe': recipe, 'quantity': quantity},
    sampleProfiles().first);

void main() {
  group('drawing engine', () {
    test('every ready-made preset lays out and is priced', () {
      final recipe = defaultRecipe(sampleProfiles().first);
      for (final preset in drawingPresets) {
        final d = preset.drawing();
        final layout = layoutDrawing(d, recipe);
        expect(layout.cells, isNotEmpty, reason: preset.id);
        expect(calc(d, recipe)['total'], greaterThan(0), reason: preset.id);
      }
      // Fresh ids every time, so inserting a preset twice never collides.
      final a = drawingPresets.first.drawing(),
          b = drawingPresets.first.drawing();
      expect(a['root']['id'], isNot(b['root']['id']));
    });

    test('equalizing gives equal gross sections across nested splits', () {
      final recipe = defaultRecipe({});
      final d = newDrawing()
        ..['widthMm'] = 2100
        ..['root'] = {
          'id': 's1',
          'axis': 'v',
          'ratio': .2,
          'a': newLeaf('a'),
          'b': {
            'id': 's2',
            'axis': 'v',
            'ratio': .7,
            'a': newLeaf('b'),
            'b': newLeaf('c')
          }
        };
      equalizeSections(d, recipe);
      final stops = sectionStops(layoutDrawing(d, recipe), true, 2100);
      expect(stops.length, 4);
      for (var i = 0; i < 3; i++) {
        expect(stops[i + 1] - stops[i], closeTo(700, .5));
      }
    });

    test('opening symbol lines meet at the handle, open toward the hinges', () {
      const box = [0.0, 0.0, 100.0, 200.0];
      expect(openingSymbolLines('left', box).single[1].x, 100);
      expect(handlePoint('left', box)!.x, 100);
      expect(openingSymbolLines('right', box).single[1].x, 0);
      expect(openingSymbolLines('top', box).single[1].y, 200);
      expect(handlePoint('top', box)!.y, 200);
      expect(openingSymbolLines('bottom', box).single[1].y, 0);
      final tilt = openingSymbolLines('tiltTurn', box);
      expect(tilt.length, 2);
      expect(tilt[1][1].y, 0); // tilts on bottom hinges
      expect(openingSymbolLines('fixed', box), isEmpty);
      // The iOS toolbar draws the same lines, meeting at the handle.
      expect(openingIconStrokes('left').single.sublist(2, 4), [1, .5]);
      expect(openingIconMark('left')![0], 1);
      expect(snapRatio(.49, 1500), .5);
      expect(snapRatio(.42, 1500), isNull);
    });

    test('net pricing bills used material plus waste, never above purchase',
        () {
      final recipe = defaultRecipe(sampleProfiles().first);
      final net = calc(newDrawing(), recipe);
      final glass = line(net, 'glass');
      expect(glass['charged'], closeTo(glass['net'] * 1.07, 1e-9));
      expect(glass['charged'], lessThanOrEqualTo(glass['quantity']));
      expect(glass['cost'], (glass['charged'] * glass['price']).round());
      final whole = calc(newDrawing(), {...recipe, 'pricingMode': 'purchase'});
      expect(line(whole, 'glass')['cost'],
          (line(whole, 'glass')['quantity'] * glass['price']).round());
      expect(net['total'], lessThan(whole['total']));
      // Totals stay the sum of the lines plus markup.
      expect(
          (net['parts'] as List).fold<int>(0, (s, p) => s + (p['cost'] as int)),
          net['cost']);
    });

    test('colour surcharge applies to profiles only', () {
      final recipe = defaultRecipe(sampleProfiles().first);
      final plain = calc(newDrawing(), recipe);
      final dark = calc(newDrawing(), {...recipe, 'finish': 'anthracite'});
      expect(line(dark, 'frame')['price'],
          closeTo(line(plain, 'frame')['price'] * 1.2, 1e-6));
      expect(line(dark, 'glass')['price'], line(plain, 'glass')['price']);
      expect(
          () => validateRecipe({...recipe, 'finish': 'pink'}), throwsException);
    });
  });

  group('business records', () {
    late Directory dir;
    late Store s;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('romflow-v1-');
      s = Store(directory: dir);
      await s.init();
      await s.addCustomer({'name': 'Aziz', 'phone': '+998901112233'});
    });
    tearDown(() => dir.delete(recursive: true));

    Future<Json> order({int quantity = 2}) => s.saveQuote({
          'customerId': s.customers.first['id'],
          'title': 'Uy derazalari',
          'items': [
            {
              'profileId': sampleProfiles().first['id'],
              'drawing':
                  drawingPresets.firstWhere((p) => p.id == 'twoOpen').drawing(),
              'recipe': defaultRecipe(sampleProfiles().first),
              'quantity': quantity,
            }
          ],
          'discount': 0,
          'installation': 100000,
          'notes': ''
        });

    test('editing keeps payments, copying starts a clean draft', () async {
      final q = await order();
      await s.payment(q, 500000, 'Avans');
      await s.changeStatus(q, 'accepted');
      final edited = await s.updateQuote(q['id'], {
        'customerId': q['customerId'],
        'title': 'Uy derazalari (3 dona)',
        'items': [
          {...(q['items'] as List).first, 'quantity': 3}
        ],
        'discount': 0,
        'installation': 100000,
        'notes': ''
      });
      expect(edited['status'], 'accepted');
      expect(edited['paid'], 500000);
      expect(edited['balance'], edited['total'] - 500000);
      expect(edited['total'], greaterThan(q['total']));
      await expectLater(
          s.updateQuote(q['id'], {
            'customerId': q['customerId'],
            'title': 'x',
            'items': edited['items'],
            'discount': edited['total'] + 100000,
            'installation': 100000,
            'notes': ''
          }),
          throwsException);
      final copy = await s.duplicateQuote(q['id']);
      expect(copy['paid'], 0);
      expect(copy['status'], 'draft');
      expect(s.quotes.length, 2);
      await s.deleteQuote(copy['id']);
      expect(s.quotes.length, 1);
    });

    test('payroll balance, suggested pay and order profit', () async {
      final q = await order();
      await s
          .saveStaff({'name': 'Usta Karim', 'payType': 'perM2', 'rate': 40000});
      final worker = s.staff.first;
      await s.assignStaff(q, worker['id']);
      final m2 = (q['items'] as List).first['areaM2'] * 2;
      final pay = Store.suggestedPay(worker, s.quotes.first);
      expect(pay, (m2 * 40000).round());
      await s.addPayroll({
        'staffId': worker['id'],
        'kind': 'accrual',
        'amount': pay,
        'quoteId': q['id']
      });
      await s.addPayroll(
          {'staffId': worker['id'], 'kind': 'advance', 'amount': 50000});
      expect(s.staffBalance(worker['id']), pay - 50000);
      await expectLater(s.deleteStaff(worker['id']), throwsException);
      await s.addExpense(
          {'category': 'transport', 'amount': 30000, 'quoteId': q['id']});
      final profit = orderProfit(s, s.quotes.first);
      expect(profit.labour, pay);
      expect(profit.extra, 30000);
      expect(profit.profit,
          profit.total - profit.material - profit.labour - profit.extra);
      await s.payment(s.quotes.first, 200000, '');
      final now = DateTime.now();
      final month = FinanceSummary.of(s, periodRange(Period.month, now));
      expect(month.income, 200000);
      expect(month.expenses, 30000);
      expect(month.salaries, 50000);
      expect(month.profit, 200000 - 30000 - 50000);
      // Everything survives a backup round trip.
      final raw = await s.exportBackup();
      final other = Store(directory: await dir.createTemp('restore'));
      await other.init();
      await other.importBackup(raw);
      expect(other.payroll.length, 2);
      expect(other.expenses.length, 1);
      expect(other.staffBalance(worker['id']), pay - 50000);
      // Deleting the order keeps what the worker earned on it.
      await s.deleteQuote(q['id']);
      expect(s.staffBalance(worker['id']), pay - 50000);
      expect(s.payroll.every((e) => e['quoteId'] == null), isTrue);
    });

    test('share texts carry totals, sizes and cut lengths', () async {
      await s.setWorkshop('Oyna Usta', phone: '+998 90 000 00 00');
      final q = await order();
      final text = quoteText(s, q);
      expect(text, contains('Oyna Usta'));
      expect(text, contains('1400×1400 mm × 2 dona'));
      expect(text, contains(money(q['total'])));
      final cuts = cutListText(q);
      expect(cuts, contains('Tashqi rama'));
      expect(cuts, contains('tayoq'));
      expect(cuts, contains('Shisha'));
    });
  });

  testWidgets('a preset dragged onto a section replaces only that section',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-preset-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DrawingEditor(store: store)));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter);
    DrawingPainter painter() =>
        tester.widget<CustomPaint>(canvas).painter! as DrawingPainter;
    await tester.tap(find.byTooltip('Andoza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('2 tabaqali'));
    await tester.pumpAndSettle();
    expect(layoutDrawing(painter().drawing, painter().recipe).cells.length, 2);
    // The design keeps the size already on the desk.
    expect(painter().drawing['widthMm'], 1500);
    final before = jsonEncode(painter().drawing);
    // Drop a ready three-part window into the right-hand section.
    await tester.ensureVisible(find.byTooltip('3 bo‘limli'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(canvas);
    final target = rect.topLeft +
        CanvasTransform(rect.size, painter().drawing, sectionDimensions: true)
            .to(const V(1050, 700));
    final gesture = await tester
        .startGesture(tester.getCenter(find.byTooltip('3 bo‘limli')));
    await gesture.moveBy(const Offset(0, 28));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pumpAndSettle();
    expect(jsonEncode(painter().drawing), before);
    await gesture.up();
    await tester.pumpAndSettle();
    final cells = layoutDrawing(painter().drawing, painter().recipe).cells;
    expect(cells.length, 4);
    expect(cells.first.node['opening'], 'left');
    // A closer is a door part: a window without a door does not offer it.
    await tester.tap(find.byTooltip('Furnitura'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dovodchik'), findsNothing);
    expect(find.byTooltip('Setka'), findsOneWidget);
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(jsonEncode(painter().drawing), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expense saved from the app shell reaches the finance page',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-expense-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    // The real app shell rebuilds MaterialApp on every store change, which
    // also rebuilds a dialog that is still closing.
    await tester.pumpWidget(RomFlow(store: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Moliya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moliya'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Xarajat'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Summa (so‘m)'), '150000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Izoh'), 'Yo‘l');
    await tester.tap(find.text('Saqlash'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.expenses.single['amount'], 150000);
    expect(find.textContaining('Tushum va xarajat'), findsOneWidget);
  });
}
