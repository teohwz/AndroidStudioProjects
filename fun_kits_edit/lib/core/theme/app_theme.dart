import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_palette.dart';

/// The app's two Material 3 themes (light + dark), switched automatically
/// via `ThemeMode.system` in `FunKitsApp`. Both are seeded from the same
/// brand colors so Flutter's tonal-palette algorithm keeps every built-in
/// [ColorScheme] role (primary/secondary/tertiary/surface/error, and their
/// "container"/"on" counterparts) harmonious and correctly contrasted in
/// each brightness — hand-picking 20+ individual role colors per mode is
/// exactly the kind of thing `ColorScheme.fromSeed` does more reliably.
///
/// Brand colors that fall outside those standard roles (success/warning/
/// gold/per-game colors) come from [AppPalette], registered as a
/// [ThemeExtension] on each theme so a migrated screen can read
/// `Theme.of(context).extension<AppPalette>()!` and get the right value
/// for whichever brightness is active.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Nunito';

  static ThemeData get light => _build(
        brightness: Brightness.light,
        palette: AppPalette.light,
        scaffoldBackground: AppColors.backgroundLight,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
        scaffoldBackground: AppColors.backgroundDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required Color scaffoldBackground,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.danger,
    );

    final textTheme = _textTheme(colorScheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [palette],

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.cardBg,
        selectedColor: colorScheme.primary,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle:
            textTheme.labelMedium?.copyWith(color: colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Buttons default to `secondary` (coral) — the "do something" action
      // color in this palette — while `primary` (brand purple) stays
      // reserved for structural chrome (app bar, nav active state). This
      // matches the reference design: a purple header/nav with a coral
      // call-to-action button, not a purple button.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          side: BorderSide(color: colorScheme.secondary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: palette.textMedium,
        type: BottomNavigationBarType.fixed,
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.4),
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textDark,
        contentTextStyle: TextStyle(color: colorScheme.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  /// Mirrors the same type scale `AppTextStyles` already established
  /// (display/heading/body/label, 36→11px) onto Material 3's named slots,
  /// deliberately leaving color unset so it inherits `onSurface` — the
  /// piece that makes text automatically legible in both themes once a
  /// screen is migrated to read from `Theme.of(context).textTheme`
  /// instead of the static, light-only `AppTextStyles`.
  static TextTheme _textTheme(Color onSurface) {
    TextStyle s(double size, FontWeight weight, {double? letterSpacing, double? height}) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: onSurface,
          letterSpacing: letterSpacing,
          height: height,
        );

    return TextTheme(
      displayLarge: s(36, FontWeight.w800, letterSpacing: -0.5),
      displayMedium: s(28, FontWeight.w800, letterSpacing: -0.3),
      displaySmall: s(22, FontWeight.w800),
      headlineLarge: s(20, FontWeight.w700),
      headlineMedium: s(18, FontWeight.w700),
      headlineSmall: s(16, FontWeight.w700),
      titleLarge: s(20, FontWeight.w700),
      titleMedium: s(16, FontWeight.w700),
      titleSmall: s(14, FontWeight.w700),
      bodyLarge: s(16, FontWeight.w400, height: 1.5),
      bodyMedium: s(14, FontWeight.w400, height: 1.5),
      bodySmall: s(12, FontWeight.w400, height: 1.4),
      labelLarge: s(14, FontWeight.w700, letterSpacing: 0.1),
      labelMedium: s(12, FontWeight.w700, letterSpacing: 0.2),
      labelSmall: s(11, FontWeight.w600, letterSpacing: 0.3),
    );
  }
}
