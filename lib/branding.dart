import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Uses the user's original blue/green artwork without recolouring/redrawing it.
/// The two source rectangles are the bottom icons in the supplied reference.
class BrandLogo extends StatelessWidget {
  final double size;
  final Brightness? brightness;
  const BrandLogo({super.key, this.size = 42, this.brightness});
  static Future<ui.Image>? _image;
  static Future<ui.Image> load() => _image ??= () async {
        final bytes = await rootBundle.load('assets/brand_reference.jpeg');
        final codec =
            await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      }();
  @override
  Widget build(BuildContext context) {
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    return Semantics(
      label: 'RomFlow logosi',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<ui.Image>(
          future: load(),
          builder: (context, snapshot) => snapshot.hasData
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(size * .22),
                  child: CustomPaint(
                    painter: BrandPainter(snapshot.data!, dark),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class BrandPainter extends CustomPainter {
  final ui.Image image;
  final bool dark;
  BrandPainter(this.image, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final scale = image.width / 1254;
    final rect = dark
        ? const Rect.fromLTWH(268, 869, 301, 303)
        : const Rect.fromLTWH(687, 869, 301, 303);
    canvas.drawImageRect(
      image,
      Rect.fromLTRB(
        rect.left * scale,
        rect.top * scale,
        rect.right * scale,
        rect.bottom * scale,
      ),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant BrandPainter old) =>
      old.dark != dark || old.image != image;
}
