import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/listy_logo.dart';
import '../../widgets/primary_button.dart';
import 'otp_screen.dart';

/// Figma frame "تسجيل العميل" (the variant with the phone field), translated
/// to English.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Requires an explicit country code -- see PhoneUtils.normalizeSignIn for
    // why guessing here is worse than refusing.
    final phone = PhoneUtils.normalizeSignIn(_controller.text);
    if (phone == null) {
      setState(() => _error = AppStrings.invalidPhoneSignIn);
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    await ref
        .read(authRepositoryProvider)
        .sendOtp(
          e164Phone: phone,
          onCodeSent: (session) {
            if (!mounted) return;
            setState(() => _sending = false);
            context.push(
              Routes.otp,
              extra: OtpArgs(
                phone: phone,
                verificationId: session.verificationId,
                resendToken: session.resendToken,
              ),
            );
          },
          onAutoVerified: (_) {
            // Android auto-retrieved the SMS and signed in already; the
            // router's redirect moves us to Home.
            if (!mounted) return;
            setState(() => _sending = false);
          },
          onFailed: (failure) {
            if (!mounted) return;
            setState(() {
              _sending = false;
              _error = failure.message;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      const ListyLogo(size: 115),
                      const SizedBox(height: 12),
                      Text(AppStrings.appName, style: AppTextStyles.wordmark),
                      const SizedBox(height: 56),
                      Text(AppStrings.signIn, style: AppTextStyles.heading),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.signInBody,
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      AppTextField(
                        controller: _controller,
                        hintText: AppStrings.phoneNumber,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        errorText: _error,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Start with your country code, e.g. +1 555 123 4567',
                          style: AppTextStyles.profileMeta.copyWith(
                            color: AppColors.gray40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      PrimaryButton(
                        label: AppStrings.login,
                        loading: _sending,
                        onPressed: _sending ? null : _submit,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
