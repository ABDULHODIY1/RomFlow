import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/adaptive_ui.dart';
import 'package:romflow/app_theme.dart';
import 'package:romflow/billing.dart';
import 'package:romflow/design_catalog.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/finance.dart';
import 'package:romflow/main.dart';
import 'package:romflow/manufacturers_page.dart';
import 'package:romflow/measurements.dart';
import 'package:romflow/price_sources.dart';
import 'package:romflow/staff_pay.dart';
import 'package:romflow/store.dart';

/// Every iPhone, iPad and a small Android, at the normal text size and with
/// large Dynamic Type: nothing may overflow or cover something else.
const screens = <(String, Size)>[
  ('iPhone SE 1', Size(320, 568)),
  ('iPhone SE 3 / 8', Size(375, 667)),
  ('iPhone mini', Size(375, 812)),
  ('iPhone 17', Size(402, 874)),
  ('iPhone Pro Max', Size(440, 956)),
  ('kichik Android', Size(360, 640)),
  ('iPad mini', Size(744, 1133)),
  ('iPad Air yotiq', Size(1180, 820)),
  ('iPad Pro 13', Size(1032, 1376)),
  ('iPhone yotiq', Size(874, 402)),
];

void main() {
  for (final design in ['glass', 'material']) {
    for (final (name, size) in screens) {
      for (final scale in [1.0, 1.35]) {
        testWidgets('$name, $design, matn ×$scale: hech narsa sig‘may qolmaydi',
            (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(() => applyDesign('auto'));
          final dir = Directory.systemTemp.createTempSync('romflow-small-');
          addTearDown(() => dir.deleteSync(recursive: true));
          final store = Store(directory: dir);
          await tester.runAsync(store.init);
          store.designPreference = design;
          applyDesign(design);

          final problems = <String>[];
          final old = FlutterError.onError;
          FlutterError.onError = (d) {
            final text = d.exceptionAsString().split('\n').first;
            final at = RegExp(r'lib/[a-z_0-9]+\.dart:\d+')
                .firstMatch(d.toString())
                ?.group(0);
            problems.add('$text @ $at');
          };
          Future<void> check(String where, Widget page) async {
            final before = problems.length;
            await tester.pumpWidget(MaterialApp(
                theme: romFlowTheme(Brightness.light),
                // As the app does: text grows at most 1.15×.
                builder: (context, child) => MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.15, child: child!),
                home: page));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
            for (var i = before; i < problems.length; i++) {
              problems[i] = '[$where] ${problems[i]}';
            }
          }

          try {
            await tester.pumpWidget(RomFlow(store: store));
            await tester.pump(const Duration(seconds: 1));
            for (final tab in ['Buyurtmalar', 'Katalog', 'Sozlamalar']) {
              final before = problems.length;
              final f = find.text(tab);
              if (f.evaluate().isNotEmpty) {
                await tester.tap(f.last, warnIfMissed: false);
                await tester.pump(const Duration(milliseconds: 600));
              }
              for (var i = before; i < problems.length; i++) {
                problems[i] = '[$tab] ${problems[i]}';
              }
            }
            final drawing =
                drawingPresets.firstWhere((p) => p.id == 'two').drawing();
            final recipe = catalogRecipe(store);
            await check(
                'Smeta',
                DrawingEditor(store: store, initial: {
                  'profileId': store.profiles.first['id'],
                  'quantity': 1,
                  'drawing': drawing,
                }));
            await check('Katalog dizayn',
                DesignCatalogPage(recipe: recipe, store: store));
            await check('3D', View3D(drawing: drawing, recipe: recipe));
            await check('Zavodlar', ManufacturersPage(store: store));
            await check('Razmer', MeasurementEditor(store: store));
            await check('Razmerlar', MeasurementsPage(store: store));
            await check('Narxlar', PriceSourcesPage(store: store));
            await check('Tarif', TariffPage(store: store));
            await check('Moliya', FinancePage(store: store));
            await check('Xodimlar', StaffPage(store: store));
          } finally {
            FlutterError.onError = old;
          }
          expect(problems, isEmpty, reason: problems.join('\n'));
        });
      }
    }
  }
}
