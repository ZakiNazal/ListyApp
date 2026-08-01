import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/listy_logo.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_back_button.dart';

class OtpArgs {
  const OtpArgs({
    required this.phone,
    required this.verificationId,
    this.resendToken,
  });

  final String phone;
  final String verificationId;
  final int? resendToken;
}

/// Not present in the Figma file -- Phone auth cannot work without it, so this
/// screen is composed from the same tokens as the login frame: logo block,
/// heading, muted body copy, and the orange full-width action button.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const int _codeLength = 6;
  static const int _resendCooldown = 60;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late String _verificationId = widget.args.verificationId;
  late int? _resendToken = widget.args.resendToken;

  bool _verifying = false;
  bool _resending = false;
  String? _error;

  Timer? _timer;
  int _secondsLeft = _resendCooldown;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != _codeLength) {
      setState(() => _error = AppStrings.invalidCode);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .verifyOtp(
            verificationId: _verificationId,
            smsCode: code,
            e164Phone: widget.args.phone,
          );
      // The router redirect takes over from here and lands on Home.
    } on PhoneAuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = AppStrings.genericError;
      });
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;

    setState(() {
      _resending = true;
      _error = null;
    });

    await ref
        .read(authRepositoryProvider)
        .sendOtp(
          e164Phone: widget.args.phone,
          resendToken: _resendToken,
          onCodeSent: (session) {
            if (!mounted) return;
            setState(() {
              _resending = false;
              _verificationId = session.verificationId;
              _resendToken = session.resendToken;
            });
            _startCooldown();
          },
          onAutoVerified: (_) {
            if (!mounted) return;
            setState(() => _resending = false);
          },
          onFailed: (failure) {
            if (!mounted) return;
            setState(() {
              _resending = false;
              _error = failure.message;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().length == _codeLength;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          fallback: Routes.login,
          tooltip: AppStrings.changeNumber,
        ),
      ),
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
                      const SizedBox(height: 20),
                      const ListyLogo(size: 96),
                      const SizedBox(height: 40),
                      Text(
                        AppStrings.verifyNumber,
                        style: AppTextStyles.heading,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.otpBody(
                          PhoneUtils.pretty(widget.args.phone),
                        ),
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _CodeInput(
                        controller: _controller,
                        focusNode: _focusNode,
                        length: _codeLength,
                        hasError: _error != null,
                        onChanged: (value) {
                          setState(() => _error = null);
                          if (value.length == _codeLength) _verify();
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: AppTextStyles.profileMeta.copyWith(
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _resending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: _secondsLeft > 0 ? null : _resend,
                              child: Text(
                                _secondsLeft > 0
                                    ? AppStrings.resendIn(_secondsLeft)
                                    : AppStrings.resendCode,
                                style: AppTextStyles.rowLabel.copyWith(
                                  color: _secondsLeft > 0
                                      ? AppColors.gray30
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                      const Spacer(),
                      PrimaryButton(
                        label: AppStrings.verify,
                        loading: _verifying,
                        onPressed: canSubmit && !_verifying ? _verify : null,
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

/// Six boxed digits backed by a single hidden text field. Tapping anywhere
/// focuses the field, so the OS keyboard and SMS autofill both behave normally.
class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onChanged,
    required this.hasError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // The real field, invisible but focusable and autofill-capable.
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 52,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
            ),
          ),
        ),
        GestureDetector(
          onTap: focusNode.requestFocus,
          behavior: HitTestBehavior.opaque,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(length, (i) {
                  final filled = i < value.text.length;
                  final active = i == value.text.length;
                  return Container(
                    width: 44,
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: hasError
                            ? AppColors.primary
                            : active
                            ? AppColors.label
                            : AppColors.gray20,
                        width: active || hasError ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      filled ? value.text[i] : '',
                      style: AppTextStyles.heading.copyWith(fontSize: 20),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
