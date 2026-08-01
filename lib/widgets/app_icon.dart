import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/constants/app_assets.dart';
import '../core/theme/app_colors.dart';

/// Renders one of the supplied icons, PNG or SVG, tinted to [color].
///
/// The assets are monochrome glyphs, so a colour filter is enough to drive
/// active/inactive states -- there is no separate "selected" artwork to swap in.
/// Picking PNG vs SVG by extension keeps call sites from caring which is which.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color = AppColors.label,
  });

  /// Renders the asset in its own colours instead of tinting it.
  ///
  /// Needed for artwork that is not a monochrome glyph -- Success.svg is a
  /// green circle and tick, and flattening it through a colour filter would
  /// throw that away.
  const AppIcon.original(this.asset, {super.key, this.size = 24})
    : color = null;

  final String asset;
  final double size;

  /// Null means "leave the asset's own colours alone".
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (AppAssets.isSvg(asset)) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
      );
    }

    return Image.asset(
      asset,
      width: size,
      height: size,
      color: color,
      // The supplied PNGs are a single 24x24 resolution with no @2x/@3x
      // variants, so they are upscaled on high-density screens. Filtering
      // softens the resulting stair-stepping.
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          Icon(Icons.broken_image_outlined, size: size, color: color),
    );
  }
}
