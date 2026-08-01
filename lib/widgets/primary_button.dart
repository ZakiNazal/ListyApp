import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// The filled action button used on the language, login, OTP and Request
/// screens. Renders grey when [onPressed] is null, matching the disabled
/// "Send" button in the Figma Request frame.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: enabled ? AppColors.primary : AppColors.disabled,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Text(label, style: AppTextStyles.button),
          ),
        ),
      ),
    );
  }
}

/// The outlined "Cancel" button on the confirmation sheet.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.gray20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          foregroundColor: AppColors.label,
        ),
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(color: AppColors.label),
        ),
      ),
    );
  }
}
