import 'package:flutter/material.dart';
import 'design_engine.dart';
import 'dialogs.dart';

class DraftPayload {
  final String kind, value, label;
  const DraftPayload(this.kind, this.value, this.label);
}

/// Symbols describe the actual action before the user places it on the canvas.
class DraftTool extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? opening;
  final Widget? preview;
  final bool selected;
  final double width;
  final VoidCallback onTap;
  final DraftPayload? dragData;
  final VoidCallback? onDragStarted, onDragFinished;
  const DraftTool(
      {super.key,
      required this.label,
      this.icon,
      this.opening,
      this.preview,
      this.selected = false,
      this.width = 72,
      required this.onTap,
      this.dragData,
      this.onDragStarted,
      this.onDragFinished});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    final tile = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
            button: true,
            selected: selected,
            child: Tooltip(
                message: label,
                child: Material(
                    color:
                        selected ? colors.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                            width: width,
                            height: 58,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (preview != null)
                                    SizedBox(
                                        width: 30, height: 27, child: preview)
                                  else if (opening != null)
                                    CustomPaint(
                                        size: const Size(27, 27),
                                        painter: OpeningSymbol(opening!, color))
                                  else
                                    Icon(icon, size: 24, color: color),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(label,
                                          maxLines: 1,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: color,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400))),
                                ])))))));
    if (dragData == null) return tile;
    return Draggable<DraftPayload>(
      data: dragData,
      affinity: Axis.vertical,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragFinished?.call(),
      childWhenDragging: Opacity(opacity: .3, child: tile),
      feedback: Transform.translate(
          offset: const Offset(-38, -78),
          child: Material(
              elevation: 0,
              color: colors.primaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side:
                      BorderSide(color: colors.primary.withValues(alpha: .4))),
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (preview != null)
                      SizedBox(width: 44, height: 40, child: preview)
                    else if (opening != null)
                      CustomPaint(
                          size: const Size(30, 30),
                          painter: OpeningSymbol(opening!, colors.primary))
                    else
                      Icon(icon, color: colors.primary, size: 28),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12, color: colors.onPrimaryContainer)),
                  ])))),
      child: tile,
    );
  }
}

class OpeningSymbol extends CustomPainter {
  final String opening;
  final Color color;
  OpeningSymbol(this.opening, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), p);
    final box = [r.left, r.top, r.right, r.bottom];
    for (final line in openingSymbolLines(opening, box)) {
      canvas.drawPath(
          Path()..addPolygon([for (final v in line) Offset(v.x, v.y)], false),
          p);
    }
    final handle = handlePoint(opening, box);
    if (handle != null) {
      final side = hingeSide(opening);
      final along = side == 'top' || side == 'bottom'
          ? const Offset(3, 0)
          : const Offset(0, 3);
      final at = Offset(handle.x, handle.y);
      canvas.drawLine(at - along, at + along, p..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(OpeningSymbol old) =>
      old.opening != opening || old.color != color;
}

Future<double?> draftNumber(BuildContext context,
    {required String title,
    required num initial,
    required double min,
    required double max,
    String unit = 'mm'}) async {
  String value = initial == initial.roundToDouble()
      ? initial.toInt().toString()
      : initial.toString();
  bool replace = true;
  String? error;
  return showSettledDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, set) => AlertDialog(
                  scrollable: true,
                  title: Text(title),
                  content: SizedBox(
                      width: 300,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('${value.isEmpty ? '0' : value} $unit',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600))),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 12),
                        for (final row in [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                          ['.', '0', '⌫']
                        ])
                          Row(children: [
                            for (final key in row)
                              Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: OutlinedButton(
                                          onPressed: () => set(() {
                                                error = null;
                                                if (key == '⌫') {
                                                  value = replace
                                                      ? ''
                                                      : (value.isEmpty
                                                          ? ''
                                                          : value.substring(
                                                              0,
                                                              value.length -
                                                                  1));
                                                  replace = false;
                                                  return;
                                                }
                                                if (replace) {
                                                  value = '';
                                                  replace = false;
                                                }
                                                if (key == '.' &&
                                                    value.contains('.')) {
                                                  return;
                                                }
                                                if (value.length < 10) {
                                                  value += key;
                                                }
                                              }),
                                          child: Text(key,
                                              style: const TextStyle(
                                                  fontSize: 21)))))
                          ]),
                        Text('$min–$max $unit',
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Bekor qilish')),
                    FilledButton(
                        onPressed: () {
                          final n = double.tryParse(value);
                          if (n == null ||
                              !n.isFinite ||
                              n < min ||
                              n > max ||
                              (unit == 'dona' && n != n.roundToDouble())) {
                            set(() => error =
                                '${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)} $unit kiriting');
                            return;
                          }
                          Navigator.pop(context, n);
                        },
                        child: const Text('Saqlash')),
                  ])));
}

/// Drawn above the canvas only; it never participates in hit testing.
class DraftDropPainter extends CustomPainter {
  final List<Offset> polygon, line;
  final bool valid, snapped;
  final Color color;

  /// Millimetre read-outs drawn next to the preview (position, text).
  final List<(Offset, String)> labels;
  DraftDropPainter(
      {required this.polygon,
      required this.line,
      required this.valid,
      required this.color,
      this.snapped = false,
      this.labels = const []});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    if (!valid && polygon.isNotEmpty) {
      // The section is under the finger but this part does not fit there.
      final path = Path()..addPolygon(polygon, true);
      canvas.drawPath(
          path,
          paint
            ..color = color.withValues(alpha: .16)
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          path,
          paint
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      return;
    }
    if (!valid) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Offset.zero & size, const Radius.circular(18)),
          paint
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      return;
    }
    if (polygon.isEmpty) return;
    final path = Path()..addPolygon(polygon, true);
    canvas.drawPath(
        path,
        paint
          ..color = color.withValues(alpha: .14)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        paint
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    if (line.length == 2) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawLine(
          line[0],
          line[1],
          paint
            ..color = Colors.white
            ..strokeWidth = 7);
      canvas.drawLine(
          line[0],
          line[1],
          paint
            ..color = snapped ? const Color(0xff1f9d55) : color
            ..strokeWidth = snapped ? 4 : 3);
      canvas.restore();
    }
    paintReadouts(canvas, labels, snapped ? const Color(0xff1f9d55) : color);
  }

  @override
  bool shouldRepaint(DraftDropPainter old) => true;
}

/// Small rounded millimetre badges, readable on top of glass and profiles.
void paintReadouts(Canvas canvas, List<(Offset, String)> labels, Color color) {
  for (final (at, text) in labels) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr)
      ..layout();
    final box = Rect.fromCenter(
        center: at, width: painter.width + 12, height: painter.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(8)),
        Paint()..color = color);
    painter.paint(canvas, box.topLeft + const Offset(6, 3));
  }
}

/// Context actions for one section, shown on long press.
class SectionAction {
  final String id, label;
  final IconData icon;
  final String? opening;
  const SectionAction(this.id, this.label, this.icon, {this.opening});
}
