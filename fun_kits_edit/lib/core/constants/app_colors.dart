import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF6C63FF);       // Vibrant Purple
  static const Color secondary = Color(0xFFFF6584);     // Coral Pink
  static const Color accent = Color(0xFFFFD700);        // Gold (for prizes/wins)
  static const Color success = Color(0xFF43D787);       // Green
  static const Color warning = Color(0xFFFF9F43);       // Orange
  static const Color danger = Color(0xFFFF6B6B);        // Red

  // Neutrals
  static const Color backgroundLight = Color(0xFFF8F7FF);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFF0EFFF);
  static const Color textDark = Color(0xFF2D2D3A);
  static const Color textMedium = Color(0xFF6B6B80);
  static const Color textLight = Color(0xFFFFFFFF);

  // Game-specific
  static const Color quizColor = Color(0xFF4ECDC4);
  static const Color puzzleColor = Color(0xFFFF9F43);
  static const Color luckyDrawColor = Color(0xFF6C63FF);
  static const Color leaderboardColor = Color(0xFFFFD700);
  static const Color exhibitorColor = Color(0xFF43D787);
  static const Color spinWheelColor = Color(0xFFFF6B9D);
  static const Color scratchCardColor = Color(0xFFFFB84D);
  static const Color guessNumberColor = Color(0xFF5C6BC0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8B80FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFFF6584), Color(0xFFFF8EA3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
