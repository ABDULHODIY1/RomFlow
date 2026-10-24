import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/main.dart';
import 'package:romflow/store.dart';

void main() {
  testWidgets('startup paints UI before any plugin initialization',
      (tester) async {
    await tester.pumpWidget(const StartApp());
    await tester.pump();
    expect(find.text('RomFlow'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 13));
    expect(
        find.text(
            'Ilovani ochishda xato yuz berdi. Ma’lumotlar o‘chirilgani yo‘q.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'small phone opens constructor, local catalog editor, offline settings with no login',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-ui-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = Store(directory: dir);
    await tester.runAsync(s.init);
    await tester.pumpWidget(RomFlow(store: s));
    await tester.pumpAndSettle();
    // No "offline / free" badge any more; the plan sits behind this button.
    expect(find.text('Offline • Bepul'), findsNothing);
    expect(find.byKey(const ValueKey('tariff')), findsOneWidget);
    // A new smeta starts by choosing and drawing its first window.
    await tester.tap(find.text('Yangi smeta'));
    await tester.pumpAndSettle();
    expect(find.text('Tayyor dizaynlar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-to-smeta')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Katalog'));
    await tester.pumpAndSettle();
    expect(find.text('Yangi profil qo‘shish'), findsOneWidget);
    await tester.tap(find.text('Yangi profil qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.text('Yangi profil tizimi'), findsOneWidget);
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();
    expect(find.text('Tarif'), findsOneWidget);
    expect(find.text('Pro • hozircha bepul'), findsOneWidget);
    expect(find.text('Serverga ulanish'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
