import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../widgets/primary_button.dart';

/// Opening a received (or sent) list: who it's between, its items, and a
/// checkbox per item.
///
/// Both the list and its items are streamed, so when one person ticks
/// something off it appears on the other person's screen without a refresh --
/// that live sync is the whole point of sending a list rather than texting it.
class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  /// Guards against re-marking on every rebuild -- the list is streamed, so
  /// build runs again on each remote change.
  bool _markedRead = false;

  String get listId => widget.listId;

  /// Clears this side's unread marker once the list is actually on screen.
  ///
  /// `markListRead` existed but nothing ever called it, so ownerReadAt /
  /// assigneeReadAt only moved when an item was ticked -- meaning a sender who
  /// opened and read a list still looked like they had unread activity forever.
  void _markReadOnce(ListyList list, String myUid) {
    if (_markedRead) return;
    _markedRead = true;
    ref
        .read(listRepositoryProvider)
        .markListRead(listId, list.ownerUid == myUid)
        .catchError((Object e) => debugPrint('markListRead failed: $e'));
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(listByIdProvider(listId));
    final itemsAsync = ref.watch(listItemsProvider(listId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    final loaded = listAsync.valueOrNull;
    if (loaded != null && myUid != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _markReadOnce(loaded, myUid),
      );
    }

    final list = listAsync.valueOrNull;
    final isSender = list != null && list.ownerUid == myUid;

    // Check if within 15 mins
    final canEdit =
        isSender &&
        list.createdAt != null &&
        DateTime.now().difference(list.createdAt!) <=
            const Duration(minutes: 15);

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.title ?? AppStrings.itemLists),
        leading: const AppBackButton(),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit List',
              onPressed: () {
                final items = itemsAsync.valueOrNull ?? const [];
                context.push(
                  Routes.editList,
                  extra: {'list': list, 'items': items},
                );
              },
            ),
          if (isSender)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: AppStrings.deleteList,
              onPressed: () => _confirmDelete(context),
            )
          // The recipient cannot delete the sender's list, but does need a way
          // to clear an unwanted one off their own screen.
          else if (list != null && myUid != null)
            IconButton(
              icon: const Icon(Icons.visibility_off_outlined),
              tooltip: AppStrings.removeFromMyLists,
              onPressed: () => _confirmHide(context, myUid),
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

          final isSender = list.ownerUid == myUid;
          final needsResponse = !isSender && list.status == ListStatus.pending;
          final isDenied = list.status == ListStatus.denied;

          return Column(
            children: [
              _Header(list: list, myUid: myUid),
              if (needsResponse) ...[
                const Divider(height: 1),
                _AcceptDenyBar(list: list),
              ],
              if (isDenied) ...[
                const Divider(height: 1),
                _DeniedBanner(list: list, canUndo: !isSender),
              ],
              if (list.status == ListStatus.completed) ...[
                const Divider(height: 1),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: AppColors.success.withValues(alpha: 0.12),
                  child: Text(
                    AppStrings.listCompleted,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.rowLabelBold.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
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

                    final incomplete = items
                        .where((i) => !i.done && !i.isMissing)
                        .toList();
                    final completedOrMissing = items
                        .where((i) => i.done || i.isMissing)
                        .toList();
                    final sortedItems = [...incomplete, ...completedOrMissing];

                    final readOnly = needsResponse || isDenied;

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: sortedItems.length,
                      itemBuilder: (context, i) {
                        final item = sortedItems[i];
                        return _ItemTile(
                          item: item,
                          isSender: isSender,
                          readOnly: readOnly,
                          onToggle: (done) async {
                            await _applyItemChange(
                              list: list,
                              items: items,
                              item: item,
                              done: done,
                              isMissing: false,
                              myUid: myUid,
                            );
                          },
                          onMissing: (missing) async {
                            await _applyItemChange(
                              list: list,
                              items: items,
                              item: item,
                              done: false,
                              isMissing: missing,
                              myUid: myUid,
                              missingItemName: missing ? item.name : null,
                            );
                          },
                        );
                      },
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

  /// Writes one item change and decides whether the sender should hear about it.
  ///
  /// Whether this was the finishing touch is decided by the repository's
  /// transaction, not here. Two earlier attempts got this wrong: reading
  /// `list.doneCount` was always one write behind, and projecting from the
  /// local [items] list double-fires if both devices tick at once. The
  /// transaction sees the real state and reports the transition exactly once.
  Future<void> _applyItemChange({
    required ListyList list,
    required List<ListItem> items,
    required ListItem item,
    required bool done,
    required bool isMissing,
    required String? myUid,
    String? missingItemName,
  }) async {
    if (myUid == null) return;

    final wasCounting = item.done || item.isMissing;
    final listRepo = ref.read(listRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);

    final justCompleted = await listRepo.updateItemState(
      listId,
      item.id,
      done: done,
      isMissing: isMissing,
      wasCounting: wasCounting,
    );

    if (missingItemName != null) {
      await userRepo.sendNotification(
        targetUid: list.ownerUid,
        fromUid: myUid,
        listId: listId,
        message: 'Marked "$missingItemName" as missing in "${list.title}"',
      );
    }

    if (justCompleted) {
      // "Finished" overstates it when things were missing, so say which.
      final anyMissing =
          isMissing || items.any((i) => i.id != item.id && i.isMissing);
      await userRepo.sendNotification(
        targetUid: list.ownerUid,
        fromUid: myUid,
        listId: listId,
        message: anyMissing
            ? 'Finished "${list.title}" — some items were missing'
            : 'Finished the list: "${list.title}"',
      );
    }
  }

  /// Removes the list from this user's own view only.
  Future<void> _confirmHide(BuildContext context, String myUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.gray5,
        title: const Text(AppStrings.removeFromMyLists),
        content: const Text(AppStrings.removeFromMyListsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              AppStrings.remove,
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(listRepositoryProvider).setHidden(listId, myUid, true);
    if (context.mounted) context.backOr(Routes.itemLists);
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
    required this.readOnly,
    required this.onToggle,
    required this.onMissing,
  });

  final ListItem item;
  final bool isSender;
  final bool readOnly;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onMissing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSender || readOnly ? null : () => onToggle(!item.done),
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
              onChanged: isSender || readOnly
                  ? null
                  : (v) => onToggle(v ?? false),
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.name,
                style: AppTextStyles.rowLabelBold.copyWith(
                  // Struck through and muted once done or missing
                  decoration: (item.done || item.isMissing)
                      ? TextDecoration.lineThrough
                      : null,
                  color: (item.done || item.isMissing)
                      ? AppColors.gray30
                      : AppColors.label,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${item.quantity}',
              style: AppTextStyles.rowLabelBold.copyWith(
                color: (item.done || item.isMissing)
                    ? AppColors.gray30
                    : AppColors.label,
              ),
            ),
            const SizedBox(width: 8),
            if (!isSender && !readOnly)
              IconButton(
                icon: Icon(
                  item.isMissing
                      ? Icons.remove_circle
                      : Icons.remove_circle_outline,
                  color: item.isMissing ? AppColors.error : AppColors.gray40,
                ),
                onPressed: () => onMissing(!item.isMissing),
                tooltip: 'Mark as missing',
              )
            else if (item.isMissing)
              const Padding(
                padding: EdgeInsets.only(left: 8.0, right: 8.0),
                child: Icon(
                  Icons.remove_circle,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown on a denied list. The person who denied it can change their mind --
/// previously a denial was permanent with no way back for either side.
class _DeniedBanner extends ConsumerWidget {
  const _DeniedBanner({required this.list, required this.canUndo});

  final ListyList list;
  final bool canUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gutter,
        vertical: 10,
      ),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.listDenied,
              style: AppTextStyles.rowLabelBold.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          if (canUndo)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final myUid = ref.read(authStateProvider).valueOrNull?.uid;
                if (myUid == null) return;

                // Same disposal trap as _AcceptDenyBar: undoing the denial
                // removes this banner, so both repositories are captured
                // before anything is awaited.
                final lists = ref.read(listRepositoryProvider);
                final users = ref.read(userRepositoryProvider);

                await lists.updateListStatus(list.id, ListStatus.accepted);
                await users.sendNotification(
                  targetUid: list.ownerUid,
                  fromUid: myUid,
                  listId: list.id,
                  message: 'Accepted your list after all: "${list.title}"',
                );
              },
              child: Text(
                AppStrings.undoDeny,
                style: AppTextStyles.link.copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _AcceptDenyBar extends ConsumerWidget {
  const _AcceptDenyBar({required this.list});

  final ListyList list;

  /// Sets the status and tells the sender.
  ///
  /// Accepting or denying used to update the document silently, so the person
  /// who sent the list had no way of knowing it had been picked up or refused
  /// -- the single most important signal in the whole flow.
  Future<void> _respond(WidgetRef ref, ListStatus status) async {
    final myUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (myUid == null) return;

    // Everything is read up front, before the first await.
    //
    // Answering the list flips its status, the list stream pushes the new
    // document, and this bar is rebuilt out of existence -- so by the time the
    // first await returns, `ref` belongs to a disposed element and touching it
    // throws "Cannot use ref after the widget was disposed". The repositories
    // themselves outlive the widget, so holding them is safe.
    final lists = ref.read(listRepositoryProvider);
    final users = ref.read(userRepositoryProvider);

    await lists.updateListStatus(list.id, status);

    await users.sendNotification(
      targetUid: list.ownerUid,
      fromUid: myUid,
      listId: list.id,
      message: status == ListStatus.accepted
          ? 'Accepted your list: "${list.title}"'
          : 'Declined your list: "${list.title}"',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.gray5,
      padding: const EdgeInsets.all(AppTheme.gutter),
      child: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Deny',
              onPressed: () => _respond(ref, ListStatus.denied),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              label: 'Accept',
              onPressed: () => _respond(ref, ListStatus.accepted),
            ),
          ),
        ],
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
      child: Text(text, style: AppTextStyles.body, textAlign: TextAlign.center),
    ),
  );
}
