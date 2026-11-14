import 'package:flutter/material.dart';

class AppColors {
  // Brand Greens
  static const Color primary = Color(0xFF0D631B);
  static const Color primaryContainer = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFF006E1C);
  static const Color secondaryContainer = Color(0xFF98F994);
  static const Color primaryFixed = Color(0xFFA3F69C);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFFCBFFC2);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF9F9FF);
  static const Color surface = Color(0xFFF9F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F3FF);
  static const Color surfaceContainer = Color(0xFFE8EEFF);
  static const Color surfaceContainerHigh = Color(0xFFE3E8F9);
  static const Color surfaceContainerHighest = Color(0xFFDDE2F3);

  // Text & Content
  static const Color onSurface = Color(0xFF161C27);
  static const Color onSurfaceVariant = Color(0xFF40493D);
  static const Color outline = Color(0xFF707A6C);
  static const Color outlineVariant = Color(0xFFBFCABA);

  // States
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF006E1C),
      Color(0xFF2E7D32),
    ],
  );
}
