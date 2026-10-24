import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';
import 'package:romflow/design_engine.dart';

/// Three equal columns, 1500 × 1500.
DMap threeColumns() => {
      ...newDrawing(),
      'widthMm': 1500,
      'heightMm': 1500,
      'root': {
        'id': 's1',
        'axis': 'v',
        'ratio': 1 / 3,
        'a': newLeaf('left'),
        'b': {
          'id': 's2',
          'axis': 'v',
          'ratio': .5,
          'a': {...newLeaf('door'), 'opening': 'doorLeft'},
          'b': newLeaf('right'),
        },
      },
    };

void main() {
  final profile = sampleProfiles().first, recipe = recipeFor(profile);
  final f = (recipe['frameFace'] as num).toDouble();
  DrawingCell cell(DMap d, String id) =>
      layoutDrawing(d, recipe).cells.firstWhere((c) => c.node['id'] == id);
  double tall(DMap d, String id) => cell(d, id).box[3] - cell(d, id).box[1];
  double wide(DMap d, String id) => cell(d, id).box[2] - cell(d, id).box[0];

  test('pulling the door down moves only the door; the frame steps', () {
    final d = threeColumns();
    final door = resizeSection(d, recipe, 'door', 'bottom', 600);
    expect(door['heightMm'], 2100);
    expect(tall(door, 'door'), closeTo(tall(d, 'door') + 600, .01));
    // The windows on either side stay as they were, over the wall.
    for (final id in ['left', 'right']) {
      expect(tall(door, id), closeTo(tall(d, id), .01));
      expect(wide(door, id), closeTo(wide(d, id), .01));
      expect(cell(door, id).box[1], closeTo(cell(d, id).box[1], .01));
    }
    final l = layoutDrawing(door, recipe);
    // An upside-down T: eight corners, 600 mm steps either side.
    expect(l.outer.length, 8);
    expect(bounds(l.outer), [0, 0, 1500, 2100]);
    expect(polygonArea(l.outer), lessThan(1500 * 2100));
    // The door's clear opening keeps its width below the windows.
    expect(l.inner.length, 8);
    final doorBox = cell(door, 'door').box;
    expect(rectClip(l.inner, doorBox).length, greaterThanOrEqualTo(4));
    expect(polygonArea(rectClip(l.inner, doorBox)),
        closeTo((doorBox[2] - doorBox[0]) * (doorBox[3] - doorBox[1]), 20));
    // The imposts stop at the windows' bottom frame.
    for (final s in l.splits) {
      expect(s.b.y, closeTo(cell(door, 'left').box[3], .01));
    }
  });

  test('pulling the side windows up cuts them off the same way', () {
    var d = threeColumns();
    d = resizeSection(d, recipe, 'left', 'bottom', -500);
    d = resizeSection(d, recipe, 'right', 'bottom', -500);
    expect(d['heightMm'], 1500);
    expect(d['root']['a']['trim'], {'bottom': 500});
    final l = layoutDrawing(d, recipe);
    expect(l.outer.length, 8);
    expect(tall(d, 'left'), closeTo(1500 - 2 * f - 500, .01));
    expect(tall(d, 'door'), closeTo(1500 - 2 * f, .01));
    // Pulling one back down to the floor makes that side straight again.
    final back = resizeSection(d, recipe, 'left', 'bottom', 500);
    expect(back['root']['a']['trim'], isNull);
    expect(layoutDrawing(back, recipe).outer.length, 6);
  });

  test('the bill follows the stepped frame', () {
    final rect = threeColumns(),
        stepped = resizeSection(rect, recipe, 'door', 'bottom', 600);
    DMap calc(DMap d) => calculateDrawing(
        {'drawing': d, 'quantity': 1, 'recipe': recipe}, profile);
    final a = calc(rect), b = calc(stepped);
    // Eight frame pieces round the T.
    final outline = layoutDrawing(stepped, recipe).outer,
        perPiece = ((a['cuts']['frame']['netMm'] as num) - 6000) / 4;
    // Each piece is rounded up to a whole millimetre.
    expect(b['cuts']['frame']['netMm'],
        closeTo(perimeter(outline) + 8 * perPiece + 4, 4));
    // A T is as long round as its 1500 × 2100 bounding box.
    expect(perimeter(outline), closeTo(2 * (1500 + 2100), 1));
    expect(b['total'], greaterThan(a['total']));
    expect(layoutDrawing(stepped, recipe).cells.length, 3);
  });

  test('a section can also be pulled out at the top or the side', () {
    final d = threeColumns();
    final up = resizeSection(d, recipe, 'door', 'top', -200);
    expect(up['heightMm'], 1700);
    // Everything else keeps its place relative to the floor.
    expect(cell(up, 'left').box[3] - cell(up, 'left').box[1],
        closeTo(tall(d, 'left'), .01));
    expect(cell(up, 'left').box[3], closeTo(1700 - f, .01));
    final out = resizeSection(d, recipe, 'right', 'right', 250);
    expect(out['widthMm'], 1750);
    expect(wide(out, 'right'), closeTo(wide(d, 'right') + 250, .01));
    expect(wide(out, 'door'), closeTo(wide(d, 'door'), .01));
  });

  test('splitting a cut section keeps the cut; removing it keeps the extent',
      () {
    var d = resizeSection(threeColumns(), recipe, 'left', 'bottom', -500);
    // Split the cut window in two, one above the other.
    final leaf = findNode(d['root'] as DMap, 'left')!;
    final trim = leaf['trim'];
    leaf
      ..clear()
      ..addAll({
        'id': 'left-split',
        'axis': 'h',
        'ratio': .5,
        'trim': trim,
        'a': newLeaf('left-top'),
        'b': {...newLeaf('left-bottom'), 'trim': trim},
      });
    final top = tall(d, 'left-top'), bottom = tall(d, 'left-bottom');
    expect(top, closeTo(bottom, .01));
    expect(cell(d, 'left-bottom').box[3], closeTo(1500 - f - 500, .01));
    expect(subtreeTrim(d, recipe, 'left-split'), {'bottom': 500});
    expect(subtreeTrim(d, recipe, 's2'), isEmpty);
  });

  test('a cut that would leave less than 80 mm is refused', () {
    final d = threeColumns();
    expect(() => resizeSection(d, recipe, 'left', 'bottom', -1400),
        throwsException);
    expect(() => resizeSection(d, recipe, 'door', 'bottom', 5000),
        throwsException);
  });

  test('outline of a union of boxes', () {
    final t = boxUnion([
      [0, 0, 300, 100],
      [100, 100, 200, 300]
    ]);
    expect(t.length, 8);
    expect(signedArea(t), closeTo(300 * 100 + 100 * 200, 1e-6));
    expect(
        () => boxUnion([
              [0, 0, 100, 100],
              [100, 100, 200, 200]
            ]),
        throwsException);
  });
}
