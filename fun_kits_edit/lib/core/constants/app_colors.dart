import 'package:flutter/material.dart';

/// The app's default (light) color palette. This is the "legacy" static
/// palette most screens still reference directly as `AppColors.xxx` — as
/// part of the phased UI redesign, screens are migrated one area at a time
/// to instead pull colors from `Theme.of(context)` (see
/// `lib/core/theme/app_theme.dart` and `AppPalette`), which is what makes
/// dark mode actually correct for that screen. Until a screen is migrated,
/// it keeps rendering with these light values regardless of system theme —
/// an expected, temporary state during the rollout, not a bug.
///
/// Palette: "Carnival" — anchored on the FunKits app icon's own purple
/// (`#5E52A6`) rather than an unrelated new hue, with a coral action color,
/// a gold prize/points accent, a teal secondary accent, and a near-black
/// "ink" used for dark surfaces/headers. `primary` (purple) is the brand/
/// structural color (app bars, nav active state, general brand tint);
/// `secondary` (coral) is the "do something" action color used by buttons.
class AppColors {
  // ── Brand Colors ───────────────────────────────────────────────────────
  static const Color primary = Color(0xFF5E52A6); // Brand Purple (app icon)
  static const Color secondary = Color(0xFFD85A30); // Coral (CTA/action)
  static const Color accent = Color(0xFFF2B134); // Gold (prizes/points)
  static const Color tertiary = Color(0xFF1D9E75); // Teal (secondary accent)
  static const Color success = Color(0xFF2ECC71); // Green
  static const Color warning = Color(0xFFF5A623); // Amber
  static const Color danger = Color(0xFFE6484F); // Red

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF4F3F8); // "Canvas"
  static const Color backgroundDark = Color(0xFF1C1B2E); // "Ink"
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFECE9F7); // light lavender container
  static const Color textDark = Color(0xFF1C1B2E); // "Ink" reused for text
  static const Color textMedium = Color(0xFF6B6478);
  static const Color textLight = Color(0xFFFFFFFF);

  // ── Game-specific ──────────────────────────────────────────────────────
  static const Color quizColor = Color(0xFF5E52A6);
  static const Color puzzleColor = Color(0xFF1D9E75);
  static const Color luckyDrawColor = Color(0xFFD85A30);
  static const Color leaderboardColor = Color(0xFFF2B134);
  static const Color exhibitorColor = Color(0xFF1D9E75);
  static const Color spinWheelColor = Color(0xFF5E52A6);
  static const Color scratchCardColor = Color(0xFFF2B134);
  static const Color guessNumberColor = Color(0xFF4D7CFF);

  // ── "Gradients" ────────────────────────────────────────────────────────
  // Kept as LinearGradient (not a flat Color) purely so FunButton and any
  // screen still passing `gradient:` keeps compiling with zero API changes
  // — the reference mockups use flat, solid fills everywhere, so each of
  // these is now a near-imperceptible two-stop gradient (a hint of depth)
  // rather than the previous bold two-hue diagonal sweep.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5E52A6), Color(0xFF6C60B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFD85A30), Color(0xFFE0703F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF2B134), Color(0xFFF5C158)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
