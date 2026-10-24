import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/store.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';

void main() {
  test(
      'pull handle releases downward rod before leaf swings; door hardware stays separate',
      () {
    final r = recipeFor(sampleProfiles()
        .firstWhere((p) => p['id'] == 'series-akfa-simple-hollow'))
      ..['windowHandle'] = 'pull';
    final d = newDrawing()..['root'] = {...newLeaf('a'), 'opening': 'left'};
    final m = WindowModel(d, r),
        rod = m.motions.values.firstWhere((x) => x.mode == 'rod');
    const point = P3(100, 200, 50);
    final released = rod.transform(point, .11);
    expect(released.x, point.x);
    expect(released.y, point.y + 12);
    expect(released.z, point.z);
    final leaf = m.groups['a']!;
    expect(leaf.transform(point, .11).x, point.x);
    expect(leaf.transform(point, .8).z, isNot(point.z));
    expect(m.parts.values.where((p) => p.title.startsWith('Yelma')).length,
        greaterThanOrEqualTo(2));
    expect(m.parts.values.any((p) => p.materialKey == 'cylinder'), isFalse);
    d['root'] = {...newLeaf('a'), 'opening': 'doorLeft'};
    final door = WindowModel(d, r);
    expect(door.motions, isEmpty);
    expect(door.parts.values.any((p) => p.materialKey == 'cylinder'), isTrue);
    final handle =
        door.parts.values.firstWhere((p) => p.title.startsWith('Eshik'));
    expect(handle.extent.x, greaterThan(80));
    expect(door.faces.where((f) => f.partId == handle.id).length,
        greaterThan(100));
  });
  test(
      'warehouse aggregates purchasing units, isolates systems, consumes once and returns exactly',
      () async {
    final dir = await Directory.systemTemp.createTemp('romflow-v7');
    addTearDown(() => dir.delete(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    final p = s.profiles
            .firstWhere((p) => p['id'] == 'series-akfa-simple-hollow'),
        r = recipeFor(p),
        d = newDrawing();
    final item = {
      'profileId': p['id'],
      'drawing': d,
      'recipe': r,
      'widthMm': 1500,
      'heightMm': 1500,
      'quantity': 1
    };
    await s.addCustomer({'name': 'Ali', 'phone': '', 'address': ''});
    final q = await s.saveQuote({
      'customerId': s.customers.first['id'],
      'title': 'Sinov',
      'items': [item, item],
      'discount': 0,
      'installation': 0,
      'notes': ''
    });
    final needs = s.stockNeeds(q['items']);
    expect(needs, isNotEmpty);
    final single = s.stockNeeds([q['items'][0]]);
    for (final n in needs) {
      expect(
          n['required'],
          closeTo(
              (single.firstWhere((a) => a['id'] == n['id'])['required']
                      as num) *
                  2,
              1e-6));
      await s.saveStock({
        'profileId': n['profileId'],
        'key': n['key'],
        'unit': n['unit'],
        'quantity': (n['required'] as num) + 10,
        'price': 1000,
        'minimum': 1
      });
    }
    final original = s.inventory.map((r) => r['quantity']).toList();
    await s.applyQuoteStock(q['id'], true);
    expect(s.inventory.every((r) => ((r['quantity'] as num) - 10).abs() < 1e-6),
        isTrue);
    await expectLater(s.applyQuoteStock(q['id'], true), throwsA(anything));
    final reopened = Store(directory: dir);
    await reopened.init();
    await reopened.applyQuoteStock(q['id'], false);
    expect(reopened.inventory.map((r) => r['quantity']).toList(), original);
    await expectLater(
        reopened.applyQuoteStock(q['id'], false), throwsA(anything));
    final other = [
      {...q['items'][0], 'profileId': 'another-system'}
    ];
    expect(
        reopened.stockNeeds(other).every((r) => r['available'] == 0), isTrue);
    await reopened.saveStock({...reopened.inventory.first, 'quantity': 0});
    final before = await reopened.exportBackup();
    await expectLater(
        reopened.applyQuoteStock(q['id'], true), throwsA(anything));
    expect(await reopened.exportBackup(), before);
  });
  test(
      'theme and drawing templates survive backup, reopened storage and old format',
      () async {
    final dir = await Directory.systemTemp.createTemp('romflow-v7-theme');
    addTearDown(() => dir.delete(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    final p = s.profiles.first, r = recipeFor(p), d = newDrawing();
    await s.setTheme('dark');
    await s.saveDrawingTemplate('Mening romim', {
      'drawing': d,
      'recipe': r,
      'profileId': p['id'],
      'widthMm': 1500,
      'heightMm': 1500,
      'quantity': 1
    });
    d['widthMm'] = 900;
    final restored = Store(directory: dir);
    await restored.init();
    expect(restored.themePreference, 'dark');
    expect(restored.drawingTemplates.single['item']['drawing']['widthMm'],
        isNot(900));
    await expectLater(restored.setTheme('invalid'), throwsA(anything));
    final backup = await restored.exportBackup();
    await restored
        .deleteDrawingTemplate(restored.drawingTemplates.single['id']);
    await restored.importBackup(backup);
    expect(restored.drawingTemplates.length, 1);
  });
}
