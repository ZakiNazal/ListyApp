import 'package:flutter/material.dart';

import '../core/router/app_router.dart';

/// The leading back arrow for every full-screen page.
///
/// Uses [AppNavigation.backOr] rather than a bare `context.pop()`: these pages
/// can be reached either by being pushed (a real stack entry) or by a `go` from
/// the drawer (which replaces the stack). Popping in the second case throws
/// "There is nothing to pop", so this falls back to a sensible destination.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = Routes.home, this.tooltip});

  /// Where to land when there is no stack entry to return to.
  final String fallback;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => context.backOr(fallback),
    );
  }
}
