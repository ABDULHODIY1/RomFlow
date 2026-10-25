import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'i18n.dart';

/// Liquid Glass design (iOS 26 and later): navigation bars, tab bar,
/// sheets and controls float as glass over the content. On by default on
/// iPhone and iPad; Settings can switch it on or off on every platform, and
/// --dart-define=ROMFLOW_GLASS=true forces it for screenshots.
bool _glass = defaultTargetPlatform == TargetPlatform.iOS ||
    const bool.fromEnvironment('ROMFLOW_GLASS');
bool get usesIOSGlass => _glass;

/// Apple's own Liquid Glass (system tab bar and glass buttons) is drawn on
/// iPhone and iPad; Flutter's imitation is not used there.
bool get nativeGlass => _glass && !kIsWeb && Platform.isIOS;

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
///
/// A backdrop blur is a full offscreen pass every frame the area repaints;
/// dozens of them on one list made scrolling stutter and the phone warm.
/// Only floating chrome over moving content blurs (app bar, tab bar,
/// toolbar buttons). Tinted, opaque and content-level glass sits on a flat
/// page, where a blur shows nothing: it is painted, not filtered. The 3D
/// page ([brightness] dark) never blurs over the model it redraws.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final Color? tint;
  final bool opaque, shadow;

  /// Dark glass on a dark page (3D) whatever the app theme.
  final Brightness? brightness;

  /// Blur what is behind; by default only untinted, see-through glass does.
  final bool? blur;
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(28)),
    this.tint,
    this.opaque = false,
    this.shadow = true,
    this.brightness,
    this.blur,
  });

  @override
  Widget build(BuildContext context) {
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    // Shared Flutter surfaces stay glass on iOS too. Native navigation and
    // buttons continue to use UIKit; content keeps the same geometry.
    final solid = MediaQuery.highContrastOf(context);
    final filtered =
        this.blur ?? (!opaque && tint == null && brightness == null);
    // On iPhone and iPad the floating glass is Apple's own: a UIGlassEffect
    // view behind the Flutter content, which bends and lights what is under
    // it as the system bars do.
    if (!solid && filtered && nativeGlass) {
      return _NativeGlass(
        radius: radius,
        // Sheets and dialogs carry long text: a denser tint of the page
        // colour keeps it readable over whatever is behind.
        tint: opaque
            ? (tint ?? Theme.of(context).colorScheme.surface)
                .withValues(alpha: .6)
            : tint,
        dark: dark,
        shadow: shadow,
        child: child,
      );
    }
    if (!solid && !filtered) {
      final painted = ClipRSuperellipse(
        borderRadius: radius,
        child: CustomPaint(
          painter: _GlassPainter(radius, dark, tint, opaque, frosted: true),
          child: child,
        ),
      );
      if (!shadow) return painted;
      return DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(borderRadius: radius),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .30 : .10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: painted,
      );
    }
    final blur = ImageFilter.blur(
      sigmaX: opaque ? 30 : 18,
      sigmaY: opaque ? 30 : 18,
      tileMode: TileMode.mirror,
    );
    final glass = ClipRSuperellipse(
      borderRadius: radius,
      child: solid
          ? ColoredBox(
              color: tint?.withValues(alpha: 1) ??
                  (dark ? const Color(0xff1b2633) : Colors.white),
              child: child,
            )
          : BackdropFilter(
              // UIKit platform views support a blur backdrop, not a colour
              // matrix filter composed over the native view.
              filter: nativeGlass
                  ? blur
                  : ImageFilter.compose(outer: blur, inner: _saturate),
              child: CustomPaint(
                painter: _GlassPainter(radius, dark, tint, opaque),
                child: child,
              ),
            ),
    );
    if (!shadow || solid) return glass;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: radius),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .30 : .10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: glass,
    );
  }
}

class _NativeGlass extends StatelessWidget {
  final BorderRadius radius;
  final Color? tint;
  final bool dark, shadow;
  final Widget child;
  const _NativeGlass({
    required this.radius,
    required this.tint,
    required this.dark,
    required this.shadow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final params = <String, Object?>{
      'dark': dark,
      'corners': [
        radius.topLeft.x,
        radius.topRight.x,
        radius.bottomRight.x,
        radius.bottomLeft.x,
      ],
      // UIKit tints the glass itself; a light touch, as in Apple's apps.
      if (tint != null) 'tint': tint!.toARGB32(),
    };
    // Passthrough: the content takes the surface's full size, as on the
    // painted glass; loose, an icon sat in the top-left corner of its
    // circle.
    final glass = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          // Taps go to the Flutter content; the glass only shows.
          child: IgnorePointer(
            child: UiKitView(
              // New look, new view: UIKit glass is configured once.
              key: ValueKey(jsonEncode(params)),
              viewType: 'romflow/glass-surface',
              creationParams: params,
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
        ),
        ClipRSuperellipse(borderRadius: radius, child: child),
      ],
    );
    if (!shadow) return glass;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: radius),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .30 : .10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: glass,
    );
  }
}

class _GlassPainter extends CustomPainter {
  final BorderRadius radius;
  final bool dark, opaque;
  final Color? tint;

  /// No blur behind: a denser body keeps what is behind from reading
  /// through, as the frosted material does.
  final bool frosted;
  _GlassPainter(this.radius, this.dark, this.tint, this.opaque,
      {this.frosted = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = radius.toRSuperellipse(rect);
    // Body: a thin milky layer (or a tint) over the blurred backdrop.
    final body = tint != null
        ? tint!.withValues(
            alpha: opaque
                ? .92
                : frosted
                    // A see-through tint keeps its own alpha; a solid one
                    // gets a dense frosted body.
                    ? (tint!.a < 1 ? tint!.a : .86)
                    : .78)
        : (dark ? const Color(0xff1b2633) : Colors.white).withValues(
            alpha: opaque
                ? (dark ? .94 : .90)
                : frosted
                    ? (dark ? .78 : .72)
                    : (dark ? .42 : .34),
          );
    canvas.drawRSuperellipse(shape, Paint()..color = body);
    // Painted (frosted) glass: a soft sheen from the top and light caught
    // only along the upper edge, fading down the sides, as on Apple's glass
    // controls. A full bright rim read as a second outline on every button.
    if (frosted) {
      canvas.drawRSuperellipse(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: dark ? .07 : .22),
              Colors.white.withValues(alpha: 0),
              Colors.black.withValues(alpha: dark ? .10 : .03),
            ],
            stops: const [0, .55, 1],
          ).createShader(rect),
      );
      canvas.drawRSuperellipse(
        radius.toRSuperellipse(rect.deflate(.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: dark ? .22 : .7),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, .4],
          ).createShader(rect),
      );
      return;
    }
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
        ).createShader(rect),
    );
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
      old.frosted != frosted ||
      old.radius != radius;
}

/// Shared decoration preserves the original control, semantics and geometry.
class GlassControl extends StatelessWidget {
  final Widget child;
  final Color? tint;

  /// False leaves [child] as it is (a card with its own colours).
  final bool enabled;

  /// Dark glass on a dark or coloured backdrop, whatever the app theme.
  final Brightness? brightness;
  const GlassControl({
    super.key,
    required this.child,
    this.tint,
    this.enabled = true,
    this.brightness,
  });
  @override
  Widget build(BuildContext context) {
    if (!usesIOSGlass || !enabled) return child;
    final scheme = Theme.of(context).colorScheme;
    final c = child;
    final selected = c is ChoiceChip
        ? c.selected
        : c is FilterChip
            ? c.selected
            : c is SwitchListTile
                ? c.value
                : c is CheckboxListTile
                    ? c.value == true
                    : false;
    final accent = tint ?? scheme.primary;
    final soft = brightness == Brightness.dark
        ? accent.withValues(alpha: .55)
        : Color.alphaBlend(
            accent.withValues(alpha: selected ? .20 : .07),
            scheme.surface,
          );
    // Chips and segmented buttons are capsules: the glass follows them
    // instead of drawing a box around the pill.
    final capsule = c is ChoiceChip ||
        c is FilterChip ||
        c is ActionChip ||
        c is InputChip ||
        c is SegmentedButton;
    final radius = BorderRadius.circular(capsule ? 100 : 12);
    // Capsule controls and the search field are Apple's own glass on
    // iPhone: the selected chip or segment carries a tint of the accent.
    if (nativeGlass && (capsule || c is TextField)) {
      return GlassSurface(
        radius: radius,
        tint: selected ? accent.withValues(alpha: .35) : null,
        shadow: false,
        blur: true,
        brightness: brightness,
        child: child,
      );
    }
    // A field's floating label sits on its top edge: the glass goes behind
    // the field and never clips the label.
    if (c is TextField || c is FormField) {
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: GlassSurface(
                radius: radius,
                tint: soft,
                shadow: false,
                brightness: brightness,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          child,
        ],
      );
    }
    return GlassSurface(
      radius: radius,
      tint: soft,
      shadow: false,
      brightness: brightness,
      child: child,
    );
  }
}

/// All ordinary Material buttons get glass from their theme, including custom
/// local foreground/background colours. Flutter retains tap/keyboard handling.
ButtonStyle glassButtonStyle(
  ButtonStyle original, {
  required Color tint,
  bool prominent = false,
}) {
  if (!usesIOSGlass) return original;
  return original.copyWith(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    backgroundBuilder: (context, states, child) {
      final scheme = Theme.of(context).colorScheme;
      final widget = context.widget;
      final local = widget is ButtonStyleButton ? widget.style : null;
      final disabled = states.contains(WidgetState.disabled);
      final accent = local?.backgroundColor?.resolve(states) ??
          (prominent
              ? original.backgroundColor?.resolve(states)
              : local?.foregroundColor?.resolve(states)) ??
          tint;
      final colour = disabled
          ? scheme.surfaceContainerHighest
          : prominent || states.contains(WidgetState.selected)
              ? accent
              : Color.alphaBlend(accent.withValues(alpha: .12), scheme.surface);
      // On iPhone a button is a capsule of Apple's glass: tinted with its
      // colour when prominent (as UIKit's prominent glass), clear with a
      // coloured label otherwise.
      if (nativeGlass && !disabled) {
        final strong = prominent || states.contains(WidgetState.selected);
        return GlassSurface(
          radius: BorderRadius.circular(100),
          tint: strong ? accent : null,
          shadow: false,
          blur: true,
          child: child ?? const SizedBox.shrink(),
        );
      }
      return GlassSurface(
        radius: BorderRadius.circular(12),
        tint: colour,
        shadow: false,
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

/// A responsive extended action button uses the same themed button pipeline.
/// Its label wraps at large text sizes rather than escaping a narrow phone.
class GlassActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget label;
  final Widget? icon;
  final Object? heroTag;
  const GlassActionButton.extended({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.heroTag,
  });
  @override
  Widget build(BuildContext context) {
    if (!usesIOSGlass) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        icon: icon,
        label: label,
        heroTag: heroTag ?? const _GlassActionHero(),
      );
    }
    final available = MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        32;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: available.clamp(48.0, double.infinity),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Flexible(child: label),
          ],
        ),
      ),
    );
  }
}

class _GlassActionHero {
  const _GlassActionHero();
}

Color glassActionTint(String id) {
  final key = id.toLowerCase();
  if (RegExp('delete|remove|trash').hasMatch(key)) {
    return const Color(0xffc84456);
  }
  if (RegExp('add|new|create').hasMatch(key)) return const Color(0xff23845f);
  if (RegExp('share|export').hasMatch(key)) return const Color(0xff8055c8);
  if (RegExp('photo|camera|scan').hasMatch(key)) return const Color(0xff178b94);
  return const Color(0xff206bc4);
}

/// A round glass button for a toolbar icon.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final Brightness? brightness;
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = 44,
    this.brightness,
  });
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
    final target = size < 48 ? 48.0 : size;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: selected,
        label: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: target,
              child: Center(
                child: SizedBox.square(
                  dimension: size,
                  child: GlassSurface(
                    radius: BorderRadius.circular(size / 2),
                    tint: selected ? scheme.primary : null,
                    brightness: brightness,
                    child: Icon(icon, size: size * .5, color: ink),
                  ),
                ),
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
  GlassAppBar({
    super.key,
    Widget? leading,
    super.automaticallyImplyLeading = true,
    super.title,
    List<Widget>? actions,
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
    Brightness? glassBrightness,
  }) : super(
          // Liquid Glass, as in Apple's apps: no slab across the top; the
          // page fades out under the title, and the back button and the
          // tools float on glass of their own.
          leading: leading ??
              (usesIOSGlass &&
                      automaticallyImplyLeading &&
                      glassBrightness == null
                  ? const _GlassBackButton()
                  : null),
          actions: glassBrightness == null ? _glassActions(actions) : actions,
          flexibleSpace: flexibleSpace ??
              (!usesIOSGlass
                  ? null
                  : glassBrightness == null
                      ? const _TopEdge()
                      : GlassSurface(
                          radius: BorderRadius.zero,
                          shadow: false,
                          brightness: glassBrightness,
                          child: const SizedBox.expand(),
                        )),
          backgroundColor: usesIOSGlass ? Colors.transparent : backgroundColor,
          surfaceTintColor: usesIOSGlass ? Colors.transparent : null,
          scrolledUnderElevation: usesIOSGlass ? 0 : null,
        );

  /// Plain icon buttons and menus share one glass capsule, as Apple groups
  /// a bar's tools; native glass buttons keep their own glass.
  static List<Widget>? _glassActions(List<Widget>? actions) {
    if (!usesIOSGlass || actions == null) return actions;
    final out = <Widget>[], group = <Widget>[];
    void flush() {
      if (group.isEmpty) return;
      out.add(_GlassCapsule(children: List.of(group)));
      group.clear();
    }

    for (final a in actions) {
      if (a is IconButton || a is PopupMenuButton) {
        group.add(a);
      } else if (a is SizedBox && a.child == null) {
        // Spacing that only made room for a bare icon.
      } else {
        flush();
        out.add(a);
      }
    }
    flush();
    out.add(const SizedBox(width: 12));
    return out;
  }
}

/// The page fading out under the title, Apple's scroll edge effect.
class _TopEdge extends StatelessWidget {
  const _TopEdge();
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg.withValues(alpha: .96), bg.withValues(alpha: 0)],
            stops: const [.55, 1],
          ),
        ),
      ),
    );
  }
}

/// Bar tools on one capsule of Apple's glass.
class _GlassCapsule extends StatelessWidget {
  final List<Widget> children;
  const _GlassCapsule({required this.children});
  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          height: 44,
          child: GlassSurface(
            radius: BorderRadius.circular(22),
            shadow: false,
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ),
        ),
      );
}

/// Back (or close, for a full-screen form) on a glass circle; nothing on a
/// page that cannot go back.
class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton();
  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null || !route.canPop) return const SizedBox.shrink();
    final close = route is PageRoute && route.fullscreenDialog;
    return Center(
      child: GlassIconButton(
        icon: close ? Icons.close : Icons.arrow_back_ios_new,
        tooltip: tr(close ? 'Yopish' : 'Orqaga'),
        onPressed: () => Navigator.maybePop(context),
      ),
    );
  }
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
      backgroundColor: backgroundColor,
    );
  }
  const top = BorderRadius.vertical(top: Radius.circular(34));
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // The glass draws its own handle.
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: .18),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      // Sheets float over the page: real glass, so the page behind is
      // blurred away instead of reading through as ghost buttons.
      child: GlassSurface(
        radius: top,
        tint: backgroundColor,
        opaque: true,
        blur: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragHandle)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 14),
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  );
}

/// One system glass button: an SF Symbol and/or a title.
class GlassButton {
  final String id;
  final String? symbol, title, subtitle, label;

  /// 'glass', 'prominent' (tinted) or 'white' (white glass, blue text).
  final String style;
  final Color? tint;
  final bool selected, enabled, expand, light;
  final double? size;
  final double height, fontSize, iconSize;
  const GlassButton(
    this.id, {
    this.symbol,
    this.title,
    this.subtitle,
    this.label,
    this.style = 'glass',
    this.tint,
    this.selected = false,
    this.enabled = true,
    this.expand = false,
    this.light = false,
    this.size,
    this.height = 48,
    this.fontSize = 15,
    this.iconSize = 16,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        if (symbol != null) 'symbol': symbol,
        // UIKit draws these: they go over in the chosen language.
        if (title != null) 'title': tr(title!),
        if (subtitle != null) 'subtitle': tr(subtitle!),
        if (label != null) 'label': tr(label!),
        'style': style,
        'tint': (tint ?? glassActionTint(id)).toARGB32(),
        'selected': selected,
        'enabled': enabled,
        'expand': expand,
        'light': light,
        if (size != null) 'size': size,
        'height': height,
        'fontSize': fontSize,
        'iconSize': iconSize,
      };
}

/// A row or column of Apple's glass buttons on iPhone and iPad; [fallback]
/// (the usual Flutter buttons) everywhere else.
class NativeGlassButtons extends StatefulWidget {
  final List<GlassButton> items;
  final ValueChanged<String> onTap;
  final Widget fallback;
  final double height;
  final double? width;
  final bool vertical, dark, equal;
  final double spacing;
  const NativeGlassButtons({
    super.key,
    required this.items,
    required this.onTap,
    required this.fallback,
    this.height = 48,
    this.width,
    this.vertical = false,
    this.dark = false,
    this.equal = false,
    this.spacing = 8,
  });
  @override
  State<NativeGlassButtons> createState() => _NativeGlassButtonsState();
}

class _NativeGlassButtonsState extends State<NativeGlassButtons> {
  MethodChannel? channel;
  bool available = true;
  String? lastConfiguration;
  Map<String, Object?> get configuration {
    // The buttons have a fixed height and share the row: their titles grow
    // a little with Dynamic Type, never out of the capsule.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
    return {
      'items': [
        for (final b in widget.items)
          {
            ...b.toMap(),
            'fontSize': scaler.scale(b.fontSize),
            'subtitleFontSize': scaler.scale(11),
          },
      ],
      'vertical': widget.vertical,
      'dark': widget.dark || Theme.brightnessOf(context) == Brightness.dark,
      'equal': widget.equal,
      'spacing': widget.spacing,
    };
  }

  Future<void> sync() async {
    final current = channel;
    if (current == null) return;
    try {
      final next = configuration;
      final signature = jsonEncode(next);
      if (signature == lastConfiguration) return;
      lastConfiguration = signature;
      await current.invokeMethod<void>('configure', next);
    } on PlatformException {
      if (mounted) setState(() => available = false);
    } on MissingPluginException {
      if (mounted) setState(() => available = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(sync());
  }

  @override
  void didUpdateWidget(covariant NativeGlassButtons old) {
    super.didUpdateWidget(old);
    unawaited(sync());
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!nativeGlass || !available) return widget.fallback;
    return SizedBox(
      height: widget.height < 48 ? 48 : widget.height,
      width: widget.width == null
          ? null
          : (widget.width! < 48 ? 48 : widget.width),
      child: UiKitView(
        viewType: 'romflow/glass-buttons',
        creationParams: configuration,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          channel?.setMethodCallHandler(null);
          channel = MethodChannel('romflow/glass-buttons/$id');
          lastConfiguration = null;
          channel!.setMethodCallHandler((call) async {
            if (call.method == 'onTap' && mounted && available) {
              final id = call.arguments;
              if (id is String &&
                  widget.items.any((b) => b.id == id && b.enabled)) {
                widget.onTap(id);
              }
            }
          });
          // A rebuild may have happened while UIKit was creating the view.
          unawaited(sync());
        },
      ),
    );
  }
}

/// The tab bar. On iPhone and iPad it is Apple's own UITabBar, the real
/// Liquid Glass that bends the page behind it like a lens; it reaches the
/// bottom of the screen as a system bar does and takes the height it asks
/// for, so the capsule is never squeezed. Elsewhere a Flutter glass capsule
/// stands in.
class IOSGlassNavigation extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const IOSGlassNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  @override
  State<IOSGlassNavigation> createState() => _IOSGlassNavigationState();
}

class _IOSGlassNavigationState extends State<IOSGlassNavigation> {
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.grid_view_outlined,
    Icons.tune,
  ];
  static const _labels = ['Asosiy', 'Buyurtmalar', 'Katalog', 'Sozlamalar'];

  MethodChannel? channel;
  bool available = true;
  String? lastConfiguration;

  /// The system bar's own height, reported by UIKit once laid out.
  double? nativeHeight;

  Future<void> sync() async {
    final current = channel;
    if (current == null) return;
    try {
      final next = {
        'selected': widget.selected,
        'dark': Theme.brightnessOf(context) == Brightness.dark,
      };
      final signature = jsonEncode(next);
      if (signature == lastConfiguration) return;
      lastConfiguration = signature;
      await current.invokeMethod<void>('configure', next);
    } on PlatformException {
      if (mounted) setState(() => available = false);
    } on MissingPluginException {
      if (mounted) setState(() => available = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(sync());
  }

  @override
  void didUpdateWidget(covariant IOSGlassNavigation old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) unawaited(sync());
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Widget item(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme, on = i == widget.selected;
    final color = on ? scheme.primary : scheme.onSurface.withValues(alpha: .72);
    return Expanded(
      child: Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: on
                  ? scheme.primary.withValues(alpha: .16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icons[i], size: 25, color: color),
                    const SizedBox(height: 3),
                    Tx(
                      _labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget system(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: (nativeHeight ?? 62 + bottom).clamp(49.0, 140.0),
      child: UiKitView(
        viewType: 'romflow/liquid-navigation',
        creationParams: {
          'selected': widget.selected,
          'dark': Theme.brightnessOf(context) == Brightness.dark,
          'titles': [for (final l in _labels) tr(l)],
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          channel?.setMethodCallHandler(null);
          channel = MethodChannel('romflow/liquid-navigation/$id');
          lastConfiguration = null;
          channel!.setMethodCallHandler((call) async {
            if (!mounted) return;
            if (call.method == 'onTab') {
              final index = call.arguments;
              if (index is int && index >= 0 && index < 4) {
                widget.onChanged(index);
              }
            } else if (call.method == 'height') {
              final h = call.arguments;
              if (h is num && (h - (nativeHeight ?? 0)).abs() > .5) {
                setState(() => nativeHeight = h.toDouble());
              }
            }
          });
          unawaited(sync());
        },
      ),
    );
  }

  Widget flutterBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: GlassSurface(
              radius: BorderRadius.circular(34),
              child: Row(
                children: [for (var i = 0; i < 4; i++) item(context, i)],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final native = nativeGlass && available;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // A soft edge under the bar, as Apple's scroll edge effect: the page
        // still shows through the glass, but rows don't fight its labels.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(alpha: 0),
                    Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(alpha: native ? .55 : .9),
                  ],
                ),
              ),
            ),
          ),
        ),
        native ? system(context) : flutterBar(context),
      ],
    );
  }
}

/// [child] wrapped by [glass] when Liquid Glass is on, as it is otherwise.
Widget whenGlass(Widget child, Widget Function(Widget child) glass) =>
    usesIOSGlass ? glass(child) : child;

/// Keeps lists and forms at a readable width on tablets and desktops;
/// phones are unaffected.
Widget readable(Widget child, {double maxWidth = 880}) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

/// The existing Card layout, margins and taps with a readable glass material.
class GlassCard extends Card {
  const GlassCard({
    super.key,
    super.child,
    super.margin,
    super.color,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.shape,
    super.clipBehavior,
    super.borderOnForeground,
    super.semanticContainer,
  });

  @override
  Widget build(BuildContext context) {
    if (!usesIOSGlass) return super.build(context);
    final effectiveShape = shape ?? Theme.of(context).cardTheme.shape;
    final radius = effectiveShape is RoundedRectangleBorder
        ? effectiveShape.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(16);
    return Card(
      margin: margin,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: effectiveShape,
      clipBehavior: clipBehavior,
      borderOnForeground: borderOnForeground,
      semanticContainer: semanticContainer,
      child: GlassSurface(
        radius: radius,
        tint: color ??
            Color.alphaBlend(
              Theme.of(context).colorScheme.primary.withValues(alpha: .045),
              Theme.of(context).colorScheme.surface,
            ),
        opaque: true,
        shadow: false,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Keep Flutter's scrolling, keyboard avoidance and accessible dialog layout.
class GlassAlertDialog extends AlertDialog {
  const GlassAlertDialog({
    super.key,
    super.icon,
    super.iconPadding,
    super.iconColor,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.content,
    super.contentPadding,
    super.contentTextStyle,
    super.actions,
    super.actionsPadding,
    super.actionsAlignment,
    super.actionsOverflowAlignment,
    super.actionsOverflowDirection,
    super.actionsOverflowButtonSpacing,
    super.buttonPadding,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.semanticLabel,
    super.insetPadding,
    super.clipBehavior,
    super.shape,
    super.alignment,
    super.constraints,
    super.scrollable,
  });

  @override
  Widget build(BuildContext context) {
    final original = super.build(context);
    if (!usesIOSGlass || original is! Dialog) return original;
    final effectiveShape =
        original.shape ?? Theme.of(context).dialogTheme.shape;
    final radius = effectiveShape is RoundedRectangleBorder
        ? effectiveShape.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(20);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetAnimationDuration: original.insetAnimationDuration,
      insetAnimationCurve: original.insetAnimationCurve,
      insetPadding: original.insetPadding,
      shape: effectiveShape,
      clipBehavior: original.clipBehavior,
      alignment: original.alignment,
      constraints: original.constraints,
      semanticsRole: original.semanticsRole,
      child: GlassSurface(
        radius: radius,
        tint: backgroundColor,
        opaque: true,
        shadow: false,
        blur: true,
        child: original.child ?? const SizedBox.shrink(),
      ),
    );
  }
}
