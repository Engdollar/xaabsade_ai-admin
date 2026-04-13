import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme({required Brightness brightness}) {
  const brandNavy = Color(0xFF0E1D2C);
  const brandTeal = Color(0xFF0E6B67);
  const brandGold = Color(0xFFF2C879);
  const lightSurfaceTint = Color(0xFFF5F1E9);
  const lightBackground = Color(0xFFF7F3ED);
  const darkSurface = Color(0xFF101823);
  const darkSurfaceTint = Color(0xFF0D1B28);
  const darkInput = Color(0xFF1A2634);
  const darkCard = Color(0xFF16202B);

  final isDark = brightness == Brightness.dark;
  final surfaceTint = isDark ? darkSurfaceTint : lightSurfaceTint;
  final scaffoldBackground = isDark ? darkSurface : lightBackground;
  final onSurface = isDark ? Colors.white : brandNavy;
  final appBarForeground = isDark ? Colors.white : brandNavy;
  final inputFill = isDark ? darkInput : Colors.white.withOpacity(0.85);
  final cardColor = isDark ? darkCard : Colors.white.withOpacity(0.9);

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: brandTeal,
        brightness: brightness,
      ).copyWith(
        primary: brandTeal,
        secondary: brandGold,
        surface: surfaceTint,
        onPrimary: Colors.white,
        onSecondary: brandNavy,
        onSurface: onSurface,
      );

  final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    textTheme: baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: appBarForeground,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      labelStyle: TextStyle(color: onSurface.withOpacity(0.8)),
      hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
      floatingLabelStyle: TextStyle(color: onSurface.withOpacity(0.9)),
      prefixIconColor: onSurface.withOpacity(0.8),
      suffixIconColor: onSurface.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandTeal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    useMaterial3: true,
  );
}
