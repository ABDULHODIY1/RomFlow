import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'ai_vision.dart';
import 'design_catalog.dart' show DesignPainter;
import 'design_engine.dart';
import 'platform_files.dart';
import 'window_photo.dart';
import 'adaptive_ui.dart';

/// "Joyida": the window or door where it goes, the opening in the wall or
/// the old window, drawn in perspective so the client sees it installed
/// before ordering. On a phone the camera is live: the window stands in
/// the opening the phone looks at. A photo of it can then be fine-tuned
/// (corners by hand, or found by Claude with the workshop's key) and
/// sent. Without a camera it works on a photo.
Future<void> openInPlace(BuildContext context,
        {required DMap drawing, required DMap recipe, String aiKey = ''}) =>
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Platform.isAndroid || Platform.isIOS
                ? LiveInPlacePage(
                    drawing: drawing, recipe: recipe, aiKey: aiKey)
                : InPlacePage(drawing: drawing, recipe: recipe, aiKey: aiKey)));

/// A sample photo of an opening, to try the view without a photo.
const samplePhotoAsset = 'assets/sample_opening.jpg';

class InPlacePage extends StatefulWidget {
  final DMap drawing, recipe;
  final String aiKey;

  /// A picture taken by the live camera, and where it saw the opening
  /// (fractions of the picture, top-left first).
  final Uint8List? photo;
  final List<(double, double)>? corners;
  const InPlacePage(
      {super.key,
      required this.drawing,
      required this.recipe,
      this.aiKey = '',
      this.photo,
      this.corners});
  @override
  State<InPlacePage> createState() => _InPlacePageState();
}

class _InPlacePageState extends State<InPlacePage> {
  ui.Image? photo;
  Gray? gray;

  /// The opening's corners on the photo, in its pixels, top-left first.
  List<Offset> corners = const [];
  int? dragCorner;
  Offset? dragFrom;
  List<Offset>? dragStart;
  bool clean = false;
  String? busy, note;
  final shot = GlobalKey();

  @override
  void initState() {
    super.initState();
    final taken = widget.photo;
    if (taken != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => load(taken, known: widget.corners));
    }
  }

  @override
  void dispose() {
    photo?.dispose();
    super.dispose();
  }

  void say(Object text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text('$text'.replaceFirst(RegExp(r'^\w*Exception: '), ''))));

  Future<void> pick(ImageSource source) async {
    try {
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 2400, imageQuality: 92);
      if (file == null || !mounted) return;
      await load(await file.readAsBytes());
    } catch (e) {
      if (mounted) say('Rasm ochilmadi: $e');
    }
  }

  Future<void> sample() async {
    try {
      final data = await rootBundle.load(samplePhotoAsset);
      await load(data.buffer.asUint8List());
    } catch (e) {
      if (mounted) say('Namuna ochilmadi: $e');
    }
  }

  /// At most 1600 px on the long side; the guess works on a smaller copy.
  /// With [known] corners (from the live camera) only Claude looks again.
  Future<void> load(Uint8List bytes, {List<(double, double)>? known}) async {
    setState(() => busy = 'Rasm ochilmoqda…');
    try {
      Future<ui.Image> decode(int longest) async {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final scale = longest / math.max(descriptor.width, descriptor.height);
        final codec = await descriptor.instantiateCodec(
            targetWidth: scale < 1 ? (descriptor.width * scale).round() : null,
            targetHeight:
                scale < 1 ? (descriptor.height * scale).round() : null);
        return (await codec.getNextFrame()).image;
      }

      final image = await decode(1600), small = await decode(480);
      final rgba = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
      final g =
          Gray.fromRgba(rgba!.buffer.asUint8List(), small.width, small.height);
      small.dispose();
      if (!mounted) return;
      final w = image.width.toDouble(), h = image.height.toDouble();
      // Until the opening is found: the window in the middle, as tall as
      // half the photo.
      final ww = (widget.drawing['widthMm'] as num).toDouble(),
          wh = (widget.drawing['heightMm'] as num).toDouble(),
          tall = h * .5,
          wide = math.min(w * .8, tall * ww / wh);
      setState(() {
        photo?.dispose();
        photo = image;
        gray = g;
        corners = known != null && known.length == 4
            ? [for (final (x, y) in known) Offset(x * w, y * h)]
            : [
                Offset((w - wide) / 2, (h - tall) / 2),
                Offset((w + wide) / 2, (h - tall) / 2),
                Offset((w + wide) / 2, (h + tall) / 2),
                Offset((w - wide) / 2, (h + tall) / 2),
              ];
        note = known == null
            ? null
            : 'Kamerada topilgan joy. Kerak bo‘lsa burchaklarni suring.';
      });
      if (known == null || widget.aiKey.isNotEmpty) {
        await find(ai: widget.aiKey.isNotEmpty);
      }
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> find({required bool ai}) async {
    final image = photo, g = gray;
    if (image == null || g == null) return;
    setState(() => busy =
        ai ? 'AI o‘rnini topmoqda… (10–40 soniya)' : 'O‘rni aniqlanmoqda…');
    try {
      final List<(double, double)> found;
      if (ai) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        found = await AiVision.findOpening(png!.buffer.asUint8List(),
            apiKey: widget.aiKey);
      } else {
        found = await compute(guessOpening, g);
      }
      if (!mounted) return;
      setState(() {
        corners = [
          for (final (x, y) in found) Offset(x * image.width, y * image.height)
        ];
        note = ai
            ? 'AI topdi. Kerak bo‘lsa burchaklarni suring.'
            : 'Telefonda topildi. Ko‘k nuqtalarni o‘rinning burchaklariga suring.';
      });
    } catch (e) {
      if (mounted) say(e);
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> save() async {
    setState(() => clean = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final boundary =
          shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ratio = photo!.width / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: ratio.clamp(1, 4));
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      final result = await shareFile(
          'RomFlow-joyida-${DateTime.now().millisecondsSinceEpoch}.png',
          'image/png',
          data.buffer.asUint8List(),
          text: 'RomFlow • joyida ko‘rinishi');
      if (result != null && mounted) say(result);
    } catch (e) {
      if (mounted) say('Rasmni saqlab bo‘lmadi: $e');
    } finally {
      if (mounted) setState(() => clean = false);
    }
  }

  Widget pickStep() {
    final text = Theme.of(context).textTheme,
        camera = Platform.isAndroid || Platform.isIOS;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              colors: [Color(0xff6b5cff), Color(0xff1f8fff)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: const Center(
            child: Icon(Icons.add_a_photo_outlined,
                size: 72, color: Colors.white)),
      ),
      const SizedBox(height: 18),
      Text('Joyida ko‘rish', style: text.titleLarge),
      const SizedBox(height: 6),
      Text(
          'Telefonni rom qo‘yiladigan o‘ringa — devordagi darchaga yoki eski romga — qarating va rasmga oling. Dastur o‘rnini topadi va chizilgan rom yoki eshikni o‘sha joyga qo‘yib ko‘rsatadi. Rasmni mijozga yuborish mumkin.',
          style: text.bodyMedium),
      const SizedBox(height: 18),
      if (camera)
        FilledButton.icon(
          key: const ValueKey('in-place-camera'),
          onPressed: busy == null ? () => pick(ImageSource.camera) : null,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Kamera'),
        ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const ValueKey('in-place-gallery'),
        onPressed: busy == null ? () => pick(ImageSource.gallery) : null,
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(camera ? 'Galereyadan tanlash' : 'Rasm faylini tanlash'),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        key: const ValueKey('in-place-sample'),
        onPressed: busy == null ? sample : null,
        icon: const Icon(Icons.image_outlined),
        label: const Text('Namuna rasm bilan sinab ko‘rish'),
      ),
      const SizedBox(height: 12),
      Text(
          widget.aiKey.isEmpty
              ? 'O‘rin telefonda taxminan topiladi; burchaklarni qo‘lda aniqlashtirasiz. Sozlamalar → AI kamera’da Claude kalitini kiritsangiz, o‘rinni AI topadi.'
              : 'O‘rinni AI topadi (rasm Anthropic’ga yuboriladi); burchaklarni qo‘lda ham surish mumkin.',
          style: text.bodySmall),
    ]);
  }

  Widget placeStep() {
    final image = photo!;
    return LayoutBuilder(builder: (context, box) {
      final s =
          math.min(box.maxWidth / image.width, box.maxHeight / image.height);
      Offset toScreen(Offset p) => p * s;
      Offset toPhoto(Offset p) => Offset(
          (p.dx / s).clamp(0, image.width.toDouble()),
          (p.dy / s).clamp(0, image.height.toDouble()));
      final quad = [for (final c in corners) toScreen(c)];
      return Center(
        child: RepaintBoundary(
          key: shot,
          child: SizedBox(
            width: image.width * s,
            height: image.height * s,
            child: GestureDetector(
              key: const ValueKey('in-place-photo'),
              onPanStart: (d) {
                var best = 44.0;
                dragCorner = null;
                for (var i = 0; i < 4; i++) {
                  final dist = (quad[i] - d.localPosition).distance;
                  if (dist < best) {
                    best = dist;
                    dragCorner = i;
                  }
                }
                // Inside the window: the whole window moves.
                dragFrom = dragCorner == null &&
                        (Path()..addPolygon(quad, true))
                            .contains(d.localPosition)
                    ? d.localPosition
                    : null;
                dragStart = corners;
              },
              onPanUpdate: (d) {
                final i = dragCorner, from = dragFrom, start = dragStart;
                if (i != null) {
                  setState(() => corners = List.of(corners)
                    ..[i] = toPhoto(d.localPosition));
                } else if (from != null && start != null) {
                  final shift = (d.localPosition - from) / s;
                  setState(() => corners = [for (final c in start) c + shift]);
                }
              },
              onPanEnd: (_) {
                dragCorner = null;
                dragFrom = null;
              },
              child: CustomPaint(
                key: const ValueKey('in-place-view'),
                painter: InPlacePainter(
                    image, quad, widget.drawing, widget.recipe,
                    handles: !clean),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: photo == null ? null : const Color(0xff10161d),
      appBar: GlassAppBar(
        title: const Text('Joyida ko‘rish'),
        actions: [
          if (photo != null)
            IconButton(
                tooltip: 'Boshqa rasm',
                onPressed: () => setState(() {
                      photo?.dispose();
                      photo = null;
                      gray = null;
                    }),
                icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(child: photo == null ? pickStep() : placeStep()),
        if (busy != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black38,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5)),
                      const SizedBox(width: 14),
                      Flexible(child: Text(busy!)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
      bottomNavigationBar: photo == null
          ? null
          : Material(
              color: scheme.surface,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        note ??
                            'Ko‘k nuqtalarni o‘rinning to‘rt burchagiga suring; romning o‘rtasidan ushlab butunini surish mumkin.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('in-place-find'),
                          onPressed: busy == null
                              ? () => find(ai: widget.aiKey.isNotEmpty)
                              : null,
                          icon: Icon(widget.aiKey.isEmpty
                              ? Icons.center_focus_strong_outlined
                              : Icons.auto_awesome),
                          label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(widget.aiKey.isEmpty
                                  ? 'O‘rnini topish'
                                  : 'AI bilan topish')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('in-place-save'),
                          onPressed: busy == null ? save : null,
                          icon: const Icon(Icons.ios_share),
                          label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Mijozga yuborish')),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
    );
  }
}

/// The photo with the window drawn into [quad] (screen points, top-left
/// first) in perspective.
class InPlacePainter extends CustomPainter {
  /// The photo; null over the live camera picture.
  final ui.Image? image;
  final List<Offset> quad;
  final DMap drawing, recipe;
  final bool handles;
  InPlacePainter(this.image, this.quad, this.drawing, this.recipe,
      {this.handles = true});

  /// The canvas matrix that takes the drawing (in mm) onto [quad].
  static Float64List matrix(List<Offset> quad, double width, double height) {
    final m = Homography([for (final c in quad) (c.dx, c.dy)]);
    return Float64List.fromList([
      m.a / width, m.d / width, 0, m.g / width, //
      m.b / height, m.e / height, 0, m.h / height, //
      0, 0, 1, 0, //
      m.c, m.f, 0, 1,
    ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final photo = image;
    if (photo != null) {
      paintImage(
          canvas: canvas,
          rect: Offset.zero & size,
          image: photo,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium);
    }
    if (quad.length != 4) return;
    final outline = Path()..addPolygon(quad, true);
    // A soft shadow in the reveal.
    canvas.drawPath(
        outline.shift(const Offset(2, 3)),
        Paint()
          ..color = Colors.black.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    final w = (drawing['widthMm'] as num).toDouble(),
        h = (drawing['heightMm'] as num).toDouble();
    canvas.save();
    canvas.transform(matrix(quad, w, h));
    DesignPainter(drawing, recipe, installed: true).paint(canvas, Size(w, h));
    canvas.restore();
    if (!handles) return;
    canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xff3a8dff).withValues(alpha: .8));
    for (final c in quad) {
      canvas.drawCircle(
          c, 13, Paint()..color = Colors.white.withValues(alpha: .9));
      canvas.drawCircle(
          c,
          13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xff3a8dff));
      canvas.drawCircle(c, 3, Paint()..color = const Color(0xff3a8dff));
    }
  }

  @override
  bool shouldRepaint(InPlacePainter old) => true;
}

/// The live camera: the window stands in the opening the phone looks at,
/// found again a few times a second on the phone itself. Corners can be
/// held by hand; a photo is then taken for fine-tuning and sending.
class LiveInPlacePage extends StatefulWidget {
  final DMap drawing, recipe;
  final String aiKey;
  const LiveInPlacePage(
      {super.key,
      required this.drawing,
      required this.recipe,
      this.aiKey = ''});
  @override
  State<LiveInPlacePage> createState() => _LiveInPlacePageState();
}

class _LiveInPlacePageState extends State<LiveInPlacePage>
    with WidgetsBindingObserver {
  CameraController? camera;
  String? problem;

  /// The opening on the picture, as fractions, top-left first.
  List<Offset>? quad;
  bool tracking = true, found = false, working = false, taking = false;
  int misses = 0;
  DateTime last = DateTime(0);
  int? dragCorner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(const []);
    camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = camera;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      camera = null;
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      start();
    }
  }

  Future<void> start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => problem = 'Bu qurilmada kamera topilmadi');
        return;
      }
      final back = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      final c = CameraController(back, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.startImageStream(frame);
      setState(() {
        camera = c;
        problem = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => problem = e.code.contains('Denied')
          ? 'Kameraga ruxsat berilmagan. Telefon sozlamalari → Ilovalar → RomFlow → Ruxsatlar → Kamera.'
          : 'Kamera ochilmadi: ${e.description ?? e.code}');
    } catch (e) {
      if (mounted) setState(() => problem = 'Kamera ochilmadi: $e');
    }
  }

  /// A few times a second: where the opening is on this frame.
  void frame(CameraImage image) {
    final c = camera;
    if (!tracking || working || c == null) return;
    final now = DateTime.now();
    if (now.difference(last) < const Duration(milliseconds: 150)) return;
    working = true;
    last = now;
    try {
      final plane = image.planes.first;
      final g = grayFromLuma(
          plane.bytes, image.width, image.height, plane.bytesPerRow,
          step: math.max(1, math.max(image.width, image.height) ~/ 220),
          // A frame already standing upright is not turned again.
          rotation:
              image.width > image.height ? c.description.sensorOrientation : 0);
      final guess = [for (final (x, y) in guessOpening(g)) Offset(x, y)];
      final wide = guess[1].dx - guess[0].dx, tall = guess[2].dy - guess[1].dy;
      if (wide < .12 || tall < .12 || wide > .94 || tall > .95) {
        if (++misses > 8 && found) setState(() => found = false);
        return;
      }
      misses = 0;
      final before = quad;
      setState(() {
        // Smoothed, so the window does not shake with every frame.
        quad = before == null
            ? guess
            : [
                for (var i = 0; i < 4; i++)
                  Offset.lerp(before[i], guess[i], .35)!
              ];
        found = true;
      });
    } finally {
      working = false;
    }
  }

  /// Holds the window where it is and takes the photo for fine-tuning.
  Future<void> take() async {
    final c = camera, q = quad;
    if (c == null || taking) return;
    setState(() {
      taking = true;
      tracking = false;
    });
    try {
      await c.stopImageStream();
      final file = await c.takePicture();
      var bytes = await file.readAsBytes();
      // A picture still lying on its side is turned to stand upright.
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width > descriptor.height) {
        final image =
            (await (await descriptor.instantiateCodec()).getNextFrame()).image;
        bytes = await _turn(image, c.description.sensorOrientation);
        image.dispose();
      }
      if (!mounted) return;
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => InPlacePage(
                  drawing: widget.drawing,
                  recipe: widget.recipe,
                  aiKey: widget.aiKey,
                  photo: bytes,
                  corners:
                      q == null ? null : [for (final p in q) (p.dx, p.dy)])));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Rasmga olib bo‘lmadi: $e')));
      setState(() {
        taking = false;
        tracking = true;
      });
      try {
        await c.startImageStream(frame);
      } catch (_) {}
    }
  }

  static Future<Uint8List> _turn(ui.Image image, int degrees) async {
    final w = image.width.toDouble(),
        h = image.height.toDouble(),
        turned = degrees % 180 != 0,
        outW = turned ? h : w,
        outH = turned ? w : h,
        recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..translate(outW / 2, outH / 2)
      ..rotate(degrees * math.pi / 180)
      ..drawImage(image, Offset(-w / 2, -h / 2), Paint());
    final out =
        await recorder.endRecording().toImage(outW.round(), outH.round());
    final png = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    return png!.buffer.asUint8List();
  }

  void fromPhoto() => Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => InPlacePage(
              drawing: widget.drawing,
              recipe: widget.recipe,
              aiKey: widget.aiKey)));

  Widget view(CameraController c) {
    // The window's own shape in the middle until the opening is found.
    final ww = (widget.drawing['widthMm'] as num).toDouble(),
        wh = (widget.drawing['heightMm'] as num).toDouble();
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / c.value.aspectRatio,
        child: LayoutBuilder(builder: (context, box) {
          final size = box.biggest,
              tall = size.height * .4,
              wide = math.min(size.width * .8, tall * ww / wh);
          final q = quad ??
              [
                Offset((size.width - wide) / 2 / size.width,
                    (size.height - tall) / 2 / size.height),
                Offset((size.width + wide) / 2 / size.width,
                    (size.height - tall) / 2 / size.height),
                Offset((size.width + wide) / 2 / size.width,
                    (size.height + tall) / 2 / size.height),
                Offset((size.width - wide) / 2 / size.width,
                    (size.height + tall) / 2 / size.height),
              ];
          final points = [
            for (final p in q) Offset(p.dx * size.width, p.dy * size.height)
          ];
          return Stack(fit: StackFit.expand, children: [
            CameraPreview(c),
            GestureDetector(
              key: const ValueKey('live-view'),
              // Moving a corner by hand holds the window there.
              onPanStart: (d) {
                var best = 44.0;
                dragCorner = null;
                for (var i = 0; i < 4; i++) {
                  final dist = (points[i] - d.localPosition).distance;
                  if (dist < best) {
                    best = dist;
                    dragCorner = i;
                  }
                }
                if (dragCorner != null) {
                  setState(() {
                    tracking = false;
                    quad = q;
                  });
                }
              },
              onPanUpdate: (d) {
                final i = dragCorner, current = quad;
                if (i == null || current == null) return;
                setState(() => quad = List.of(current)
                  ..[i] = Offset((d.localPosition.dx / size.width).clamp(0, 1),
                      (d.localPosition.dy / size.height).clamp(0, 1)));
              },
              onPanEnd: (_) => dragCorner = null,
              child: CustomPaint(
                painter: InPlacePainter(
                    null, points, widget.drawing, widget.recipe,
                    handles: !tracking || !found),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = camera, scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: GlassAppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Joyida — kamera'),
        actions: [
          IconButton(
              tooltip: 'Rasmdan',
              onPressed: fromPhoto,
              icon: const Icon(Icons.photo_library_outlined)),
        ],
      ),
      body: problem != null
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(problem!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: fromPhoto, child: const Text('Rasm bilan')),
              ]),
            ))
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(children: [
                  Positioned.fill(child: view(c)),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(18)),
                        child: Text(
                            !tracking
                                ? 'Qo‘lda: burchaklarni suring'
                                : found
                                    ? 'O‘rin topildi — rom joyida'
                                    : 'Telefonni darchaga qarating…',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
      bottomNavigationBar: c == null
          ? null
          : Material(
              color: Colors.black,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('live-auto'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54)),
                        onPressed: () => setState(() {
                          tracking = !tracking;
                          misses = 0;
                        }),
                        icon: Icon(tracking
                            ? Icons.center_focus_strong
                            : Icons.pan_tool_alt_outlined),
                        label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(tracking ? 'Avto' : 'Qo‘lda')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const ValueKey('live-take'),
                        style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: taking ? null : take,
                        icon: taking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera),
                        label: const FittedBox(
                            fit: BoxFit.scaleDown, child: Text('Rasmga olish')),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}
