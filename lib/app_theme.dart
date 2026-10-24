import 'package:flutter/material.dart';

/// Shared, restrained surfaces keep the workshop readable in both themes.
ThemeData romFlowTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xff111821) : const Color(0xfff6f7f9);
  final surface = dark ? const Color(0xff192330) : Colors.white;
  final field = dark ? const Color(0xff151e2a) : const Color(0xfff8fafc);
  final text = dark ? const Color(0xffe7edf5) : const Color(0xff1c293b);
  final muted = dark ? const Color(0xffa6b4c6) : const Color(0xff627187);
  final border = dark ? const Color(0xff2d3a4b) : const Color(0xffe3e8ef);
  final accent = dark ? const Color(0xff91c5ff) : const Color(0xff206bc4);
  final selected = dark ? const Color(0xff223a55) : const Color(0xffeaf2fc);
  const blue = Color(0xff206bc4);
  final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: brightness)
      .copyWith(
          primary: accent,
          onPrimary: dark ? const Color(0xff102e50) : Colors.white,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: muted,
          surfaceContainerHighest: field,
          primaryContainer: selected,
          onPrimaryContainer: accent,
          secondaryContainer: selected,
          onSecondaryContainer: accent,
          outline: border,
          outlineVariant: border);
  final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: border, width: .8));
  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final input = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: border));
  final base = ThemeData(
      useMaterial3: true, brightness: brightness, colorScheme: scheme);
  final typography = base.textTheme
      .apply(bodyColor: text, displayColor: text)
      .copyWith(
          titleLarge:
              TextStyle(
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: text),
          titleMedium: TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: text),
          bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: text),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: text),
          bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
          labelLarge: const TextStyle(
              fontSize: 14, height: 1.2, fontWeight: FontWeight.w600));
  final button = FilledButton.styleFrom(
      backgroundColor: dark ? const Color(0xff2873c7) : blue,
      foregroundColor: Colors.white,
      disabledBackgroundColor:
          dark ? const Color(0xff283648) : const Color(0xffe4e9f0),
      disabledForegroundColor: muted,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: buttonShape,
      textStyle: typography.labelLarge);
  return base.copyWith(
    textTheme: typography,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.titleLarge),
    cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 12),
        shape: cardShape),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        hintStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted, fontSize: 12),
        border: input,
        enabledBorder: input,
        focusedBorder:
            input.copyWith(borderSide: BorderSide(color: accent, width: 1.5)),
        errorBorder:
            input.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: input.copyWith(
            borderSide: BorderSide(color: scheme.error, width: 1.5))),
    filledButtonTheme: FilledButtonThemeData(style: button),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(elevation: const WidgetStatePropertyAll(0))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(48, 48),
            shape: buttonShape,
            side: BorderSide(color: border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            textStyle: typography.labelLarge)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(48, 48),
            shape: buttonShape,
            textStyle: typography.labelLarge)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: buttonShape),
    chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: selected,
        disabledColor: field,
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: text, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: accent),
        checkmarkColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: selected,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? accent : muted)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : muted,
            size: 23))),
    dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
    dividerTheme: DividerThemeData(color: border, space: 24, thickness: .8),
    listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
        iconColor: muted,
        textColor: text,
        titleTextStyle: typography.titleMedium,
        subtitleTextStyle: typography.bodySmall),
    expansionTileTheme: ExpansionTileThemeData(
        iconColor: accent,
        collapsedIconColor: muted,
        textColor: text,
        collapsedTextColor: text,
        childrenPadding: const EdgeInsets.fromLTRB(4, 8, 4, 12)),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    iconTheme: IconThemeData(color: muted, size: 22),
    sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: border),
  );
}
