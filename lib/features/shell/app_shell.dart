import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../widgets/app_icon.dart';
import '../drawer/app_drawer.dart';

/// Chrome shared by Home / Request / Profile: the app bar with the bell and
/// hamburger, the Design 23 drawer, and the three-tab bottom navigation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _tabs = <({String route, String label, String icon})>[
    (route: Routes.home, label: AppStrings.home, icon: AppAssets.home),
    (
      route: Routes.request,
      label: AppStrings.request,
      icon: AppAssets.request,
    ),
    (
      route: Routes.profile,
      label: AppStrings.profile,
      icon: AppAssets.profile,
    ),
  ];

  String get _title => switch (location) {
    Routes.request => AppStrings.request,
    Routes.profile => AppStrings.profile,
    _ => AppStrings.home,
  };

  int get _currentIndex {
    final index = _tabs.indexWhere((t) => t.route == location);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final incoming = ref.watch(incomingListsProvider);
    final outgoingProgress = ref.watch(outgoingProgressListsProvider);
    
    final allNotifications = [...incoming, ...outgoingProgress];
    final notificationCount = allNotifications.where((l) {
      final activity = l.lastActivityAt ?? l.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (l.ownerUid == uid) {
        final readAt = l.ownerReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return activity.isAfter(readAt);
      } else {
        final readAt = l.assigneeReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return activity.isAfter(readAt);
      }
    }).length;

    return Scaffold(
      // The drawer is a floating card, so the Scaffold must not paint its own
      // background behind it.
      drawerScrimColor: AppColors.scrim,
      drawer: AppDrawer(currentLocation: location),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_title),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const AppIcon(AppAssets.menu, size: 22),
            tooltip: 'Menu',
            onPressed: Scaffold.of(context).openDrawer,
          ),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: notificationCount > 0,
              label: Text('$notificationCount'),
              child: const AppIcon(AppAssets.bell, size: 22),
            ),
            tooltip: AppStrings.notifications,
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => context.go(_tabs[i].route),
        tabs: _tabs,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({String route, String label, String icon})> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.white, border: Border(
          top: BorderSide(color: AppColors.gray30, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: _NavItem(
                      icon: tabs[i].icon,
                      label: tabs[i].label,
                      selected: i == currentIndex,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final String icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.label;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.navLabel.copyWith(color: color)),
      ],
    );
  }
}

class TabTransition extends StatefulWidget {
  const TabTransition({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<TabTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _currentIndex;

  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _previousIndex = null;
        });
      }
    });
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previousIndex = oldWidget.index;
      _currentIndex = widget.index;

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (i) {
        final isCurrent = i == _currentIndex;
        final isPrevious = i == _previousIndex;

        if (!isCurrent && !isPrevious) {
          return Offstage(
            offstage: true,
            child: TickerMode(
              enabled: false,
              child: widget.children[i],
            ),
          );
        }

        Widget child = widget.children[i];

        if (isPrevious) {
          Offset endOffset;
          if (_previousIndex == 1) {
            endOffset = const Offset(0.0, 1.0);
          } else if (_currentIndex == 1) {
            endOffset = const Offset(0.0, -1.0);
          } else {
            final isLtr = _currentIndex > _previousIndex!;
            endOffset = Offset(isLtr ? -1.0 : 1.0, 0.0);
          }

          child = SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: endOffset,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        } else if (isCurrent && _previousIndex != null) {
          Offset beginOffset;
          if (_currentIndex == 1) {
            beginOffset = const Offset(0.0, 1.0);
          } else if (_previousIndex == 1) {
            beginOffset = const Offset(0.0, -1.0);
          } else {
            final isLtr = _currentIndex > _previousIndex!;
            beginOffset = Offset(isLtr ? 1.0 : -1.0, 0.0);
          }

          child = SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        }

        return TickerMode(
          enabled: isCurrent,
          child: child,
        );
      }),
    );
  }
}
