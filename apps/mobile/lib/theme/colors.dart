import 'package:flutter/material.dart';

class SwiftBeamColors {
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF161B22);
  static const Color primaryCyan = Color(0xFF00D9FF);
  static const Color accentPurple = Color(0xFF9B5CFF);
  static const Color successGreen = Color(0xFF00D77E);
  static const Color warningYellow = Color(0xFFFFC857);
  static const Color dangerRed = Color(0xFFFF5D73);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x30FFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient backgroundAmbientGradient = RadialGradient(
    center: Alignment(0, -0.5),
    radius: 1.2,
    colors: [Color(0x209B5CFF), Color(0x1500D9FF), Color(0xFF0F172A)],
    stops: [0.0, 0.4, 1.0],
  );
}
