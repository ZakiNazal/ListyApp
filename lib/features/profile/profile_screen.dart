import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/invite_repository.dart';
import '../../data/repositories/list_repository.dart';
import '../../widgets/app_chevron.dart';
import '../../widgets/app_icon.dart';

/// The Profile tab: three bordered navigation cards.
///
/// Matches the supplied design exactly -- Upcoming Lists, Item Lists, Invited
/// Friends, each a rounded outlined card with a leading icon, label and
/// trailing chevron. No avatar block or stat cards; those live on Home.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Active only, so a denied or finished list stops counting as work.
    final upcoming = ref.watch(incomingActiveListsProvider).length;
    final needsResponse = ref.watch(pendingResponseCountProvider);
    final lists = ref.watch(listStatsProvider).lists;
    final invites = ref.watch(myInvitesProvider).valueOrNull?.length ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        20,
        AppTheme.gutter,
        20,
      ),
      children: [
        _NavCard(
          icon: AppAssets.clipboard,
          label: AppStrings.upcomingLists,
          badge: upcoming,
          // An unanswered list is more urgent than an unfinished one.
          highlightBadge: needsResponse > 0,
          onTap: () => context.push(Routes.upcomingLists),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: AppAssets.clipboard,
          label: AppStrings.itemLists,
          badge: lists,
          onTap: () => context.push(Routes.itemLists),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: AppAssets.users,
          label: AppStrings.invitedFriends,
          badge: invites,
          onTap: () => context.push(Routes.invitedFriends),
        ),
      ],
    );
  }
}

/// One outlined navigation card.
///
/// The count is not in the design, so it only appears when non-zero -- an empty
/// app still looks exactly like the mockup.
class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.highlightBadge = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  /// Paints the count in the accent colour when it needs attention rather than
  /// merely being non-zero.
  final bool highlightBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.gray20),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.rowLabelBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: highlightBadge
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.gray5,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: AppTextStyles.cardCaption.copyWith(
                      color: highlightBadge
                          ? AppColors.primary
                          : AppColors.label,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const AppChevron(size: 14, color: AppColors.label),
            ],
          ),
        ),
      ),
    );
  }
}
