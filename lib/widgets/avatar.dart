import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Circular avatar with a graceful fallback chain:
/// photo bytes -> network URL -> initials -> plain grey disc.
///
/// The grey disc is what the Figma "Select user" rows show, so an entry with no
/// name and no photo still matches the design.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.photo,
    this.photoUrl,
    this.initials,
    this.size = 32,
  });

  final Uint8List? photo;
  final String? photoUrl;
  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (photo != null && photo!.isNotEmpty) {
      content = Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      content = Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialsOrBlank(),
      );
    } else {
      content = _initialsOrBlank();
    }

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.gray20,
        child: content,
      ),
    );
  }

  Widget _initialsOrBlank() {
    if (initials == null || initials!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Text(
        initials!,
        style: AppTextStyles.rowLabel.copyWith(
          fontSize: size * 0.36,
          color: AppColors.label,
        ),
      ),
    );
  }
}
