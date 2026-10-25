import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Liquid Glass design (iOS 26 and later): navigation bars, tab bar,
/// sheets and controls float as glass over the content. On by default on
/// iPhone and iPad; Settings can switch it on or off on every platform, and
/// --dart-define=ROMFLOW_GLASS=true forces it for screenshots.
bool _glass = defaultTargetPlatform == TargetPlatform.iOS ||
    const bool.fromEnvironment('ROMFLOW_GLASS');
bool get usesIOSGlass => _glass;

/// Applies the Settings choice: 'auto', 'glass' or 'material'.
void applyDesign(String preference) {
  _glass = const bool.fromEnvironment('ROMFLOW_GLASS') ||
      switch (preference) {
        'glass' => true,
        'material' => false,
        _ => defaultTargetPlatform == TargetPlatform.iOS,
      };
}

/// More colour through the glass, as Apple's material does.
const _saturate = ColorFilter.matrix(<double>[
  1.4724, -.4291, -.0433, 0, 0, //
  -.1276, 1.1709, -.0433, 0, 0, //
  -.1276, -.4291, 1.5567, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// One piece of Liquid Glass: the content behind is blurred and brightened,
/// a light edge catches the light at the top and the bottom, a soft glare
/// runs down from the top. [tint] colours it (a primary button); [opaque]
/// keeps long text readable (sheets).
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final Color? tint;
  final bool opaque, shadow;

  /// Dark glass on a dark page (3D) whatever the app theme.
  final Brightness? brightness;
  const GlassSurface(
      {super.key,
      required this.child,
      this.radius = const BorderRadius.all(Radius.circular(28)),
      this.tint,
      this.opaque = false,
      this.shadow = true,
      this.brightness});

  @override
  Widget build(BuildContext context) {
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    // Reduce Transparency and high contrast get a solid surface.
    final solid = MediaQuery.highContrastOf(context);
    final glass = ClipRSuperellipse(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.compose(
            outer: ImageFilter.blur(
                sigmaX: opaque ? 30 : 18,
                sigmaY: opaque ? 30 : 18,
                tileMode: TileMode.mirror),
            inner: _saturate),
        child: CustomPaint(
          painter: _GlassPainter(radius, dark, tint, opaque || solid),
          child: child,
        ),
      ),
    );
    if (!shadow) return glass;
    return DecoratedBox(
      decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(borderRadius: radius),
          shadows: [
            BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .30 : .10),
                blurRadius: 22,
                offset: const Offset(0, 8)),
          ]),
      child: glass,
    );
  }
}

class _GlassPainter extends CustomPainter {
  final BorderRadius radius;
  final bool dark, opaque;
  final Color? tint;
  _GlassPainter(this.radius, this.dark, this.tint, this.opaque);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = radius.toRSuperellipse(rect);
    // Body: a thin milky layer (or a tint) over the blurred backdrop.
    final body = tint != null
        ? tint!.withValues(alpha: opaque ? .92 : .78)
        : (dark ? const Color(0xff1b2633) : Colors.white).withValues(
            alpha: opaque ? (dark ? .80 : .74) : (dark ? .42 : .34));
    canvas.drawRSuperellipse(shape, Paint()..color = body);
    // Glare from the top.
    canvas.drawRSuperellipse(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: dark ? .10 : .30),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect));
    // The rim: light on the top-left and bottom-right edges, as glass
    // catches light on both sides.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? .45 : .95),
          Colors.white.withValues(alpha: dark ? .06 : .18),
          Colors.white.withValues(alpha: dark ? .25 : .65),
        ],
        stops: const [0, .5, 1],
      ).createShader(rect);
    canvas.drawRSuperellipse(radius.toRSuperellipse(rect.deflate(.6)), rim);
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.dark != dark ||
      old.tint != tint ||
      old.opaque != opaque ||
      old.radius != radius;
}

/// A round glass button for a toolbar icon.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final Brightness? brightness;
  const GlassIconButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.selected = false,
      this.size = 44,
      this.brightness});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    final ink = selected
        ? scheme.onPrimary
        : dark
            ? Colors.white.withValues(alpha: onPressed == null ? .35 : .92)
            : scheme.onSurface.withValues(alpha: onPressed == null ? .35 : 1);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: SizedBox.square(
          dimension: size,
          child: GlassSurface(
            radius: BorderRadius.circular(size / 2),
            tint: selected ? scheme.primary : null,
            brightness: brightness,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: Icon(icon, size: size * .5, color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app bar in glass when Liquid Glass is on, the usual one otherwise.
class GlassAppBar extends AppBar {
  GlassAppBar(
      {super.key,
      super.leading,
      super.automaticallyImplyLeading,
      super.title,
      super.actions,
      Widget? flexibleSpace,
      super.bottom,
      super.elevation,
      Color? backgroundColor,
      super.foregroundColor,
      super.centerTitle,
      super.titleSpacing,
      super.toolbarHeight,
      super.titleTextStyle,
      super.systemOverlayStyle,
      Brightness? glassBrightness})
      : super(
          flexibleSpace: flexibleSpace ??
              (usesIOSGlass
                  ? GlassSurface(
                      radius: BorderRadius.zero,
                      shadow: false,
                      brightness: glassBrightness,
                      child: const SizedBox.expand())
                  : null),
          backgroundColor: usesIOSGlass ? Colors.transparent : backgroundColor,
          surfaceTintColor: usesIOSGlass ? Colors.transparent : null,
          scrolledUnderElevation: usesIOSGlass ? 0 : null,
        );
}

/// [showModalBottomSheet], as a glass sheet when Liquid Glass is on.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  Color? backgroundColor,
}) {
  if (!usesIOSGlass) {
    return showModalBottomSheet<T>(
        context: context,
        builder: builder,
        isScrollControlled: isScrollControlled,
        showDragHandle: showDragHandle,
        backgroundColor: backgroundColor);
  }
  const top = BorderRadius.vertical(top: Radius.circular(34));
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // The glass draws its own handle.
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: .18),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: GlassSurface(
        radius: top,
        opaque: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (showDragHandle)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 14),
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
          Flexible(child: builder(context)),
        ]),
      ),
    ),
  );
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
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
                      ]))))));
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
