import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/store.dart';
import 'package:romflow/main.dart';
import 'package:romflow/adaptive_ui.dart';
import 'package:romflow/workshop_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'single and double glazing share dimensions but count separate panes, edge spacer and shpros',
      () {
    final d = newDrawing(),
        p = sampleProfiles()
            .firstWhere((p) => p['id'] == 'series-akfa-simple-hollow'),
        r = recipeFor(p);
    d['root'] = {...newLeaf('a'), 'shpros': true, 'rosettes': true};
    Map<String, dynamic> bill() =>
        calculateDrawing({'drawing': d, 'recipe': r, 'quantity': 2}, p);
    final single = bill();
    expect(single['specs'].single['panes'], 1);
    expect((single['parts'] as List).any((p) => p['key'] == 'spacer'), isFalse);
    final one = WindowModel(d, r);
    expect(one.parts.values.where((p) => p.materialKey == 'glass').length, 1);
    expect(one.parts.values.where((p) => p.materialKey == 'frame').length, 4);
    final frame = one.parts.values.firstWhere((p) => p.materialKey == 'frame');
    expect(one.faces.where((f) => f.partId == frame.id).length,
        greaterThanOrEqualTo(24));
    r['glazingType'] = 'double';
    final two = bill();
    expect(two['specs'].single['panes'], 2);
    expect(two['specs'].single['packageThicknessMm'], 20);
    Map line(Map b, String k) =>
        (b['parts'] as List).firstWhere((p) => p['key'] == k);
    expect(line(two, 'glass')['net'],
        closeTo(line(single, 'glass')['net'] * 2, 1e-8));
    final g = (two['specs'].single['polygon'] as List)
        .map((v) => V((v[0] as num).toDouble(), (v[1] as num).toDouble()))
        .toList();
    expect(line(two, 'spacer')['net'],
        closeTo(perimeter(inset(g, 6)) / 1000 * 2, 1e-8));
    expect(line(two, 'spacerCorner')['net'], 8);
    expect(line(two, 'shprosJoint')['net'], 6);
    expect(line(two, 'shprosRosette')['net'], 6);
    expect(line(two, 'desiccant')['unit'], 'kg');
    final model = WindowModel(d, r),
        panes =
            model.parts.values.where((p) => p.materialKey == 'glass').toList();
    expect(panes.length, 2);
    expect((panes.last.center.z - panes.first.center.z).abs(), 16);
    expect(
        panes.last.explosionOffset(1, 1500, 1500, 1500).z -
            panes.first.explosionOffset(1, 1500, 1500, 1500).z,
        closeTo(720, 1e-8));
    expect(
        model.parts.values.where((p) => p.materialKey == 'spacer').length, 4);
    expect(
        model.parts.values.where((p) => p.materialKey == 'shpros').length, 4);
    expect(drawingSvg(d, r), contains('stroke="#b49742"'));
    expect(
        sampleProfiles().any((p) => p['id'] == 'series-akfa-thermo65'), isTrue);
  });
  test(
      'auto fit keeps opened and exploded components inside a phone viewport at every orbit',
      () {
    final d = newDrawing(),
        r = recipeFor(sampleProfiles()
            .firstWhere((p) => p['id'] == 'series-akfa-simple-hollow'));
    r['glazingType'] = 'double';
    d['root'] = {...newLeaf('a'), 'opening': 'doorLeft', 'shpros': true};
    final m = WindowModel(d, r),
        size = const Size(390, 480),
        camera = 1500 * 3.3;
    for (final yaw in [-3.14, -1.5, 0.0, 1.5, 3.14]) {
      for (final pitch in [-2.0, 0.0, 2.0]) {
        for (final explosion in [0.0, 1.0]) {
          final painter = ModelPainter(m, yaw, pitch, 1, .7, 'all', false,
              explosion: explosion);
          for (final f in m.faces) {
            for (final vertex in f.vertices) {
              final p = painter.positioned(vertex, f.group, m.parts[f.partId]);
              if (camera - p.z <= 1500 * .15) {
                continue;
              }
              final v = painter.project(p, size);
              expect(v.dx, inInclusiveRange(24.99, size.width - 24.99));
              expect(v.dy, inInclusiveRange(24.99, size.height - 24.99));
            }
          }
        }
      }
    }
  });
  test(
      'offline debts reject overpayment atomically; reminders and payments survive backup/reopen',
      () async {
    final dir = Directory.systemTemp.createTempSync('romflow-ledger-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    await s.addDebt({
      'person': 'Ali',
      'phone': '',
      'direction': 'receivable',
      'amount': 100000,
      'note': 'Profil uchun',
      'due': null
    });
    await s.addDebt({
      'person': 'Yetkazib beruvchi',
      'phone': '',
      'direction': 'payable',
      'amount': 50000,
      'note': '',
      'due': null
    });
    final id = s.debts.last['id'];
    final results = await Future.wait([
      s
          .debtPayment(id, 70000, 'Naqd')
          .then((_) => true)
          .catchError((_) => false),
      s
          .debtPayment(id, 70000, 'Takror')
          .then((_) => true)
          .catchError((_) => false)
    ]);
    expect(results, [true, false]);
    expect(Store.debtBalance(s.debts.last), 30000);
    final rid = await s.saveReminder({
      'title': 'Rom o‘lchash',
      'note': 'Ali bilan',
      'due': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'done': false
    });
    final raw = await s.exportBackup(), next = Store(directory: dir);
    await next.init();
    expect(next.reminders.single['id'], rid);
    expect(Store.debtBalance(next.debts.last), 30000);
    final invalid = jsonDecode(raw);
    invalid['debts'][1]['payments'][0]['amount'] = 200000;
    await expectLater(
        next.importBackup(jsonEncode(invalid)), throwsA(anything));
    expect(Store.debtBalance(next.debts.last), 30000);
    final legacy = jsonDecode(raw)
      ..remove('debts')
      ..remove('reminders');
    await next.importBackup(jsonEncode(legacy));
    expect(next.debts, isEmpty);
    expect(next.reminders, isEmpty);
  });
  testWidgets(
      'debt form, partial repayment and reminder are usable on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('romflow/reminders'),
            (call) async => call.method == 'schedule' ? true : null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('romflow/reminders'), null));
    final dir = Directory.systemTemp.createTempSync('romflow-ledger-ui-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await tester.runAsync(s.init);
    await tester.pumpWidget(MaterialApp(home: WorkshopTools(store: s)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qarz yozish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ali');
    await tester.enterText(find.byType(TextFormField).at(2), '100000');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Qarzni saqlash'));
    await tester.tap(find.text('Qarzni saqlash'));
    for (var tick = 0; tick < 12; tick++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(s.debts.length, 1);
    // On a slow machine the list shows the saved entry a little later
    // than the store has it: wait for it (bounded) before scrolling to it.
    for (var tick = 0;
        tick < 100 && find.text('Ali').evaluate().isEmpty;
        tick++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Scroll the entry itself into view rather than looking up a list
    // first: on slow machines the closing dialog's list could be the one
    // found and then vanish.
    await tester.ensureVisible(find.text('Ali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To‘lov yozish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '25000');
    await tester.tap(find.text('To‘lovni saqlash'));
    for (var tick = 0; tick < 12; tick++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(Store.debtBalance(s.debts.single), 75000);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eslatmalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eslatma qo‘shish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Montaj');
    await tester.tap(find.text('Eslatmani saqlash'));
    for (var tick = 0; tick < 12; tick++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(s.reminders.single['title'], 'Montaj');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'iOS receives separate glass navigation while Android keeps Material navigation',
      (tester) async {
    // Phone size: tablets and desktops use a side rail instead.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-platform-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await tester.runAsync(s.init);
    await tester.pumpWidget(RomFlow(store: s));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(RomFlow(key: UniqueKey(), store: s));
    await tester.pumpAndSettle();
    expect(find.byType(IOSGlassNavigation), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.descendant(
        of: find.byType(IOSGlassNavigation), matching: find.text('Katalog')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
