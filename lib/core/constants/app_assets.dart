/// Paths to the supplied artwork.
///
/// The filenames come from the design hand-off and contain spaces, so they are
/// centralised here rather than typed at each call site -- a typo in an asset
/// path is a runtime failure, not a compile error.
abstract final class AppAssets {
  static const _icons = 'assets/icons';
  static const _logo = 'assets/logo';

  /// The folded-map wordmark glyph. 161x128.
  static const logo = '$_logo/Logo.png';

  // Bottom navigation.
  static const home = '$_icons/Home.svg';
  static const request = '$_icons/Add documents.svg';
  static const profile = '$_icons/Profile.svg';

  // App bar.
  static const menu = '$_icons/Menu.svg';
  static const bell = '$_icons/Basics.svg';

  // Stat cards. These two are SVG, so they render through flutter_svg.
  static const clipboard = '$_icons/Clipboard menu.svg';
  static const objects = '$_icons/Game objects.svg';
  static const users = '$_icons/user.svg';

  /// Green circle-and-tick for confirmation sheets. Unlike the other icons this
  /// carries its own colour (#60C554), so it must be rendered untinted.
  static const success = '$_icons/Success.svg';

  /// The trailing chevron on tappable rows. A 5x8 viewBox, not square -- use
  /// [AppChevron] rather than [AppIcon] so it is not stretched.
  static const chevron = '$_icons/Vector.svg';

  /// The dropdown arrow on select fields. A 9x5 viewBox -- wide and short,
  /// the opposite proportion to [chevron].
  static const chevronDown = '$_icons/Vector_down.svg';

  static bool isSvg(String path) => path.toLowerCase().endsWith('.svg');
}
