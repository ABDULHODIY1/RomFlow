import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/store.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/workshop_field.dart';

void main() {
  test(
    'decimal paste preserves value; integers reject fractional quantities',
    () {
      final decimal = WorkshopNumberFormatter();
      const old = TextEditingValue(text: '12');
      expect(
        decimal
            .formatEditUpdate(old, const TextEditingValue(text: '1 234,50'))
            .text,
        '1234.50',
      );
      expect(
        decimal.formatEditUpdate(old, const TextEditingValue(text: '2.3.4')),
        old,
      );
      expect(
        decimal.formatEditUpdate(old, const TextEditingValue(text: '-5')),
        old,
      );
      expect(
        WorkshopNumberFormatter(
          decimal: false,
        ).formatEditUpdate(old, const TextEditingValue(text: '1.5')),
        old,
      );
      expect(
        decimal.formatEditUpdate(old, const TextEditingValue(text: '')).text,
        '',
      );
    },
  );

  testWidgets('number replacement, clear, inline error and recovery', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1500');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkshopField(
            controller: controller,
            label: 'Eni',
            number: true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
    await tester.enterText(find.byType(TextField), '1200,5');
    await tester.pump();
    expect(controller.text, '1200.5');
    await tester.tap(find.byTooltip('Tozalash'));
    await tester.pump();
    expect(controller.text, '');
    expect(find.text('0 yoki musbat son kiriting'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '800');
    await tester.pump();
    expect(find.text('0 yoki musbat son kiriting'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard toolbar has reachable next and done actions', (
    tester,
  ) async {
    final first = TextEditingController(), second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => WorkshopKeyboardTools(child: child!),
        home: Scaffold(
          body: ListView(
            children: [
              WorkshopField(controller: first, label: 'Birinchi', number: true),
              WorkshopField(
                controller: second,
                label: 'Ikkinchi',
                number: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.text('Keyingisi'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).focusNode!.hasFocus,
      isTrue,
    );
    await tester.tap(find.text('Tayyor'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).focusNode!.hasFocus,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small phone dimensions retain invalid text and show correction',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('romflow-usability-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = Store(directory: dir);
      await tester.runAsync(store.init);
      await tester.pumpWidget(
        MaterialApp(
          theme: romFlowTheme(Brightness.dark),
          home: DrawingEditor(startInVisualMode: false, store: store),
        ),
      );
      await tester.pumpAndSettle();
      final width = find.byWidgetPredicate(
        (w) => w is WorkshopField && w.label == 'Eni, mm',
      );
      await tester.scrollUntilVisible(
        width,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.descendant(of: width, matching: find.byType(TextField)),
        '20',
      );
      await tester.scrollUntilVisible(
        find.text('O‘lchamni qo‘llash'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('O‘lchamni qo‘llash'));
      await tester.pumpAndSettle();
      expect(tester.widget<WorkshopField>(width).controller.text, '20');
      expect(find.text('300–6000 mm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'material search retains edited prices and readable dark inputs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('romflow-price-ui-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = Store(directory: dir);
      await tester.runAsync(store.init);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: romFlowTheme(Brightness.dark),
          home: RepaintBoundary(
            key: key,
            child: RecipeEditor(recipe: recipeFor(store.profiles.first)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byWidgetPredicate(
        (w) => w is WorkshopField && w.label == 'Materialni qidirish',
      );
      await tester.scrollUntilVisible(
        search,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.descendant(of: search, matching: find.byType(TextField)),
        'samorez',
      );
      await tester.pumpAndSettle();
      final screw = find.byWidgetPredicate(
        (w) => w is WorkshopField && w.label.startsWith('Samorez /'),
      );
      await tester.ensureVisible(screw);
      await tester.enterText(
        find.descendant(of: screw, matching: find.byType(TextField)),
        '450',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: search, matching: find.byType(TextField)),
        'rezina',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: search, matching: find.byType(TextField)),
        'samorez',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<WorkshopField>(screw).controller.text, '450');
      expect(tester.takeException(), isNull);
      // A real Flutter UI capture for visual review.
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Directory.systemTemp.path}/romflow-ui-price.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    },
  );
}
