import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/design_catalog.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/store.dart';

void main() {
  testWidgets('filter chips narrow the designs; tabs keep their names',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-catalog-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    final recipe = catalogRecipe(store);
    // Every design knows what it has.
    final fortochka = drawingPresets
        .where((p) =>
            p.group == 'Deraza' &&
            designTags(p, recipe).contains('Fortochkali'))
        .toList();
    expect(fortochka, isNotEmpty);
    expect(designTags(drawingPresets.firstWhere((p) => p.id == 'two'), recipe),
        {'2 bo‘lim'});
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: DesignCatalogPage(recipe: recipe, store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Derazalar 27'), findsOneWidget);
    expect(find.byKey(const ValueKey('design-two')), findsOneWidget);
    await tester.dragUntilVisible(
        find.byKey(const ValueKey('filter-Fortochkali')),
        find.byKey(const ValueKey('filter-all')),
        const Offset(-120, 0));
    await tester.tap(find.byKey(const ValueKey('filter-Fortochkali')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('design-two')), findsNothing);
    expect(
        find.byKey(ValueKey('design-${fortochka.first.id}')), findsOneWidget);
    // Another tab starts with all of its designs.
    await tester.tap(find.byKey(const ValueKey('group-Eshik')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('filter-all')))
            .selected,
        isTrue);
    // Folded, the tab names stay.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Eshiklar 16'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
