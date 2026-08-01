import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/listy_logo.dart';
import '../../widgets/app_back_button.dart';

/// Figma frame "About Us".
///
/// The frame is an empty page with only the app bar drawn, so the body is
/// placeholder copy in the file's type styles. Swap the paragraph for the real
/// text when you have it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.aboutUs),
        leading: const AppBackButton(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: [
          const SizedBox(height: 24),
          const Center(child: ListyLogo(size: 110)),
          const SizedBox(height: 14),
          Center(
            child: Text(AppStrings.appName, style: AppTextStyles.wordmark),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Version 1.0.0', style: AppTextStyles.profileMeta),
          ),
          const SizedBox(height: 32),
          Text(
            'Listy App lets you build a list of what you need and send it '
            'straight to someone in your contacts. They get the list, tick '
            'things off as they go, and you both stay in sync.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
