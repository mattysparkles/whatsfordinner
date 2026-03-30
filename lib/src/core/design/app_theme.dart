import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    final seed = Colors.deepOrange;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      chipTheme: const ChipThemeData(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    );
  }

  static ThemeData dark() {
    final seed = Colors.deepOrange;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    );
  }
}
