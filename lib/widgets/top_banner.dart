import 'dart:async';

import 'package:flutter/material.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// A top-of-screen banner for in-app notifications.
///
/// This deliberately does *not* use `SnackBar`. A floating SnackBar is laid out
/// by the Scaffold, which first reserves room for `bottomNavigationBar` and the
/// FAB and only then measures the bar. Faking a top position with a large
/// bottom margin makes the SnackBar taller than the space the Scaffold has left,
/// and Flutter asserts "Floating SnackBar presented off screen".
///
/// An overlay entry sits above every Scaffold, so it has the whole window and
/// none of that arithmetic.
abstract final class TopBanner {
  static OverlayEntry? _entry;
  static Timer? _timer;

  /// Shows [message] at the top of the screen for four seconds.
  ///
  /// A second call replaces the banner already on screen rather than stacking,
  /// so a burst of notifications cannot bury the app behind them.
  static void show(String message, {VoidCallback? onTap}) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    hide();

    final entry = OverlayEntry(
      builder: (_) => _Banner(
        message: message,
        onTap: () {
          hide();
          onTap?.call();
        },
        onDismiss: hide,
      ),
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 4), hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;

    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _Banner extends StatefulWidget {
  const _Banner({
    required this.message,
    required this.onTap,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Clear of the status bar and the notch on every device.
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: _controller,
          child: Dismissible(
            key: const ValueKey('listy-top-banner'),
            direction: DismissDirection.up,
            // Without this the banner animates its own height to zero after the
            // swipe, which looks broken when the entry is removed immediately.
            resizeDuration: null,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: AppColors.label,
              borderRadius: BorderRadius.circular(12),
              elevation: 6,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    widget.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.rowLabelBold.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
