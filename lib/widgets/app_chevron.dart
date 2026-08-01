import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/constants/app_assets.dart';
import '../core/theme/app_colors.dart';

/// The supplied chevrons: "›" on tappable rows and "⌄" on select fields.
///
/// Not an [AppIcon]. That widget assumes a square glyph and sets width and
/// height to the same value; these two assets are markedly non-square (5x8 and
/// 9x5), so forcing them square would stretch them in opposite directions.
/// Here [size] is the meaningful dimension and the other follows from the
/// asset's own viewBox.
class AppChevron extends StatelessWidget {
  /// Trailing "›". [size] is the height.
  const AppChevron({super.key, this.size = 14, this.color = AppColors.gray30})
    : _asset = AppAssets.chevron,
      _aspectRatio = 5 / 8,
      _sizeIsHeight = true;

  /// Dropdown "⌄". [size] is the width.
  const AppChevron.down({
    super.key,
    this.size = 12,
    this.color = AppColors.label,
  }) : _asset = AppAssets.chevronDown,
       _aspectRatio = 5 / 9,
       _sizeIsHeight = false;

  final double size;
  final Color color;

  final String _asset;

  /// Ratio of the minor dimension to the major one, from the source viewBox.
  final double _aspectRatio;
  final bool _sizeIsHeight;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _asset,
      height: _sizeIsHeight ? size : size * _aspectRatio,
      width: _sizeIsHeight ? size * _aspectRatio : size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
