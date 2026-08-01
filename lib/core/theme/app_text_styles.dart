import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography for Listy App.
///
/// The Figma file declares "Cairo" as its text style family
/// (Small Regular Text -> Cairo SemiBold 14 / 20).
abstract final class AppTextStyles {
  static TextStyle _cairo({
    required double size,
    required FontWeight weight,
    double? height,
    Color color = AppColors.label,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.cairo(
      fontSize: size,
      fontWeight: weight,
      height: height == null ? null : height / size,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Splash wordmark - "Listy App".
  static TextStyle get wordmark =>
      _cairo(size: 30, weight: FontWeight.w800, height: 42);

  /// Screen title in the centre of the app bar.
  static TextStyle get appBarTitle =>
      _cairo(size: 16, weight: FontWeight.w600, height: 22);

  /// Large heading, e.g. "Sign in".
  static TextStyle get heading =>
      _cairo(size: 24, weight: FontWeight.w700, height: 34);

  /// Body copy under a heading.
  static TextStyle get body =>
      _cairo(size: 14, weight: FontWeight.w400, height: 22, color: AppColors.gray40);

  /// Standard row / list label.
  static TextStyle get rowLabel =>
      _cairo(size: 15, weight: FontWeight.w500, height: 20);

  /// Emphasised row label, e.g. item names in the Item Lists screen.
  static TextStyle get rowLabelBold =>
      _cairo(size: 15, weight: FontWeight.w700, height: 20);

  /// Field label above an input, e.g. "List Name".
  static TextStyle get fieldLabel =>
      _cairo(size: 14, weight: FontWeight.w600, height: 20);

  /// Input text.
  static TextStyle get input =>
      _cairo(size: 15, weight: FontWeight.w400, height: 20);

  /// Placeholder inside an input.
  static TextStyle get hint =>
      _cairo(size: 15, weight: FontWeight.w400, height: 20, color: AppColors.gray30);

  /// Filled button label.
  static TextStyle get button =>
      _cairo(size: 15, weight: FontWeight.w600, height: 20, color: AppColors.white);

  /// Stat card caption, e.g. "Number of Lists".
  static TextStyle get cardCaption =>
      _cairo(size: 13, weight: FontWeight.w500, height: 18);

  /// Stat card value, e.g. "34".
  static TextStyle get cardValue =>
      _cairo(size: 28, weight: FontWeight.w700, height: 36);

  /// Bottom navigation label.
  static TextStyle get navLabel =>
      _cairo(size: 11, weight: FontWeight.w500, height: 14);

  /// Uppercase section header in the drawer, e.g. "SETTINGS".
  static TextStyle get sectionHeader => _cairo(
        size: 12,
        weight: FontWeight.w600,
        height: 16,
        color: AppColors.gray30,
        letterSpacing: 1.0,
      );

  /// Drawer menu row.
  static TextStyle get drawerItem =>
      _cairo(size: 15, weight: FontWeight.w600, height: 20);

  /// Name in the drawer profile header.
  static TextStyle get profileName =>
      _cairo(size: 15, weight: FontWeight.w700, height: 20);

  /// Phone / email under the profile name.
  static TextStyle get profileMeta =>
      _cairo(size: 12, weight: FontWeight.w400, height: 16, color: AppColors.gray40);

  /// "Invite" link in the Select user sheet.
  static TextStyle get link => _cairo(
        size: 14,
        weight: FontWeight.w500,
        height: 20,
        color: AppColors.link,
      );
}
