import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/listy_logo.dart';

/// Figma frame "شاشة البداية" -- logo centred slightly above the middle with
/// the wordmark beneath it.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Hold the splash briefly, then let the router's redirect decide where to
    // go. If Firebase has already restored a session the redirect sends the
    // user straight to Home instead.
    _timer = Timer(const Duration(milliseconds: 1400), _advance);
  }

  void _advance() {
    if (!mounted) return;
    final signedIn = ref.read(authStateProvider).valueOrNull != null;
    context.go(signedIn ? Routes.home : Routes.language);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Matches the Figma frame: the logo block sits above centre.
              const Spacer(flex: 3),
              const ListyLogo(size: 160),
              const SizedBox(height: 14),
              Text(
                AppStrings.appName,
                style: AppTextStyles.wordmark,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 5),
            ],
          ),
        ),
      ),
    );
  }
}
