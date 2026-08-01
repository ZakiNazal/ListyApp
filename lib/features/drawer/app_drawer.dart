import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/avatar.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.currentLocation});

  final String currentLocation;

  static const double _inset = 30;
  static const double _width = 275;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;

    // The card floats: inset from the left and bottom by 30px, and from the
    // top by 30px plus whatever the status bar occupies so it never collides
    // with the notch on a real device.
    final topInset = _inset + MediaQuery.paddingOf(context).top;

    return SizedBox(
      width: _inset + _width,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_inset, topInset, 0, _inset),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _width,
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(
                    name: user?.label ?? AppStrings.appName,
                    subtitle: PhoneUtils.pretty(
                      user?.phone ?? authUser?.phoneNumber,
                    ),
                    photoUrl: user?.photoUrl,
                    initials: user?.initials ?? '',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(Routes.profile);
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 8),
                      children: [
                        _DrawerItem(
                          asset: AppAssets.clipboard,
                          label: AppStrings.myLists,
                          active: currentLocation == Routes.itemLists,
                          onTap: () => _go(context, Routes.itemLists),
                        ),
                        _DrawerItem(
                          asset: AppAssets.request,
                          label: AppStrings.requests,
                          active: currentLocation == Routes.request,
                          onTap: () => _go(context, Routes.request),
                        ),
                        _DrawerItem(
                          asset: AppAssets.bell,
                          label: AppStrings.notifications,
                          active: currentLocation == Routes.notifications,
                          onTap: () => _go(context, Routes.notifications),
                        ),
                        _DrawerItem(
                          asset: AppAssets.profile,
                          label: AppStrings.profile,
                          active: currentLocation == Routes.profile,
                          onTap: () => _go(context, Routes.profile),
                        ),
                        const SizedBox(height: 28),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 22),
                          child: _SectionLabel(AppStrings.settingsSection),
                        ),
                        const SizedBox(height: 4),
                        _DrawerItem(
                          icon: Icons.info_outline,
                          label: AppStrings.aboutUs,
                          muted: true,
                          onTap: () => _go(context, Routes.about),
                        ),
                        _DrawerItem(
                          icon: Icons.phone_outlined,
                          label: AppStrings.contactUs,
                          muted: true,
                          onTap: () => _go(context, Routes.about),
                        ),
                        _DrawerItem(
                          icon: Icons.settings_outlined,
                          label: AppStrings.settings,
                          muted: true,
                          onTap: () => _go(context, Routes.profile),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 5),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: AppStrings.logOut,
                    onTap: () async {
                      // Read everything before the drawer closes. Popping
                      // disposes this element, and `ref` cannot be touched
                      // afterwards -- the signOut read below used to run after
                      // an await and threw "Cannot use ref after the widget was
                      // disposed".
                      final uid = ref.read(authStateProvider).valueOrNull?.uid;
                      final push = ref.read(pushRepositoryProvider);
                      final auth = ref.read(authRepositoryProvider);

                      Navigator.of(context).pop();

                      // Drop this device's push token first, or the phone keeps
                      // receiving notifications for an account that is no
                      // longer signed in on it.
                      if (uid != null) await push.unregister(uid);
                      await auth.signOut();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Closes the drawer, then navigates.
  ///
  /// Uses [AppNavigation.goOrPush] rather than a bare `go`: `go` replaces the
  /// whole stack, which left full-screen pages like Item Lists with nothing to
  /// pop and made their back arrow throw. Shell tabs still replace; everything
  /// else stacks so it can be backed out of.
  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.goOrPush(route);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.onTap,
    this.photoUrl,
  });

  final String name;
  final String subtitle;
  final String initials;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gray20),
          ),
          child: Row(
            children: [
              Avatar(photoUrl: photoUrl, initials: initials, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTextStyles.profileMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextStyles.sectionHeader);
}

/// A single menu row. The active row gets the accent colour plus a 3px bar on
/// the leading edge, which is the treatment drawn in Design 23.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.onTap,
    this.asset,
    this.icon,
    this.active = false,
    this.muted = false,
  }) : assert(asset != null || icon != null, 'needs an asset or an icon');

  /// Path into [AppAssets]. Only four of the drawer's rows have supplied
  /// artwork; the rest fall back to [icon].
  final String? asset;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  /// The SETTINGS group renders in a lighter grey in the design.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : muted
        ? AppColors.gray30
        : AppColors.label;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 47,
        child: Row(
          children: [
            // Active indicator bar on the leading edge.
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 19),
            asset != null
                ? AppIcon(asset!, size: 22, color: color)
                : Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.drawerItem.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
