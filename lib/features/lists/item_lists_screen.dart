import 'package:flutter/foundation.dart';
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
import '../request/widgets/item_row.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_chevron.dart';

/// Figma frame "Item Lists" -- each list renders as a grey group header
/// ("Lists 1  (4 Items)") followed by its item rows with the quantity on the
/// trailing edge.
class ItemListsScreen extends ConsumerWidget {
  const ItemListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(listsWithItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.itemLists),
        leading: const AppBackButton(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(text: _describe(error)),
        data: (groups) {
          if (groups.isEmpty) {
            return const _Message(text: AppStrings.noLists);
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: groups.length,
            itemBuilder: (context, index) => _ListGroup(group: groups[index]),
          );
        },
      ),
    );
  }
}

class _ListGroup extends StatelessWidget {
  const _ListGroup({required this.group});

  final ListWithItems group;

  @override
  Widget build(BuildContext context) {
    // The whole group -- header and items -- opens the list, so there is no
    // hunting for a small tap target.
    void open() => context.push(Routes.listDetail(group.list.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: open,
          child: Container(
            color: AppColors.gray5,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.gutter,
              vertical: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: AppTextStyles.rowLabelBold,
                      children: [
                        TextSpan(text: group.list.title),
                        TextSpan(
                          text: '  ${AppStrings.itemCount(group.items.length)}',
                          style: AppTextStyles.rowLabel.copyWith(
                            color: AppColors.gray40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const AppChevron(size: 16, color: AppColors.label),
              ],
            ),
          ),
        ),
        for (final item in group.items)
          InkWell(
            onTap: open,
            child: ItemListTile(
              name: item.name,
              quantity: item.quantity,
              done: item.done,
            ),
          ),
      ],
    );
  }
}

/// In debug builds show the real failure. A screen that only ever says
/// "Something went wrong" is undiagnosable -- the Firestore error code is the
/// whole diagnosis. Release builds still get the friendly line.
String _describe(Object error) =>
    kReleaseMode ? AppStrings.genericError : '${AppStrings.genericError}\n\n$error';

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
