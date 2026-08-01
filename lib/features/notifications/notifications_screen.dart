import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/listy_list.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_chevron.dart';

/// Reached from the bell in the app bar. The Figma file draws the bell but no
/// notifications frame, so this lists incoming lists -- the ones assigned to
/// the signed-in user by someone else -- using the file's row styles.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final listsAsync = ref.watch(myListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notifications),
        leading: const AppBackButton(),
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(AppStrings.genericError, style: AppTextStyles.body),
        ),
        data: (lists) {
          final notifications = lists
              .where((l) {
                if (l.ownerUid != uid) return true; // incoming
                if (l.doneCount > 0) return true; // outgoing with progress
                return false;
              })
              .toList(growable: false);

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

          final sorted = notifications.toList()
            ..sort(
              (a, b) => (b.lastActivityAt ?? b.createdAt ?? DateTime.now())
                  .compareTo(a.lastActivityAt ?? a.createdAt ?? DateTime.now()),
            );

          return ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: AppTheme.gutter),
            itemBuilder: (context, i) =>
                _NotificationRow(list: sorted[i], myUid: uid),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.list, required this.myUid});

  final ListyList list;
  final String? myUid;

  bool _isUnread() {
    final activity =
        list.lastActivityAt ??
        list.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (list.ownerUid == myUid) {
      final readAt = list.ownerReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return activity.isAfter(readAt);
    } else {
      final readAt =
          list.assigneeReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return activity.isAfter(readAt);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutgoing = list.ownerUid == myUid;
    // Show the other person's name
    final otherUid = isOutgoing ? list.assignedToUid : list.ownerUid;
    final otherName = ref.watch(userLabelProvider(otherUid));

    String subtitle;
    if (isOutgoing) {
      if (list.doneCount >= list.itemCount && list.itemCount > 0) {
        subtitle = '$otherName finished the list!';
      } else {
        subtitle =
            '$otherName ticked off ${list.doneCount} of ${list.itemCount} items';
      }
    } else {
      subtitle =
          '$otherName sent ${list.itemCount} '
          '${list.itemCount == 1 ? 'item' : 'items'}';
    }

    final unread = _isUnread();

    return InkWell(
      onTap: () {
        if (unread && myUid != null) {
          ref.read(listRepositoryProvider).markListRead(list.id, isOutgoing);
        }
        context.push(Routes.listDetail(list.id));
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.title,
                    style: AppTextStyles.rowLabelBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.profileMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const AppChevron(size: 14, color: AppColors.gray30),
          ],
        ),
      ),
    );
  }
}
