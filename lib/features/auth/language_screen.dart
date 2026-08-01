import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/listy_logo.dart';
import '../../widgets/primary_button.dart';

/// Figma frame "تسجيل العميل" (the variant with the two stacked buttons).
///
/// The original frame offers Arabic and English. Per the brief the app ships in
/// English only, so the Arabic button is present to match the design but is
/// disabled and marked "coming soon" rather than silently doing nothing.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const ListyLogo(size: 115),
              const SizedBox(height: 12),
              Text(AppStrings.appName, style: AppTextStyles.wordmark),
              const SizedBox(height: 56),
              Text(
                AppStrings.chooseLanguage,
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.chooseLanguageBody,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Opacity(
                opacity: 0.45,
                child: PrimaryButton(
                  label: AppStrings.arabic,
                  onPressed: null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Arabic is not available yet.',
                style: AppTextStyles.profileMeta,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: AppStrings.english,
                onPressed: () => context.go(Routes.login),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
