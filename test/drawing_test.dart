import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/store.dart';

DMap calc(DMap d, {DMap? recipe, int quantity = 1}) => calculateDrawing({
      'drawing': d,
      'profileId': sampleProfiles().first['id'],
      'quantity': quantity
    }, {
      ...sampleProfiles().first,
      if (recipe != null) 'drawingRecipe': recipe
    });
DMap line(DMap result, String key) =>
    (result['parts'] as List).cast<DMap>().firstWhere((p) => p['key'] == key);
void main() {
  test(
      'independent fixed-frame dimensions, glass, U-rubber and financial totals',
      () {
    final result = calc(newDrawing());
    expect(result['areaM2'], 2.25);
    // 1500 outer - two 50 mm frame faces - two 3 mm glass clearances.
    final side = 1394.0;
    expect(line(result, 'glass')['net'], closeTo(side * side / 1e6, 1e-8));
    expect(
        line(result, 'uGasket')['net'], closeTo(4 * side / 1000 * 1.03, 1e-8));
    expect(result['openingCount'], 0);
    expect(line(result, 'frame')['net'], 6);
    expect(line(result, 'frame')['quantity'],
        12); // kerf means 4 x 1500 cannot fit 6000.
    expect(result['total'], (result['cost'] * 1.25).round());
    expect(
        (result['parts'] as List)
            .fold<int>(0, (s, p) => s + (p['cost'] as int)),
        result['cost']);
  });
  test(
      'photo layout: two independently opening leaves, fixed center, two mullions',
      () {
    final d = newDrawing();
    d['root'] = {
      'id': 's1',
      'axis': 'v',
      'ratio': 1 / 3,
      'a': {...newLeaf('a'), 'opening': 'left'},
      'b': {
        'id': 's2',
        'axis': 'v',
        'ratio': .5,
        'a': newLeaf('b'),
        'b': {...newLeaf('c'), 'opening': 'right'}
      }
    };
    final out = calc(d);
    expect(out['openingCount'], 2);
    expect((out['specs'] as List).length, 3);
    expect(line(out, 'handle')['quantity'], 2);
    expect(line(out, 'hinge')['quantity'], 4);
    expect(line(out, 'windowLock')['quantity'], 2);
    expect(line(out, 'mullionJoint')['quantity'], 4);
    expect(line(out, 'sealInner')['net'], greaterThan(0));
    expect(line(out, 'sealOuter')['net'], line(out, 'sealInner')['net']);
  });
  test('door locks, passive bolt, lambir strips, mesh and custom consumption',
      () {
    final d = newDrawing();
    d['heightMm'] = 2100;
    d['widthMm'] = 1000;
    d['root'] = {
      ...newLeaf('1'),
      'opening': 'doorRight',
      'fill': 'lambris',
      'locks': 2,
      'closer': true,
      'mesh': true
    };
    final recipe = defaultRecipe(sampleProfiles().first);
    recipe['customMaterials'] = [
      {
        'name': 'Armatura',
        'unit': 'm',
        'basis': 'sashM',
        'rate': .8,
        'price': 10000
      }
    ];
    final out = calc(d, recipe: recipe, quantity: 3);
    expect(line(out, 'doorLock')['quantity'], 6);
    expect(line(out, 'cylinder')['quantity'], 6);
    expect(line(out, 'doorHinge')['quantity'], 9);
    expect(line(out, 'closer')['quantity'], 3);
    expect(out['cuts']['lambris']['bars'], isNotEmpty);
    expect(line(out, 'lambris')['quantity'],
        greaterThanOrEqualTo(line(out, 'lambris')['net']));
    expect(line(out, 'meshCorner')['quantity'], 12);
    expect((out['parts'] as List).any((p) => p['name'] == 'Armatura'), isTrue);
    d['root']['opening'] = 'passive';
    d['root']['mesh'] = false;
    final passive = calc(d, recipe: recipe);
    expect(line(passive, 'passiveBolt')['quantity'], 2);
    expect(
        (passive['parts'] as List).any((p) => p['key'] == 'doorLock'), isFalse);
  });
  test(
      'round and arch outlines approximate analytical geometry and reject bad contours',
      () {
    final d = newDrawing()
      ..['widthMm'] = 1000
      ..['heightMm'] = 1000
      ..['shape'] = 'circle';
    expect(polygonArea(outline(d)), closeTo(math.pi * 500 * 500, 400));
    expect(perimeter(outline(d)), closeTo(math.pi * 1000, 1));
    final out = calc(d);
    expect(out['warning'], contains('Egri'));
    expect(line(out, 'bending')['quantity'], greaterThan(3));
    d['shape'] = 'arch';
    d['riseMm'] = 500;
    expect(polygonArea(outline(d)),
        closeTo(1000 * 500 + math.pi * 500 * 500 / 2, 200));
    expect(calc(d)['areaM2'], greaterThan(.89));
    d['shape'] = 'custom';
    d['vertices'] = [
      [0, 0],
      [1, 1],
      [1, 0],
      [0, 1]
    ];
    expect(() => outline(d), throwsException);
    d['vertices'] = [
      [0, 0],
      [1, 0],
      [.5, .5],
      [1, 1],
      [0, 1]
    ];
    expect(() => outline(d), throwsException);
  });
  test('random cutting plans conserve purchased stock exactly', () {
    final rng = math.Random(42);
    for (var t = 0; t < 100; t++) {
      final pieces =
          List.generate(20, (_) => (100 + rng.nextInt(2800)).toDouble());
      final p = packBars(pieces, 6000, 3, 500);
      expect(p['purchasedMm'],
          closeTo(p['netMm'] + p['sawMm'] + p['offcutMm'], 1e-6));
      expect(p['offcutMm'], closeTo(p['reusableMm'] + p['scrapMm'], 1e-6));
      expect((p['bars'] as List).every((b) => b['remaining'] >= 0), isTrue);
    }
    expect(() => packBars([6000], 6000, 3, 500), throwsException);
  });
  test('sheet packing supports rotation and conserves area with no overlap',
      () {
    final p = packSheets([
      for (var j = 0; j < 8; j++)
        {'w': 900.0, 'h': 400.0, 'area': 360000.0, 'id': '$j'}
    ], 1000, 1200, 3);
    expect(p['purchaseM2'], closeTo(p['netM2'] + p['offcutM2'], 1e-9));
    for (final sheet in p['sheets']) {
      double usedHeight = 0;
      for (final row in sheet['rows']) {
        double usedWidth = 0;
        for (final rect in row['parts']) {
          usedWidth += rect['w'] + 3;
          expect(rect['h'] <= row['height'], isTrue);
        }
        expect(usedWidth - 3, lessThanOrEqualTo(1000));
        usedHeight += row['height'] + 3;
      }
      expect(usedHeight - 3, lessThanOrEqualTo(1200));
    }
    expect(
        () => packSheets([
              {'w': 2000, 'h': 2000, 'area': 4e6, 'id': 'x'}
            ], 1000, 1000, 3),
        throwsException);
  });
  test(
      'prices snapshotted in quotes, drawing and recipes survive offline backup',
      () async {
    final dir = await Directory.systemTemp.createTemp('drawing-store-');
    addTearDown(() => dir.delete(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    await s.addCustomer({'name': 'Usta', 'phone': '', 'address': ''});
    final d = newDrawing(), r = recipeFor(s.profiles.first);
    final input = {
      'drawing': d,
      'recipe': r,
      'profileId': s.profiles.first['id'],
      'quantity': 2
    };
    final q = await s.saveQuote({
      'items': [input],
      'customerId': s.customers.first['id'],
      'title': 'Chizma',
      'discount': 0,
      'installation': 0
    });
    final before = q['total'];
    r['prices']['frame'] = 100000;
    await s.saveProfile({...s.profiles.first, 'drawingRecipe': r});
    expect(s.quotes.first['total'], before);
    final backup = await s.exportBackup();
    expect(jsonDecode(backup)['quotes'][0]['items'][0]['drawing'], isNotNull);
    final restored = Store(directory: dir);
    await restored.init();
    expect(restored.quotes.first['total'], before);
    expect(restored.profiles.first['drawingRecipe']['prices']['frame'], 100000);
    expect(
        calculate(Map<String, dynamic>.from(restored.quotes.first['items'][0]),
            restored.profiles.first)['total'],
        before);
  });
}
