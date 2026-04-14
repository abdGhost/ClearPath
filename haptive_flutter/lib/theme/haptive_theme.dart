import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Haptive visual tokens — Ultimate Dark + Bento surfaces.
abstract final class HaptiveColors {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0F0F0F);
  static const Color border = Color(0xFF1C1C1E);
  static const Color clean = Color(0xFFD4FF00);
  static const Color progress = Color(0xFF007AFF);
  static const Color label = Color(0xFF8E8E93);
  static const Color glassHighlight = Color(0x14FFFFFF);
}

ThemeData buildHaptiveTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: HaptiveColors.background,
    splashFactory: InkSplash.splashFactory,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        fontSize: 48,
        height: 1.05,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        fontSize: 12,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        fontSize: 12,
        color: HaptiveColors.label,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: HaptiveColors.clean,
      secondary: HaptiveColors.progress,
      surface: HaptiveColors.surface,
      onSurface: Colors.white,
      outline: HaptiveColors.border,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HaptiveColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0x1FD4FF00),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: selected ? 23 : 22,
          color: selected ? HaptiveColors.clean : HaptiveColors.label,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? HaptiveColors.clean : HaptiveColors.label,
          letterSpacing: 0.15,
        );
      }),
    ),
  );
}
