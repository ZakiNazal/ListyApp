import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  /// Corner radius token from Figma (`radius/radius-md`).
  static const double radiusMd = 8;

  /// Spacing token from Figma (`spacing/spacing-sm`).
  static const double spacingSm = 12;

  /// Horizontal page gutter used across the screens.
  static const double gutter = 20;

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.white,
      primaryColor: AppColors.primary,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.label,
        error: AppColors.primary,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(
        bodyColor: AppColors.label,
        displayColor: AppColors.label,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.gray20,
        thickness: 1,
        space: 1,
      ),
      // NOTE: Flutter renamed these theme classes to the `...ThemeData` suffix
      // (AppBarTheme -> AppBarThemeData, InputDecorationTheme ->
      // InputDecorationThemeData) in 3.32. If you ever build this on an older
      // SDK, drop the `Data` suffix on the two below.
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.label,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.appBarTitle,
        iconTheme: const IconThemeData(color: AppColors.label, size: 24),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: AppTextStyles.hint,
        // Firebase auth errors are long sentences; the default single line
        // truncates them to uselessness.
        errorMaxLines: 4,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _outline(AppColors.gray20),
        enabledBorder: _outline(AppColors.gray20),
        focusedBorder: _outline(AppColors.label),
        errorBorder: _outline(AppColors.primary),
        focusedErrorBorder: _outline(AppColors.primary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static OutlineInputBorder _outline(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: color),
      );
}
