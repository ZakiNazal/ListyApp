import 'package:flutter/material.dart';

/// Colour tokens extracted directly from the Listy App Figma file.
///
/// Figma variable name -> constant:
///   Static                -> primary
///   Gray 100 / Label      -> label
///   Gray 40               -> gray40
///   Gray 30               -> gray30
///   Gray 20               -> gray20
///   Gray 5                -> gray5
///   Tab Bar Selection     -> link
abstract final class AppColors {
  /// Primary accent. Used for the login buttons and the active bottom-nav tab.
  /// Per the design review this also replaces the green active state that
  /// appeared in the "Design 23" drawer frame, so the accent is consistent.
  static const Color primary = Color(0xFFEE492E);

  /// Primary text colour (Figma "Gray 100" / "Label").
  static const Color label = Color(0xFF12131A);

  /// Secondary / muted text.
  static const Color gray40 = Color(0xFF9A9EB2);

  /// Disabled text and icons.
  static const Color gray30 = Color(0xFFBABDCC);

  /// Borders and dividers.
  static const Color gray20 = Color(0xFFD8DAE5);

  /// Section header / subtle row background.
  static const Color gray5 = Color(0xFFF3F3F7);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// Link colour used by the "Invite" action in the Select user sheet.
  static const Color link = Color(0xFF0088FF);

  /// Success tick on the confirmation sheet.
  static const Color success = Color(0xFF34C759);

  /// Scrim behind the floating drawer and modal sheets.
  static const Color scrim = Color(0x66000000);

  /// Disabled button fill (the greyed-out "Send" button).
  static const Color disabled = Color(0xFF979797);

  /// Error color for denied lists or missing items
  static const Color error = Color(0xFFFF3B30);
}
