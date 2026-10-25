import 'adaptive_ui.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_engine.dart';
import 'drawing_3d.dart';
import 'dialogs.dart';
import 'photo_window_page.dart';
import 'store.dart';

/// Usual places for a window, offered as one-tap labels.
const roomNames = [
  'Zal',
  'Oshxona',
  'Yotoqxona',
  'Bolalar xonasi',
  'Mehmonxona',
  'Balkon',
  'Koridor',
  'Hammom',
  'Ofis',
  'Do‘kon',
];

/// Asks where the window goes. Null when cancelled, '' to remove the label.
Future<String?> pickRoom(BuildContext context, String? current) {
  final field = TextEditingController(text: current ?? '');
  return showSettledDialog<String>(
    context: context,
    builder: (c) => GlassAlertDialog(
      title: const Text('Rom joyi'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassControl(
            child: TextField(
              key: const ValueKey('room-field'),
              controller: field,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Masalan: Zal, 2-qavat oshxona',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in roomNames)
                GlassControl(
                  child: ActionChip(
                    label: Text(r),
                    onPressed: () => Navigator.pop(c, r),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => Navigator.pop(c, ''),
            child: const Text('Olib tashlash'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Bekor'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, field.text.trim()),
          child: const Text('Saqlash'),
        ),
      ],
    ),
  ).whenComplete(field.dispose);
}

/// A window design drawn like a product picture: light frame, tinted
/// glass with a highlight, grey sandwich panels.
class DesignPainter extends CustomPainter {
  final DMap drawing, recipe;

  /// White frame and deep blue glass, for the catalog tabs.
  final bool hero;
  final bool dark;

  /// On a photo of the opening: the window fills the size exactly (in mm
  /// when the size is the window's), in its real colour, with sashes and
  /// handles, and the glass lets a little of the photo through.
  final bool installed;
  DesignPainter(
    this.drawing,
    this.recipe, {
    this.hero = false,
    this.dark = false,
    this.installed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final DrawingLayout l;
    try {
      l = layoutDrawing(drawing, recipe);
    } catch (_) {
      return;
    }
    final w = (drawing['widthMm'] as num).toDouble(),
        h = (drawing['heightMm'] as num).toDouble(),
        margin = installed ? 0 : 2,
        s = math.min((size.width - margin) / w, (size.height - margin) / h),
        dx = (size.width - w * s) / 2,
        dy = (size.height - h * s) / 2;
    Offset to(V v) => Offset(dx + v.x * s, dy + v.y * s);
    Path path(List<V> p) => Path()..addPolygon(p.map(to).toList(), true);
    final frame = installed
        ? Color(finishColors[recipe['finish'] ?? 'white'] ?? 0xfff4f6f8)
        : hero
            ? Colors.white
            : dark
                ? const Color(0xff9aabbd)
                : const Color(0xffe2e9f0);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = installed ? 4 * s : .8
      ..color = Colors.black.withValues(alpha: installed ? .22 : .06);
    canvas.drawPath(path(l.outer), Paint()..color = frame);
    if (!hero) canvas.drawPath(path(l.outer), edge);
    if (installed) canvas.drawPath(path(l.inner), edge);

    void pane(List<V> polygon, String fill) {
      final p = path(polygon), r = p.getBounds();
      if (fill == 'empty') return;
      if (fill == 'panel' || fill == 'lambris') {
        canvas.drawPath(
          p,
          Paint()
            ..color = hero
                ? const Color(0xffb9c7d3)
                : dark
                    ? const Color(0xff708293)
                    : const Color(0xffc5d1db),
        );
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..color = Colors.black.withValues(alpha: .1),
        );
        if (fill == 'lambris') {
          final line = Paint()
            ..color = Colors.black.withValues(alpha: .08)
            ..strokeWidth = .8;
          canvas.save();
          canvas.clipPath(p);
          for (var y = r.top + 5; y < r.bottom; y += 5) {
            canvas.drawLine(Offset(r.left, y), Offset(r.right, y), line);
          }
          canvas.restore();
        }
        return;
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white.withValues(alpha: installed ? .78 : 1)
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: installed
                ? const [
                    Color(0xc86f9fbd),
                    Color(0xb0a9cfe3),
                    Color(0xc8789fb8),
                  ]
                : hero
                    ? const [
                        Color(0xff0a78c8),
                        Color(0xff1e94e0),
                        Color(0xff0a78c8),
                      ]
                    : const [
                        Color(0xff86c4e6),
                        Color(0xffb6dcf0),
                        Color(0xff8fcae8),
                      ],
            stops: const [0, .55, 1],
          ).createShader(r),
      );
      // Two light streaks, as on the glass in a showroom picture.
      canvas.save();
      canvas.clipPath(p);
      final streak = Paint()
        ..color = Colors.white.withValues(alpha: hero ? .35 : .4)
        ..strokeWidth = math.max(1, r.shortestSide * .05);
      final k = r.shortestSide;
      canvas.drawLine(
        r.bottomLeft + Offset(k * .25, -k * .1),
        r.topLeft + Offset(k * .75, k * .3),
        streak,
      );
      canvas.drawLine(
        r.bottomLeft + Offset(k * .45, -k * .05),
        r.topLeft + Offset(k * .95, k * .35),
        streak..strokeWidth *= .5,
      );
      canvas.restore();
    }

    for (final c in l.cells) {
      final opening = c.node['opening'] as String? ?? 'fixed';
      if (c.node['infill'] != null) {
        canvas.drawPath(path(c.polygon), Paint()..color = frame);
        for (final part in layoutInfill(c, recipe).cells) {
          pane(part.polygon, part.node['fill'] as String? ?? 'glass');
        }
      } else if (installed && opening != 'fixed') {
        // The sash: its own frame round the glass, and the handle.
        canvas.drawPath(path(c.polygon), Paint()..color = frame);
        canvas.drawPath(path(c.polygon), edge);
        final glass = inset(c.polygon, (recipe['sashFace'] as num).toDouble());
        if (glass.length > 2) {
          pane(glass, c.node['fill'] as String? ?? 'glass');
          canvas.drawPath(path(glass), edge);
        }
      } else {
        pane(c.polygon, c.node['fill'] as String? ?? 'glass');
      }
      if (installed && opening != 'fixed') {
        final b = bounds(c.polygon), hinge = handlePoint(opening, b);
        if (hinge != null) {
          // On the middle of the sash frame, not its outer edge.
          final half = (recipe['sashFace'] as num).toDouble() / 2,
              at = V(
                hinge.x == b[0]
                    ? hinge.x + half
                    : hinge.x == b[2]
                        ? hinge.x - half
                        : hinge.x,
                hinge.y == b[1]
                    ? hinge.y + half
                    : hinge.y == b[3]
                        ? hinge.y - half
                        : hinge.y,
              );
          final vertical = at.x != hinge.x;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: to(at),
                width: (vertical ? 26 : 120) * s,
                height: (vertical ? 120 : 26) * s,
              ),
              Radius.circular(10 * s),
            ),
            Paint()..color = const Color(0xff4a5561),
          );
        }
      }
      if (!hero && !installed && opening != 'fixed') {
        final b = bounds(c.polygon);
        final mark = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9
          ..color = const Color(0xff1f5f8f).withValues(alpha: .45);
        for (final line in openingSymbolLines(opening, b)) {
          canvas.drawPath(
            Path()..addPolygon(line.map(to).toList(), false),
            mark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(DesignPainter old) =>
      old.drawing != drawing || old.hero != hero || old.dark != dark;
}

class DesignThumb extends StatelessWidget {
  final DMap drawing, recipe;
  final bool hero;
  const DesignThumb({
    super.key,
    required this.drawing,
    required this.recipe,
    this.hero = false,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.infinite,
        painter: DesignPainter(
          drawing,
          recipe,
          hero: hero,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      );
}

/// What was picked in the catalog. [preset] is null for a blank window.
class CatalogChoice {
  final DrawingPreset? preset;
  final num width, height;
  final int count;
  final String? room;

  /// A drawing made elsewhere (the AI camera) instead of a design.
  final DMap? custom;
  const CatalogChoice(
    this.preset,
    this.width,
    this.height,
    this.count,
    this.room,
  ) : custom = null;
  CatalogChoice.photo(DMap this.custom, this.count, this.room)
      : preset = null,
        width = custom['widthMm'] as num,
        height = custom['heightMm'] as num;

  DMap drawing() =>
      custom ??
      preset?.drawing(width: width, height: height) ??
      {...newDrawing(), 'widthMm': width, 'heightMm': height};

  /// A new smeta window, ready for the drawing editor.
  DMap item() => {
        'drawing': drawing(),
        'quantity': count,
        if (room != null) 'label': room,
      };
}

/// The profile the editor starts with, for the thumbnails' proportions.
DMap catalogRecipe(Store store) => recipeFor(
      store.profiles.firstWhere(
        (p) => p['id'] == 'series-akfa-simple-thick',
        orElse: () => store.profiles.first,
      ),
    );

Future<CatalogChoice?> openDesignCatalog(
  BuildContext context, {
  required DMap recipe,
  Store? store,
  num? width,
  num? height,
  int count = 1,
  String? room,
  bool replacing = false,
}) =>
    Navigator.push<CatalogChoice>(
      context,
      MaterialPageRoute(
        builder: (_) => DesignCatalogPage(
          recipe: recipe,
          store: store,
          width: width,
          height: height,
          count: count,
          room: room,
          replacing: replacing,
        ),
      ),
    );

/// Ready designs by kind (windows, doors, arches, other shapes), or a blank
/// window, with its size, count and room.
class DesignCatalogPage extends StatefulWidget {
  final DMap recipe;

  /// For the AI camera card; without it the card is not shown.
  final Store? store;
  final num? width, height;
  final int count;
  final String? room;

  /// Opened from the drawing desk: the design replaces the current drawing
  /// and keeps its size unless another size is typed.
  final bool replacing;
  const DesignCatalogPage({
    super.key,
    required this.recipe,
    this.store,
    this.width,
    this.height,
    this.count = 1,
    this.room,
    this.replacing = false,
  });
  @override
  State<DesignCatalogPage> createState() => _DesignCatalogPageState();
}

class _DesignCatalogPageState extends State<DesignCatalogPage> {
  String group = 'Deraza';
  String? chosen;

  /// A filter chip in the current tab, null for all of its designs.
  String? filter;
  final scroll = ScrollController();
  late int count = widget.count;
  late String? room = widget.room;
  late final width = TextEditingController(text: '${widget.width ?? 1500}'),
      height = TextEditingController(text: '${widget.height ?? 1500}');

  /// Once a size is typed (or came with the window) a design keeps it.
  late bool sizeTyped = widget.width != null;
  String? problem;

  @override
  void dispose() {
    scroll.dispose();
    width.dispose();
    height.dispose();
    super.dispose();
  }

  void choose(DrawingPreset? p) => setState(() {
        chosen = p?.id;
        problem = null;
        if (p != null && !sizeTyped) {
          width.text = '${p.widthMm}';
          height.text = '${p.heightMm}';
        }
      });

  /// The chosen design (or blank window) at the typed size, if valid.
  CatalogChoice? choice() {
    final w = num.tryParse(width.text.trim().replaceAll(',', '.')),
        h = num.tryParse(height.text.trim().replaceAll(',', '.'));
    if (w == null || h == null || w < 300 || h < 300 || w > 6000 || h > 6000) {
      setState(() => problem = 'Eni va bo‘yi 300–6000 mm bo‘lsin');
      return null;
    }
    final preset = chosen == null
        ? null
        : drawingPresets.firstWhere((p) => p.id == chosen);
    final c = CatalogChoice(preset, w, h, count, room);
    try {
      layoutDrawing(c.drawing(), widget.recipe);
    } catch (e) {
      setState(() => problem = '$e'.replaceFirst('Exception: ', ''));
      return null;
    }
    return c;
  }

  void preview3d() {
    final c = choice();
    if (c == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => View3D(
          drawing: c.drawing(),
          recipe: widget.recipe,
          aiKey: widget.store?.aiKey ?? '',
        ),
      ),
    );
  }

  void start() {
    final c = choice();
    if (c != null) Navigator.pop(context, c);
  }

  /// A tap on a card opens it on the drawing desk right away.
  void open(DrawingPreset? p) {
    choose(p);
    start();
  }

  /// Two quick starts side by side: a blank window, or one from a photo.
  /// Phones up to the iPhone SE / 8 size: the header starts folded and the
  /// two first cards drop their second line, so designs show at once.
  bool get short => MediaQuery.sizeOf(context).height < 740;

  Widget quickStarts() {
    final scheme = Theme.of(context).colorScheme, on = chosen == null;
    Widget card({
      required Key key,
      required String title,
      required String subtitle,
      required Widget icon,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      Gradient? gradient,
      bool selected = false,
    }) =>
        Expanded(
          child: Material(
            key: key,
            color: gradient == null ? scheme.surface : Colors.transparent,
            elevation: gradient == null ? 1.5 : 3,
            shadowColor: Colors.black26,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: gradient == null
                  ? BorderSide(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 2 : 1,
                    )
                  : BorderSide.none,
            ),
            child: Ink(
              decoration: BoxDecoration(gradient: gradient),
              // Glass only on the plain card: a milky layer washed the AI
              // camera's colours and white title out.
              child: GlassControl(
                  enabled: gradient == null,
                  child: InkWell(
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              icon,
                              const Spacer(),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: gradient == null
                                    ? scheme.primary
                                    : Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: gradient == null
                                  ? scheme.onSurface
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(
            key: const ValueKey('design-blank'),
            title: 'Bo‘sh rom',
            subtitle: 'O‘zingiz bo‘lib chizasiz',
            selected: on,
            onTap: () => open(null),
            onLongPress: () => choose(null),
            icon: Container(
              width: 34,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xffdfe7ef), width: 4),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xffa9dcf6), Color(0xff6fc3ef)],
                ),
              ),
              child: Icon(Icons.add, color: scheme.primary, size: 22),
            ),
          ),
          if (widget.store != null) ...[
            const SizedBox(width: 10),
            card(
              key: const ValueKey('design-camera'),
              title: 'AI kamera',
              subtitle: 'Romni rasmga oling — chizma o‘zi',
              gradient: const LinearGradient(
                colors: [Color(0xff6a4cff), Color(0xff2f86ea)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () async {
                final store = widget.store!;
                final choice = await openPhotoWindow(
                  context,
                  store,
                  widget.recipe,
                );
                if (choice != null && mounted) Navigator.pop(context, choice);
              },
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Filter chips for what the designs in this tab have.
  Widget filters(List<DrawingPreset> designs) {
    final scheme = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    for (final p in designs) {
      for (final tag in designTags(p, widget.recipe)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final chips = [
      for (final tag in designTagOrder)
        if ((counts[tag] ?? 0) > 0 && counts[tag]! < designs.length) tag,
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    Widget chip(String? tag, String label) {
      final on = filter == tag;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GlassControl(
          child: ChoiceChip(
            key: ValueKey('filter-${tag ?? 'all'}'),
            label: Text(label),
            selected: on,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: on ? scheme.onPrimary : scheme.onSurface,
            ),
            selectedColor: scheme.primary,
            backgroundColor: scheme.surface,
            side: BorderSide(
              color: on ? scheme.primary : scheme.outlineVariant,
            ),
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() => filter = tag),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        // Each tab's chips start from "Hammasi".
        key: ValueKey('filters-$group'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip(null, 'Hammasi ${designs.length}'),
          for (final tag in chips) chip(tag, '$tag ${counts[tag]}'),
        ],
      ),
    );
  }

  Widget designTile(DrawingPreset p) {
    final scheme = Theme.of(context).colorScheme,
        on = chosen == p.id,
        dark = Theme.of(context).brightness == Brightness.dark;
    // The picture says it; the name stays for screen readers.
    return Semantics(
      label: '${p.name}, ${p.widthMm} × ${p.heightMm} mm',
      child: Material(
        color: scheme.surface,
        elevation: on ? 3 : 1,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: on ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: GlassControl(
            child: InkWell(
          key: ValueKey('design-${p.id}'),
          onTap: () => open(p),
          onLongPress: () {
            HapticFeedback.selectionClick();
            choose(p);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color:
                      dark ? const Color(0xff1d2733) : const Color(0xffeef3f8),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DesignThumb(
                          drawing: p.drawing(),
                          recipe: widget.recipe,
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: IconButton(
                          key: ValueKey('design-3d-${p.id}'),
                          tooltip: '3D ko‘rish',
                          visualDensity: VisualDensity.compact,
                          iconSize: 17,
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.surface.withValues(
                              alpha: .9,
                            ),
                            minimumSize: const Size(28, 28),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            choose(p);
                            preview3d();
                          },
                          icon: Icon(Icons.view_in_ar, color: scheme.primary),
                        ),
                      ),
                      if (on)
                        Positioned(
                          left: -2,
                          top: -2,
                          child: Icon(
                            Icons.check_circle,
                            size: 20,
                            color: scheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme,
        all = drawingPresets.where((p) => p.group == group).toList(),
        designs = filter == null
            ? all
            : all
                .where((p) => designTags(p, widget.recipe).contains(filter))
                .toList(),
        wide = MediaQuery.sizeOf(context).width,
        preset = chosen == null
            ? null
            : drawingPresets.firstWhere((p) => p.id == chosen);
    InputDecoration field(String label) => InputDecoration(
          labelText: label,
          suffixText: 'mm',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xffedf1f5),
      body: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _CatalogHeader(
              top: MediaQuery.paddingOf(context).top,
              folded: short,
              group: group,
              recipe: widget.recipe,
              onGroup: (g) {
                setState(() {
                  group = g;
                  filter = null;
                });
                // Another tab starts from its first designs.
                if (scroll.hasClients && scroll.offset > 0) scroll.jumpTo(0);
              },
              onBack: () => Navigator.maybePop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, short ? 10 : 14, 16, 6),
              child: quickStarts(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tayyor dizaynlar',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: filters(all)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide >= 1100
                    ? 7
                    : wide >= 800
                        ? 5
                        : wide >= 560
                            ? 4
                            : 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: group == 'Eshik' ? .62 : .9,
              ),
              delegate: SliverChildListDelegate([
                for (final p in designs) designTile(p),
              ]),
            ),
          ),
        ],
      ),
      // The size fields ride up with the keyboard: they were left under it,
      // so the width being typed could not be seen.
      bottomNavigationBar: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: whenGlass(
          Material(
            elevation: usesIOSGlass ? 0 : 10,
            color: usesIOSGlass ? Colors.transparent : scheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GlassControl(
                            child: TextFormField(
                              key: const ValueKey('catalog-width'),
                              controller: width,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => sizeTyped = true,
                              decoration: field('Eni'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassControl(
                            child: TextFormField(
                              key: const ValueKey('catalog-height'),
                              controller: height,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => sizeTyped = true,
                              decoration: field('Bo‘yi'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Kamaytirish',
                                visualDensity: VisualDensity.compact,
                                onPressed: count > 1
                                    ? () => setState(() => count--)
                                    : null,
                                icon: const Icon(Icons.remove, size: 18),
                              ),
                              Text(
                                '$count',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              IconButton(
                                tooltip: 'Ko‘paytirish',
                                visualDensity: VisualDensity.compact,
                                onPressed: count < 1000
                                    ? () => setState(() => count++)
                                    : null,
                                icon: const Icon(Icons.add, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (problem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          problem!,
                          style: TextStyle(color: scheme.error, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Tooltip(
                          message: 'Joyi (xona)',
                          child: OutlinedButton(
                            key: const ValueKey('catalog-room'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: room == null ? 0 : 12,
                              ),
                              minimumSize: const Size(46, 46),
                            ),
                            onPressed: () async {
                              final value = await pickRoom(context, room);
                              if (value != null && mounted) {
                                setState(
                                    () => room = value.isEmpty ? null : value);
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place_outlined, size: 20),
                                if (room != null) ...[
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 80),
                                    child: Text(
                                      room!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          key: const ValueKey('catalog-3d'),
                          tooltip: '3D ko‘rish',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(46, 46),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                          onPressed: preview3d,
                          icon: Icon(Icons.view_in_ar, color: scheme.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('catalog-start'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: start,
                            icon: Icon(
                              widget.replacing
                                  ? Icons.check
                                  : Icons.draw_outlined,
                              size: 20,
                            ),
                            label: Text(
                              widget.replacing
                                  ? 'Qo‘llash'
                                  : preset == null
                                      ? 'Bo‘sh romni chizish'
                                      : preset.name,
                              key: const ValueKey('catalog-choice'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          (panel) => GlassSurface(
            radius: const BorderRadius.vertical(top: Radius.circular(26)),
            opaque: true,
            child: panel,
          ),
        ),
      ),
    );
  }
}

/// What a ready design has, for the catalog's filter chips.
const designTagOrder = [
  'Fortochkali',
  'Panelli',
  'Surilma',
  '1 bo‘lim',
  '2 bo‘lim',
  '3 bo‘lim',
  '4+ bo‘lim',
];
final _tags = <String, Set<String>>{};

Set<String> designTags(DrawingPreset p, DMap recipe) => _tags[p.id] ??= () {
      final out = <String>{};
      final List<DrawingCell> cells;
      try {
        cells = layoutDrawing(p.drawing(), recipe).cells;
      } catch (_) {
        return out;
      }
      final n = cells.length;
      out.add(n >= 4 ? '4+ bo‘lim' : '$n bo‘lim');
      bool any(bool Function(DMap n) test) {
        bool visit(DMap n) =>
            test(n) ||
            (n['axis'] != null && (visit(n['a'] as DMap) || visit(n['b']))) ||
            (n['infill'] is Map && visit(n['infill'] as DMap));
        return cells.any((c) => visit(c.node));
      }

      if (any((n) => n['opening'] == 'bottom' || n['opening'] == 'top')) {
        out.add('Fortochkali');
      }
      if (any((n) => n['fill'] == 'panel' || n['fill'] == 'lambris')) {
        out.add('Panelli');
      }
      if (any((n) => '${n['opening']}'.startsWith('slide'))) {
        out.add('Surilma');
      }
      return out;
    }();

class _CatalogHeader extends SliverPersistentHeaderDelegate {
  final double top;

  /// Starts folded (short screens).
  final bool folded;
  final String group;
  final DMap recipe;
  final ValueChanged<String> onGroup;
  final VoidCallback onBack;
  _CatalogHeader({
    required this.top,
    this.folded = false,
    required this.group,
    required this.recipe,
    required this.onGroup,
    required this.onBack,
  });

  static const _art = {
    'Deraza': 'three',
    'Eshik': 'doubleDoor',
    'Arka': 'archTop3',
    'Boshqa': 'circle',
  };

  @override
  double get maxExtent => top + (folded ? 112 : 204);
  @override
  double get minExtent => top + 112;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t =
        folded ? 1.0 : (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff07b2f5), Color(0xff13618f), Color(0xff1d2b3a)],
        ),
      ),
      padding: EdgeInsets.only(top: top),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Orqaga',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Opacity(
                    opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                    child: const Text(
                      'Qanday rom?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  for (final e in presetGroups.entries)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Material(
                          color: group == e.key
                              ? Colors.white.withValues(alpha: .2)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: group == e.key
                                  ? Colors.white.withValues(alpha: .7)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          // Dark glass on the blue header, not the light
                          // one that hid the white names.
                          child: GlassControl(
                              tint: group == e.key
                                  ? const Color(0xff3d7fb8)
                                  : const Color(0xff17405f),
                              brightness: Brightness.dark,
                              child: InkWell(
                                key: ValueKey('group-${e.key}'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => onGroup(e.key),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 6, 6, 4),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: DesignThumb(
                                          hero: true,
                                          drawing: drawingPresets
                                              .firstWhere(
                                                (p) => p.id == _art[e.key],
                                              )
                                              .drawing(),
                                          recipe: recipe,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      // The name stays readable when the header folds.
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${e.value} ${drawingPresets.where((p) => p.group == e.key).length}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: group == e.key
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CatalogHeader old) =>
      old.group != group ||
      old.top != top ||
      old.recipe != recipe ||
      old.folded != folded;
}
