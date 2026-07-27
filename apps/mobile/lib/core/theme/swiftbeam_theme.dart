import 'package:flutter/material.dart';

class SwiftBeamTheme {
  // Color Tokens
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF161B22);
  static const Color primaryCyan = Color(0xFF00D9FF);
  static const Color secondaryIndigo = Color(0xFF6D5DF6);
  static const Color accentPurple = Color(0xFF9B5CFF);
  static const Color successGreen = Color(0xFF00D97E);
  static const Color warningYellow = Color(0xFFFFC857);
  static const Color dangerRed = Color(0xFFFF5D73);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSlate,
      colorScheme: const ColorScheme.dark(
        surface: surfaceDark,
        primary: primaryCyan,
        secondary: secondaryIndigo,
        tertiary: accentPurple,
        error: dangerRed,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'sans-serif',
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: 'sans-serif',
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontFamily: 'sans-serif',
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
          fontFamily: 'sans-serif',
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark.withValues(alpha: 0.7),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: darkSlate,
          minimumSize: const Size.fromHeight(64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'sans-serif',
          ),
        ),
      ),
    );
  }
}
