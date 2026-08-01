import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/list_item.dart';
import '../../data/models/listy_list.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../widgets/app_back_button.dart';

/// Opening a received (or sent) list: who it's between, its items, and a
/// checkbox per item.
///
/// Both the list and its items are streamed, so when one person ticks
/// something off it appears on the other person's screen without a refresh --
/// that live sync is the whole point of sending a list rather than texting it.
class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(listByIdProvider(listId));
    final itemsAsync = ref.watch(listItemsProvider(listId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    final list = listAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.title ?? AppStrings.itemLists),
        leading: const AppBackButton(),
        actions: [
          if (list != null && list.ownerUid == myUid)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: AppStrings.deleteList,
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(text: AppStrings.genericError),
        data: (list) {
          if (list == null) return const _Message(text: AppStrings.listGone);

          return Column(
            children: [
              _Header(list: list, myUid: myUid),
              const Divider(height: 1),
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _Message(text: AppStrings.genericError),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _Message(text: AppStrings.noItems);
                    }
                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      itemBuilder: (context, i) => _ItemTile(
                        item: items[i],
                        isSender: list.ownerUid == myUid,
                        onToggle: (done) => ref
                            .read(listRepositoryProvider)
                            .setItemDone(listId, items[i].id, done),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.gray5,
        title: const Text(AppStrings.deleteList),
        content: const Text(AppStrings.deleteListBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              AppStrings.delete,
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      await ref.read(listRepositoryProvider).deleteList(listId, uid);
    }
    // The list is gone, so returning to a stale detail route is not an option;
    // backOr falls through to Item Lists when there is no stack entry.
    if (context.mounted) context.backOr(Routes.itemLists);
  }
}

/// Names the other person and shows how far through the list they are.
class _Header extends ConsumerWidget {
  const _Header({required this.list, required this.myUid});

  final ListyList list;
  final String? myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outgoing = list.ownerUid == myUid;
    // Show the person on the other end, whichever direction the list went.
    final otherUid = outgoing ? list.assignedToUid : list.ownerUid;
    final otherName = ref.watch(userLabelProvider(otherUid));

    final items = ref.watch(listItemsProvider(list.id)).valueOrNull;
    final total = items?.length ?? list.itemCount;
    final done = items?.where((i) => i.done).length ?? 0;

    return Container(
      width: double.infinity,
      color: AppColors.gray5,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gutter,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                outgoing ? Icons.north_east : Icons.south_west,
                size: 16,
                color: AppColors.gray40,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  outgoing
                      ? AppStrings.sentTo(otherName)
                      : AppStrings.receivedFrom(otherName),
                  style: AppTextStyles.rowLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 6,
                backgroundColor: AppColors.gray20,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.doneOf(done, total),
              style: AppTextStyles.profileMeta,
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.isSender,
    required this.onToggle,
  });

  final ListItem item;
  final bool isSender;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSender ? null : () => onToggle(!item.done),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.gray20)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gutter,
          vertical: 6,
        ),
        child: Row(
          children: [
            Checkbox(
              value: item.done,
              onChanged: isSender ? null : (v) => onToggle(v ?? false),
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.name,
                style: AppTextStyles.rowLabelBold.copyWith(
                  // Struck through and muted once done, so the remaining work
                  // is what stands out.
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  color: item.done ? AppColors.gray30 : AppColors.label,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${item.quantity}',
              style: AppTextStyles.rowLabelBold.copyWith(
                color: item.done ? AppColors.gray30 : AppColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.gutter),
      child: Text(
        text,
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
