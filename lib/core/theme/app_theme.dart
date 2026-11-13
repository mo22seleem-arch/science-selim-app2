import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const midnight = Color(0xFF121C24);   // main background
  static const surface  = Color(0xFF1A232A);   // cards / fields
  static const cream    = Color(0xFFF0F4F8);   // text + borders
  static const muted    = Color(0xFF9FB0BF);
  static const accent   = Color(0xFF5BC0EB);
  static const error    = Color(0xFFFF6B6B);
}

ThemeData buildSpaceTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final text = GoogleFonts.cairoTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.cream, displayColor: AppColors.cream);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.midnight,
    textTheme: text,
    colorScheme: const ColorScheme.dark(
        primary: AppColors.accent, onPrimary: AppColors.midnight,
        surface: AppColors.surface, onSurface: AppColors.cream, error: AppColors.error),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true, fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.muted),
      enabledBorder: border(AppColors.cream.withValues(alpha: .25)),
      focusedBorder: border(AppColors.cream, 1.6),
      errorBorder: border(AppColors.error), focusedErrorBorder: border(AppColors.error, 1.6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cream, foregroundColor: AppColors.midnight,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16)),
    ),
    appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.midnight, foregroundColor: AppColors.cream, elevation: 0),
  );
}
