import 'package:flutter/material.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/core/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.warriorNavy,
      brightness: Brightness.light,
    ).copyWith(
      tertiary: AppColors.growthLime,
      onTertiary: AppColors.textStrong,
      tertiaryContainer: const Color(0xFFE8FFC9),
      onTertiaryContainer: AppColors.textStrong,
    );

    final TextTheme textTheme = AppTypography.textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scholarCream,
      textTheme: textTheme.apply(
        bodyColor: AppColors.textStrong,
        displayColor: AppColors.warriorNavy,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.warriorNavy,
        foregroundColor: AppColors.scholarCream,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.heading(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.scholarCream,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.warriorNavy.withAlpha(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.warriorNavy.withAlpha(30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.levelUpTeal,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.warriorNavy,
          foregroundColor: Colors.white,
          textStyle: AppTypography.body(fontWeight: FontWeight.w700),
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.warriorNavy,
          textStyle: AppTypography.body(fontWeight: FontWeight.w700),
          minimumSize: const Size(44, 48),
          side: BorderSide(color: AppColors.warriorNavy.withAlpha(80)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.warriorNavy,
          textStyle: AppTypography.body(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.growthLime,
        foregroundColor: AppColors.textStrong,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.growthLime,
        linearTrackColor: AppColors.warriorNavy.withAlpha(18),
        circularTrackColor: AppColors.warriorNavy.withAlpha(18),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.growthLime
              : null;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.textStrong),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.growthLime
              : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.warriorNavy
              : null;
        }),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.growthLime.withAlpha(72),
        checkmarkColor: AppColors.warriorNavy,
        side: BorderSide(color: AppColors.warriorNavy.withAlpha(28)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.levelUpTeal,
        selectionColor: AppColors.growthLime.withAlpha(92),
        selectionHandleColor: AppColors.levelUpTeal,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: AppTypography.heading(
          color: AppColors.textStrong,
          fontSize: 20,
        ),
        contentTextStyle: AppTypography.body(
          color: AppColors.textMuted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textStrong,
        contentTextStyle: AppTypography.body(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.warriorNavy.withAlpha(24),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.warriorNavy,
      brightness: Brightness.dark,
    ).copyWith(
      tertiary: AppColors.growthLime,
      onTertiary: AppColors.textStrong,
      tertiaryContainer: const Color(0xFF31502B),
      onTertiaryContainer: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: AppTypography.textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.heading(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.growthLime,
        foregroundColor: AppColors.textStrong,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.growthLime,
        linearTrackColor: Colors.white.withAlpha(24),
        circularTrackColor: Colors.white.withAlpha(24),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.growthLime,
        selectionColor: AppColors.growthLime.withAlpha(72),
        selectionHandleColor: AppColors.growthLime,
      ),
    );
  }
}
