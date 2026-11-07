import 'package:flutter/material.dart';

ThemeData buildShopTheme() {
  const blue = Color(0xFF0879E8);
  const ink = Color(0xFF142B49);
  const line = Color(0xFFE4ECF5);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: blue,
        brightness: Brightness.light,
      ).copyWith(
        primary: blue,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
        secondary: const Color(0xFF0BA76D),
        primaryContainer: const Color(0xFFE9F3FF),
        onPrimaryContainer: const Color(0xFF075CB0),
        outline: const Color(0xFFCBD8E8),
        outlineVariant: line,
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: line),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'ShopSans',
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F9FD),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'ShopSans',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      iconTheme: IconThemeData(color: blue),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7FAFE),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: blue, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: const Color(0xFF6C839D),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'ShopSans',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: blue,
        side: const BorderSide(color: Color(0xFFC8E0FC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      height: 76,
      indicatorColor: const Color(0xFFE9F3FF),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'ShopSans',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? blue
              : const Color(0xFF718299),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? blue
              : const Color(0xFF718299),
          size: 24,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFE9F3FF),
      selectedIconTheme: IconThemeData(color: blue),
      selectedLabelTextStyle: TextStyle(
        fontFamily: 'ShopSans',
        color: blue,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: Color(0xFF718299)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE9F3FF),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
