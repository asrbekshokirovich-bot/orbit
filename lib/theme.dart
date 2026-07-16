import 'package:flutter/material.dart';

class OrbitColors {
  static const bg = Color(0xFF071426);
  static const surface = Color(0xFF0E2036);
  static const surface2 = Color(0xFF13273F);
  static const coral = Color(0xFFFF7A5C);
  static const violet = Color(0xFFA78BFA);
  static const cyan = Color(0xFF38E0F8);
  static const green = Color(0xFF4ADE80);
  static const amber = Color(0xFFFBBF24);
  static const textDim = Color(0xFF8FA6C0);
}

ThemeData orbitTheme() {
  const scheme = ColorScheme.dark(
    primary: OrbitColors.cyan,
    secondary: OrbitColors.violet,
    surface: OrbitColors.surface,
    error: OrbitColors.coral,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: OrbitColors.bg,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: OrbitColors.bg,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: OrbitColors.surface,
      indicatorColor: OrbitColors.cyan.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OrbitColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
