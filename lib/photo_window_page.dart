import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ai_vision.dart';
import 'design_catalog.dart';
import 'design_engine.dart';
import 'store.dart';
import 'window_photo.dart';
import 'adaptive_ui.dart';
import 'i18n.dart';

/// AI camera: a photo of a window becomes its drawing. The window's four
/// corners are marked on the photo, the frame is straightened, and its bars
/// are found on the phone itself, or by Claude when the workshop has added
/// its own AI key. Every bar can be removed or added before drawing.
Future<CatalogChoice?> openPhotoWindow(
  BuildContext context,
  Store store,
  DMap recipe,
) =>
    Navigator.push<CatalogChoice>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoWindowPage(store: store, recipe: recipe),
      ),
    );

(Uint8List, WindowGrid) _straightenAndDetect(
  (Gray, Uint8List, List<(double, double)>, int, int) job,
) {
  final (source, colour, quad, w, h) = job;
  final straight = source.rectify(quad, w, h),
      pixels = rectifyRgba(colour, source.width, source.height, quad, w, h);
  return (pixels, detectGrid(straight, colour: pixels));
}

class PhotoWindowPage extends StatefulWidget {
  final Store store;
  final DMap recipe;
  const PhotoWindowPage({super.key, required this.store, required this.recipe});
  @override
  State<PhotoWindowPage> createState() => _PhotoWindowPageState();
}

class _PhotoWindowPageState extends State<PhotoWindowPage> {
  ui.Image? photo, straight;
  Gray? gray;
  Uint8List? colour;
  List<Offset> corners = const [];
  WindowGrid? grid;
  String mode = 'remove';
  int? dragCorner;
  String? busy, note;
  final width = TextEditingController(), height = TextEditingController();

  @override
  void dispose() {
    width.dispose();
    height.dispose();
    photo?.dispose();
    straight?.dispose();
    super.dispose();
  }

  void say(Object text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Tx('$text')));

  Future<void> pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 92,
      );
      if (file == null || !mounted) return;
      setState(() => busy = 'Rasm ochilmoqda…');
      await load(await file.readAsBytes());
    } catch (e) {
      if (mounted) say('Rasm ochilmadi: $e');
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  /// Decodes at most 1100 px on the long side: enough for the bars and
  /// light for the phone.
  Future<void> load(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = 1100 / math.max(descriptor.width, descriptor.height);
    final codec = await descriptor.instantiateCodec(
      targetWidth: scale < 1 ? (descriptor.width * scale).round() : null,
      targetHeight: scale < 1 ? (descriptor.height * scale).round() : null,
    );
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width.toDouble(), h = image.height.toDouble();
    setState(() {
      photo?.dispose();
      photo = image;
      colour = data!.buffer.asUint8List();
      gray = Gray.fromRgba(colour!, image.width, image.height);
      corners = [
        Offset(w * .12, h * .12),
        Offset(w * .88, h * .12),
        Offset(w * .88, h * .88),
        Offset(w * .12, h * .88),
      ];
      grid = null;
      note = null;
    });
  }

  num? field(TextEditingController c) {
    final v = num.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v < 300 || v > 6000 ? null : v;
  }

  /// Height / width of the frame: from the typed size, else from the photo.
  double aspect() {
    final w = field(width), h = field(height);
    if (w != null && h != null) return (h / w).toDouble();
    final c = corners;
    final across = (c[1] - c[0]).distance + (c[2] - c[3]).distance,
        down = (c[3] - c[0]).distance + (c[2] - c[1]).distance;
    return (down / across).clamp(.25, 4.0);
  }

  Future<void> straighten() async {
    final source = gray!, a = aspect();
    final quad = [for (final c in corners) (c.dx, c.dy)];
    const outWidth = 360;
    final outHeight = (outWidth * a).round();
    // Off the UI thread; only plain data crosses to the worker.
    final result = await compute(_straightenAndDetect, (
      source,
      colour!,
      quad,
      outWidth,
      outHeight,
    ));
    final (pixels, found) = result;
    final view = await rgbaImage(pixels, outWidth, outHeight);
    if (!mounted) return;
    setState(() {
      straight?.dispose();
      straight = view;
      grid ??= found;
    });
  }

  Future<ui.Image> rgbaImage(Uint8List rgba, int w, int h) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  Future<void> detect({required bool ai}) async {
    if (gray == null) return;
    setState(() {
      busy = ai
          ? 'AI rasmni o‘qimoqda… (10–40 soniya)'
          : 'Chiziqlar aniqlanmoqda…';
      grid = null;
      note = null;
    });
    try {
      if (ai) {
        final png = await photo!.toByteData(format: ui.ImageByteFormat.png);
        final found = await AiVision.read(
          png!.buffer.asUint8List(),
          apiKey: widget.store.aiKey,
        );
        grid = found;
        note = 'AI aniqladi. Chiziqlarni tekshiring.';
      }
      await straighten();
      if (!ai) {
        note =
            'Telefonda aniqlandi. Ortiqcha chiziqni o‘chiring, yetmaganini qo‘shing.';
      }
    } catch (e) {
      if (mounted) say(e);
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  void finish() {
    final g = grid;
    if (g == null) return;
    var w = field(width), h = field(height);
    if (w == null && h == null) w = 1500;
    w ??= (h! / aspect() / 10).round() * 10;
    h ??= (w * aspect() / 10).round() * 10;
    final d = g.drawing(w.clamp(300, 6000), h.clamp(300, 6000));
    try {
      layoutDrawing(d, widget.recipe);
    } catch (e) {
      say('$e'.replaceFirst('Exception: ', ''));
      return;
    }
    Navigator.pop(context, CatalogChoice.photo(d, 1, null));
  }

  /// A tap on the straightened photo: remove the nearest bar, add one, or
  /// change the opening of the section under the finger.
  void editAt(double fx, double fy) {
    final g = grid;
    if (g == null) return;
    final main = g.columns ? fx : fy, other = g.columns ? fy : fx;
    setState(() {
      switch (mode) {
        case 'v':
          g.columns ? g.addCut(fx) : g.addInner(fy, fx);
        case 'h':
          g.columns ? g.addInner(fx, fy) : g.addCut(fy);
        case 'opening':
          final i = g.partAt(main);
          var j = 0;
          while (j < g.inner[i].length && other > g.inner[i][j]) {
            j++;
          }
          const cycle = [
            'fixed',
            'tiltTurn',
            'left',
            'right',
            'bottom',
            'doorLeft',
          ];
          final now = cycle.indexOf(g.openings[i][j]);
          g.openings[i][j] = cycle[(now + 1) % cycle.length];
        default:
          var best = .05;
          void Function()? remove;
          for (var i = 0; i < g.cuts.length; i++) {
            if ((g.cuts[i] - main).abs() < best) {
              best = (g.cuts[i] - main).abs();
              remove = () => g.removeCut(i);
            }
          }
          final i = g.partAt(main);
          for (var j = 0; j < g.inner[i].length; j++) {
            if ((g.inner[i][j] - other).abs() < best) {
              best = (g.inner[i][j] - other).abs();
              remove = () => g.removeInner(i, j);
            }
          }
          remove?.call();
      }
    });
  }

  Widget pickStep() {
    final text = Theme.of(context).textTheme,
        scheme = Theme.of(context).colorScheme,
        camera = Platform.isAndroid || Platform.isIOS;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xff07b2f5), Color(0xff13618f)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.photo_camera_outlined,
              size: 76,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Tx('Romni rasmga oling', style: text.titleLarge),
        const SizedBox(height: 6),
        Tx(
          'Romni iloji boricha to‘g‘ridan, butunligicha oling: ramaning to‘rt burchagi ko‘rinsin. Keyin burchaklarni belgilaysiz — dastur rasmni to‘g‘rilab, impostlarni topadi.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 18),
        if (camera)
          FilledButton.icon(
            key: const ValueKey('photo-camera'),
            onPressed: busy == null ? () => pick(ImageSource.camera) : null,
            icon: const Icon(Icons.photo_camera),
            label: const Tx('Kamera'),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('photo-gallery'),
          onPressed: busy == null ? () => pick(ImageSource.gallery) : null,
          icon: const Icon(Icons.photo_library_outlined),
          label: Tx(camera ? 'Galereyadan tanlash' : 'Rasm faylini tanlash'),
        ),
        const SizedBox(height: 18),
        GlassCard(
          child: GlassControl(
              child: ListTile(
            leading: Icon(
              widget.store.aiKey.isEmpty ? Icons.memory : Icons.auto_awesome,
              color: scheme.primary,
            ),
            title: Tx(
              widget.store.aiKey.isEmpty
                  ? 'Telefonda aniqlash'
                  : 'Claude AI ulangan',
            ),
            subtitle: Tx(
              widget.store.aiKey.isEmpty
                  ? 'Internet kerak emas. Ochilish turi va aniqroq natija uchun Sozlamalar → AI kamera’da Claude kalitini kiriting.'
                  : 'Rasm Anthropic’ga yuboriladi; impostlar va ochilish turlari aniqlanadi.',
            ),
          )),
        ),
      ],
    );
  }

  Widget cornersStep() {
    final image = photo!;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final s = math.min(
                    box.maxWidth / image.width,
                    box.maxHeight / image.height,
                  ),
                  dx = (box.maxWidth - image.width * s) / 2,
                  dy = (box.maxHeight - image.height * s) / 2;
              Offset toScreen(Offset p) => Offset(dx + p.dx * s, dy + p.dy * s);
              Offset toPhoto(Offset p) => Offset(
                    ((p.dx - dx) / s).clamp(0, image.width.toDouble()),
                    ((p.dy - dy) / s).clamp(0, image.height.toDouble()),
                  );
              return GestureDetector(
                key: const ValueKey('photo-corners'),
                onPanStart: (d) {
                  var best = 48.0;
                  dragCorner = null;
                  for (var i = 0; i < 4; i++) {
                    final dist =
                        (toScreen(corners[i]) - d.localPosition).distance;
                    if (dist < best) {
                      best = dist;
                      dragCorner = i;
                    }
                  }
                },
                onPanUpdate: (d) {
                  final i = dragCorner;
                  if (i == null) return;
                  setState(() {
                    corners = List.of(corners)..[i] = toPhoto(d.localPosition);
                    grid = null;
                  });
                },
                onPanEnd: (_) => dragCorner = null,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _QuadPainter(
                    image,
                    [for (final c in corners) toScreen(c)],
                    s,
                    Offset(dx, dy),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Tx(
            'Ko‘k nuqtalarni ramaning to‘rt tashqi burchagiga suring.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget reviewStep() {
    final image = straight!, g = grid!;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final s = math.min(
                        box.maxWidth / image.width,
                        box.maxHeight / image.height,
                      ) *
                      .94,
                  rect = Rect.fromCenter(
                    center: Offset(box.maxWidth / 2, box.maxHeight / 2),
                    width: image.width * s,
                    height: image.height * s,
                  );
              return GestureDetector(
                key: const ValueKey('photo-review'),
                onTapUp: (d) {
                  if (!rect.contains(d.localPosition)) return;
                  editAt(
                    (d.localPosition.dx - rect.left) / rect.width,
                    (d.localPosition.dy - rect.top) / rect.height,
                  );
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _GridPainter(image, rect, g),
                ),
              );
            },
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Tx(note!, style: Theme.of(context).textTheme.bodySmall),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: GlassControl(
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'remove', label: Tx('O‘chirish')),
                ButtonSegment(value: 'v', label: Tx('+ Tik')),
                ButtonSegment(value: 'h', label: Tx('+ Yotiq')),
                ButtonSegment(value: 'opening', label: Tx('Ochilish')),
              ],
              selected: {mode},
              onSelectionChanged: (v) => setState(() => mode = v.single),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step = photo == null
        ? 0
        : grid == null || straight == null
            ? 1
            : 2;
    return Scaffold(
      appBar: GlassAppBar(
        title: const Tx('AI kamera'),
        actions: [
          if (photo != null)
            IconButton(
              tooltip: tr('Boshqa rasm'),
              onPressed: () => setState(() {
                photo = null;
                grid = null;
                straight = null;
              }),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: step == 0
                ? pickStep()
                : step == 1
                    ? cornersStep()
                    : reviewStep(),
          ),
          if (busy != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 14),
                          Flexible(child: Tx(busy!)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: step == 0
          ? null
          : Material(
              elevation: 8,
              color: scheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GlassControl(
                              child: TextField(
                                key: const ValueKey('photo-width'),
                                controller: width,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: tr('Eni'),
                                  suffixText: 'mm',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GlassControl(
                              child: TextField(
                                key: const ValueKey('photo-height'),
                                controller: height,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: tr('Bo‘yi'),
                                  suffixText: 'mm',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (field(width) == null || field(height) == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Tx(
                            'Eni va bo‘yini razmerdan yozing: rasmdan o‘lcham taxminiy chiqadi.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (step == 1)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const ValueKey('photo-detect'),
                                onPressed: busy == null
                                    ? () => detect(ai: false)
                                    : null,
                                icon: const Icon(Icons.memory),
                                label: const FittedBox(
                                  child: Tx('Telefonda aniqlash'),
                                ),
                              ),
                            ),
                            if (widget.store.aiKey.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const ValueKey('photo-ai'),
                                  onPressed: busy == null
                                      ? () => detect(ai: true)
                                      : null,
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const FittedBox(
                                    child: Tx('AI bilan'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => setState(() => grid = null),
                              child: const Tx('Burchaklar'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                key: const ValueKey('photo-finish'),
                                onPressed: finish,
                                icon: const Icon(Icons.draw_outlined),
                                label: const FittedBox(
                                  child: Tx('Chizmaga o‘tkazish'),
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
    );
  }
}

/// The photo with the frame's four corners and the outline between them.
class _QuadPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> corners;
  final double scale;
  final Offset origin;
  _QuadPainter(this.image, this.corners, this.scale, this.origin);
  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: origin & Size(image.width * scale, image.height * scale),
      image: image,
      filterQuality: FilterQuality.medium,
    );
    final outline = Path()..addPolygon(corners, true);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        outline,
      ),
      Paint()..color = Colors.black.withValues(alpha: .35),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xff3a8dff),
    );
    for (final c in corners) {
      canvas.drawCircle(
        c,
        15,
        Paint()..color = Colors.white.withValues(alpha: .9),
      );
      canvas.drawCircle(
        c,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xff3a8dff),
      );
      canvas.drawCircle(c, 3, Paint()..color = const Color(0xff3a8dff));
    }
  }

  @override
  bool shouldRepaint(_QuadPainter old) => true;
}

/// The straightened frame with the bars that will become imposts, and the
/// opening of each section.
class _GridPainter extends CustomPainter {
  final ui.Image image;
  final Rect rect;
  final WindowGrid grid;
  _GridPainter(this.image, this.rect, this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: rect,
      image: image,
      filterQuality: FilterQuality.medium,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xffff9f1a),
    );
    final bar = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xffff9f1a);
    Offset at(double main, double other) => grid.columns
        ? Offset(rect.left + main * rect.width, rect.top + other * rect.height)
        : Offset(rect.left + other * rect.width, rect.top + main * rect.height);
    for (final c in grid.cuts) {
      canvas.drawLine(at(c, 0), at(c, 1), bar);
    }
    for (var i = 0; i < grid.partCount; i++) {
      final (a, b) = grid.part(i);
      for (final o in grid.inner[i]) {
        canvas.drawLine(at(a, o), at(b, o), bar);
      }
      final stops = [0.0, ...grid.inner[i], 1.0];
      for (var j = 0; j + 1 < stops.length; j++) {
        final p0 = at(a, stops[j]), p1 = at(b, stops[j + 1]);
        final cell = Rect.fromPoints(p0, p1).deflate(6);
        if (grid.fills[i][j] == 'panel') {
          canvas.drawRect(
            cell,
            Paint()..color = Colors.white.withValues(alpha: .45),
          );
        }
        final opening = grid.openings[i][j];
        if (opening == 'fixed') continue;
        final mark = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white;
        for (final line in openingSymbolLines(opening, [
          cell.left,
          cell.top,
          cell.right,
          cell.bottom,
        ])) {
          canvas.drawPath(
            Path()..addPolygon([for (final v in line) Offset(v.x, v.y)], false),
            mark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
