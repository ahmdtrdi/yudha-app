import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final TextTheme materialTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final TextTheme bodyTextTheme = GoogleFonts.dmSansTextTheme(
      materialTextTheme,
    );
    final TextTheme headingTextTheme = GoogleFonts.fredokaTextTheme(
      materialTextTheme,
    );

    return bodyTextTheme.copyWith(
      displayLarge: _heading(headingTextTheme.displayLarge),
      displayMedium: _heading(headingTextTheme.displayMedium),
      displaySmall: _heading(headingTextTheme.displaySmall),
      headlineLarge: _heading(headingTextTheme.headlineLarge),
      headlineMedium: _heading(headingTextTheme.headlineMedium),
      headlineSmall: _heading(headingTextTheme.headlineSmall),
      titleLarge: _heading(headingTextTheme.titleLarge),
      labelLarge: bodyTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }

  static TextStyle heading({
    Color? color,
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
  }) {
    return GoogleFonts.fredoka(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextStyle body({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
  }) {
    return GoogleFonts.dmSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextStyle metric({
    Color? color,
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextStyle? _heading(TextStyle? style) {
    return style?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0);
  }
}
