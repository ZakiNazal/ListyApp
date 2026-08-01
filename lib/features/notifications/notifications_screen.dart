import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/activity_notification.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_chevron.dart';
import '../../widgets/app_icon.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark notifications as seen when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        ref.read(userRepositoryProvider).markNotificationsSeen(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.notifications),
          leading: const AppBackButton(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notifications),
        leading: const AppBackButton(),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(AppStrings.genericError, style: AppTextStyles.body),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.gutter),
                child: Text(
                  'Nothing new right now.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: AppTheme.gutter),
            itemBuilder: (context, i) => _NotificationRow(
              notification: notifications[i],
              myUid: uid,
            ),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification, required this.myUid});

  final ActivityNotification notification;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = !notification.isRead;

    return InkWell(
      onTap: () {
        if (unread) {
          ref.read(userRepositoryProvider).markNotificationRead(myUid, notification.id);
        }
        if (notification.listId.isNotEmpty) {
          context.push(Routes.listDetail(notification.listId));
        }
      },
      child: Container(
        color: unread ? AppColors.primary.withValues(alpha: 0.05) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gutter,
          vertical: 14,
        ),
        child: Row(
          children: [
            if (unread) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.gray5,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: AppIcon(AppAssets.clipboard, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notification.message,
                style: unread ? AppTextStyles.rowLabelBold : AppTextStyles.rowLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const AppChevron(size: 14, color: AppColors.gray30),
          ],
        ),
      ),
    );
  }
}
