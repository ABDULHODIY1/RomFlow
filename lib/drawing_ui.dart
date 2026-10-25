import 'drawing_controls.dart';
import 'workshop_field.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calculator.dart';
import 'design_engine.dart';
import 'store.dart';
import 'dialogs.dart';
import 'drawing_3d.dart';
import 'design_catalog.dart';
import 'in_place_page.dart';
import 'manufacturers.dart' show comparisonKeys;
import 'manufacturers_page.dart';
import 'adaptive_ui.dart';
import 'i18n.dart';

const _blue = Color(0xff206bc4);

/// Designs offered right on the desk; the catalog holds the rest.
const quickPresets = {
  'fixed',
  'single',
  'two',
  'twoOpen',
  'three',
  'transom',
  'door',
  'doubleDoor',
  'balcony',
  'arch',
};
DMap cloneMap(DMap v) => Map<String, dynamic>.from(jsonDecode(jsonEncode(v)));

/// A small picture of a drawn window for lists.
class WindowThumb extends StatelessWidget {
  final DMap drawing, recipe;
  const WindowThumb({super.key, required this.drawing, required this.recipe});
  @override
  Widget build(BuildContext context) =>
      DesignThumb(drawing: drawing, recipe: recipe);
}

class DrawingEditor extends StatefulWidget {
  final Store store;
  final DMap? initial;
  final bool startInVisualMode;

  /// App bar title; the drawing is a window of a smeta.
  final String title;

  const DrawingEditor({
    super.key,
    required this.store,
    this.initial,
    this.startInVisualMode = true,
    this.title = 'Yangi smeta',
  });
  @override
  State<DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<DrawingEditor> {
  late DMap drawing, recipe;
  late String profile;
  final width = TextEditingController(),
      height = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      rise = TextEditingController();
  final undo = <DMap>[], redo = <DMap>[];
  String selected = '1', tool = 'select';
  late bool visualMode;
  String palette = 'split',
      openingTool = 'left',
      fillTool = 'glass',
      hardwareTool = 'mesh';
  String? selectedFill;
  final dropCanvasKey = GlobalKey();
  DraftPayload? hoverPayload;
  Offset? hoverPoint;
  bool draggingPart = false, hoverSnapped = false;
  // Divider dragging: live readouts, snapping and the remove zone.
  List<(Offset, String)> guide = const [];
  double? snappedTo;
  Offset? lastPointer;
  Rect? trashZone;
  bool overTrash = false;
  // Live price, recomputed only when the document changes.
  String? priceKey, livePrice;
  final points = <V>[];
  String? error;
  DMap? report;
  int serial = 10;
  DrawingSplit? dragged;
  int? draggedVertex;

  /// The side of the chosen section being pulled, and the drawing before.
  ({String side, Offset at})? edge;
  DMap? edgeStart;
  bool draggingSize = false, editingGesture = false, dragCheckpoint = false;
  Offset? dragDown;

  /// Two fingers zoom and move the desk (1×–5×); one finger draws.
  double zoom = 1;
  Offset pan = Offset.zero;
  final pointers = <int, Offset>{};
  bool pinching = false;
  double pinchZoom = 1, pinchDistance = 1;
  Offset pinchPan = Offset.zero, pinchFocal = Offset.zero;

  /// The last tap, for a double tap that opens a section's settings.
  DateTime? lastTapAt;
  String? lastTapCell;
  CanvasTransform? dragTransform;
  double dragWidth = 0, dragHeight = 0;
  bool saving = false;

  /// Where the window goes (Zal, Oshxona…), shown in the smeta and PDF.
  String? label;

  /// The canvas shows a live 3D picture instead of the drawing.
  bool show3d = false;

  /// The drawing over the whole screen: tool rows and the bottom panel
  /// hidden until switched back.
  bool fullDesk = false;
  @override
  void initState() {
    super.initState();
    visualMode = widget.startInVisualMode;
    final item = widget.initial;
    label = item?['label'] as String?;
    profile = item?['profileId'] ??
        (widget.store.profiles.any((p) => p['id'] == 'series-akfa-simple-thick')
            ? 'series-akfa-simple-thick'
            : widget.store.profiles.first['id']);
    drawing = cloneMap(item?['drawing'] ?? newDrawing());
    recipe = cloneMap(
      item?['recipe'] ??
          recipeFor(
            widget.store.profiles.firstWhere((p) => p['id'] == profile),
          ),
    );
    quantity.text = '${item?['quantity'] ?? 1}';
    syncFields();
    selected = firstLeaf(Map<String, dynamic>.from(drawing['root']))['id'];
  }

  /// Opens the design catalog; the chosen design replaces the drawing and
  /// keeps its size unless another one was typed there.
  Future<void> openCatalog() async {
    final choice = await openDesignCatalog(
      context,
      recipe: recipe,
      store: widget.store,
      width: drawing['widthMm'],
      height: drawing['heightMm'],
      count: int.tryParse(quantity.text) ?? 1,
      room: label,
      replacing: true,
    );
    if (!mounted || choice == null) return;
    change(() {
      drawing = choice.drawing();
      selected = firstLeaf(drawing['root'])['id'];
      selectedFill = null;
      tool = 'select';
      points.clear();
      syncFields();
    });
    setState(() {
      quantity.text = '${choice.count}';
      label = choice.room;
    });
  }

  void syncFields() {
    width.text = '${drawing['widthMm']}';
    height.text = '${drawing['heightMm']}';
    rise.text = '${drawing['riseMm']}';
  }

  DMap firstLeaf(DMap n) =>
      n['axis'] == null ? n : firstLeaf(Map<String, dynamic>.from(n['a']));
  DMap? node(String id, [DMap? n]) {
    n ??= drawing['root'];
    if (n!['id'] == id) return n;
    if (n['axis'] == null) {
      return n['infill'] == null ? null : node(id, n['infill']);
    }
    return node(id, n['a']) ?? node(id, n['b']);
  }

  void checkpoint() {
    undo.add(cloneMap(drawing));
    if (undo.length > 60) undo.removeAt(0);
    redo.clear();
    report = null;
    error = null;
  }

  void change(void Function() fn) {
    final before = cloneMap(drawing);
    checkpoint();
    try {
      fn();
      layoutDrawing(drawing, recipe);
      setState(() {});
    } catch (e) {
      drawing = before;
      if (node(selected) == null) selected = firstLeaf(drawing['root'])['id'];
      syncFields();
      undo.removeLast();
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  void travel(bool back) {
    final source = back ? undo : redo, target = back ? redo : undo;
    if (source.isEmpty) return;
    target.add(cloneMap(drawing));
    drawing = source.removeLast();
    if (node(selected) == null) selected = firstLeaf(drawing['root'])['id'];
    if (selectedFill != null && node(selectedFill!) == null) {
      selectedFill = null;
    }
    syncFields();
    setState(() {
      report = null;
      error = null;
    });
  }

  void resize() {
    final w = num.tryParse(width.text), h = num.tryParse(height.text);
    final arch = num.tryParse(rise.text);
    if (w == null ||
        h == null ||
        !w.isFinite ||
        !h.isFinite ||
        w < 300 ||
        h < 300 ||
        w > 6000 ||
        h > 6000 ||
        (drawing['shape'] == 'arch' &&
            (arch == null || !arch.isFinite || arch <= 0))) {
      setState(
        () => error =
            'Eni va bo‘yi 300–6000 mm bo‘lsin. Kiritilgan qiymatni tekshiring.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Tx(error!)));
      return;
    }
    num whole(num v) => v == v.roundToDouble() ? v.toInt() : v;
    change(() {
      drawing['widthMm'] = whole(num.parse(width.text.replaceAll(',', '.')));
      drawing['heightMm'] = whole(num.parse(height.text.replaceAll(',', '.')));
      drawing['riseMm'] = arch ?? drawing['riseMm'];
      if (drawing['shape'] == 'circle') {
        drawing['heightMm'] = drawing['widthMm'];
      }
      final w = drawing['widthMm'], h = drawing['heightMm'];
      if (w < 300 || h < 300 || w > 6000 || h > 6000) {
        throw Exception('O‘lcham 300–6000 mm');
      }
    });
    syncFields();
  }

  void split(DrawingCell c, bool vertical, double pos) {
    change(() {
      final b = c.box, k = vertical ? 0 : 1;
      final ratio = ((pos - b[k]) / (b[k + 2] - b[k])).clamp(.1, .9);
      final old = node(c.node['id'])!, trim = old['trim'];
      final left = {
            ...cloneMap(old),
            'id': 'c${DateTime.now().microsecondsSinceEpoch}-${serial++}',
          }..remove('trim'),
          right = {
            ...cloneMap(old),
            'id': 'c${DateTime.now().microsecondsSinceEpoch}-${serial++}',
          }..remove('trim');
      old.clear();
      old.addAll({
        'id': 's${DateTime.now().microsecondsSinceEpoch}-${serial++}',
        'axis': vertical ? 'v' : 'h',
        'ratio': ratio,
        'a': left,
        'b': right,
        // A section cut short of the frame stays cut as a whole.
        if (trim != null) 'trim': trim,
      });
      selected = left['id'];
      tool = 'select';
    });
  }

  void splitInfill(bool vertical) {
    change(() {
      final owner = node(selected)!;
      owner['infill'] ??= {
        'id': 'f${serial++}',
        'fill': owner['fill'] ?? 'glass',
      };
      final root = owner['infill'] as DMap;
      final current = selectedFill == null
          ? firstLeaf(root)
          : node(selectedFill!, root) ?? firstLeaf(root);
      if (current['axis'] != null) throw Exception('Ichki bo‘limni tanlang');
      final a = {
            ...current,
            'id': 'f${DateTime.now().microsecondsSinceEpoch}-${serial++}',
          },
          b = {
            ...current,
            'id': 'f${DateTime.now().microsecondsSinceEpoch}-${serial++}',
          };
      final id = current['id'];
      current.clear();
      current.addAll({
        'id': id,
        'axis': vertical ? 'v' : 'h',
        'ratio': .5,
        'a': a,
        'b': b,
      });
      selectedFill = a['id'];
    });
  }

  Future<void> partsPalette() async {
    final owner = node(selected);
    if (owner == null || owner['axis'] != null) return;
    final result = await showGlassSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Tx(
                  'Detallardan yig‘ish',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Tx(
                  'Avval chizmada bo‘limni tanlang. Detallar shu bo‘limga ulanadi; 3D va sarf birga yangilanadi.',
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    for (final item in <(String, String, String, IconData)>[
                      (
                        'v',
                        'Tik impost',
                        'Tanlang, so‘ng chizmada o‘rnini bosing',
                        Icons.vertical_split,
                      ),
                      (
                        'h',
                        'Yotiq impost',
                        'Tanlang, so‘ng chizmada o‘rnini bosing',
                        Icons.horizontal_split,
                      ),
                      (
                        'innerV',
                        'Qanot ichiga tik profil',
                        'Shu qanot to‘ldirmasini ajratish',
                        Icons.grid_view,
                      ),
                      (
                        'innerH',
                        'Qanot ichiga yotiq profil',
                        'Qulf va petlya soni ko‘paymaydi',
                        Icons.table_rows,
                      ),
                      for (final entry in openingNames.entries)
                        (
                          'open:${entry.key}',
                          entry.key == 'fixed'
                              ? 'Qanotni olish'
                              : 'Qanot: ${entry.value}',
                          'Profil, petlya va tutqich to‘plami',
                          Icons.door_front_door,
                        ),
                      (
                        'fill:glass',
                        'Shisha',
                        'Tanlangan ichki to‘ldirma yoki butun bo‘lim',
                        Icons.window,
                      ),
                      (
                        'fill:panel',
                        'Sendvich panel',
                        'Tanlangan ichki to‘ldirma yoki butun bo‘lim',
                        Icons.rectangle_outlined,
                      ),
                      (
                        'fill:lambris',
                        'Lambir',
                        'Tanlangan ichki to‘ldirma yoki butun bo‘lim',
                        Icons.view_week,
                      ),
                      (
                        'fill:empty',
                        'To‘ldirmani olish',
                        'Profil va furnitura saqlanadi',
                        Icons.crop_square,
                      ),
                      (
                        'mesh',
                        'Setka qo‘shish / olish',
                        'Ochilgan qanotga tegishli',
                        Icons.grid_on,
                      ),
                      (
                        'lock',
                        'Yana bitta qulf / zapor',
                        'Ochilgan faol qanotga tegishli',
                        Icons.lock_outline,
                      ),
                      (
                        'closer',
                        'Dovodchik qo‘shish / olish',
                        'Eshik qanotiga tegishli',
                        Icons.settings_input_component,
                      ),
                      (
                        'threshold',
                        'Ostona qo‘shish / olish',
                        'Eshik qanotiga tegishli',
                        Icons.horizontal_rule,
                      ),
                    ])
                      GlassControl(
                          child: ListTile(
                        leading: Icon(item.$4, color: _blue),
                        title: Tx(item.$2),
                        subtitle: Tx(item.$3),
                        onTap: () => Navigator.pop(context, item.$1),
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'v' || result == 'h') {
      setState(() => tool = result);
      return;
    }
    if (result == 'innerV' || result == 'innerH') {
      splitInfill(result == 'innerV');
      return;
    }
    change(() {
      if (result.startsWith('open:')) {
        owner['opening'] = result.substring(5);
      } else if (result.startsWith('fill:')) {
        final sub = owner['infill'] as DMap?;
        final target = sub == null
            ? owner
            : (selectedFill == null
                ? firstLeaf(sub)
                : node(selectedFill!, sub) ?? firstLeaf(sub));
        target['fill'] = result.substring(5);
      } else {
        final opening = owner['opening'] as String;
        if (opening == 'fixed') {
          throw Exception('Avval ochiladigan qanot qo‘shing');
        }
        if (result == 'lock') {
          if (opening == 'passive') {
            throw Exception('Passiv qanotga shpingalet ishlatiladi');
          }
          owner['locks'] = math.min(
            10,
            (owner['locks'] as num? ?? 1).toInt() + 1,
          );
        } else if (result == 'mesh') {
          owner['mesh'] = owner['mesh'] != true;
        } else {
          if (!opening.startsWith('door') && opening != 'passive') {
            throw Exception('Bu detal eshik qanoti uchun');
          }
          owner[result] = result == 'threshold'
              ? owner[result] == false
              : owner[result] != true;
        }
      }
    });
  }

  Future<void> saveAsTemplate() async {
    final text = TextEditingController();
    final name = await showSettledDialog<String>(
      context: context,
      builder: (c) => GlassAlertDialog(
        title: const Tx('Andoza nomi'),
        content: GlassControl(
          child: TextField(
            controller: text,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('Masalan: ikki qanotli rom'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Tx('Bekor'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, text.text.trim()),
            child: const Tx('Saqlash'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name == null || !mounted) return;
    try {
      await widget.store.saveDrawingTemplate(name, item());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Tx('Andoza saqlandi')));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> loadTemplate() async {
    final selectedTemplate = await showGlassSheet<DMap>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            const Tx(
              'Saqlangan andozalar',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (widget.store.drawingTemplates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Tx('Avval chizmani andoza qilib saqlang.'),
              ),
            for (final t in widget.store.drawingTemplates)
              GlassControl(
                  child: ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: Tx(t['name']),
                subtitle: Tx(
                  '${t['item']['widthMm']} × ${t['item']['heightMm']} mm',
                ),
                onTap: () => Navigator.pop(c, t),
              )),
          ],
        ),
      ),
    );
    if (selectedTemplate == null || !mounted) return;
    final data = cloneMap(selectedTemplate['item']);
    undo.clear();
    redo.clear();
    setState(() {
      drawing = cloneMap(data['drawing']);
      recipe = cloneMap(data['recipe']);
      profile = data['profileId'];
      quantity.text = '${data['quantity']}';
      selected = firstLeaf(drawing['root'])['id'];
      selectedFill = null;
      tool = 'select';
      syncFields();
    });
  }

  void beginDrag(Offset local, CanvasTransform t, DrawingLayout layout) {
    dragged = null;
    draggedVertex = null;
    edge = null;
    edgeStart = null;
    draggingSize = false;
    overTrash = false;
    snappedTo = null;
    guide = const [];
    dragDown = local;
    lastPointer = local;
    dragTransform = t;
    dragWidth = (drawing['widthMm'] as num).toDouble();
    dragHeight = (drawing['heightMm'] as num).toDouble();
    if (tool == 'size') {
      draggingSize = (local - t.to(V(dragWidth, dragHeight))).distance < 30;
      return;
    }
    if (tool == 'vertices') {
      double best = 24;
      final vertices = drawing['vertices'] as List;
      for (var j = 0; j < vertices.length; j++) {
        final p = V(
          (vertices[j][0] as num) * dragWidth,
          (vertices[j][1] as num) * dragHeight,
        );
        final distance = (t.to(p) - local).distance;
        if (distance < best) {
          best = distance;
          draggedVertex = j;
        }
      }
      return;
    }
    if (tool != 'select') return;
    if (visualMode) {
      for (final h in sectionHandles(layout, t)) {
        if ((h.at - local).distance < 24) {
          edge = h;
          edgeStart = cloneMap(drawing);
          return;
        }
      }
    }
    dragged = splitAt(local, t, layout);
  }

  /// Grips on the sides of the chosen section that can be pulled: on an
  /// impost it moves, on the bottom or right frame the window grows.
  List<({String side, Offset at})> sectionHandles(
    DrawingLayout layout,
    CanvasTransform t,
  ) {
    final cell =
        layout.cells.where((c) => c.node['id'] == selected).firstOrNull;
    if (cell == null) return const [];
    final b = bounds(cell.polygon),
        sides = sectionSides(drawing, selected),
        cx = (b[0] + b[2]) / 2,
        cy = (b[1] + b[3]) / 2,
        small = t.scale * math.min(b[2] - b[0], b[3] - b[1]) < 70;
    double half(String side) =>
        ((sides[side] == null ? recipe['frameFace'] : recipe['mullionFace'])
                as num)
            .toDouble() /
        2;
    return [
      for (final side in sides.keys)
        if (!small || side == 'right' || side == 'bottom')
          (
            side: side,
            at: t.to(switch (side) {
              'right' => V(b[2] + half(side), cy),
              'left' => V(b[0] - half(side), cy),
              'top' => V(cx, b[1] - half(side)),
              _ => V(cx, b[3] + half(side)),
            }),
          ),
    ];
  }

  /// Pulls the chosen side by the pointer's travel, in 5 mm steps.
  void pullEdge(Offset local, CanvasTransform t) {
    final grip = edge, start = edgeStart;
    if (grip == null || start == null) return;
    final horizontal = grip.side == 'left' || grip.side == 'right';
    final travel =
        horizontal ? local.dx - dragDown!.dx : local.dy - dragDown!.dy;
    final delta = (travel / t.scale / 5).round() * 5.0;
    try {
      final next = resizeSection(start, recipe, selected, grip.side, delta);
      drawing = next;
      syncFields();
      final cell = layoutDrawing(
        drawing,
        recipe,
      ).cells.firstWhere((c) => c.node['id'] == selected);
      final size =
          horizontal ? cell.box[2] - cell.box[0] : cell.box[3] - cell.box[1];
      guide = [
        (
          local + (horizontal ? const Offset(0, -34) : const Offset(46, 0)),
          '${size.round()} mm',
        ),
      ];
      setState(() => error = null);
    } catch (_) {
      // Past the smallest or largest size: the side stays where it was.
    }
  }

  /// The impost (main or inside a sash) under [local], if any.
  DrawingSplit? splitAt(Offset local, CanvasTransform t, DrawingLayout layout) {
    final p = t.from(local);
    double best = 22 / t.scale;
    DrawingSplit? hit;
    final splits = [
      ...layout.splits,
      for (final c in layout.cells)
        if (c.node['infill'] != null) ...layoutInfill(c, recipe).splits,
    ];
    for (final split in splits) {
      final distance = distanceToSegment(p, split.a, split.b);
      if (distance < best) {
        best = distance;
        hit = split;
      }
    }
    return hit;
  }

  /// A second finger came down: the edit the first one began is undone,
  /// and the fingers zoom instead.
  void cancelEdit() {
    if (dragCheckpoint && undo.isNotEmpty) {
      drawing = cloneMap(undo.removeLast());
    }
    dragCheckpoint = false;
    dragged = null;
    draggedVertex = null;
    draggingSize = false;
    edge = null;
    edgeStart = null;
    dragTransform = null;
    snappedTo = null;
    guide = const [];
    overTrash = false;
    editingGesture = false;
  }

  void startPinch() {
    final p = pointers.values.toList();
    cancelEdit();
    setState(() {
      pinching = true;
      pinchZoom = zoom;
      pinchPan = pan;
      pinchFocal = (p[0] + p[1]) / 2;
      pinchDistance = math.max(1, (p[0] - p[1]).distance);
    });
  }

  void updatePinch(Size size) {
    final p = pointers.values.take(2).toList();
    if (p.length < 2) return;
    final focal = (p[0] + p[1]) / 2;
    final next =
        (pinchZoom * (p[0] - p[1]).distance / pinchDistance).clamp(1.0, 5.0);
    // The point of the drawing under the fingers stays under them.
    final content = (pinchFocal - pinchPan) / pinchZoom;
    final moved = focal - content * next;
    setState(() {
      zoom = next;
      pan = Offset(
        moved.dx.clamp(size.width * (1 - next), 0.0),
        moved.dy.clamp(size.height * (1 - next), 0.0),
      );
    });
  }

  void resetZoom() => setState(() {
        zoom = 1;
        pan = Offset.zero;
      });

  void endDrag() {
    final removing = dragged != null && overTrash && dragCheckpoint;
    final id = dragged?.node['id'] as String?;
    dragged = null;
    draggedVertex = null;
    draggingSize = false;
    edge = null;
    edgeStart = null;
    dragTransform = null;
    snappedTo = null;
    guide = const [];
    overTrash = false;
    if (removing && undo.isNotEmpty) {
      // The checkpoint taken when the drag began holds the pre-drag drawing,
      // so a single undo brings the impost back exactly where it was.
      drawing = cloneMap(undo.last);
      removeSplit(id!);
    }
    if (editingGesture || removing) setState(() => editingGesture = false);
  }

  void updateDrag(Offset local) {
    final t = dragTransform;
    if (t == null) return;
    lastPointer = local;
    if (edge != null) {
      pullEdge(local, t);
      return;
    }
    if (dragged != null) {
      final over = trashZone?.contains(local) ?? false;
      if (over != overTrash) {
        overTrash = over;
        if (over) HapticFeedback.mediumImpact();
      }
      moveDivider(local, t);
      return;
    }
    if (!draggingSize && draggedVertex == null) return;
    final before = cloneMap(drawing);
    if (draggingSize) {
      final delta = local - dragDown!;
      final w = (dragWidth + delta.dx / t.scale).round().clamp(300, 6000),
          h = (dragHeight + delta.dy / t.scale).round().clamp(300, 6000);
      drawing['widthMm'] = w;
      drawing['heightMm'] = drawing['shape'] == 'circle' ? w : h;
      if (drawing['shape'] == 'arch') {
        drawing['riseMm'] = math.min<num>(
          drawing['riseMm'] as num,
          drawing['heightMm'] as num,
        );
      }
    } else {
      final v = t.from(local);
      drawing['vertices'][draggedVertex!] = [
        (v.x / dragWidth).clamp(0, 1),
        (v.y / dragHeight).clamp(0, 1),
      ];
    }
    try {
      layoutDrawing(drawing, recipe);
      syncFields();
      setState(() => error = null);
    } catch (_) {
      drawing = before;
    }
  }

  /// Snaps [at] (mm along axis [k]) inside a section [box] to halves, thirds,
  /// quarters and to other imposts, and reports the gross section extent.
  ({double at, bool snapped, double from, double to}) snapInBox(
    DrawingLayout l,
    List<double> box,
    int k,
    double at,
    double toleranceMm, {
    String? exclude,
    bool main = true,
  }) {
    final total = (drawing[k == 0 ? 'widthMm' : 'heightMm'] as num).toDouble(),
        inner = bounds(l.inner),
        face = (recipe['mullionFace'] as num).toDouble();
    final from = !main
            ? box[k]
            : (box[k] - inner[k]).abs() < .5
                ? 0.0
                : box[k] - face / 2,
        to = !main
            ? box[k + 2]
            : (box[k + 2] - inner[k + 2]).abs() < .5
                ? total
                : box[k + 2] + face / 2;
    final candidates = <double>[
      for (final q in const [1 / 2, 1 / 3, 2 / 3, 1 / 4, 3 / 4])
        from + (to - from) * q,
      if (main)
        for (final s in l.splits)
          if (s.node['id'] != exclude && (s.node['axis'] == 'v') == (k == 0))
            k == 0 ? s.a.x : s.a.y,
    ];
    double? best;
    for (final c in candidates) {
      if (c <= box[k] + 45 || c >= box[k + 2] - 45) continue;
      if ((c - at).abs() <= toleranceMm &&
          (best == null || (c - at).abs() < (best - at).abs())) {
        best = c;
      }
    }
    return (at: best ?? at, snapped: best != null, from: from, to: to);
  }

  List<(Offset, String)> readouts(
    CanvasTransform t,
    List<double> box,
    int k,
    double at,
    double from,
    double to,
  ) {
    final mid = (box[1 - k] + box[3 - k]) / 2;
    V point(double along) => k == 0 ? V(along, mid) : V(mid, along);
    return [
      (t.to(point((from + at) / 2)), '${(at - from).round()}'),
      (t.to(point((at + to) / 2)), '${(to - at).round()}'),
    ];
  }

  void moveDivider(Offset local, CanvasTransform transform) {
    final split = dragged;
    if (split == null) return;
    final layout = layoutDrawing(drawing, recipe);
    final main = layout.splits.any((s) => s.node['id'] == split.node['id']);
    final p = transform.from(local),
        k = split.node['axis'] == 'v' ? 0 : 1,
        target = node(split.node['id'])!;
    final old = target['ratio'];
    final span = split.box[k + 2] - split.box[k];
    final raw = (k == 0 ? p.x : p.y)
        .clamp(split.box[k] + span * .05, split.box[k + 2] - span * .05)
        .toDouble();
    final snap = snapInBox(
      layout,
      split.box,
      k,
      raw,
      12 / transform.scale,
      exclude: split.node['id'],
      main: main,
    );
    if (snap.snapped && snappedTo != snap.at) HapticFeedback.selectionClick();
    snappedTo = snap.snapped ? snap.at : null;
    target['ratio'] = ((snap.at - split.box[k]) / span).clamp(.05, .95);
    try {
      layoutDrawing(drawing, recipe);
      guide = readouts(transform, split.box, k, snap.at, snap.from, snap.to);
      setState(() {});
    } catch (_) {
      target['ratio'] = old;
    }
  }

  /// Removes an impost: the two sections become one with the first one's
  /// opening, fill and fittings.
  void removeSplit(String id) {
    final target = findNode(drawing['root'] as DMap, id);
    if (target == null || target['axis'] == null) return;
    final keep = target['a'] as DMap;
    final replacement = keep['axis'] == null
        ? cloneMap(keep)
        : Map<String, dynamic>.from(newLeaf('x'));
    replacement['id'] = 'm${DateTime.now().microsecondsSinceEpoch}-${serial++}';
    _keepExtent(replacement, id);
    target
      ..clear()
      ..addAll(replacement);
    if (node(selected) == null) selected = replacement['id'];
    selectedFill = null;
    report = null;
    try {
      layoutDrawing(drawing, recipe);
      error = null;
    } catch (e) {
      error = '$e';
    }
    HapticFeedback.mediumImpact();
    if (mounted) {
      toast('Impost olib tashlandi. “Orqaga” bilan qaytaring.');
    }
  }

  /// [leaf] replaces subtree [id]: it reaches as far as the sections it
  /// stands for, so a door merged with a window over a wall stays a door.
  void _keepExtent(DMap leaf, String id) {
    try {
      final trim = subtreeTrim(drawing, recipe, id);
      if (trim.isEmpty) {
        leaf.remove('trim');
      } else {
        leaf['trim'] = trim;
      }
    } catch (_) {
      leaf.remove('trim');
    }
  }

  void merge() {
    bool visit(DMap n) {
      if (n['axis'] == null) return false;
      if (n['a']['id'] == selected || n['b']['id'] == selected) {
        final id = n['id'];
        final kept = n['a']['id'] == selected ? n['a'] : n['b'];
        final merged =
            kept['axis'] == null ? {...cloneMap(kept), 'id': id} : newLeaf(id);
        _keepExtent(merged, id);
        n.clear();
        n.addAll(merged);
        selected = id;
        return true;
      }
      return visit(n['a']) || visit(n['b']);
    }

    change(() {
      if (!visit(drawing['root'])) {
        throw Exception('Birlashtirish uchun bo‘lingan bo‘limni tanlang');
      }
    });
  }

  int _quantity() {
    final n = int.tryParse(quantity.text);
    if (n == null || n < 1 || n > 1000) {
      throw Exception('Konstruksiya sonini 1–1000 oralig‘ida kiriting');
    }
    return n;
  }

  DMap item() => {
        'profileId': profile,
        'template': 'drawing',
        'drawing': cloneMap(drawing),
        'recipe': cloneMap(recipe),
        'quantity': _quantity(),
        'widthMm': drawing['widthMm'],
        'heightMm': drawing['heightMm'],
        'color': 'white',
        'mosquito': false,
        if (label != null) 'label': label,
      };
  DMap calculate() {
    return calculateDrawing(
      item(),
      widget.store.profiles.firstWhere((p) => p['id'] == profile),
    );
  }

  /// Sizes typed in the detailed settings count without a separate
  /// “apply” step.
  void applyTypedSize() {
    if (num.tryParse(width.text.replaceAll(',', '.')) != drawing['widthMm'] ||
        num.tryParse(height.text.replaceAll(',', '.')) != drawing['heightMm'] ||
        (drawing['shape'] == 'arch' &&
            num.tryParse(rise.text.replaceAll(',', '.')) !=
                drawing['riseMm'])) {
      resize();
    }
  }

  void preview() {
    applyTypedSize();
    try {
      setState(() {
        report = calculate();
        error = null;
      });
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  @override
  void dispose() {
    for (final c in [width, height, quantity, rise]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DrawingLayout? layout;
    try {
      layout = layoutDrawing(drawing, recipe);
    } catch (e) {
      error = '$e';
    }
    final n = node(selected);
    final leaf = n != null && n['axis'] == null ? n : null;
    if (visualMode) return visualWorkspace(layout, leaf);
    return Scaffold(
      appBar: GlassAppBar(
        title: const Tx('Batafsil sozlash'),
        actions: [
          IconButton(
            tooltip: tr('Chizma stoliga qaytish'),
            onPressed: () {
              applyTypedSize();
              setState(() => visualMode = true);
            },
            icon: const Icon(Icons.draw_outlined),
          ),
          IconButton(
            tooltip: tr('Detallardan yig‘ish'),
            onPressed: partsPalette,
            icon: const Icon(Icons.add_box_outlined),
          ),
          IconButton(
            tooltip: tr('Orqaga'),
            onPressed: undo.isEmpty ? null : () => travel(true),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: tr('Qaytarish'),
            onPressed: redo.isEmpty ? null : () => travel(false),
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: editingGesture ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(16),
          children: [
            const Tx(
              'KONSTRUKSIYA → MATERIALLAR → RASKROY',
              style: TextStyle(
                fontSize: 11,
                color: _blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: partsPalette,
              icon: const Icon(Icons.add_box_outlined),
              label: const Tx('Detallardan yig‘ish'),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: saveAsTemplate,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Tx('Andoza saqlash'),
                ),
                TextButton.icon(
                  onPressed: loadTemplate,
                  icon: const Icon(Icons.folder_open),
                  label: const Tx('Andozalar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassControl(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: profile,
                decoration: InputDecoration(
                  labelText: tr('Profil tizimi / seriya'),
                ),
                items: [
                  for (final p in widget.store.profiles)
                    DropdownMenuItem(value: p['id'], child: Tx(p['name'])),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  final next = recipeFor(
                    widget.store.profiles.firstWhere((p) => p['id'] == v),
                  );
                  try {
                    layoutDrawing(drawing, next);
                    setState(() {
                      profile = v;
                      recipe = cloneMap(next);
                      report = null;
                    });
                  } catch (e) {
                    setState(() => error = '$e');
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            GlassControl(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('glazing-${recipe['glazingType'] ?? 'single'}'),
                initialValue: recipe['glazingType'] ?? 'single',
                decoration: InputDecoration(
                  labelText: tr('Shisha qavatlari'),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'single',
                    child: Tx('1 oynali • bitta shisha'),
                  ),
                  DropdownMenuItem(
                    value: 'double',
                    child: Tx('2 oynali • shisha + ajratgich + shisha'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  recipe['glazingType'] = v;
                  report = null;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Tx(
                'Shisha: ${GlazingSpec(recipe).label} • jami ${GlazingSpec(recipe).totalMm.toStringAsFixed(1)} mm',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 12),
            GlassControl(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey(drawing['shape']),
                initialValue: drawing['shape'],
                decoration: InputDecoration(labelText: tr('Tashqi shakl')),
                items: [
                  for (final e in shapeNames.entries)
                    DropdownMenuItem(value: e.key, child: Tx(e.value)),
                ],
                onChanged: (v) => change(() {
                  drawing['shape'] = v;
                  if (v == 'circle') {
                    drawing['heightMm'] = drawing['widthMm'];
                    syncFields();
                  }
                  if (v == 'arch') {
                    drawing['riseMm'] = math.min<num>(
                      drawing['riseMm'] as num,
                      drawing['heightMm'] as num,
                    );
                  }
                  // Keep the divisions when they still fit the new outline.
                  try {
                    layoutDrawing(drawing, recipe);
                  } catch (_) {
                    drawing['root'] = newLeaf('1');
                  }
                  selected = firstLeaf(drawing['root'])['id'];
                  points.clear();
                }),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: numField(width, 'Eni, mm')),
                const SizedBox(width: 10),
                Expanded(child: numField(height, 'Bo‘yi, mm')),
              ],
            ),
            if (drawing['shape'] == 'arch')
              numField(rise, 'Arka ko‘tarilishi, mm'),
            numField(quantity, 'Konstruksiya soni'),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  resize();
                },
                icon: const Icon(Icons.check),
                label: const Tx('O‘lchamni qo‘llash'),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              children: [
                for (final e in {
                  'select': 'Tanlash / surish',
                  'v': 'Tik bo‘lish',
                  'h': 'Yotiq bo‘lish',
                  'size': 'O‘lchamni tortish',
                  if (drawing['shape'] == 'custom')
                    'vertices': 'Kontur nuqtalari',
                  if (drawing['shape'] == 'custom') 'outline': 'Kontur chizish',
                }.entries)
                  GlassControl(
                    child: ChoiceChip(
                      label: Tx(e.value),
                      selected: tool == e.key,
                      onSelected: (_) => setState(() {
                        tool = e.key;
                        points.clear();
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Tx(
              tool == 'outline'
                  ? 'Kontur bo‘ylab nuqtalarni ketma-ket bosing, so‘ng “Konturni qo‘llash”.'
                  : tool == 'select'
                      ? 'Bo‘limni bosing. Ko‘k impost tutqichini surib bo‘lim enini/bo‘yini o‘zgartiring.'
                      : tool == 'size'
                          ? 'Pastki o‘ng burchakdagi tutqichni torting. Raqamli o‘lchamlarni yuqoridan ham kiritsa bo‘ladi.'
                          : tool == 'vertices'
                              ? 'Sariq kontur nuqtasini tortib shaklni o‘zgartiring. Kontur qavariq bo‘lib qoladi.'
                              : 'Bo‘lish chizig‘i o‘tadigan joyni bosing.',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                try {
                  layoutDrawing(drawing, recipe);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => View3D(
                        drawing: cloneMap(drawing),
                        recipe: cloneMap(recipe),
                        calculation: calculate(),
                        returnToEditor: true,
                        aiKey: widget.store.aiKey,
                      ),
                    ),
                  );
                } catch (e) {
                  setState(() => error = '$e');
                }
              },
              icon: const Icon(Icons.view_in_ar),
              label: const Tx('3D ko‘rinish • ochilish animatsiyasi'),
            ),
            drawingCanvas(layout),
            if (tool == 'outline')
              Wrap(
                spacing: 10,
                children: [
                  TextButton(
                    onPressed: points.isEmpty
                        ? null
                        : () => setState(() => points.removeLast()),
                    child: const Tx('Oxirgi nuqtani olish'),
                  ),
                  FilledButton(
                    onPressed: points.length < 3
                        ? null
                        : () => change(() {
                              drawing['vertices'] = [
                                for (final p in points) [p.x, p.y],
                              ];
                              drawing['root'] = newLeaf('1');
                              selected = '1';
                              tool = 'select';
                              points.clear();
                            }),
                    child: const Tx('Konturni qo‘llash'),
                  ),
                ],
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Tx(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (leaf != null && recipe['glazingType'] == 'double') ...[
              GlassControl(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Tx('Shishalar orasidagi oltin shpros'),
                  subtitle: const Tx('Chet ajratgichidan alohida bezak'),
                  value: leaf['shpros'] == true,
                  onChanged: (v) => change(() => leaf['shpros'] = v),
                ),
              ),
              if (leaf['shpros'] == true) ...[
                Row(
                  children: [
                    const Expanded(child: Tx('Tik shpros')),
                    IconButton(
                      onPressed: () => change(
                        () => leaf['shprosV'] = math.max(
                          0,
                          (leaf['shprosV'] as num? ?? 1).toInt() - 1,
                        ),
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Tx('${leaf['shprosV'] ?? 1}'),
                    IconButton(
                      onPressed: () => change(
                        () => leaf['shprosV'] = math.min(
                          8,
                          (leaf['shprosV'] as num? ?? 1).toInt() + 1,
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(child: Tx('Yotiq shpros')),
                    IconButton(
                      onPressed: () => change(
                        () => leaf['shprosH'] = math.max(
                          0,
                          (leaf['shprosH'] as num? ?? 3).toInt() - 1,
                        ),
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Tx('${leaf['shprosH'] ?? 3}'),
                    IconButton(
                      onPressed: () => change(
                        () => leaf['shprosH'] = math.min(
                          8,
                          (leaf['shprosH'] as num? ?? 3).toInt() + 1,
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                GlassControl(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Tx('Shpros bezak tugunlari'),
                    value: leaf['rosettes'] == true,
                    onChanged: (v) => change(() => leaf['rosettes'] = v),
                  ),
                ),
              ],
            ],
            if (leaf != null) ...[
              const SizedBox(height: 16),
              Tx(
                'Tanlangan bo‘lim • ${layout?.cells.indexWhere((c) => c.node['id'] == selected) != null ? (layout!.cells.indexWhere((c) => c.node['id'] == selected) + 1) : selected}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('$selected-${leaf['opening']}'),
                  initialValue: leaf['opening'],
                  decoration: InputDecoration(
                    labelText: tr('Ochilishi (xonadan ko‘rinish)'),
                  ),
                  items: [
                    for (final e in openingNames.entries)
                      DropdownMenuItem(value: e.key, child: Tx(e.value)),
                  ],
                  onChanged: (v) => change(() => leaf['opening'] = v),
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('$selected-${leaf['fill']}'),
                  initialValue: leaf['fill'],
                  decoration: InputDecoration(labelText: tr('To‘ldirma')),
                  items: const [
                    DropdownMenuItem(value: 'glass', child: Tx('Shisha')),
                    DropdownMenuItem(
                      value: 'panel',
                      child: Tx('Sendvich panel'),
                    ),
                    DropdownMenuItem(value: 'lambris', child: Tx('Lambir')),
                    DropdownMenuItem(
                      value: 'empty',
                      child: Tx('Bo‘sh (to‘ldirmasiz)'),
                    ),
                  ],
                  onChanged: (v) => change(() => leaf['fill'] = v),
                ),
              ),
              if (leaf['opening'] != 'fixed') ...[
                GlassControl(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Tx('Tashqariga ochiladi'),
                    subtitle: const Tx('O‘chiq bo‘lsa: ichkariga'),
                    value: leaf['outward'] == true,
                    onChanged: (v) => change(() => leaf['outward'] = v),
                  ),
                ),
                GlassControl(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Tx('Shu qanotga setka'),
                    value: leaf['mesh'] == true,
                    onChanged: (v) => change(() => leaf['mesh'] = v),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(child: Tx('Qulf / zapor soni')),
                    IconButton(
                      onPressed: () => change(
                        () => leaf['locks'] = math.max<int>(
                          0,
                          ((leaf['locks'] ?? 1) as num).toInt() - 1,
                        ),
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Tx('${leaf['locks'] ?? 1}'),
                    IconButton(
                      onPressed: () => change(
                        () => leaf['locks'] = math.min<int>(
                          10,
                          ((leaf['locks'] ?? 1) as num).toInt() + 1,
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (leaf['opening'].toString().contains('door') ||
                    leaf['opening'] == 'passive') ...[
                  GlassControl(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Tx('Dovodchik'),
                      value: leaf['closer'] == true,
                      onChanged: (v) => change(() => leaf['closer'] = v),
                    ),
                  ),
                  GlassControl(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Tx('Ostona'),
                      value: leaf['threshold'] != false,
                      onChanged: (v) => change(() => leaf['threshold'] = v),
                    ),
                  ),
                ],
              ],
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => split(
                      layout!.cells.firstWhere((c) => c.node['id'] == selected),
                      true,
                      (layout.cells
                                  .firstWhere((c) => c.node['id'] == selected)
                                  .box[0] +
                              layout.cells
                                  .firstWhere((c) => c.node['id'] == selected)
                                  .box[2]) /
                          2,
                    ),
                    icon: const Icon(Icons.vertical_split),
                    label: const Tx('Tik ½'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => split(
                      layout!.cells.firstWhere((c) => c.node['id'] == selected),
                      false,
                      (layout.cells
                                  .firstWhere((c) => c.node['id'] == selected)
                                  .box[1] +
                              layout.cells
                                  .firstWhere((c) => c.node['id'] == selected)
                                  .box[3]) /
                          2,
                    ),
                    icon: const Icon(Icons.horizontal_split),
                    label: const Tx('Yotiq ½'),
                  ),
                  TextButton(
                    onPressed: merge,
                    child: const Tx('Bo‘limni birlashtirish'),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => positionDialog(
                  layout!.cells.firstWhere((c) => c.node['id'] == selected),
                ),
                icon: const Icon(Icons.straighten),
                label: const Tx('Aniq bo‘lim o‘lchami (mm)'),
              ),
            ],
            if (leaf != null) ...[
              const Divider(height: 24),
              const Tx(
                'Qanot ichidagi to‘ldirmalar',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Tx(
                'Bitta qanot ichida shisha, panel yoki lambirni ajrating. Qulf va petlya soni ko‘paymaydi.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => splitInfill(true),
                    icon: const Icon(Icons.vertical_split),
                    label: const Tx('Ichki tik bo‘lish'),
                  ),
                  TextButton.icon(
                    onPressed: () => splitInfill(false),
                    icon: const Icon(Icons.horizontal_split),
                    label: const Tx('Ichki yotiq bo‘lish'),
                  ),
                ],
              ),
              if (leaf['infill'] != null) ...[
                Builder(
                  builder: (context) {
                    final ownerCell = layout!.cells.firstWhere(
                          (c) => c.node['id'] == selected,
                        ),
                        sub = layoutInfill(ownerCell, recipe);
                    final id =
                        sub.cells.any((c) => c.node['id'] == selectedFill)
                            ? selectedFill!
                            : sub.cells.first.node['id'] as String;
                    final target = node(id, leaf['infill'])!;
                    return Column(
                      children: [
                        GlassControl(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: ValueKey(
                              'inner-$selected-$id-${sub.cells.length}',
                            ),
                            initialValue: id,
                            decoration: InputDecoration(
                              labelText: tr('Ichki to‘ldirmani tanlang'),
                            ),
                            items: [
                              for (var j = 0; j < sub.cells.length; j++)
                                DropdownMenuItem(
                                  value: sub.cells[j].node['id'],
                                  child: Tx(
                                    '${j + 1} · ${sub.cells[j].node['fill']} · ${(sub.cells[j].box[2] - sub.cells[j].box[0]).round()}×${(sub.cells[j].box[3] - sub.cells[j].box[1]).round()} mm',
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => selectedFill = v),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GlassControl(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: ValueKey('innerfill-$id-${target['fill']}'),
                            initialValue: target['fill'],
                            decoration: InputDecoration(
                              labelText: tr('Tanlangan ichki material'),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'glass',
                                child: Tx('Shisha'),
                              ),
                              DropdownMenuItem(
                                value: 'panel',
                                child: Tx('Panel'),
                              ),
                              DropdownMenuItem(
                                value: 'lambris',
                                child: Tx('Lambir'),
                              ),
                              DropdownMenuItem(
                                value: 'empty',
                                child: Tx('Bo‘sh'),
                              ),
                            ],
                            onChanged: (v) => change(() => target['fill'] = v),
                          ),
                        ),
                        for (final boundary in sub.splits)
                          Row(
                            children: [
                              const Tx('Ichki chegara'),
                              Expanded(
                                child: GlassControl(
                                  child: Slider(
                                    value: (boundary.node['ratio'] as num)
                                        .toDouble(),
                                    min: .1,
                                    max: .9,
                                    divisions: 80,
                                    label:
                                        '${((boundary.node['ratio'] as num) * 100).round()}%',
                                    onChangeStart: (_) => checkpoint(),
                                    onChanged: (v) {
                                      final actual = node(
                                            boundary.node['id'],
                                            leaf['infill'],
                                          )!,
                                          old = actual['ratio'];
                                      actual['ratio'] = v;
                                      try {
                                        layoutDrawing(drawing, recipe);
                                        setState(() => report = null);
                                      } catch (_) {
                                        actual['ratio'] = old;
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        TextButton(
                          onPressed: () => change(() {
                            leaf.remove('infill');
                            selectedFill = null;
                          }),
                          child: const Tx('Ichki bo‘linishlarni olish'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
            const Divider(height: 30),
            TextButton.icon(
              onPressed: () {
                final next = recipeFor(
                  widget.store.profiles.firstWhere((p) => p['id'] == profile),
                );
                try {
                  layoutDrawing(drawing, next);
                  setState(() {
                    recipe = cloneMap(next);
                    report = null;
                  });
                } catch (e) {
                  setState(() => error = '$e');
                }
              },
              icon: const Icon(Icons.price_change_outlined),
              label: const Tx('Profilning saqlangan yangi narxlarini olish'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final next = await Navigator.push<DMap>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeEditor(recipe: recipe),
                  ),
                );
                if (next != null) {
                  try {
                    layoutDrawing(drawing, next);
                    setState(() {
                      recipe = next;
                      report = null;
                    });
                  } catch (e) {
                    setState(() => error = '$e');
                  }
                }
              },
              icon: const Icon(Icons.tune),
              label: const Tx('Barcha materiallar, narx va texnik me’yorlar'),
            ),
            TextButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        validateRecipe(recipe);
                        final p = widget.store.profiles.firstWhere(
                          (p) => p['id'] == profile,
                        );
                        await widget.store.saveProfile({
                          ...p,
                          'drawingRecipe': cloneMap(recipe),
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Tx(
                                'Retsept shu profil uchun saqlandi',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) setState(() => error = '$e');
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Tx('Narxlarni shu profil uchun eslab qolish'),
            ),
            FilledButton.icon(
              onPressed: preview,
              icon: const Icon(Icons.calculate_outlined),
              label: const Tx('Material va chiqindini hisoblash'),
            ),
            if (report != null) ...[
              DrawingReport(item: report!),
              FilledButton.icon(
                onPressed: () {
                  try {
                    calculate();
                    Navigator.pop(context, item());
                  } catch (e) {
                    setState(() => error = '$e');
                  }
                },
                icon: const Icon(Icons.playlist_add_check),
                label: const Tx('Smetaga qo‘shish'),
              ),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget drawingCanvas(
    DrawingLayout? layout, {
    double? height = 360,
    bool bare = false,
  }) =>
      Container(
        height: height,
        // Bare on the desk: the paper is the whole screen, not a card.
        decoration: bare
            ? null
            : BoxDecoration(
                color: paperColor,
                borderRadius: BorderRadius.circular(18),
              ),
        child: layout == null
            ? Center(child: Tx(error ?? 'Chizma xato'))
            : LayoutBuilder(
                builder: (context, cs) {
                  final size = Size(cs.maxWidth, cs.maxHeight);
                  final transform = CanvasTransform(
                    size,
                    drawing,
                    sectionDimensions: visualMode,
                  );
                  trashZone = Rect.fromCenter(
                    center: Offset(size.width / 2, size.height - 30),
                    width: 190,
                    height: 42,
                  );
                  final interactive = Listener(
                    onPointerDown: (details) {
                      if (pinching) return;
                      beginDrag(details.localPosition, transform, layout);
                      dragCheckpoint = false;
                      if (dragged != null ||
                          edge != null ||
                          draggedVertex != null ||
                          draggingSize) {
                        setState(() => editingGesture = true);
                      }
                    },
                    onPointerMove: (details) {
                      if (pinching || !editingGesture) return;
                      if (!dragCheckpoint) {
                        if ((details.localPosition - dragDown!).distance < 3) {
                          return;
                        }
                        checkpoint();
                        dragCheckpoint = true;
                      }
                      updateDrag(details.localPosition);
                    },
                    onPointerUp: (_) => endDrag(),
                    onPointerCancel: (_) => endDrag(),
                    child: GestureDetector(
                      onTapUp: (details) =>
                          canvasTap(details.localPosition, transform, layout),
                      onLongPressStart: (details) => canvasLongPress(
                        details.localPosition,
                        transform,
                        layout,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            size: size,
                            painter: DrawingPainter(
                              drawing,
                              recipe,
                              paper: !bare,
                              ink: bare ? deskInk(context) : null,
                              selected: selected,
                              points: points,
                              editVertices: tool == 'vertices',
                              showResize: tool == 'size',
                              sectionDimensions: visualMode,
                            ),
                          ),
                          if (visualMode && tool == 'select')
                            IgnorePointer(
                              child: CustomPaint(
                                key: const ValueKey('section-handles'),
                                painter: HandlesPainter(
                                  sectionHandles(layout, transform),
                                  active: edge?.side,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          if (edge != null && dragCheckpoint)
                            IgnorePointer(
                              child: CustomPaint(
                                painter: DividerGuidePainter(
                                  labels: guide,
                                  snapped: false,
                                  trash: null,
                                  overTrash: false,
                                ),
                              ),
                            ),
                          if (dragged != null && dragCheckpoint)
                            IgnorePointer(
                              child: CustomPaint(
                                key: const ValueKey('divider-guide'),
                                painter: DividerGuidePainter(
                                  labels: guide,
                                  snapped: snappedTo != null,
                                  trash: trashZone,
                                  overTrash: overTrash,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (!bare) return interactive;
                  // The desk: two fingers zoom and move it.
                  return Listener(
                    onPointerDown: (e) {
                      pointers[e.pointer] = e.localPosition;
                      if (pointers.length == 2) startPinch();
                    },
                    onPointerMove: (e) {
                      if (!pointers.containsKey(e.pointer)) return;
                      pointers[e.pointer] = e.localPosition;
                      if (pinching) updatePinch(size);
                    },
                    onPointerUp: (e) {
                      pointers.remove(e.pointer);
                      if (pointers.isEmpty && pinching) {
                        setState(() => pinching = false);
                      }
                    },
                    onPointerCancel: (e) {
                      pointers.remove(e.pointer);
                      if (pointers.isEmpty && pinching) {
                        setState(() => pinching = false);
                      }
                    },
                    child: ClipRect(
                      child: Transform(
                        transform: Matrix4.identity()
                          ..translateByDouble(pan.dx, pan.dy, 0, 1)
                          ..scaleByDouble(zoom, zoom, 1, 1),
                        child: interactive,
                      ),
                    ),
                  );
                },
              ),
      );

  void canvasTap(
    Offset local,
    CanvasTransform transform,
    DrawingLayout layout,
  ) {
    if (visualMode && dimensionTap(local, transform)) return;
    final v = transform.from(local);
    if (tool == 'size' || tool == 'vertices') return;
    if (tool == 'outline') {
      if (points.length < 24) {
        setState(
          () => points.add(
            V(
              (v.x / (drawing['widthMm'] as num)).clamp(0, 1),
              (v.y / (drawing['heightMm'] as num)).clamp(0, 1),
            ),
          ),
        );
      }
      return;
    }
    for (final c in layout.cells) {
      if (!pointIn(c.polygon, v)) continue;
      if (visualMode &&
          (tool == 'opening' || tool == 'fill' || tool == 'hardware')) {
        selected = c.node['id'];
        if (tool == 'hardware') {
          final why = hardwareError(c.node, hardwareTool);
          if (why != null) {
            setState(() => error = why);
            return;
          }
        }
        change(() {
          final target = node(c.node['id'])!;
          if (tool == 'opening') {
            target['opening'] = openingTool;
          } else if (tool == 'hardware') {
            applyHardware(target, hardwareTool);
          } else {
            fillCell(target, c, v, fillTool);
          }
        });
        HapticFeedback.selectionClick();
      } else if (tool == 'select') {
        // A second tap on the same section opens its settings.
        final now = DateTime.now(), id = c.node['id'] as String;
        final twice = lastTapCell == id &&
            lastTapAt != null &&
            now.difference(lastTapAt!) < const Duration(milliseconds: 350);
        lastTapAt = twice ? null : now;
        lastTapCell = twice ? null : id;
        if (twice) {
          HapticFeedback.selectionClick();
          sectionMenu(id);
          return;
        }
        setState(() {
          selected = c.node['id'];
          selectedFill = null;
          error = null;
          if (c.node['infill'] != null) {
            for (final sub in layoutInfill(c, recipe).cells) {
              if (pointIn(sub.polygon, v)) {
                selectedFill = sub.node['id'];
                break;
              }
            }
          }
        });
      } else {
        final vertical = tool == 'v', k = vertical ? 0 : 1;
        final snap = snapInBox(
          layout,
          c.box,
          k,
          vertical ? v.x : v.y,
          12 / transform.scale,
        );
        split(c, vertical, snap.at);
      }
      break;
    }
  }

  /// Fill a whole section, or only the inner part under [at] when the sash
  /// has been divided inside.
  void fillCell(DMap target, DrawingCell cell, V at, String fill) {
    if (target['infill'] == null) {
      target['fill'] = fill;
      return;
    }
    for (final part in layoutInfill(cell, recipe).cells) {
      if (pointIn(part.polygon, at)) {
        node(part.node['id'], target['infill'])!['fill'] = fill;
        return;
      }
    }
    throw Exception('Ichki bo‘lim ustiga bosing');
  }

  String? hardwareError(DMap target, String kind) {
    final opening = target['opening'] as String? ?? 'fixed';
    switch (kind) {
      case 'mesh' || 'lock':
        if (opening == 'fixed') {
          return 'Avval shu bo‘limga ochiladigan qanot yoki eshik qo‘ying';
        }
        if (kind == 'lock' && opening == 'passive') {
          return 'Passiv qanotda qulf emas, shpingalet bo‘ladi';
        }
        if (kind == 'lock' && ((target['locks'] as num?) ?? 1) >= 10) {
          return 'Ko‘pi bilan 10 ta qulf';
        }
        return null;
      case 'closer' || 'threshold':
        return isDoorOpening(opening) ? null : 'Bu detal faqat eshik uchun';
      case 'shpros':
        return recipe['glazingType'] == 'double'
            ? null
            : 'Shpros 2 oynali shishada bo‘ladi: “Rang” → Shisha → 2 oynali';
    }
    return 'Noma’lum detal';
  }

  void applyHardware(DMap target, String kind) {
    switch (kind) {
      case 'mesh':
        target['mesh'] = target['mesh'] != true;
      case 'lock':
        target['locks'] = math.min(
          10,
          (target['locks'] as num? ?? 1).toInt() + 1,
        );
      case 'closer':
        target['closer'] = target['closer'] != true;
      case 'threshold':
        target['threshold'] = target['threshold'] == false;
      case 'shpros':
        target['shpros'] = target['shpros'] != true;
    }
  }

  void canvasLongPress(
    Offset local,
    CanvasTransform transform,
    DrawingLayout layout,
  ) {
    if (!visualMode) return;
    final divider = splitAt(local, transform, layout);
    endDrag();
    if (divider != null) {
      dividerMenu(divider, layout);
      return;
    }
    final v = transform.from(local);
    for (final c in layout.cells) {
      if (pointIn(c.polygon, v)) {
        setState(() {
          selected = c.node['id'];
          selectedFill = null;
        });
        HapticFeedback.mediumImpact();
        sectionMenu(c.node['id'] as String);
        return;
      }
    }
  }

  bool dimensionTap(Offset point, CanvasTransform transform) {
    final top = transform.to(const V(0, 0));
    final bottom = transform.to(
      V(
        (drawing['widthMm'] as num).toDouble(),
        (drawing['heightMm'] as num).toDouble(),
      ),
    );
    if (point.dx < top.dx - 6 && point.dy >= top.dy && point.dy <= bottom.dy) {
      if (point.dx > top.dx - 32 &&
          sectionStops(
                layoutDrawing(drawing, recipe),
                false,
                (drawing['heightMm'] as num).toDouble(),
              ).length >
              2) {
        editSection(false, transform.from(point).y);
      } else {
        editOverall(false);
      }
      return true;
    }
    if (point.dy > bottom.dy + 8 &&
        point.dy < bottom.dy + 65 &&
        point.dx >= top.dx &&
        point.dx <= bottom.dx) {
      if (point.dy < bottom.dy + 33 &&
          sectionStops(
                layoutDrawing(drawing, recipe),
                true,
                (drawing['widthMm'] as num).toDouble(),
              ).length >
              2) {
        editSection(true, transform.from(point).x);
      } else {
        editOverall(true);
      }
      return true;
    }
    return false;
  }

  Future<void> editSection(bool horizontal, double at) async {
    final layout = layoutDrawing(drawing, recipe), k = horizontal ? 0 : 1;
    final stops = sectionStops(
      layout,
      horizontal,
      (drawing[horizontal ? 'widthMm' : 'heightMm'] as num).toDouble(),
    );
    final i = List.generate(
      stops.length - 1,
      (i) => i,
    ).firstWhere((i) => at >= stops[i] && at <= stops[i + 1], orElse: () => 0);
    final movingRight = i < stops.length - 2;
    final boundary = stops[movingRight ? i + 1 : i];
    final candidates = layout.splits.where(
      (split) => (split.node['axis'] == 'v') == horizontal,
    );
    final split = candidates.firstWhere(
      (split) => ((horizontal ? split.a.x : split.a.y) - boundary).abs() < .01,
    );
    final value = await draftNumber(
      context,
      title: horizontal ? 'Bo‘lim eni' : 'Bo‘lim bo‘yi',
      initial: stops[i + 1] - stops[i],
      min: 80,
      max: 6000,
    );
    if (!mounted || value == null) return;
    change(() {
      final position = movingRight ? stops[i] + value : stops[i + 1] - value;
      node(split.node['id'])!['ratio'] =
          (position - split.box[k]) / (split.box[k + 2] - split.box[k]);
    });
  }

  Future<void> editOverall(bool horizontal) async {
    final value = await draftNumber(
      context,
      title: horizontal ? 'Rom eni' : 'Rom bo‘yi',
      initial: drawing[horizontal ? 'widthMm' : 'heightMm'],
      min: 300,
      max: 6000,
    );
    if (!mounted || value == null) return;
    (horizontal ? width : height).text =
        value == value.roundToDouble() ? '${value.toInt()}' : '$value';
    resize();
  }

  Future<void> showVisualReport() async {
    preview();
    if (report == null) return;
    final current = report!;
    final add = await showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .86,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    Tx(
                      'Materiallar va sarf',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DrawingReport(item: current),
                  ],
                ),
              ),
              // Always in reach, however long the material list is.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('report-add'),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.playlist_add_check),
                    label: Tx(
                      'Smetaga qo‘shish • ${money(current['total'])}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || add != true) return;
    Navigator.pop(context, item());
  }

  /// Adds the window to the smeta straight away, without the material list.
  void addToSmeta() {
    try {
      calculate();
      Navigator.pop(context, item());
    } catch (e) {
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> editRoom() async {
    final value = await pickRoom(context, label);
    if (!mounted || value == null) return;
    setState(() => label = value.isEmpty ? null : value);
  }

  Future<void> editQuantity() async {
    final value = await draftNumber(
      context,
      title: 'Rom soni',
      initial: int.tryParse(quantity.text) ?? 1,
      min: 1,
      max: 1000,
      unit: 'dona',
    );
    if (mounted && value != null) {
      setState(() {
        quantity.text = '${value.toInt()}';
        report = null;
      });
    }
  }

  /// 2D drawing or a live 3D picture of the same window.
  void placeOnPhoto() {
    try {
      layoutDrawing(drawing, recipe);
    } catch (e) {
      toast('$e'.replaceFirst('Exception: ', ''));
      return;
    }
    openInPlace(
      context,
      drawing: cloneMap(drawing),
      recipe: cloneMap(recipe),
      aiKey: widget.store.aiKey,
    );
  }

  Widget viewSwitch() {
    if (nativeGlass) {
      // 2D | 3D and the photo view as UIKit's glass buttons.
      return NativeGlassButtons(
        height: 40,
        width: 60 + 60 + 40 + 8,
        spacing: 4,
        items: [
          GlassButton('2d', title: '2D', selected: !show3d, height: 40),
          GlassButton('3d', title: '3D', selected: show3d, height: 40),
          const GlassButton(
            'place',
            symbol: 'camera',
            label: 'Joyida ko‘rish',
            size: 40,
            iconSize: 16,
          ),
        ],
        onTap: (id) => switch (id) {
          '2d' => setState(() => show3d = false),
          '3d' => setState(() => show3d = true),
          _ => placeOnPhoto(),
        },
        fallback: const SizedBox.shrink(),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    Widget side(String label, bool on, VoidCallback tap) => Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('view-$label'),
          borderRadius: BorderRadius.circular(14),
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: on ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Tx(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: on ? scheme.onPrimary : scheme.primary,
              ),
            ),
          ),
        ));
    // One glass capsule, the chosen view on a tinted lens inside it.
    return whenGlass(
      Material(
        color: usesIOSGlass ? Colors.transparent : scheme.surface,
        elevation: usesIOSGlass ? 0 : 2,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              side('2D', !show3d, () => setState(() => show3d = false)),
              side('3D', show3d, () => setState(() => show3d = true)),
              // The window on a photo of its opening.
              Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: const ValueKey('view-place'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: placeOnPhoto,
                    child: Tooltip(
                      message: 'Joyida ko‘rish',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
      (capsule) => GlassSurface(
        radius: BorderRadius.circular(20),
        shadow: false,
        blur: true,
        child: capsule,
      ),
    );
  }

  /// One line about the chosen section, with its settings one tap away.
  Widget selectionBar(DrawingLayout layout, DMap leaf) {
    final scheme = Theme.of(context).colorScheme;
    final index = layout.cells.indexWhere((c) => c.node['id'] == leaf['id']);
    if (index < 0) return const SizedBox.shrink();
    final box = layout.cells[index].box;
    final opening = switch (leaf['opening']) {
      'tiltTurn' => 'Burilma',
      'passive' => 'Passiv qanot',
      'doorLeft' => 'Eshik, chap',
      'doorRight' => 'Eshik, o‘ng',
      final String o => openingNames[o] ?? 'Yopiq',
      _ => 'Yopiq',
    };
    final fill = const {
          'glass': 'shisha',
          'panel': 'panel',
          'lambris': 'lambir',
          'empty': 'bo‘sh',
        }[leaf['fill']] ??
        '';
    return whenGlass(
      Material(
        key: const ValueKey('section-bar'),
        color: usesIOSGlass ? Colors.transparent : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(usesIOSGlass ? 22 : 12),
        child: (InkWell(
          borderRadius: BorderRadius.circular(usesIOSGlass ? 22 : 12),
          onTap: () => sectionMenu(selected),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.primary,
                  child: Tx(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tx(
                    '${(box[2] - box[0]).round()} × ${(box[3] - box[1]).round()} mm • $opening • $fill',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                // The whole bar opens the settings; the arrow says so.

                Icon(Icons.chevron_right, size: 20, color: scheme.primary),
              ],
            ),
          ),
        )),
      ),
      // The chosen section on a capsule of Apple's glass.
      (bar) => GlassSurface(
        radius: BorderRadius.circular(22),
        shadow: false,
        blur: true,
        child: bar,
      ),
    );
  }

  /// The palette of tool groups: a glass capsule when Liquid Glass is on.
  Widget glassBar(ColorScheme scheme, Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
        child: child is NativeGlassButtons || child is SingleChildScrollView
            // UIKit's buttons bring their own glass; the Flutter tools are
            // round buttons of their own, with the paper between them.
            ? Center(child: child)
            : usesIOSGlass
                // A floating toolbar over the paper: one capsule of Apple's
                // glass, as wide as its tools, the drawing showing through.
                ? Center(
                    child: GlassSurface(
                      radius: BorderRadius.circular(25),
                      blur: true,
                      child: child,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: child,
                  ),
      );

  /// The bottom panel: a glass card when Liquid Glass is on.
  Widget deskPanel(ColorScheme scheme, Widget child) {
    const padding = EdgeInsets.fromLTRB(12, 4, 12, 10);
    if (usesIOSGlass) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: GlassSurface(
          radius: BorderRadius.circular(30),
          // Apple's glass, drawn by UIKit: it costs Flutter nothing while
          // the drawing is dragged.
          blur: true,
          child: Padding(padding: padding, child: child),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: child,
    );
  }

  /// The profile in use, and every manufacturer's price for this window.
  Widget profileBar() {
    final scheme = Theme.of(context).colorScheme;
    final name = widget.store.profiles
        .where((p) => p['id'] == profile)
        .map((p) => '${p['name']}')
        .firstOrNull;
    final canCompare = widget.store.catalog != null;
    return Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('compare-prices'),
          borderRadius: BorderRadius.circular(10),
          onTap: canCompare ? comparePrices : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
            child: Row(
              children: [
                Icon(
                  Icons.factory_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Tx(
                    name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (canCompare) ...[
                  Flexible(
                    flex: 0,
                    child: Tx(
                      'Zavodlar narxi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: scheme.primary),
                ],
              ],
            ),
          ),
        ));
  }

  Future<void> comparePrices() async {
    try {
      final id = await showPriceComparison(
        context,
        widget.store,
        drawing: cloneMap(drawing),
        quantity: _quantity(),
        keep: {for (final k in comparisonKeys) k: recipe[k]},
        currentProfile: profile,
        currentTotal: () {
          try {
            return calculate()['total'] as num;
          } catch (_) {
            return null;
          }
        }(),
      );
      if (id == null || !mounted) return;
      final next = recipeFor(
        widget.store.profiles.firstWhere((p) => p['id'] == id),
      );
      // Colour, glazing and handles stay, as priced in the comparison.
      for (final k in comparisonKeys) {
        if (recipe[k] != null) next[k] = recipe[k];
      }
      layoutDrawing(drawing, next);
      setState(() {
        profile = id;
        recipe = cloneMap(next);
        report = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  /// Size, count, colour and room of the window: tap one to change it.
  Widget specBar() {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String key, String caption, Widget value, VoidCallback onTap) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            // Plain on the panel's glass; glass on glass reads as clutter.
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey('spec-$key'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // One line in every cell, so the row stays level.
                        SizedBox(
                          height: 15,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Tx(
                              caption,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 20,
                          child: FittedBox(fit: BoxFit.scaleDown, child: value),
                        ),
                      ],
                    ),
                  ),
                )),
          ),
        );
    TextStyle strong = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    return Row(
      children: [
        cell(
          'width',
          'Eni, mm',
          Tx('${drawing['widthMm']}', style: strong),
          () => editOverall(true),
        ),
        cell(
          'height',
          'Bo‘yi, mm',
          Tx('${drawing['heightMm']}', style: strong),
          () => editOverall(false),
        ),
        cell(
          'count',
          'Soni',
          Tx('${quantity.text} dona', style: strong),
          editQuantity,
        ),
        cell(
          'colour',
          'Rang',
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 7,
                backgroundColor: Color(
                  finishColors[recipe['finish'] ?? 'silver'] ?? 0xffd7dee7,
                ),
              ),
              const SizedBox(width: 4),
              Tx(
                (finishNames[recipe['finish'] ?? 'silver'] ?? 'Rang')
                    .split('/')
                    .first
                    .trim(),
                style: strong,
              ),
            ],
          ),
          appearanceSheet,
        ),
        cell('room', 'Joyi', Tx(label ?? '＋', style: strong), editRoom),
      ],
    );
  }

  void visual3D() {
    try {
      final bill = calculate();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => View3D(
            drawing: cloneMap(drawing),
            recipe: cloneMap(recipe),
            calculation: bill,
            returnToEditor: true,
            aiKey: widget.store.aiKey,
          ),
        ),
      );
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  /// Short message that floats above the editor's action buttons, so it
  /// never hides “3D” or “Hisoblash”.
  void toast(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Tx(text),
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, visualMode ? 150 : 16),
      ),
    );
  }

  void startPartDrag() {
    if (mounted) {
      setState(() {
        show3d = false;
        draggingPart = true;
        error = null;
      });
    }
  }

  /// A part let go over the drawing: placed in the section under it.
  void dropPart(DraftPayload payload, Offset? local) {
    final box = dropCanvasKey.currentContext?.findRenderObject();
    final next = local == null || box is! RenderBox
        ? null
        : plannedDrop(payload, local, box.size);
    finishPartDrag();
    if (next == null || !next.valid) {
      toast(next?.error ?? 'Rom ichidagi mos bo‘limga tashlang');
      return;
    }
    change(() {
      drawing = next.drawing!;
      selected = next.selection;
      selectedFill = null;
      tool = 'select';
      serial++;
    });
    HapticFeedback.lightImpact();
  }

  /// A UIKit toolbar button held and dragged: the same preview and drop as
  /// the Flutter tools' drag.
  void nativeDrag(DraftTool t, String phase, Offset global) {
    final payload = t.dragData;
    if (payload == null) return;
    switch (phase) {
      case 'start':
        HapticFeedback.selectionClick();
        startPartDrag();
      case 'move':
        final local = localDrop(global);
        setState(() {
          hoverPayload = payload;
          hoverPoint = local;
        });
      case 'end':
        dropPart(payload, localDrop(global));
      default:
        finishPartDrag();
    }
  }

  void finishPartDrag() {
    if (mounted) {
      setState(() {
        draggingPart = false;
        hoverPayload = null;
        hoverPoint = null;
      });
    }
  }

  Offset? localDrop(Offset global) {
    final box = dropCanvasKey.currentContext?.findRenderObject();
    // Back through the desk's zoom to the drawing's own coordinates.
    return box is RenderBox ? (box.globalToLocal(global) - pan) / zoom : null;
  }

  DraftPlacement? plannedDrop(DraftPayload payload, Offset local, Size size) {
    final layout = layoutDrawing(drawing, recipe);
    final transform = CanvasTransform(size, drawing, sectionDimensions: true);
    final at = transform.from(local);
    // A finger over the frame still means the section next to it.
    final cell = nearestCell(layout, at, 36 / transform.scale);
    if (cell == null) return null;
    final outline = cell.polygon.map(transform.to).toList();
    DraftPlacement reject(String why) => DraftPlacement(
          null,
          cell.node['id'] as String,
          outline,
          const [],
          error: why.replaceFirst('Exception: ', ''),
        );
    final next = cloneMap(drawing);
    final target = node(cell.node['id'], next['root'])!;
    String selection = target['id'];
    var polygon = cell.polygon;
    final line = <V>[];
    var labels = <(Offset, String)>[];
    var snapped = false;
    switch (payload.kind) {
      case 'split':
        final vertical = payload.value == 'v', k = vertical ? 0 : 1;
        final span = cell.box[k + 2] - cell.box[k];
        final raw = (vertical ? at.x : at.y)
            .clamp(cell.box[k] + span * .1, cell.box[k + 2] - span * .1)
            .toDouble();
        final snap = snapInBox(layout, cell.box, k, raw, 12 / transform.scale);
        snapped = snap.snapped;
        final trim = target['trim'];
        final left = {...cloneMap(target), 'id': 'drop-$serial-a'}
          ..remove('trim');
        final right = {...cloneMap(target), 'id': 'drop-$serial-b'}
          ..remove('trim');
        target
          ..clear()
          ..addAll({
            'id': 'drop-$serial-s',
            'axis': payload.value,
            'ratio': (snap.at - cell.box[k]) / span,
            'a': left,
            'b': right,
            if (trim != null) 'trim': trim,
          });
        selection = left['id'];
        line.addAll(
          vertical
              ? [V(snap.at, cell.box[1]), V(snap.at, cell.box[3])]
              : [V(cell.box[0], snap.at), V(cell.box[2], snap.at)],
        );
        labels = readouts(transform, cell.box, k, snap.at, snap.from, snap.to);
      case 'opening':
        target['opening'] = payload.value;
      case 'fill':
        if (target['infill'] != null) {
          final inner = layoutInfill(cell, recipe);
          for (final part in inner.cells) {
            if (pointIn(part.polygon, at)) {
              node(part.node['id'], target['infill'])!['fill'] = payload.value;
              polygon = part.polygon;
              break;
            }
          }
          if (identical(polygon, cell.polygon)) {
            return reject('Ichki bo‘lim ustiga olib boring');
          }
        } else {
          target['fill'] = payload.value;
        }
      case 'hardware':
        final why = hardwareError(target, payload.value);
        if (why != null) return reject(why);
        applyHardware(target, payload.value);
      case 'preset':
        final preset = drawingPresets.firstWhere((p) => p.id == payload.value);
        final inserted = reidTree(preset.root(), 'p$serial');
        target
          ..clear()
          ..addAll(inserted);
        selection = firstLeaf(target)['id'];
      default:
        return null;
    }
    try {
      layoutDrawing(next, recipe);
    } catch (e) {
      return reject('$e');
    }
    return DraftPlacement(
      next,
      selection,
      polygon.map(transform.to).toList(),
      line.map(transform.to).toList(),
      labels: labels,
      snapped: snapped,
    );
  }

  Widget dropWorkspace(DrawingLayout? layout) => SizedBox.expand(
        key: dropCanvasKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            DraftPlacement? placement;
            if (hoverPayload != null && hoverPoint != null) {
              placement = plannedDrop(hoverPayload!, hoverPoint!, size);
            }
            final valid = placement?.valid == true;
            final color = valid
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error;
            return DragTarget<DraftPayload>(
              onWillAcceptWithDetails: (_) => true,
              onMove: (details) {
                final local = localDrop(details.offset);
                if (local != null) {
                  setState(() {
                    hoverPayload = details.data;
                    hoverPoint = local;
                  });
                }
              },
              onLeave: (_) => setState(() {
                hoverPayload = null;
                hoverPoint = null;
              }),
              onAcceptWithDetails: (details) =>
                  dropPart(details.data, localDrop(details.offset)),
              builder: (context, accepted, rejected) => Stack(
                fit: StackFit.expand,
                children: [
                  drawingCanvas(layout, height: null, bare: true),
                  if (hoverPayload != null)
                    IgnorePointer(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform(
                            // The preview follows the desk's zoom.
                            transform: Matrix4.identity()
                              ..translateByDouble(pan.dx, pan.dy, 0, 1)
                              ..scaleByDouble(zoom, zoom, 1, 1),
                            child: CustomPaint(
                              key: const ValueKey('draft-drop-preview'),
                              painter: DraftDropPainter(
                                polygon: placement?.polygon ?? [],
                                line: placement?.line ?? [],
                                labels: placement?.labels ?? const [],
                                snapped: placement?.snapped == true,
                                valid: valid,
                                color: color,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Center(
                              child: Material(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Tx(
                                    valid
                                        ? '${hoverPayload!.label} — shu yerga qo‘yish${placement!.snapped ? ' • teng' : ''}'
                                        : placement?.error ??
                                            'Rom ichidagi mos bo‘limga olib boring',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

  DrawingCell? nearestCell(DrawingLayout layout, V at, double reachMm) {
    DrawingCell? best;
    var distance = reachMm;
    for (final c in layout.cells) {
      if (pointIn(c.polygon, at)) return c;
      for (var j = 0; j < c.polygon.length; j++) {
        final d = distanceToSegment(
          at,
          c.polygon[j],
          c.polygon[(j + 1) % c.polygon.length],
        );
        if (d < distance) {
          distance = d;
          best = c;
        }
      }
    }
    return best;
  }

  /// Replaces the drawing with [preset] at the size already entered.
  void applyPreset(DrawingPreset preset) {
    change(() {
      drawing = preset.drawing(
        width: drawing['widthMm'],
        height: drawing['heightMm'],
      );
      selected = firstLeaf(drawing['root'])['id'];
      selectedFill = null;
      tool = 'select';
      points.clear();
      syncFields();
    });
    if (error == null) HapticFeedback.selectionClick();
  }

  /// Left becomes right: the order of sections, openings and 90° joins.
  void mirror() {
    const swap = {
      'left': 'right',
      'right': 'left',
      'doorLeft': 'doorRight',
      'doorRight': 'doorLeft',
      'slideLeft': 'slideRight',
      'slideRight': 'slideLeft',
    };
    void flip(DMap n) {
      if (n['axis'] == 'v') {
        final a = n['a'];
        n['a'] = n['b'];
        n['b'] = a;
        n['ratio'] = 1 - (n['ratio'] as num);
      }
      if (n['axis'] != null) {
        flip(n['a']);
        flip(n['b']);
        return;
      }
      n['opening'] = swap[n['opening']] ?? n['opening'];
      if (n['infill'] != null) flip(n['infill']);
    }

    change(() {
      flip(drawing['root']);
      final joins = cornerJoins(drawing);
      if (joins.isNotEmpty) {
        drawing['joins'] = [
          for (final side in const ['left', 'right'])
            if (joins.contains(side == 'left' ? 'right' : 'left')) side,
        ];
      }
      if (drawing['vertices'] is List) {
        drawing['vertices'] = [
          for (final v in (drawing['vertices'] as List).reversed)
            [1 - (v[0] as num), v[1]],
        ];
      }
    });
    if (error == null) {
      HapticFeedback.selectionClick();
      toast('Chap va o‘ng almashtirildi');
    }
  }

  void equalize([String? rootId]) {
    change(() => equalizeSections(drawing, recipe, rootId: rootId));
    if (error == null) HapticFeedback.selectionClick();
  }

  /// Total for the current document; recalculated only after it changes.
  String? livePriceText() {
    if (editingGesture || draggingPart) return livePrice;
    final key =
        '${jsonEncode(drawing)}|${jsonEncode(recipe)}|${quantity.text}|$profile';
    if (key == priceKey) return livePrice;
    priceKey = key;
    try {
      livePrice = money(calculate()['total']);
    } catch (_) {
      livePrice = null;
    }
    return livePrice;
  }

  Future<void> appearanceSheet() async {
    await showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          void update(void Function() fn) {
            setState(() {
              fn();
              report = null;
            });
            refresh(() {});
          }

          Widget title(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                child: Tx(text, style: Theme.of(context).textTheme.titleSmall),
              );
          final colours = Map<String, dynamic>.from(recipe['colorPct'] ?? {});
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Tx(
                    'Profil, rang va furnitura',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  title('Profil tizimi'),
                  GlassControl(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: profile,
                      items: [
                        for (final p in widget.store.profiles)
                          DropdownMenuItem(
                            value: p['id'] as String,
                            child: Tx(
                              p['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        final next = recipeFor(
                          widget.store.profiles.firstWhere((p) => p['id'] == v),
                        );
                        for (final k in [
                          'finish',
                          'glazingType',
                          'hardwareFinish',
                          'windowHandle',
                          'handleStyle',
                        ]) {
                          if (recipe[k] != null) next[k] = recipe[k];
                        }
                        try {
                          layoutDrawing(drawing, next);
                          update(() {
                            profile = v;
                            recipe = cloneMap(next);
                          });
                        } catch (e) {
                          setState(() => error = '$e');
                        }
                      },
                    ),
                  ),
                  title('Profil rangi'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in finishNames.entries)
                        GlassControl(
                          child: ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: Color(
                                finishColors[e.key] ?? 0xffffffff,
                              ),
                              radius: 9,
                            ),
                            label: Tx(
                              '${e.value}${((colours[e.key] ?? 0) as num) > 0 ? ' +${(colours[e.key] as num).round()}%' : ''}',
                            ),
                            selected: (recipe['finish'] ?? 'silver') == e.key,
                            onSelected: (_) =>
                                update(() => recipe['finish'] = e.key),
                          ),
                        ),
                    ],
                  ),
                  title('Shisha'),
                  GlassControl(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'single', label: Tx('1 oynali')),
                        ButtonSegment(
                          value: 'double',
                          label: Tx('2 oynali paket'),
                        ),
                      ],
                      selected: {recipe['glazingType'] ?? 'single'},
                      onSelectionChanged: (v) =>
                          update(() => recipe['glazingType'] = v.single),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Tx(
                      'Shisha: ${GlazingSpec(recipe).label} • jami ${GlazingSpec(recipe).totalMm.toStringAsFixed(0)} mm',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  title('Deraza tutqichi'),
                  GlassControl(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'dolphin', label: Tx('Delfin')),
                        ButtonSegment(value: 'pull', label: Tx('Tortma')),
                        ButtonSegment(
                          value: 'lever',
                          label: Tx('Buriladigan'),
                        ),
                      ],
                      selected: {recipe['windowHandle'] ?? 'pull'},
                      onSelectionChanged: (v) =>
                          update(() => recipe['windowHandle'] = v.single),
                    ),
                  ),
                  if (drawing['shape'] == 'rect') ...[
                    title('90° burchak ulash profili'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (side, label) in const [
                          ('left', 'Chap tomonda'),
                          ('right', 'O‘ng tomonda'),
                        ])
                          GlassControl(
                            child: FilterChip(
                              key: ValueKey('join-$side'),
                              label: Tx(label),
                              selected: cornerJoins(drawing).contains(side),
                              onSelected: (on) {
                                change(() {
                                  final joins = cornerJoins(drawing).toSet();
                                  on ? joins.add(side) : joins.remove(side);
                                  report = null;
                                  drawing['joins'] = [
                                    for (final s in const ['left', 'right'])
                                      if (joins.contains(s)) s,
                                  ];
                                });
                                refresh(() {});
                              },
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Tx(
                        'Balkon burchagida keyingi rom 90° bilan ulanadi. Profil smetaga rom bo‘yi bilan qo‘shiladi; qo‘shni romda shu burchakni belgilamang.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  title('Eshik dastasi'),
                  GlassControl(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'plate',
                          label: Tx('Uzun planka'),
                        ),
                        ButtonSegment(value: 'rosette', label: Tx('Rozetka')),
                      ],
                      selected: {recipe['handleStyle'] ?? 'plate'},
                      onSelectionChanged: (v) =>
                          update(() => recipe['handleStyle'] = v.single),
                    ),
                  ),
                  title('Furnitura rangi'),
                  GlassControl(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'black', label: Tx('Qora')),
                        ButtonSegment(value: 'silver', label: Tx('Kumush')),
                        ButtonSegment(value: 'gold', label: Tx('Oltin')),
                      ],
                      selected: {recipe['hardwareFinish'] ?? 'black'},
                      onSelectionChanged: (v) =>
                          update(() => recipe['hardwareFinish'] = v.single),
                    ),
                  ),
                  title('Narx hisoblash usuli'),
                  GlassControl(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'net',
                          label: Tx('Sarf + chiqindi %'),
                        ),
                        ButtonSegment(
                          value: 'purchase',
                          label: Tx('Butun tayoq/list'),
                        ),
                      ],
                      selected: {recipe['pricingMode'] ?? 'net'},
                      onSelectionChanged: (v) =>
                          update(() => recipe['pricingMode'] = v.single),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Tx(
                      (recipe['pricingMode'] ?? 'net') == 'net'
                          ? 'Mijoz narxi: ishlatilgan metr/m² + ${recipe['wastePct'] ?? 7}% chiqindi. Xarid ro‘yxatida butun tayoq va listlar qoladi.'
                          : 'Mijoz narxiga butun tayoq va list kiradi (qoldiq ham).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final next = await Navigator.push<DMap>(
                        this.context,
                        MaterialPageRoute(
                          builder: (_) => RecipeEditor(recipe: recipe),
                        ),
                      );
                      if (next != null && mounted) {
                        setState(() {
                          recipe = next;
                          report = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.price_change_outlined),
                    label: const Tx('Barcha narxlar va me’yorlar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> sectionMenu(String id) async {
    await showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, refresh) {
          final layout = layoutDrawing(drawing, recipe);
          final index = layout.cells.indexWhere((c) => c.node['id'] == id);
          if (index < 0) return const SizedBox(height: 120);
          final cell = layout.cells[index], leaf = node(id)!;
          final opening = leaf['opening'] as String;
          final active = opening != 'fixed', door = isDoorOpening(opening);
          void apply(void Function(DMap n) fn, {bool close = false}) {
            change(() => fn(node(id)!));
            if (close) {
              Navigator.pop(sheet);
            } else {
              refresh(() {});
            }
          }

          Widget title(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                child: Tx(text, style: Theme.of(sheet).textTheme.titleSmall),
              );
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * .78,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Tx(
                    '${index + 1}-bo‘lim • ${(cell.box[2] - cell.box[0]).round()} × ${(cell.box[3] - cell.box[1]).round()} mm',
                    style: Theme.of(sheet).textTheme.titleLarge,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Tx(
                        error!,
                        style: TextStyle(
                          color: Theme.of(sheet).colorScheme.error,
                        ),
                      ),
                    ),
                  title('Ochilishi (xonadan ko‘rinish)'),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final key in openingNames.keys)
                        DraftTool(
                          label: openingNames[key]!,
                          opening: key,
                          selected: opening == key,
                          onTap: () => apply((n) => n['opening'] = key),
                        ),
                    ],
                  ),
                  title('To‘ldirma'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in const {
                        'glass': 'Shisha',
                        'panel': 'Sendvich panel',
                        'lambris': 'Lambir',
                        'empty': 'Bo‘sh',
                      }.entries)
                        GlassControl(
                          child: ChoiceChip(
                            label: Tx(e.value),
                            selected:
                                leaf['infill'] == null && leaf['fill'] == e.key,
                            onSelected: (_) => apply((n) {
                              n.remove('infill');
                              n['fill'] = e.key;
                            }),
                          ),
                        ),
                    ],
                  ),
                  if (active) ...[
                    GlassControl(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Tx('Setka'),
                        value: leaf['mesh'] == true,
                        onChanged: (v) => apply((n) => n['mesh'] = v),
                      ),
                    ),
                    GlassControl(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Tx('Tashqariga ochiladi'),
                        value: leaf['outward'] == true,
                        onChanged: (v) => apply((n) => n['outward'] = v),
                      ),
                    ),
                    if (opening != 'passive')
                      Row(
                        children: [
                          const Expanded(child: Tx('Qulf / zapor soni')),
                          IconButton(
                            onPressed: () => apply(
                              (n) => n['locks'] = math.max(
                                0,
                                (n['locks'] as num? ?? 1).toInt() - 1,
                              ),
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Tx('${leaf['locks'] ?? 1}'),
                          IconButton(
                            onPressed: () => apply(
                              (n) => n['locks'] = math.min(
                                10,
                                (n['locks'] as num? ?? 1).toInt() + 1,
                              ),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                  ],
                  if (door) ...[
                    GlassControl(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Tx('Dovodchik'),
                        value: leaf['closer'] == true,
                        onChanged: (v) => apply((n) => n['closer'] = v),
                      ),
                    ),
                    GlassControl(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Tx('Ostona'),
                        value: leaf['threshold'] != false,
                        onChanged: (v) => apply((n) => n['threshold'] = v),
                      ),
                    ),
                  ],
                  if (recipe['glazingType'] == 'double')
                    GlassControl(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Tx('Bezak shpros'),
                        value: leaf['shpros'] == true,
                        onChanged: (v) => apply((n) => n['shpros'] = v),
                      ),
                    ),
                  title('Bo‘lish'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (label, vertical, parts) in const [
                        ('Tik 2 ga', true, 2),
                        ('Tik 3 ga', true, 3),
                        ('Yotiq 2 ga', false, 2),
                        ('Yotiq 3 ga', false, 3),
                      ])
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheet);
                            splitEqually(id, vertical, parts);
                          },
                          child: Tx(label),
                        ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheet);
                          merge();
                        },
                        child: const Tx('Qo‘shnisi bilan birlashtirish'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheet);
                          positionDialog(cell);
                        },
                        child: const Tx('Aniq o‘lcham'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Splits a section into [parts] equal pieces in one undoable step.
  void splitEqually(String id, bool vertical, int parts) {
    change(() {
      final target = node(id)!, trim = target['trim'];
      final base = cloneMap(target)
        ..remove('id')
        ..remove('trim');
      DMap chain(int n) => n == 1
          ? {
              ...cloneMap(base),
              'id': 'e${serial++}-${DateTime.now().microsecondsSinceEpoch}',
            }
          : {
              'id': 'e${serial++}-${DateTime.now().microsecondsSinceEpoch}',
              'axis': vertical ? 'v' : 'h',
              'ratio': 1 / n,
              'a': {
                ...cloneMap(base),
                'id': 'e${serial++}-${DateTime.now().microsecondsSinceEpoch}',
              },
              'b': chain(n - 1),
            };
      final tree = chain(parts);
      if (trim != null) tree['trim'] = trim;
      target
        ..clear()
        ..addAll(tree);
      equalizeSections(drawing, recipe, rootId: tree['id']);
      selected = firstLeaf(target)['id'];
    });
  }

  Future<void> dividerMenu(DrawingSplit split, DrawingLayout layout) async {
    final main = layout.splits.any((s) => s.node['id'] == split.node['id']);
    final choice = await showGlassSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassControl(
                child: ListTile(
              title: Tx(
                split.node['axis'] == 'v' ? 'Tik impost' : 'Yotiq impost',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
            )),
            GlassControl(
                child: ListTile(
              leading: const Icon(Icons.straighten),
              title: const Tx('Chap/tepa bo‘lim o‘lchamini kiritish'),
              onTap: () => Navigator.pop(sheet, 'size'),
            )),
            if (main)
              GlassControl(
                  child: ListTile(
                leading: const Icon(Icons.view_column_outlined),
                title: const Tx('Bo‘limlarni teng taqsimlash'),
                onTap: () => Navigator.pop(sheet, 'equal'),
              )),
            GlassControl(
                child: ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheet).colorScheme.error,
              ),
              title: const Tx('Impostni olib tashlash'),
              subtitle: const Tx(
                'Yoki impostni sudrab pastdagi “O‘chirish” joyiga tashlang',
              ),
              onTap: () => Navigator.pop(sheet, 'remove'),
            )),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final id = split.node['id'] as String;
    if (choice == 'remove') {
      checkpoint();
      removeSplit(id);
      setState(() {});
    } else if (choice == 'equal') {
      equalize(id);
    } else {
      final k = split.node['axis'] == 'v' ? 0 : 1,
          span = split.box[k + 2] - split.box[k];
      final at = split.box[k] + span * (split.node['ratio'] as num);
      final snap = snapInBox(layout, split.box, k, at, 0, main: main);
      final value = await draftNumber(
        context,
        title: k == 0 ? 'Chap bo‘lim eni' : 'Tepa bo‘lim bo‘yi',
        initial: (at - snap.from).round(),
        min: 80,
        max: (snap.to - snap.from - 80).floorToDouble(),
      );
      if (!mounted || value == null) return;
      change(
        () => node(id)!['ratio'] =
            ((snap.from + value - split.box[k]) / span).clamp(.02, .98),
      );
    }
  }

  Widget visualWorkspace(DrawingLayout? layout, DMap? leaf) {
    Widget tools(List<Widget> children) {
      // On iPhone a row of tools is UIKit's own glass buttons, one view for
      // the row; the chosen tool is prominent glass. Dragging a part onto
      // the drawing stays with the Flutter row elsewhere.
      final row = [
        for (final c in children)
          if (c is DraftTool) c
      ];
      if (nativeGlass &&
          row.length == children.length &&
          row.isNotEmpty &&
          row.length <= 8) {
        return NativeGlassButtons(
          height: 44,
          width: row.length * 42.0 + (row.length - 1) * 4,
          spacing: 4,
          items: [
            for (var i = 0; i < row.length; i++)
              GlassButton(
                '$i',
                symbol: row[i].opening != null
                    ? openingSymbols[row[i].opening] ?? 'rectangle'
                    : row[i].preview != null
                        ? 'rectangle.split.2x1'
                        : sfSymbol(row[i].icon) ?? 'square',
                label: row[i].label,
                selected: row[i].selected,
                draggable: row[i].dragData != null,
                strokes: row[i].opening != null
                    ? openingIconStrokes(row[i].opening!)
                    : null,
                mark: row[i].opening != null
                    ? openingIconMark(row[i].opening!)
                    : null,
                size: 42,
                iconSize: 17,
              ),
          ],
          onTap: (id) => row[int.parse(id)].onTap(),
          onDrag: (id, phase, at) => nativeDrag(row[int.parse(id)], phase, at),
          fallback: const SizedBox.shrink(),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(children: children),
      );
    }

    void selectTool(String value) => setState(() {
          show3d = false;
          tool = value;
          points.clear();
          error = null;
        });
    // The six “Bo‘lish” tools fit a phone without scrolling.
    final fit = math.min(72.0, (MediaQuery.sizeOf(context).width - 18) / 6 - 6);
    DraftTool part(
      String label,
      DraftPayload payload, {
      IconData? icon,
      String? opening,
      Widget? preview,
      bool selected = false,
      double width = 72,
      required VoidCallback onTap,
    }) =>
        DraftTool(
          compact: true,
          label: label,
          width: width,
          icon: icon,
          opening: opening,
          preview: preview,
          selected: selected,
          dragData: payload,
          onDragStarted: startPartDrag,
          onDragFinished: finishPartDrag,
          onTap: onTap,
        );
    // Only fittings that this drawing can take: no door closer without a
    // door, no glazing bars on single glazing.
    final openings = [
      for (final c in layout?.cells ?? const <DrawingCell>[])
        c.node['opening'] as String? ?? 'fixed',
    ];
    final hardware = <(String, String, IconData)>[
      if (openings.any((o) => o != 'fixed')) ('mesh', 'Setka', Icons.grid_on),
      if (openings.any((o) => o != 'fixed' && o != 'passive'))
        ('lock', 'Qulf +1', Icons.lock_outline),
      if (openings.any(isDoorOpening)) ...[
        ('closer', 'Dovodchik', Icons.settings_input_component),
        ('threshold', 'Ostona', Icons.horizontal_rule),
      ],
      if (recipe['glazingType'] == 'double')
        ('shpros', 'Shpros', Icons.grid_4x4),
    ];
    // A message from the last action is shown once, not left on screen.
    if (error != null && layout != null) {
      final message = error!.replaceFirst('Exception: ', '');
      error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => toast(message));
    }
    final price = livePriceText();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // The whole screen is the drawing paper; the bars float over it.
      backgroundColor: deskPaper(context),
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        // Ink on the paper in both themes, the paper fading under it.
        foregroundColor: deskInk(context),
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                deskPaper(context),
                deskPaper(context).withValues(alpha: 0),
              ],
              stops: const [.6, 1],
            ),
          ),
        ),
        titleSpacing: 0,
        // Three tools share the bar: a compact title stays whole.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Tx(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: deskInk(context),
              ),
            ),
            Tx(
              label == null
                  ? 'Chizing — hisob avtomatik'
                  : '$label • ${drawing['widthMm']}×${drawing['heightMm']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: deskInk(context).withValues(alpha: .7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('Orqaga'),
            onPressed: undo.isEmpty ? null : () => travel(true),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: tr('Qaytarish'),
            onPressed: redo.isEmpty ? null : () => travel(false),
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            key: const ValueKey('full-desk'),
            tooltip: tr(fullDesk ? 'Asboblarni ko‘rsatish' : 'To‘liq ekran'),
            onPressed: () => setState(() => fullDesk = !fullDesk),
            icon: Icon(fullDesk ? Icons.fullscreen_exit : Icons.fullscreen),
          ),
          IconButton(
            tooltip: tr('Batafsil sozlash'),
            onPressed: () => setState(() => visualMode = false),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // Its own layer: dragging an impost does not repaint the paper.
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PaperPainter(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                if (!fullDesk) ...[
                  LayoutBuilder(
                    builder: (context, box) {
                      // All six groups stay visible on a phone without scrolling.
                      final width = math.min(72.0, (box.maxWidth - 42) / 6 - 6);
                      return glassBar(
                        scheme,
                        tools([
                          for (final entry in <(String, String, IconData)>[
                            ('split', 'Bo‘lish', Icons.grid_view_outlined),
                            ('window', 'Deraza', Icons.window_outlined),
                            ('door', 'Eshik', Icons.door_front_door_outlined),
                            ('fill', 'To‘ldirma', Icons.layers_outlined),
                            ('hardware', 'Furnitura', Icons.handyman_outlined),
                            (
                              'preset',
                              'Andoza',
                              Icons.dashboard_customize_outlined
                            ),
                          ])
                            DraftTool(
                              compact: true,
                              label: entry.$2,
                              icon: entry.$3,
                              width: width,
                              selected: palette == entry.$1,
                              dragData: switch (entry.$1) {
                                'split' => const DraftPayload(
                                    'split',
                                    'v',
                                    'Tik impost',
                                  ),
                                'window' => const DraftPayload(
                                    'opening',
                                    'tiltTurn',
                                    'Deraza qanoti',
                                  ),
                                'door' => const DraftPayload(
                                    'opening',
                                    'doorLeft',
                                    'Chap eshik',
                                  ),
                                'fill' =>
                                  DraftPayload('fill', fillTool, 'To‘ldirma'),
                                'hardware' => const DraftPayload(
                                    'hardware',
                                    'mesh',
                                    'Setka',
                                  ),
                                _ => null,
                              },
                              onDragStarted: startPartDrag,
                              onDragFinished: finishPartDrag,
                              onTap: () => setState(() {
                                show3d = false;
                                palette = entry.$1;
                                tool = 'select';
                                error = null;
                              }),
                            ),
                        ]),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  glassBar(
                    scheme,
                    tools([
                      if (palette == 'split') ...[
                        DraftTool(
                          compact: true,
                          label: 'Tanlash',
                          icon: Icons.touch_app_outlined,
                          width: fit,
                          selected: tool == 'select',
                          onTap: () => selectTool('select'),
                        ),
                        part(
                          'Tik bo‘lish',
                          const DraftPayload('split', 'v', 'Tik impost'),
                          icon: Icons.vertical_split_outlined,
                          width: fit,
                          selected: tool == 'v',
                          onTap: () => selectTool('v'),
                        ),
                        part(
                          'Yotiq bo‘lish',
                          const DraftPayload('split', 'h', 'Yotiq impost'),
                          icon: Icons.horizontal_split_outlined,
                          width: fit,
                          selected: tool == 'h',
                          onTap: () => selectTool('h'),
                        ),
                        DraftTool(
                          compact: true,
                          label: 'Tenglash',
                          icon: Icons.view_column_outlined,
                          width: fit,
                          onTap: () => equalize(),
                        ),
                        DraftTool(
                          compact: true,
                          label: 'Tortish',
                          icon: Icons.open_in_full,
                          width: fit,
                          selected: tool == 'size',
                          onTap: () => selectTool('size'),
                        ),
                        DraftTool(
                          compact: true,
                          label: 'Ko‘zgu',
                          icon: Icons.flip,
                          width: fit,
                          onTap: mirror,
                        ),
                      ],
                      if (palette == 'window' || palette == 'door')
                        for (final key in palette == 'window'
                            ? [
                                'fixed',
                                'left',
                                'right',
                                'tiltTurn',
                                'top',
                                'bottom',
                                'slideLeft',
                                'slideRight',
                              ]
                            : ['doorLeft', 'doorRight', 'passive', 'fixed'])
                          part(
                            openingNames[key]!,
                            DraftPayload('opening', key, openingNames[key]!),
                            opening: key,
                            selected: tool == 'opening' && openingTool == key,
                            onTap: () => setState(() {
                              openingTool = key;
                              tool = 'opening';
                              error = null;
                            }),
                          ),
                      if (palette == 'fill')
                        for (final entry in <(String, String, IconData)>[
                          ('glass', 'Shisha', Icons.crop_square),
                          ('panel', 'Panel', Icons.square_outlined),
                          ('lambris', 'Lambir', Icons.view_week_outlined),
                          ('empty', 'Bo‘sh', Icons.check_box_outline_blank),
                        ])
                          part(
                            entry.$2,
                            DraftPayload('fill', entry.$1, entry.$2),
                            icon: entry.$3,
                            selected: tool == 'fill' && fillTool == entry.$1,
                            onTap: () => setState(() {
                              fillTool = entry.$1;
                              tool = 'fill';
                              error = null;
                            }),
                          ),
                      if (palette == 'hardware' && hardware.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 18,
                          ),
                          child: Tx(
                            'Avval “Deraza” yoki “Eshik”dan ochiladigan qanot qo‘ying',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (palette == 'hardware')
                        for (final (key, label, icon) in hardware)
                          part(
                            label,
                            DraftPayload('hardware', key, label),
                            icon: icon,
                            selected: tool == 'hardware' && hardwareTool == key,
                            onTap: () => setState(() {
                              hardwareTool = key;
                              tool = 'hardware';
                              error = null;
                            }),
                          ),
                      if (palette == 'preset') ...[
                        DraftTool(
                          compact: true,
                          key: const ValueKey('open-catalog'),
                          label: 'Katalog',
                          icon: Icons.apps,
                          selected: true,
                          onTap: openCatalog,
                        ),
                        for (final preset in drawingPresets.where(
                          (p) => quickPresets.contains(p.id),
                        ))
                          part(
                            preset.name,
                            DraftPayload('preset', preset.id, preset.name),
                            preview:
                                PresetThumb(preset: preset, recipe: recipe),
                            onTap: () => applyPreset(preset),
                          ),
                        DraftTool(
                          compact: true,
                          label: 'Saqlash',
                          icon: Icons.bookmark_add_outlined,
                          onTap: saveAsTemplate,
                        ),
                        DraftTool(
                          compact: true,
                          label: 'Mening',
                          icon: Icons.folder_open,
                          onTap: loadTemplate,
                        ),
                      ],
                    ]),
                  ),
                ],
                SizedBox(
                  height: 46,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
                    // The 2D | 3D switch sits beside the chosen section, so the
                    // drawing gets the row it used to take.
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: leaf != null &&
                                    layout != null &&
                                    tool == 'select' &&
                                    !draggingPart &&
                                    !(dragged != null && dragCheckpoint)
                                ? selectionBar(layout, leaf)
                                : Tx(
                                    draggingPart
                                        ? 'Bo‘lim ustiga qo‘ying.'
                                        : dragged != null && dragCheckpoint
                                            ? 'O‘chirish — pastga tashlang.'
                                            : switch (tool) {
                                                'opening' =>
                                                  '${openingNames[openingTool]}: bo‘limni bosing.',
                                                'fill' => 'Bo‘limni bosing.',
                                                'hardware' => 'Qanotni bosing.',
                                                'v' || 'h' => 'Joyni bosing.',
                                                'size' => 'Tutqichni torting.',
                                                _ => palette == 'preset'
                                                    ? 'Andozani bo‘limga sudrang.'
                                                    : 'Bo‘limni bosing.',
                                              },
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
// The desk's ink: white on black paper, dark on white.
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: deskInk(context)
                                          .withValues(alpha: .7),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        viewSwitch(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: show3d && layout != null
                        ? Live3D(drawing: drawing, recipe: recipe)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              dropWorkspace(layout),
                              // Back to the whole window after zooming in.
                              if (zoom > 1.01)
                                Positioned(
                                  right: 4,
                                  bottom: 8,
                                  child: GlassIconButton(
                                    key: const ValueKey('fit-desk'),
                                    icon: Icons.fit_screen_outlined,
                                    tooltip: tr('Asl o‘lcham'),
                                    onPressed: resetZoom,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                if (!fullDesk)
                  deskPanel(
                    scheme,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        profileBar(),
                        specBar(),
                        const SizedBox(height: 6),
                        NativeGlassButtons(
                          height: 50,
                          items: [
                            const GlassButton(
                              '3d',
                              symbol: 'cube',
// Icon buttons carry no words; the name is read out.
                              label: '3D ko‘rish',
                              size: 50,
                              iconSize: 21,
                            ),
                            const GlassButton(
                              'sarf',
                              symbol: 'list.bullet.rectangle',
                              label: 'Materiallar va sarf',
                              size: 50,
                              iconSize: 21,
                            ),
                            GlassButton(
                              'add',
                              title: 'Smetaga qo‘shish',
                              subtitle: price,
                              style: 'prominent',
                              expand: true,
                              height: 50,
                            ),
                          ],
                          onTap: (id) => switch (id) {
                            '3d' => visual3D(),
                            'sarf' => showVisualReport(),
                            _ => addToSmeta(),
                          },
                          fallback: Row(
                            children: [
                              OutlinedButton(
                                key: const ValueKey('open-3d'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                ),
                                onPressed: visual3D,
                                child: Tooltip(
                                  message: tr('3D ko‘rish'),
                                  child: const Icon(Icons.view_in_ar, size: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                key: const ValueKey('calculate-drawing'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                ),
                                onPressed: showVisualReport,
                                child: Tooltip(
                                  message: tr('Materiallar va sarf'),
                                  child: const Icon(Icons.receipt_long_outlined,
                                      size: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  key: const ValueKey('add-to-smeta'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: addToSmeta,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Tx('Smetaga qo‘shish'),
                                      ),
                                      if (price != null)
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Tx(
                                            price,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget numField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: WorkshopField(
          controller: c,
          label: label,
          number: true,
          decimal: c != quantity,
          helperText: tr(c == quantity ? 'Dona' : 'Millimetrda'),
          validator: (v) {
            final value = num.tryParse(v ?? '');
            if (value == null || !value.isFinite) return 'Son kiriting';
            if (c == quantity && (value < 1 || value > 1000)) {
              return '1–1000 dona';
            }
            if ((c == width || c == height) && (value < 300 || value > 6000)) {
              return '300–6000 mm';
            }
            return null;
          },
          onChanged: (_) => setState(() {
            report = null;
            error = null;
          }),
        ),
      );
  Future<void> positionDialog(DrawingCell c) async {
    DMap? parent;
    void find(DMap n) {
      if (n['axis'] == null) return;
      if (n['a']['id'] == selected || n['b']['id'] == selected) {
        parent = n;
        return;
      }
      find(n['a']);
      find(n['b']);
    }

    find(drawing['root']);
    if (parent == null) {
      setState(() => error = 'Avval bo‘limni tik yoki yotiq bo‘ling');
      return;
    }
    final s = layoutDrawing(
          drawing,
          recipe,
        ).splits.firstWhere((s) => s.node['id'] == parent!['id']),
        k = parent!['axis'] == 'v' ? 0 : 1;
    final field = TextEditingController(
      text: (c.box[k + 2] - c.box[k]).toStringAsFixed(0),
    );
    final form = GlobalKey<FormState>();
    final ok = await showSettledDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: Tx(k == 0 ? 'Bo‘lim ichki eni' : 'Bo‘lim ichki bo‘yi'),
        scrollable: true,
        content: Form(
          key: form,
          child: WorkshopField(
            controller: field,
            label: 'Ichki o‘lcham',
            number: true,
            action: TextInputAction.done,
            suffixText: 'mm',
            helperText: tr('Profil yuzlari orasidagi ichki masofa'),
            validator: (text) {
              final value = double.tryParse(text ?? '');
              final span = s.box[k + 2] - s.box[k];
              final face = (recipe['mullionFace'] as num).toDouble();
              if (value == null ||
                  !value.isFinite ||
                  value <= 0 ||
                  value >= span - face) {
                return '0 dan katta, ${(span - face).floor()} mm dan kichik o‘lcham kiriting';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Tx('Bekor'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Tx('Qo‘llash'),
          ),
        ],
      ),
    );
    if (ok == true) {
      change(() {
        final value = double.parse(field.text.replaceAll(',', '.')),
            span = s.box[k + 2] - s.box[k],
            f = (recipe['mullionFace'] as num).toDouble();
        parent!['ratio'] = parent!['a']['id'] == selected
            ? (value + f / 2) / span
            : 1 - (value + f / 2) / span;
      });
    }
    field.dispose();
  }
}

class DraftPlacement {
  /// Null when the drop is not allowed; [error] says why.
  final DMap? drawing;
  final String selection;
  final List<Offset> polygon, line;
  final List<(Offset, String)> labels;
  final bool snapped;
  final String? error;
  DraftPlacement(
    this.drawing,
    this.selection,
    this.polygon,
    this.line, {
    this.labels = const [],
    this.snapped = false,
    this.error,
  });
  bool get valid => drawing != null;
}

/// Live section sizes and the remove zone while an impost is dragged.
/// Grips on the sides of the chosen section. The one being pulled is filled.
class HandlesPainter extends CustomPainter {
  final List<({String side, Offset at})> handles;
  final String? active;
  final Color color;
  HandlesPainter(this.handles, {this.active, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    for (final h in handles) {
      final across = h.side == 'left' || h.side == 'right';
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: h.at,
          width: across ? 14 : 38,
          height: across ? 38 : 14,
        ),
        const Radius.circular(7),
      );
      final on = h.side == active;
      canvas.drawRRect(
        r.shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawRRect(r, Paint()..color = on ? color : Colors.white);
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
      // Two grip lines across the pull direction.
      final grip = Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = on ? Colors.white : color;
      for (final o in const [-3.0, 3.0]) {
        if (across) {
          canvas.drawLine(h.at + Offset(o, -8), h.at + Offset(o, 8), grip);
        } else {
          canvas.drawLine(h.at + Offset(-8, o), h.at + Offset(8, o), grip);
        }
      }
    }
  }

  @override
  bool shouldRepaint(HandlesPainter old) => true;
}

class DividerGuidePainter extends CustomPainter {
  final List<(Offset, String)> labels;
  final bool snapped, overTrash;
  final Rect? trash;
  DividerGuidePainter({
    required this.labels,
    required this.snapped,
    required this.trash,
    required this.overTrash,
  });
  @override
  void paint(Canvas canvas, Size size) {
    paintReadouts(
      canvas,
      labels,
      snapped ? const Color(0xff1f9d55) : const Color(0xff206bc4),
    );
    final zone = trash;
    if (zone == null) return;
    final color = overTrash ? const Color(0xffd63939) : const Color(0x99d63939);
    canvas.drawRRect(
      RRect.fromRectAndRadius(zone, const Radius.circular(21)),
      Paint()..color = color.withValues(alpha: overTrash ? .95 : .18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(zone, const Radius.circular(21)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
    final text = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: String.fromCharCode(Icons.delete_outline.codePoint),
            style: TextStyle(
              fontFamily: Icons.delete_outline.fontFamily,
              package: Icons.delete_outline.fontPackage,
              fontSize: 18,
              color: overTrash ? Colors.white : color,
            ),
          ),
          TextSpan(
            text: '  O‘chirish',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: overTrash ? Colors.white : color,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, zone.center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(DividerGuidePainter old) => true;
}

/// Miniature of a ready-made construction for the toolbar.
class PresetThumb extends StatelessWidget {
  final DrawingPreset preset;
  final DMap recipe;
  const PresetThumb({super.key, required this.preset, required this.recipe});
  static final _cache = <String, DMap>{};
  @override
  Widget build(BuildContext context) => DesignThumb(
        drawing: _cache.putIfAbsent(preset.id, preset.drawing),
        recipe: recipe,
      );
}

List<double> sectionStops(DrawingLayout layout, bool horizontal, double total) {
  final values = <double>[0, total];
  for (final split in layout.splits) {
    if ((split.node['axis'] == 'v') == horizontal) {
      final value = horizontal ? split.a.x : split.a.y;
      if (values.every((old) => (old - value).abs() > .01)) values.add(value);
    }
  }
  values.sort();
  return values;
}

class CanvasTransform {
  late double scale, dx, dy;
  CanvasTransform(Size s, DMap d, {bool sectionDimensions = false}) {
    final w = (d['widthMm'] as num).toDouble(),
        h = (d['heightMm'] as num).toDouble();
    // Dimension chains sit on the left and below, so only those sides
    // need wide margins; the drawing gets the rest of the canvas.
    final left = sectionDimensions ? 64.0 : 44.0,
        bottom = sectionDimensions ? 76.0 : 52.0,
        right = 16.0,
        top = 16.0;
    scale = math.min(
      (s.width - left - right) / w,
      (s.height - top - bottom) / h,
    );
    dx = left + (s.width - left - right - w * scale) / 2;
    dy = top + (s.height - top - bottom - h * scale) / 2;
  }
  Offset to(V p) => Offset(dx + p.x * scale, dy + p.y * scale);
  V from(Offset p) => V((p.dx - dx) / scale, (p.dy - dy) / scale);
}

bool pointIn(List<V> p, V v) {
  for (var i = 0; i < p.length; i++) {
    if (cross(p[(i + 1) % p.length] - p[i], v - p[i]) < -.01) return false;
  }
  return true;
}

double distanceToSegment(V p, V a, V b) {
  final v = b - a, s = v.x * v.x + v.y * v.y;
  final t =
      s == 0 ? 0.0 : (((p - a).x * v.x + (p - a).y * v.y) / s).clamp(0.0, 1.0);
  return (p - (a + v * t)).length;
}

/// The drawing desk's paper, in both themes.
const paperColor = Color(0xffedf4fb);

/// The opening symbol in a unit square, as the native toolbar draws it:
/// the same lines as on the drawing.
List<List<double>> openingIconStrokes(String opening) => [
      for (final line in openingSymbolLines(opening, const [0, 0, 1, 1]))
        [
          for (final v in line) ...[v.x, v.y]
        ],
    ];

/// The handle's short thick mark in a unit square, or null.
List<double>? openingIconMark(String opening) {
  final h = handlePoint(opening, const [0, 0, 1, 1]);
  if (h == null) return null;
  final side = hingeSide(opening), across = side == 'top' || side == 'bottom';
  return across
      ? [h.x - .18, h.y, h.x + .18, h.y]
      : [h.x, h.y - .18, h.x, h.y + .18];
}

/// SF Symbols for the opening types on the native toolbar.
const openingSymbols = {
  'fixed': 'rectangle',
  'left': 'arrow.left.square',
  'right': 'arrow.right.square',
  'tiltTurn': 'arrow.up.left.and.arrow.down.right.square',
  'top': 'arrow.up.square',
  'bottom': 'arrow.down.square',
  'slideLeft': 'arrow.left.to.line',
  'slideRight': 'arrow.right.to.line',
  'doorLeft': 'door.left.hand.open',
  'doorRight': 'door.right.hand.open',
  'passive': 'door.left.hand.closed',
};

/// The drawing desk follows the theme: black paper with white ink in the
/// dark, white paper with dark ink in the light.
Color deskPaper(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff000000)
        : const Color(0xffffffff);
Color deskInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xffffffff)
        : const Color(0xff111a24);

/// The dotted paper across the whole drawing desk.
class PaperPainter extends CustomPainter {
  final bool dark;
  const PaperPainter(this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..isAntiAlias = true
      ..color = dark ? const Color(0xff222a33) : const Color(0xffd9e1ea);
    for (double x = 12; x < size.width; x += 18) {
      for (double y = 12; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), .7, dot);
      }
    }
  }

  @override
  bool shouldRepaint(PaperPainter old) => old.dark != dark;
}

class DrawingPainter extends CustomPainter {
  final DMap drawing, recipe;
  final String? selected;
  final List<V> points;
  final bool editVertices, showResize, sectionDimensions;

  /// Draws the dotted paper; off where the screen's paper is behind.
  final bool paper;

  /// Sizes and their lines: white on the dark desk, ink on the light one.
  final Color? ink;
  DrawingPainter(
    this.drawing,
    this.recipe, {
    this.paper = true,
    this.ink,
    this.selected,
    this.points = const [],
    this.editVertices = false,
    this.showResize = false,
    this.sectionDimensions = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final t = CanvasTransform(
          size,
          drawing,
          sectionDimensions: sectionDimensions,
        ),
        paint = Paint()..isAntiAlias = true,
        dimColor = ink ?? const Color(0xff526981);
    for (double x = 12; paper && x < size.width; x += 18) {
      for (double y = 12; y < size.height; y += 18) {
        canvas.drawCircle(
          Offset(x, y),
          .7,
          paint..color = const Color(0xffd5e2ef),
        );
      }
    }
    DrawingLayout l;
    try {
      l = layoutDrawing(drawing, recipe);
    } catch (_) {
      return;
    }
    Path path(List<V> p) {
      final out = Path();
      if (p.isEmpty) return out;
      out.moveTo(t.to(p.first).dx, t.to(p.first).dy);
      for (final v in p.skip(1)) {
        out.lineTo(t.to(v).dx, t.to(v).dy);
      }
      return out..close();
    }

    void label(
      String s,
      Offset at, {
      double font = 10,
      Color color = const Color(0xff38536e),
    }) {
      final text = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: font,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }

    final finish = recipe['finish'] as String? ?? 'silver',
        lightFinish = finish == 'white' || finish == 'silver',
        frameColor = lightFinish
            ? const Color(0xffd8dee6)
            : Color(finishColors[finish] ?? 0xffd8dee6),
        sashColor = lightFinish
            ? const Color(0xfffcfcf8)
            : Color.lerp(frameColor, Colors.white, .18)!;
    canvas.drawShadow(path(l.outer), Colors.black26, 5, false);
    canvas.drawPath(
      path(l.outer),
      paint
        ..style = PaintingStyle.fill
        ..color = frameColor,
    );
    canvas.drawPath(
      path(l.outer),
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xff8d9eaf),
    );
    // 90° corner connector to the next construction.
    for (final side in cornerJoins(drawing)) {
      final w = (drawing['widthMm'] as num).toDouble(),
          h = (drawing['heightMm'] as num).toDouble(),
          x = side == 'left' ? -26.0 : w + 4;
      canvas.drawRect(
        Rect.fromPoints(t.to(V(x, 0)), t.to(V(x + 22, h))),
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xff3d4650),
      );
      label(
        '90°',
        t.to(V(x + 11, h / 2)) + Offset(side == 'left' ? -16 : 16, 0),
        font: 12,
        color: const Color(0xff3d4650),
      );
    }
    for (var i = 0; i < l.cells.length; i++) {
      final c = l.cells[i], n = c.node, active = n['opening'] != 'fixed';
      final poly = active
          ? inset(c.polygon, (recipe['sashFace'] as num).toDouble())
          : c.polygon;
      canvas.drawPath(
        path(c.polygon),
        paint
          ..style = PaintingStyle.fill
          ..color = active ? sashColor : frameColor,
      );
      if (poly.length < 3) continue;
      final color = n['fill'] == 'empty'
          ? const Color(0xffeef3f7)
          : n['fill'] == 'glass'
              ? const Color(0xff83d6dd)
              : n['fill'] == 'lambris'
                  ? const Color(0xffd4b794)
                  : const Color(0xfff0e9db);
      canvas.drawPath(path(poly), paint..color = color);
      canvas.drawPath(
        path(poly),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xff8ea5b4),
      );
      if (n['infill'] != null) {
        final infill = layoutInfill(c, recipe);
        for (var j = 0; j < infill.cells.length; j++) {
          final sub = infill.cells[j], fill = sub.node['fill'];
          canvas.drawPath(
            path(sub.polygon),
            paint
              ..style = PaintingStyle.fill
              ..color = fill == 'glass'
                  ? const Color(0xff83d6dd)
                  : fill == 'empty'
                      ? const Color(0xffeef3f7)
                      : const Color(0xffd4b794),
          );
          final box = bounds(sub.polygon);
          label(
            '${j + 1}',
            t.to(V((box[0] + box[2]) / 2, (box[1] + box[3]) / 2)),
            font: 9,
          );
        }
        for (final split in infill.splits) {
          canvas.drawLine(
            t.to(split.a),
            t.to(split.b),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(
                2,
                (recipe['mullionFace'] as num) * t.scale,
              )
              ..color = lightFinish ? const Color(0xffcbd5df) : sashColor,
          );
          canvas.drawCircle(
            (t.to(split.a) + t.to(split.b)) / 2,
            5,
            paint
              ..style = PaintingStyle.fill
              ..color = _blue,
          );
        }
      }
      for (final fill in layoutInfill(c, recipe).cells) {
        if (fill.node['fill'] != 'glass') continue;
        final glass = inset(
          fill.polygon,
          (recipe['glassGap'] as num).toDouble(),
        );
        final bars = decorativeBars(glass, n, GlazingSpec(recipe));
        for (final bar in bars) {
          canvas.drawLine(
            t.to(bar.a),
            t.to(bar.b),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, 8 * t.scale)
              ..color = const Color(0xffb49742),
          );
        }
        if (n['rosettes'] == true) {
          for (final at in decorativeJoints(bars)) {
            canvas.drawCircle(
              t.to(at),
              math.max(2, 15 * t.scale),
              paint
                ..style = PaintingStyle.fill
                ..color = const Color(0xffd6ba69),
            );
          }
        }
      }
      final b = bounds(poly),
          tl = t.to(V(b[0], b[1])),
          br = t.to(V(b[2], b[3]));
      canvas.save();
      canvas.clipPath(path(poly));
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = _blue;
      final opening = n['opening'] as String;
      for (final line in openingSymbolLines(opening, b)) {
        canvas.drawPath(
          Path()..addPolygon([for (final v in line) t.to(v)], false),
          paint,
        );
      }
      if (n['fill'] == 'lambris') {
        for (double y = tl.dy + 8; y < br.dy; y += 10) {
          canvas.drawLine(
            Offset(tl.dx, y),
            Offset(br.dx, y),
            paint
              ..color = const Color(0xffb29475)
              ..strokeWidth = .6,
          );
        }
      }
      if (n['mesh'] == true) {
        paint
          ..color = Colors.blueGrey.withValues(alpha: .25)
          ..strokeWidth = .4;
        for (double x = tl.dx; x < br.dx; x += 7) {
          canvas.drawLine(Offset(x, tl.dy), Offset(x, br.dy), paint);
        }
        for (double y = tl.dy; y < br.dy; y += 7) {
          canvas.drawLine(Offset(tl.dx, y), Offset(br.dx, y), paint);
        }
      }
      canvas.restore();
      label(
        '${i + 1}',
        Offset((tl.dx + br.dx) / 2, (tl.dy + br.dy) / 2),
        font: 12,
      );
      final handleAt = handlePoint(opening, b);
      if (active && handleAt != null) {
        final handle = t.to(handleAt),
            side = hingeSide(opening),
            along = side == 'top' || side == 'bottom'
                ? const Offset(7, 0)
                : const Offset(0, 7);
        canvas.drawLine(
          handle - along,
          handle + along,
          paint
            ..style = PaintingStyle.stroke
            ..color = const Color(0xff33485e)
            ..strokeWidth = 3,
        );
        if (n['outward'] == true) {
          label('T', handle + const Offset(-8, 12), font: 8);
        }
      }
      if (n['mesh'] == true && active) {
        label('setka', Offset((tl.dx + br.dx) / 2, br.dy - 9), font: 7);
      }
      final locks = (n['locks'] as num? ?? 1).toInt();
      if (active && locks > 1) {
        label('$locks qulf', Offset((tl.dx + br.dx) / 2, tl.dy + 9), font: 7);
      }
      if (n['id'] == selected) {
        canvas.drawPath(
          path(c.polygon),
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = _blue,
        );
      }
      if (!sectionDimensions && b[2] - b[0] > 180) {
        label(
          '${(c.box[2] - c.box[0]).round()}',
          t.to(V((c.box[0] + c.box[2]) / 2, c.box[3])) + const Offset(0, 9),
          font: 8,
        );
      }
    }
    for (final s in l.splits) {
      final a = t.to(s.a), b = t.to(s.b);
      canvas.drawLine(
        a,
        b,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, (recipe['mullionFace'] as num) * t.scale)
          ..color = lightFinish ? const Color(0xffcbd5df) : frameColor,
      );
      canvas.drawCircle(
        (a + b) / 2,
        5,
        paint
          ..style = PaintingStyle.fill
          ..color = _blue,
      );
      canvas.drawCircle((a + b) / 2, 2, paint..color = Colors.white);
    }
    final w = (drawing['widthMm'] as num).toDouble(),
        h = (drawing['heightMm'] as num).toDouble(),
        a = t.to(const V(0, 0)),
        b = t.to(V(w, h));
    paint
      ..style = PaintingStyle.stroke
      ..color = dimColor
      ..strokeWidth = .8;
    canvas.drawLine(
      Offset(a.dx, b.dy + (sectionDimensions ? 46 : 26)),
      Offset(b.dx, b.dy + (sectionDimensions ? 46 : 26)),
      paint,
    );
    canvas.drawLine(
      Offset(a.dx - (sectionDimensions ? 43 : 22), a.dy),
      Offset(a.dx - (sectionDimensions ? 43 : 22), b.dy),
      paint,
    );
    for (final x in [a.dx, b.dx]) {
      canvas.drawLine(
        Offset(x, b.dy + (sectionDimensions ? 40 : 20)),
        Offset(x, b.dy + (sectionDimensions ? 52 : 32)),
        paint,
      );
    }
    for (final y in [a.dy, b.dy]) {
      canvas.drawLine(
        Offset(a.dx - (sectionDimensions ? 48 : 27), y),
        Offset(a.dx - (sectionDimensions ? 38 : 17), y),
        paint,
      );
    }
    label(
      '${w.round()} mm',
      Offset((a.dx + b.dx) / 2, b.dy + (sectionDimensions ? 58 : 37)),
      font: 12,
      color: dimColor,
    );
    canvas.save();
    canvas.translate(a.dx - (sectionDimensions ? 51 : 35), (a.dy + b.dy) / 2);
    canvas.rotate(-math.pi / 2);
    label('${h.round()} mm', Offset.zero, font: 12, color: dimColor);
    canvas.restore();
    if (sectionDimensions) {
      for (final horizontal in [true, false]) {
        final stops = sectionStops(l, horizontal, horizontal ? w : h);
        if (stops.length < 3) continue;
        for (var i = 0; i < stops.length - 1; i++) {
          final first = t.to(horizontal ? V(stops[i], h) : V(0, stops[i]));
          final last = t.to(
            horizontal ? V(stops[i + 1], h) : V(0, stops[i + 1]),
          );
          paint
            ..style = PaintingStyle.stroke
            ..color = dimColor
            ..strokeWidth = .8;
          if (horizontal) {
            canvas.drawLine(
              first + const Offset(0, 16),
              last + const Offset(0, 16),
              paint,
            );
            for (final at in [first, last]) {
              canvas.drawLine(
                at + const Offset(0, 12),
                at + const Offset(0, 20),
                paint,
              );
            }
            if (last.dx - first.dx > 30) {
              label(
                '${(stops[i + 1] - stops[i]).round()}',
                Offset((first.dx + last.dx) / 2, b.dy + 27),
                font: 11,
                color: dimColor,
              );
            }
          } else {
            canvas.drawLine(
              first - const Offset(16, 0),
              last - const Offset(16, 0),
              paint,
            );
            for (final at in [first, last]) {
              canvas.drawLine(
                at - const Offset(12, 0),
                at - const Offset(20, 0),
                paint,
              );
            }
            if (last.dy - first.dy > 30) {
              canvas.save();
              canvas.translate(a.dx - 25, (first.dy + last.dy) / 2);
              canvas.rotate(-math.pi / 2);
              label(
                '${(stops[i + 1] - stops[i]).round()}',
                Offset.zero,
                font: 11,
                color: dimColor,
              );
              canvas.restore();
            }
          }
        }
      }
    }
    // A stepped frame: how far each step is cut (the wall under side
    // windows), measured along the step.
    if (l.outer.length > 4 && drawing['shape'] == 'rect') {
      bool on(double v, double end) => v.abs() < .5 || (v - end).abs() < .5;
      for (var i = 0; i < l.outer.length; i++) {
        final p = l.outer[i], q = l.outer[(i + 1) % l.outer.length];
        final vertical = (p.x - q.x).abs() < .5;
        final step = vertical
            ? !on(p.x, w) && (on(p.y, h) || on(q.y, h))
            : !on(p.y, h) && (on(p.x, w) || on(q.x, w));
        if (!step) continue;
        final e = q - p, out = V(e.y, -e.x) * (1 / e.length);
        final a = t.to(p) + Offset(out.x, out.y) * 12,
            b = t.to(q) + Offset(out.x, out.y) * 12;
        paint
          ..style = PaintingStyle.stroke
          ..color = const Color(0xffc0631d)
          ..strokeWidth = 1;
        canvas.drawLine(a, b, paint);
        for (final end in [a, b]) {
          canvas.drawLine(
            end - Offset(out.x, out.y) * 4,
            end + Offset(out.x, out.y) * 4,
            paint,
          );
        }
        final mid = (a + b) / 2 + Offset(out.x, out.y) * 12;
        if (vertical) {
          canvas.save();
          canvas.translate(mid.dx, mid.dy);
          canvas.rotate(-math.pi / 2);
          label(
            '${e.length.round()}',
            Offset.zero,
            font: 11,
            color: const Color(0xffc0631d),
          );
          canvas.restore();
        } else {
          label(
            '${e.length.round()}',
            mid,
            font: 11,
            color: const Color(0xffc0631d),
          );
        }
      }
    }
    if (showResize) {
      final at = t.to(V(w, h));
      canvas.drawCircle(
        at,
        12,
        paint
          ..style = PaintingStyle.fill
          ..color = Colors.white,
      );
      canvas.drawCircle(at, 9, paint..color = _blue);
      canvas.drawLine(
        at - const Offset(4, 4),
        at + const Offset(4, 4),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
    if (editVertices && drawing['shape'] == 'custom') {
      final vertices = drawing['vertices'] as List;
      for (var j = 0; j < vertices.length; j++) {
        final at = t.to(
          V((vertices[j][0] as num) * w, (vertices[j][1] as num) * h),
        );
        canvas.drawCircle(
          at,
          9,
          paint
            ..style = PaintingStyle.fill
            ..color = Colors.amber.shade700,
        );
        label('${j + 1}', at, font: 10, color: Colors.black);
      }
    }
    if (points.isNotEmpty) {
      final p = [for (final v in points) V(v.x * w, v.y * h)];
      for (var i = 0; i < p.length; i++) {
        canvas.drawCircle(
          t.to(p[i]),
          4,
          paint
            ..style = PaintingStyle.fill
            ..color = Colors.deepOrange,
        );
        if (i > 0) {
          canvas.drawLine(
            t.to(p[i - 1]),
            t.to(p[i]),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

class DrawingReport extends StatelessWidget {
  final DMap item;
  const DrawingReport({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    final cuts = Map<String, dynamic>.from(item['cuts'] ?? {}),
        sheets = Map<String, dynamic>.from(item['sheetPlans'] ?? {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Tx(
          money(item['total']),
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.bold,
            color: _blue,
          ),
        ),
        Tx(
          '${item['quantity']} dona uchun · tannarx ${money(item['cost'])}\n${item['openingCount']} ochiladigan qanot / konstruksiya',
        ),
        Tx(
          'Narx sanasi: ${item['priceDate'] == '' ? 'kiritilmagan' : item['priceDate']}',
        ),
        GlassControl(
            child: ExpansionTile(
          title: const Tx('Materiallar va xarid summasi'),
          initiallyExpanded: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Tx(
                'Sof sarf → narxdagi miqdor. Xarid uchun butun tayoq va list soni alohida yozilgan. Barcha sonlar jami konstruksiyalar uchun.',
              ),
            ),
            for (final p in item['parts'] as List)
              GlassControl(
                  child: ListTile(
                dense: true,
                title: Tx(p['name']),
                subtitle: Tx(
                  p['charged'] != null && p['charged'] != p['quantity']
                      ? 'Sof ${(p['net'] as num).toStringAsFixed(3)} → narxda ${(p['charged'] as num).toStringAsFixed(3)} ${p['unit']} × ${money(p['price'])}\nXarid: ${(p['quantity'] as num).toStringAsFixed(3)} ${p['unit']} (butun tayoq/list)'
                      : '${(p['net'] as num).toStringAsFixed(3)} → ${(p['quantity'] as num).toStringAsFixed(3)} ${p['unit']} × ${money(p['price'])}',
                ),
                trailing: Tx(money(p['cost'])),
              )),
          ],
        )),
        GlassControl(
            child: ExpansionTile(
          title: const Tx('Profil kesish kartalari va chiqindi'),
          children: [
            for (final e in cuts.entries)
              GlassControl(
                  child: ExpansionTile(
                title: Tx(
                  '${materialNames[e.key]} • ${(e.value['bars'] as List).length} tayoq',
                ),
                subtitle: Tx(
                  'Sof ${(e.value['netMm'] / 1000).toStringAsFixed(3)} m · xarid ${(e.value['purchasedMm'] / 1000).toStringAsFixed(3)} m',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Tx(
                      'Arra izi: ${e.value['sawMm']} mm\nYaroqli qoldiq: ${e.value['reusableMm']} mm\nMayda chiqindi: ${e.value['scrapMm']} mm\nJami qoldiq: ${e.value['offcutMm']} mm',
                    ),
                  ),
                  for (var j = 0; j < (e.value['bars'] as List).length; j++)
                    GlassControl(
                        child: ListTile(
                      dense: true,
                      title: Tx(
                        '${j + 1}: ${(e.value['bars'][j]['pieces'] as List).map((v) => (v as num).round()).join(' + ')} mm',
                      ),
                      subtitle: Tx(
                        'Qoldiq: ${(e.value['bars'][j]['remaining'] as num).toStringAsFixed(1)} mm',
                      ),
                    )),
                ],
              )),
          ],
        )),
        GlassControl(
            child: ExpansionTile(
          title: const Tx('Shisha, panel va lambir listlari'),
          children: [
            for (final e in sheets.entries)
              GlassControl(
                  child: ExpansionTile(
                title: Tx(
                  '${materialNames[e.key]}: ${(e.value['sheets'] as List).length} list',
                ),
                subtitle: Tx('${e.value['sheetW']}×${e.value['sheetH']} mm'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Tx(
                      'Sof ${(e.value['netM2'] as num).toStringAsFixed(3)} m²\nXarid ${(e.value['purchaseM2'] as num).toStringAsFixed(3)} m²\nList qoldig‘i + kesish yo‘qotilishi ${(e.value['offcutM2'] as num).toStringAsFixed(3)} m² (qayta ishlatish avtomatik baholanmagan)',
                    ),
                  ),
                  for (var k = 0; k < (e.value['sheets'] as List).length; k++)
                    GlassControl(
                        child: ListTile(
                      title: Tx('List ${k + 1}'),
                      subtitle: Tx(
                        (e.value['sheets'][k]['rows'] as List)
                            .expand((r) => r['parts'] as List)
                            .map(
                              (p) =>
                                  '${(p['w'] as num).ceil()}×${(p['h'] as num).ceil()} mm',
                            )
                            .join(' · '),
                      ),
                    )),
                ],
              )),
          ],
        )),
        GlassControl(
            child: ExpansionTile(
          title: const Tx('Har bir bo‘lim tafsiloti'),
          children: [
            for (final s in item['specs'] as List)
              GlassControl(
                  child: ListTile(
                title: Tx('${s['opening']} · ${s['fill']}'),
                subtitle: Tx(
                  '${(s['widthMm'] as num).toStringAsFixed(1)}×${(s['heightMm'] as num).toStringAsFixed(1)} mm · ${(s['areaM2'] as num).toStringAsFixed(3)} m²\n${s['outward'] == true ? 'Tashqariga' : 'Ichkariga'}${s['lambrisStrips'] != null ? ' · Lambir: ${s['lambrisStrips']} dona ishchi yo‘lak' : ''}',
                ),
              )),
          ],
        )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Tx(
            item['warning'] ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.brown),
          ),
        ),
      ],
    );
  }
}

class RecipeEditor extends StatefulWidget {
  final DMap recipe;
  const RecipeEditor({super.key, required this.recipe});
  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  late DMap r;
  late Map<String, TextEditingController> params, prices, stocks, colours;
  late TextEditingController date, source;
  final priceSearch = TextEditingController();
  String priceQuery = '';
  String? error;
  @override
  void initState() {
    super.initState();
    r = {...defaultRecipe({}), ...cloneMap(widget.recipe)};
    params = {
      for (final k in recipeLabels.keys)
        k: TextEditingController(text: '${r[k]}'),
    };
    prices = {
      for (final k in materialNames.keys)
        k: TextEditingController(text: '${r['prices'][k] ?? 0}'),
    };
    stocks = {
      for (final k in linearStock)
        k: TextEditingController(
          text: '${r['stockOverrides']?[k]?['stockMm'] ?? r['stockMm']}',
        ),
    };
    colours = {
      for (final k in finishNames.keys)
        k: TextEditingController(text: '${(r['colorPct'] as Map?)?[k] ?? 0}'),
    };
    date = TextEditingController(text: r['priceDate']);
    source = TextEditingController(text: r['priceSource']);
  }

  @override
  void dispose() {
    for (final c in [
      ...params.values,
      ...prices.values,
      ...stocks.values,
      ...colours.values,
      date,
      source,
      priceSearch,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  num readNumber(TextEditingController controller, String label) {
    final value = num.tryParse(controller.text);
    if (value == null || !value.isFinite || value < 0) {
      throw Exception('$label: 0 yoki musbat son kiriting');
    }
    return value;
  }

  Widget input(TextEditingController c, String label, {bool numeric = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: WorkshopField(controller: c, label: label, number: numeric),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: GlassAppBar(title: const Tx('Materiallar va narxlar')),
        body: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              const Tx(
                'Bu qiymatlar sex retsepti. Namunaviy narxlarni yetkazib beruvchi narxi bilan almashtiring. Internetdan jonli narx olinmaydi; yangi narxni kiritganda hisob yangilanadi.',
              ),
              const SizedBox(height: 16),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: r['sectionStyle'],
                  decoration: InputDecoration(labelText: tr('Profil kesimi')),
                  items: const [
                    DropdownMenuItem(
                      value: 'plainHollow',
                      child: Tx('Oddiy alyuminiy • 1 ta bo‘sh kamera'),
                    ),
                    DropdownMenuItem(
                      value: 'chambered',
                      child: Tx('Oldingi kamerali namuna'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    r['sectionStyle'] = v;
                    if (v == 'plainHollow') {
                      r['profileChambers'] = 1;
                      params['profileChambers']!.text = '1';
                    }
                  }),
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: r['glazingType'],
                  decoration: InputDecoration(labelText: tr('Shisha turi')),
                  items: const [
                    DropdownMenuItem(
                      value: 'single',
                      child: Tx('Bir qavat shisha'),
                    ),
                    DropdownMenuItem(
                      value: 'double',
                      child: Tx('Ikki shisha + metall ajratgich'),
                    ),
                  ],
                  onChanged: (v) => setState(() => r['glazingType'] = v),
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: finishNames.containsKey(r['finish'])
                      ? r['finish']
                      : 'silver',
                  decoration: InputDecoration(labelText: tr('Profil rangi')),
                  items: [
                    for (final e in finishNames.entries)
                      DropdownMenuItem(value: e.key, child: Tx(e.value)),
                  ],
                  onChanged: (v) => setState(() => r['finish'] = v),
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: r['pricingMode'] ?? 'net',
                  decoration: InputDecoration(
                    labelText: tr('Mijoz narxi qanday hisoblanadi'),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'net',
                      child: Tx('Ishlatilgan metr/m² + chiqindi %'),
                    ),
                    DropdownMenuItem(
                      value: 'purchase',
                      child: Tx('Butun tayoq va list (qoldiq bilan)'),
                    ),
                  ],
                  onChanged: (v) => setState(() => r['pricingMode'] = v),
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: r['profileDetail'] ?? 'rebated',
                  decoration: InputDecoration(
                    labelText: tr('Oddiy profil 3D shakli'),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'rebated',
                      child: Tx('Shisha o‘rni va pog‘onali qirra'),
                    ),
                    DropdownMenuItem(
                      value: 'box',
                      child: Tx('Oldingi to‘rtburchak bo‘sh profil'),
                    ),
                  ],
                  onChanged: (v) => setState(() => r['profileDetail'] = v),
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: r['hardwareFinish'] ?? 'black',
                  decoration: InputDecoration(
                    labelText: tr('Tutqich va petlya rangi'),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'black', child: Tx('Qora / grafit')),
                    DropdownMenuItem(value: 'silver', child: Tx('Kumushrang')),
                    DropdownMenuItem(value: 'gold', child: Tx('Oltinrang')),
                  ],
                  onChanged: (v) => setState(() => r['hardwareFinish'] = v),
                ),
              ),
              const SizedBox(height: 12),
              input(date, 'Narx sanasi (YYYY-MM-DD)', numeric: false),
              input(source, 'Narx manbasi / yetkazib beruvchi', numeric: false),
              GlassControl(
                  child: ExpansionTile(
                title: const Tx('Geometriya, rezina va texnik me’yorlar'),
                children: [
                  for (final e in recipeLabels.entries)
                    input(params[e.key]!, e.value),
                ],
              )),
              GlassControl(
                  child: ExpansionTile(
                title: const Tx('Barcha materiallar narxi (UZS)'),
                initiallyExpanded: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: WorkshopField(
                      controller: priceSearch,
                      label: 'Materialni qidirish',
                      action: TextInputAction.search,
                      onChanged: (v) =>
                          setState(() => priceQuery = v.trim().toLowerCase()),
                    ),
                  ),
                  for (final e in materialNames.entries.where(
                    (e) => e.value.toLowerCase().contains(priceQuery),
                  ))
                    input(
                      prices[e.key]!,
                      '${e.value} / ${linearStock.contains(e.key) || meterMaterials.contains(e.key) ? 'metr' : areaMaterials.contains(e.key) ? 'm²' : e.key == 'desiccant' ? 'kg' : 'dona'}',
                    ),
                ],
              )),
              GlassControl(
                  child: ExpansionTile(
                title: const Tx('Rang ustamasi (profil narxiga, %)'),
                children: [
                  for (final k in finishNames.keys)
                    input(colours[k]!, '${finishNames[k]} (%)'),
                ],
              )),
              GlassControl(
                  child: ExpansionTile(
                title: const Tx('Har bir profil tayoq uzunligi'),
                children: [
                  for (final k in linearStock)
                    input(stocks[k]!, '${materialNames[k]} tayoq (mm)'),
                ],
              )),
              const SizedBox(height: 16),
              const Tx(
                'Qo‘shimcha xomashyo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Tx(
                'Armatura, burchak, qo‘shimcha rezina va boshqa material uchun o‘z formulasini qo‘shing.',
              ),
              for (var j = 0; j < (r['customMaterials'] as List).length; j++)
                GlassControl(
                    child: ListTile(
                  title: Tx(r['customMaterials'][j]['name']),
                  subtitle: Tx(
                    '${r['customMaterials'][j]['rate']} × ${r['customMaterials'][j]['basis']} · ${money(r['customMaterials'][j]['price'])}',
                  ),
                  onTap: () => extra(j),
                  trailing: IconButton(
                    onPressed: () => setState(
                        () => (r['customMaterials'] as List).removeAt(j)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                )),
              OutlinedButton.icon(
                onPressed: () => extra(null),
                icon: const Icon(Icons.add),
                label: const Tx('Material va formula qo‘shish'),
              ),
              if (error != null)
                Tx(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: () {
                  try {
                    final result = cloneMap(r);
                    for (final k in params.keys) {
                      result[k] = readNumber(params[k]!, recipeLabels[k]!);
                    }
                    result['prices'] = {
                      for (final k in prices.keys)
                        k: readNumber(prices[k]!, materialNames[k]!),
                    };
                    result['stockOverrides'] = {
                      for (final k in stocks.keys)
                        k: {
                          'stockMm': readNumber(
                            stocks[k]!,
                            '${materialNames[k]} tayoq',
                          ),
                        },
                    };
                    result['colorPct'] = {
                      for (final k in colours.keys)
                        k: readNumber(
                            colours[k]!, '${finishNames[k]} ustamasi'),
                    };
                    result['priceDate'] = date.text;
                    result['priceSource'] = source.text;
                    validateRecipe(result);
                    Navigator.pop(context, result);
                  } catch (e) {
                    setState(() => error = '$e');
                  }
                },
                child: const Tx('Narx va me’yorlarni qo‘llash'),
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      );
  Future<void> extra(int? index) async {
    final old = index == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(r['customMaterials'][index]);
    final name = TextEditingController(text: old['name'] ?? ''),
        unit = TextEditingController(text: old['unit'] ?? 'dona'),
        rate = TextEditingController(text: '${old['rate'] ?? 1}'),
        price = TextEditingController(text: '${old['price'] ?? 0}');
    String basis = old['basis'] ?? 'piece';
    String? failure;
    const bases = {
      'frameM': 'Rama perimetri, m',
      'sashM': 'Qanot perimetri, m',
      'mullionM': 'Impost, m',
      'glassPerimeterM': 'To‘ldirma perimetri, m',
      'glassM2': 'Shisha maydoni, m²',
      'panelM2': 'Panel maydoni, m²',
      'areaM2': 'Rom maydoni, m²',
      'opening': 'Ochilgan qanot soni',
      'door': 'Eshik qanoti soni',
      'piece': 'Konstruksiya soni',
    };
    final result = await showSettledDialog<DMap>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => GlassAlertDialog(
          title: const Tx('Material formulasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                input(name, 'Material nomi', numeric: false),
                GlassControl(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: basis,
                    items: [
                      for (final e in bases.entries)
                        DropdownMenuItem(value: e.key, child: Tx(e.value)),
                    ],
                    onChanged: (v) => set(() => basis = v!),
                  ),
                ),
                const SizedBox(height: 12),
                input(rate, 'Har birlik uchun sarf koeffitsiyenti'),
                input(unit, 'O‘lchov birligi', numeric: false),
                input(price, 'Birlik narxi, UZS'),
                if (failure != null)
                  Tx(failure!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Tx('Bekor'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final a = num.parse(rate.text.replaceAll(',', '.')),
                      b = num.parse(price.text.replaceAll(',', '.'));
                  if (name.text.trim().isEmpty ||
                      unit.text.trim().isEmpty ||
                      a < 0 ||
                      b < 0 ||
                      !a.isFinite ||
                      !b.isFinite) {
                    throw Exception('Nom, birlik va musbat qiymat kiriting');
                  }
                  Navigator.pop(context, {
                    'name': name.text.trim(),
                    'unit': unit.text.trim(),
                    'basis': basis,
                    'rate': a,
                    'price': b,
                  });
                } catch (e) {
                  set(() => failure = '$e');
                }
              },
              child: const Tx('Saqlash'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        if (index == null) {
          (r['customMaterials'] as List).add(result);
        } else {
          r['customMaterials'][index] = result;
        }
      });
    }
    for (final c in [name, unit, rate, price]) {
      c.dispose();
    }
  }
}
