import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/listy_list.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_chevron.dart';

/// Figma frame 1:2986 lists "Upcoming Lists" above "Item Lists".
///
/// Item Lists shows everything; this shows only what is still waiting on you --
/// lists someone else sent that you have not fully ticked off.
class UpcomingListsScreen extends ConsumerWidget {
  const UpcomingListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(listsWithItemsProvider);
    final incoming = ref.watch(incomingListsProvider);
    final incomingIds = incoming.map((l) => l.id).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.upcomingLists),
        leading: const AppBackButton(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(text: AppStrings.genericError),
        data: (groups) {
          // Waiting on you = sent to you, and not every item ticked off.
          final pending = groups
              .where(
                (g) =>
                    incomingIds.contains(g.list.id) &&
                    (g.items.isEmpty || g.items.any((i) => !i.done)),
              )
              .toList(growable: false);

          if (pending.isEmpty) {
            return const _Message(text: AppStrings.noUpcoming);
          }

          return ListView.separated(
            itemCount: pending.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: AppTheme.gutter),
            itemBuilder: (context, i) => _UpcomingRow(group: pending[i]),
          );
        },
      ),
    );
  }
}

class _UpcomingRow extends ConsumerWidget {
  const _UpcomingRow({required this.group});

  final ListWithItems group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sender = ref.watch(userLabelProvider(group.list.ownerUid));
    final total = group.items.length;
    final done = group.items.where((i) => i.done).length;

    return InkWell(
      onTap: () => context.push(Routes.listDetail(group.list.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gutter,
          vertical: 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.list.title,
                    style: AppTextStyles.rowLabelBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.receivedFrom(sender)} · '
                    '${AppStrings.doneOf(done, total)}',
                    style: AppTextStyles.profileMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const AppChevron(size: 14, color: AppColors.gray30),
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
