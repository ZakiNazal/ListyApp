import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'primary_button.dart';

/// Figma frame "20. تم ارسال الطلب بنجاح..." -- the confirmation sheet, with
/// its Arabic copy translated to English.
///
/// Shown after both of the app's send actions: dispatching a list, and firing
/// off an invite. The copy differs, the treatment does not.
Future<void> showSuccessSheet(
  BuildContext context, {
  String title = AppStrings.requestSentTitle,
  String body = AppStrings.requestSentBody,
}) {
  return showModalBottomSheet<void>(
    context: context,
    barrierColor: AppColors.scrim,
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _SuccessSheet(title: title, body: body),
  );
}

/// Confirmation after a list has been created and delivered.
Future<void> showListSentSheet(BuildContext context, String recipient) {
  return showSuccessSheet(
    context,
    title: AppStrings.listSentTitle,
    body: AppStrings.listSentBody(recipient),
  );
}

/// Confirmation after an invite has been handed to the messaging app.
Future<void> showInviteSentSheet(BuildContext context, String name) {
  return showSuccessSheet(
    context,
    title: AppStrings.inviteSentTitle,
    body: AppStrings.inviteSentBody(name),
  );
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          28,
          AppTheme.gutter,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // .original, not a tinted AppIcon: Success.svg is a green circle
            // and tick, and a colour filter would flatten it to one shade.
            const AppIcon.original(AppAssets.success, size: 48),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppTextStyles.heading.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(body, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 26),
            SecondaryButton(
              label: AppStrings.done,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
