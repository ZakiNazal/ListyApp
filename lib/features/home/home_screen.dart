import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/list_repository.dart';
import '../../widgets/app_icon.dart';

/// Figma frame "1. الصفحة الرئيسية" -- two stat cards side by side.
///
/// Both cards are tappable and open the Item Lists screen, which is the only
/// sensible destination for them and matches the flow drawn in the file.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(myListsProvider);
    final stats = ref.watch(listStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myListsProvider),
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: [
          // IntrinsicHeight is what makes CrossAxisAlignment.stretch legal
          // here. Inside a ListView the Row's cross axis is unbounded, and
          // stretch would try to size the cards to infinite height. Measuring
          // the taller card first gives the Row a real height to stretch to,
          // so both cards match even when one caption wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    caption: AppStrings.numberOfLists,
                    value: stats.lists,
                    icon: AppAssets.clipboard,
                    loading: listsAsync.isLoading,
                    onTap: () => context.push(Routes.itemLists),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    caption: AppStrings.numberOfItems,
                    value: stats.items,
                    icon: AppAssets.objects,
                    loading: listsAsync.isLoading,
                    onTap: () => context.push(Routes.itemLists),
                  ),
                ),
              ],
            ),
          ),
          if (listsAsync.hasError) ...[
            const SizedBox(height: 24),
            Text(
              AppStrings.genericError,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // The navigation rows drawn beneath the stat cards in frames
          // 1:2986 / 1:2928. Counts are live so Home doubles as an inbox
          if (listsAsync.valueOrNull?.isEmpty ?? false) ...[
            const SizedBox(height: 40),
            Text(
              AppStrings.noLists,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => context.go(Routes.request),
                child: Text(
                  'Create your first list',
                  style: AppTextStyles.rowLabel.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.caption,
    required this.value,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String caption;
  final int value;
  final String icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.gray20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    caption,
                    style: AppTextStyles.cardCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                AppIcon(icon, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            loading
                ? const SizedBox(
                    height: 36,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Text('$value', style: AppTextStyles.cardValue),
          ],
        ),
      ),
    );
  }
}
