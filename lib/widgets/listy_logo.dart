import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';

/// The Listy App mark: the supplied folded-map artwork.
///
/// This previously drew the glyph with a CustomPainter, approximating the
/// shapes from the Figma frame. Now that the real asset exists it is used
/// directly -- the [size] is the width, and the 161x128 aspect ratio of the
/// source is preserved.
class ListyLogo extends StatelessWidget {
  const ListyLogo({super.key, this.size = 128});

  /// Rendered width in logical pixels.
  final double size;

  static const double _aspectRatio = 128 / 161;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      width: size,
      height: size * _aspectRatio,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          SizedBox(width: size, height: size * _aspectRatio),
    );
  }
}
