import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:listyapp/data/repositories/user_repository.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/list_item.dart';
import '../../data/models/listy_list.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/list_repository.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../request/widgets/item_row.dart';

class EditListScreen extends ConsumerStatefulWidget {
  const EditListScreen({super.key, required this.list, required this.items});

  final ListyList list;
  final List<ListItem> items;

  @override
  ConsumerState<EditListScreen> createState() => _EditListScreenState();
}

class _EditListScreenState extends ConsumerState<EditListScreen> {
  late final TextEditingController _listNameController;

  final List<_ExistingItemEntry> _existingItems = [];
  final List<_NewItemEntry> _newItems = [];
  final List<String> _deletedItemIds = [];

  bool _saving = false;
  String? _listNameError;

  @override
  void initState() {
    super.initState();
    _listNameController = TextEditingController(text: widget.list.title);
    for (final item in widget.items) {
      _existingItems.add(_ExistingItemEntry(item));
    }
    _newItems.add(_NewItemEntry());
  }

  @override
  void dispose() {
    _listNameController.dispose();
    for (final item in _existingItems) {
      item.dispose();
    }
    for (final item in _newItems) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _isValid =>
      _listNameController.text.trim().isNotEmpty &&
      (_existingItems.isNotEmpty ||
          _newItems.any((i) => i.controller.text.trim().isNotEmpty));

  void _addNewItem() => setState(() => _newItems.add(_NewItemEntry()));

  void _removeExistingItem(int index) {
    setState(() {
      final removed = _existingItems.removeAt(index);
      _deletedItemIds.add(removed.item.id);
      removed.dispose();
    });
  }

  void _removeNewItem(int index) {
    setState(() {
      _newItems.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _listNameError = _listNameController.text.trim().isEmpty
          ? AppStrings.listNameRequired
          : null;
    });

    if (!_isValid) {
      if (_listNameError == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.itemRequired)));
      }
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final existingToUpdate = _existingItems.map((e) {
        final changed =
            e.item.name != e.controller.text || e.item.quantity != e.quantity;
        return e.item.copyWith(
          name: e.controller.text,
          quantity: e.quantity,
          done: changed ? false : e.item.done,
          isMissing: changed ? false : e.item.isMissing,
        );
      }).toList();

      final newToAdd = _newItems
          .map((e) => DraftItem(name: e.controller.text, quantity: e.quantity))
          .toList();

      await ref
          .read(listRepositoryProvider)
          .updateList(
            listId: widget.list.id,
            title: _listNameController.text,
            ownerUid: widget.list.ownerUid,
            memberUids: widget.list.memberUids,
            existingItemsToUpdate: existingToUpdate,
            newItemsToAdd: newToAdd,
            itemIdsToDelete: _deletedItemIds,
          );

      // Previously `memberUids.firstWhere((uid) => uid != uid)` -- the lambda
      // parameter shadowed the outer name, so the test compared a value to
      // itself, was always false, fell through to orElse and returned '',
      // meaning this notification never fired. Only the owner can reach this
      // screen, so the recipient is simply assignedToUid.
      final receiverUid = widget.list.assignedToUid;
      final myUid = ref.read(authStateProvider).valueOrNull?.uid;

      if (receiverUid.isNotEmpty && myUid != null) {
        await ref
            .read(userRepositoryProvider)
            .sendNotification(
              targetUid: receiverUid,
              fromUid: myUid,
              listId: widget.list.id,
              message: 'Updated the list: "${_listNameController.text.trim()}"',
            );
      }

      if (!mounted) return;
      setState(() => _saving = false);
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.genericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit List'),
        leading: const AppBackButton(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                20,
                AppTheme.gutter,
                20,
              ),
              children: [
                LabeledField(
                  label: AppStrings.listName,
                  child: AppTextField(
                    controller: _listNameController,
                    hintText: AppStrings.listName,
                    errorText: _listNameError,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _listNameError = null),
                  ),
                ),
                const SizedBox(height: 20),

                // Existing items
                for (var i = 0; i < _existingItems.length; i++) ...[
                  Text(
                    AppStrings.itemNameNumbered(i + 1),
                    style: AppTextStyles.fieldLabel,
                  ),
                  const SizedBox(height: 8),
                  ItemRow(
                    controller: _existingItems[i].controller,
                    quantity: _existingItems[i].quantity,
                    onQuantityChanged: (q) =>
                        setState(() => _existingItems[i].quantity = q),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => _removeExistingItem(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          AppStrings.delete,
                          style: AppTextStyles.rowLabel.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // New items
                for (var i = 0; i < _newItems.length; i++) ...[
                  Text(
                    _existingItems.isNotEmpty || _newItems.length > 1
                        ? AppStrings.itemNameNumbered(
                            _existingItems.length + i + 1,
                          )
                        : AppStrings.itemName,
                    style: AppTextStyles.fieldLabel,
                  ),
                  const SizedBox(height: 8),
                  ItemRow(
                    controller: _newItems[i].controller,
                    quantity: _newItems[i].quantity,
                    onQuantityChanged: (q) =>
                        setState(() => _newItems[i].quantity = q),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_existingItems.isNotEmpty || _newItems.length > 1) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => _removeNewItem(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            AppStrings.delete,
                            style: AppTextStyles.rowLabel.copyWith(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: _addNewItem,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.label),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 15,
                              color: AppColors.label,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            AppStrings.addItem,
                            style: AppTextStyles.rowLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.gray20)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              16,
              AppTheme.gutter,
              16,
            ),
            child: PrimaryButton(
              label: AppStrings.done,
              loading: _saving,
              onPressed: _isValid && !_saving ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingItemEntry {
  _ExistingItemEntry(this.item) {
    controller = TextEditingController(text: item.name);
    quantity = item.quantity;
  }

  final ListItem item;
  late final TextEditingController controller;
  late int quantity;

  void dispose() => controller.dispose();
}

class _NewItemEntry {
  _NewItemEntry() : quantity = 0;

  final TextEditingController controller = TextEditingController();
  int quantity;

  void dispose() => controller.dispose();
}
