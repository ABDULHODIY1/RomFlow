import 'package:flutter/material.dart';

/// Recording aid, compiled in only with --dart-define=ROMFLOW_DEMO=true:
/// a caption strip explaining each step and a dot where the finger is.
const demoMode = bool.fromEnvironment('ROMFLOW_DEMO');
final demoCaption = ValueNotifier<String?>(null);

class DemoOverlay extends StatefulWidget {
  final Widget child;
  const DemoOverlay({super.key, required this.child});
  @override
  State<DemoOverlay> createState() => _DemoOverlayState();
}

class _DemoOverlayState extends State<DemoOverlay> {
  final touches = <int, Offset>{};

  /// Quick taps would otherwise leave no visible dot in the recording.
  void lift(int pointer) => Future<void>.delayed(
      const Duration(milliseconds: 260),
      () => mounted ? setState(() => touches.remove(pointer)) : null);

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => setState(() => touches[e.pointer] = e.position),
        onPointerMove: (e) => setState(() => touches[e.pointer] = e.position),
        onPointerUp: (e) => lift(e.pointer),
        onPointerCancel: (e) => lift(e.pointer),
        child: Stack(children: [
          widget.child,
          for (final at in touches.values)
            Positioned(
                left: at.dx - 22,
                top: at.dy - 22,
                child: IgnorePointer(
                    child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x55ffb020),
                            border: Border.all(
                                color: const Color(0xccff8a00), width: 2))))),
          Positioned(
            left: 10,
            right: 10,
            bottom: 96,
            child: IgnorePointer(
              child: ValueListenableBuilder<String?>(
                valueListenable: demoCaption,
                builder: (context, text, _) => AnimatedOpacity(
                  opacity: text == null ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: text == null
                      ? const SizedBox.shrink()
                      : Material(
                          color: const Color(0xe6101d30),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Text(text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ]),
      );
}
