import 'package:flutter/material.dart';

/// Brand/semantic/game colors that aren't part of Flutter's standard
/// [ColorScheme] roles (success, warning, gold/prize accent, per-game
/// colors, card tint) — bundled as a [ThemeExtension] so a screen that has
/// been migrated to the new design system can pull the *correct* value for
/// the current light/dark theme via:
///
/// ```dart
/// final palette = Theme.of(context).extension<AppPalette>()!;
/// palette.success
/// ```
///
/// instead of the static, light-only `AppColors.success`. [AppColors]
/// remains the source of truth for the light ("Carnival": purple/coral/
/// gold/teal/ink) values so the two never drift apart; this class adds the
/// dark-mode counterparts and wires both into `AppTheme.light`/`.dark`.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.warning,
    required this.danger,
    required this.gold,
    required this.cardBg,
    required this.textDark,
    required this.textMedium,
    required this.quizColor,
    required this.puzzleColor,
    required this.luckyDrawColor,
    required this.exhibitorColor,
    required this.spinWheelColor,
    required this.scratchCardColor,
    required this.guessNumberColor,
    required this.goldGradient,
    required this.primaryGradient,
    required this.secondaryGradient,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color gold;
  final Color cardBg;
  final Color textDark;
  final Color textMedium;
  final Color quizColor;
  final Color puzzleColor;
  final Color luckyDrawColor;
  final Color exhibitorColor;
  final Color spinWheelColor;
  final Color scratchCardColor;
  final Color guessNumberColor;
  final LinearGradient goldGradient;
  final LinearGradient primaryGradient;
  final LinearGradient secondaryGradient;

  static const light = AppPalette(
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF5A623),
    danger: Color(0xFFE6484F),
    gold: Color(0xFFF2B134),
    cardBg: Color(0xFFECE9F7),
    textDark: Color(0xFF1C1B2E),
    textMedium: Color(0xFF6B6478),
    quizColor: Color(0xFF5E52A6),
    puzzleColor: Color(0xFF1D9E75),
    luckyDrawColor: Color(0xFFD85A30),
    exhibitorColor: Color(0xFF1D9E75),
    spinWheelColor: Color(0xFF5E52A6),
    scratchCardColor: Color(0xFFF2B134),
    guessNumberColor: Color(0xFF4D7CFF),
    goldGradient: LinearGradient(
      colors: [Color(0xFFF2B134), Color(0xFFF5C158)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF5E52A6), Color(0xFF6C60B8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    secondaryGradient: LinearGradient(
      colors: [Color(0xFFD85A30), Color(0xFFE0703F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const dark = AppPalette(
    success: Color(0xFF3DDC84),
    warning: Color(0xFFFFBB5C),
    danger: Color(0xFFFF6B72),
    gold: Color(0xFFFFCB61),
    cardBg: Color(0xFF272443),
    textDark: Color(0xFFF3F1FA),
    textMedium: Color(0xFFB6AFC7),
    quizColor: Color(0xFF9086D6),
    puzzleColor: Color(0xFF3DDCB4),
    luckyDrawColor: Color(0xFFFF8B5C),
    exhibitorColor: Color(0xFF3DDCB4),
    spinWheelColor: Color(0xFF9086D6),
    scratchCardColor: Color(0xFFFFCB61),
    guessNumberColor: Color(0xFF7C9CFF),
    goldGradient: LinearGradient(
      colors: [Color(0xFFFFCB61), Color(0xFFFFB25C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF9086D6), Color(0xFFA79CE0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    secondaryGradient: LinearGradient(
      colors: [Color(0xFFFF8B5C), Color(0xFFFFA476)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  @override
  AppPalette copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? gold,
    Color? cardBg,
    Color? textDark,
    Color? textMedium,
    Color? quizColor,
    Color? puzzleColor,
    Color? luckyDrawColor,
    Color? exhibitorColor,
    Color? spinWheelColor,
    Color? scratchCardColor,
    Color? guessNumberColor,
    LinearGradient? goldGradient,
    LinearGradient? primaryGradient,
    LinearGradient? secondaryGradient,
  }) {
    return AppPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      gold: gold ?? this.gold,
      cardBg: cardBg ?? this.cardBg,
      textDark: textDark ?? this.textDark,
      textMedium: textMedium ?? this.textMedium,
      quizColor: quizColor ?? this.quizColor,
      puzzleColor: puzzleColor ?? this.puzzleColor,
      luckyDrawColor: luckyDrawColor ?? this.luckyDrawColor,
      exhibitorColor: exhibitorColor ?? this.exhibitorColor,
      spinWheelColor: spinWheelColor ?? this.spinWheelColor,
      scratchCardColor: scratchCardColor ?? this.scratchCardColor,
      guessNumberColor: guessNumberColor ?? this.guessNumberColor,
      goldGradient: goldGradient ?? this.goldGradient,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      secondaryGradient: secondaryGradient ?? this.secondaryGradient,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      textDark: Color.lerp(textDark, other.textDark, t)!,
      textMedium: Color.lerp(textMedium, other.textMedium, t)!,
      quizColor: Color.lerp(quizColor, other.quizColor, t)!,
      puzzleColor: Color.lerp(puzzleColor, other.puzzleColor, t)!,
      luckyDrawColor: Color.lerp(luckyDrawColor, other.luckyDrawColor, t)!,
      exhibitorColor: Color.lerp(exhibitorColor, other.exhibitorColor, t)!,
      spinWheelColor: Color.lerp(spinWheelColor, other.spinWheelColor, t)!,
      scratchCardColor:
          Color.lerp(scratchCardColor, other.scratchCardColor, t)!,
      guessNumberColor:
          Color.lerp(guessNumberColor, other.guessNumberColor, t)!,
      goldGradient: LinearGradient.lerp(goldGradient, other.goldGradient, t)!,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      secondaryGradient:
          LinearGradient.lerp(secondaryGradient, other.secondaryGradient, t)!,
    );
  }
}
