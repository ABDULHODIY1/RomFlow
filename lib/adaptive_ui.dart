import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get usesIOSGlass => defaultTargetPlatform == TargetPlatform.iOS;

class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  const GlassSurface(
      {super.key,
      required this.child,
      this.radius = const BorderRadius.all(Radius.circular(28))});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xff182638)
                          : Colors.white)
                      .withValues(
                          alpha: MediaQuery.disableAnimationsOf(context)
                              ? .94
                              : .72),
                  borderRadius: radius,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .85))),
              child: child)));
}

class IOSGlassNavigation extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const IOSGlassNavigation(
      {super.key, required this.selected, required this.onChanged});
  @override
  State<IOSGlassNavigation> createState() => _IOSGlassNavigationState();
}

class _IOSGlassNavigationState extends State<IOSGlassNavigation> {
  MethodChannel? channel;
  @override
  void didUpdateWidget(covariant IOSGlassNavigation old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      channel?.invokeMethod<void>('select', widget.selected);
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Widget previewItem(int i) => Expanded(
      child: Semantics(
          selected: i == widget.selected,
          button: true,
          child: InkWell(
              onTap: () => widget.onChanged(i),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        const [
                          Icons.dashboard_outlined,
                          Icons.receipt_long_outlined,
                          Icons.grid_view_outlined,
                          Icons.tune
                        ][i],
                        color: i == widget.selected
                            ? const Color(0xff206bc4)
                            : Colors.blueGrey),
                    Text(
                        const [
                          'Asosiy',
                          'Buyurtmalar',
                          'Katalog',
                          'Sozlamalar'
                        ][i],
                        style: TextStyle(
                            fontSize: 10,
                            color: i == widget.selected
                                ? const Color(0xff206bc4)
                                : Colors.blueGrey)),
                  ])))));
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Platform.isIOS
                ? UiKitView(
                    viewType: 'romflow/liquid-navigation',
                    creationParams: {'selected': widget.selected},
                    creationParamsCodec: const StandardMessageCodec(),
                    onPlatformViewCreated: (id) {
                      channel = MethodChannel('romflow/liquid-navigation/$id');
                      channel!.setMethodCallHandler((call) async {
                        if (call.method == 'onTab' && mounted) {
                          widget.onChanged(call.arguments as int);
                        }
                      });
                    })
                : GlassSurface(
                    child: Row(children: [
                    for (var i = 0; i < 4; i++) previewItem(i)
                  ])),
          )));
}

/// Keeps lists and forms at a readable width on tablets and desktops;
/// phones are unaffected.
Widget readable(Widget child, {double maxWidth = 880}) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth), child: child));
