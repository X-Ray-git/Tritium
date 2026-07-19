import 'package:flutter/material.dart';

/// Tritium 的固定品牌色。
///
/// 品牌基色保持为 RGB(57, 97, 255)，明暗主题中的其他色阶只用于保证
/// 可读性和层级，不改变产品的品牌归属。
abstract final class TritiumColors {
  static const brand = Color(0xFF3961FF);

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDDE2FF),
    onPrimaryContainer: Color(0xFF001453),
    secondary: Color(0xFF4E5D92),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFDDE2FF),
    onSecondaryContainer: Color(0xFF0A1A4B),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFAFAFC),
    onSurface: Color(0xFF1A1B20),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF5F5F8),
    surfaceContainer: Color(0xFFEFEFF4),
    surfaceContainerHigh: Color(0xFFE8E8EE),
    surfaceContainerHighest: Color(0xFFE1E1E8),
    onSurfaceVariant: Color(0xFF5F6069),
    outline: Color(0xFF8E8F99),
    outlineVariant: Color(0xFFD9D9E2),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF2F3036),
    onInverseSurface: Color(0xFFF1F0F7),
    inversePrimary: Color(0xFFB9C3FF),
  );

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: brand,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF173CCB),
    onPrimaryContainer: Color(0xFFDDE2FF),
    secondary: Color(0xFFBEC6FF),
    onSecondary: Color(0xFF202D61),
    secondaryContainer: Color(0xFF374477),
    onSecondaryContainer: Color(0xFFDDE2FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF191A1E),
    onSurface: Color(0xFFE4E2E9),
    surfaceContainerLowest: Color(0xFF111216),
    surfaceContainerLow: Color(0xFF202126),
    surfaceContainer: Color(0xFF25262B),
    surfaceContainerHigh: Color(0xFF303137),
    surfaceContainerHighest: Color(0xFF3B3C43),
    onSurfaceVariant: Color(0xFFC6C5CF),
    outline: Color(0xFF90909A),
    outlineVariant: Color(0xFF45464F),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE4E2E9),
    onInverseSurface: Color(0xFF2F3036),
    inversePrimary: TritiumColors.brand,
  );
}

abstract final class ThemeUtils {
  static ThemeData light() => _theme(TritiumColors.lightScheme);

  static ThemeData dark() => _theme(TritiumColors.darkScheme);

  static ThemeData _theme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 48,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.34),
            width: 0.8,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        thickness: 0.5,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
