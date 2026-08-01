import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listyapp/data/repositories/user_repository.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/list_item.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/contacts_repository.dart';
import '../../data/repositories/list_repository.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/success_sheet.dart';
import 'widgets/item_row.dart';
import 'widgets/select_user_sheet.dart';

/// Figma frame "1. الصفحة الرئيسية" (the Request variant): List Name, the
/// "Choose your user" select, repeatable item rows with a quantity stepper,
/// "Add item", and a pinned Send button that stays grey until the form is valid.
class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key});

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final _listNameController = TextEditingController();
  final List<_ItemEntry> _items = [_ItemEntry()];

  ContactEntry? _selectedUser;
  bool _sending = false;
  String? _listNameError;
  String? _userError;

  @override
  void dispose() {
    _listNameController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _isValid =>
      _listNameController.text.trim().isNotEmpty &&
      _selectedUser != null &&
      _items.any((i) => i.controller.text.trim().isNotEmpty);

  void _addItem() => setState(() => _items.add(_ItemEntry()));

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() => _items.removeAt(index).dispose());
  }

  Future<void> _pickUser() async {
    final choice = await showSelectUserSheet(context);
    if (choice == null || !mounted) return;
    setState(() {
      _selectedUser = choice;
      _userError = null;
    });
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _listNameError = _listNameController.text.trim().isEmpty
          ? AppStrings.listNameRequired
          : null;
      _userError = _selectedUser == null ? AppStrings.userRequired : null;
    });

    if (!_isValid) {
      if (_listNameError == null && _userError == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.itemRequired)));
      }
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final assignedTo = _selectedUser?.registeredUser?.uid;
    if (uid == null || assignedTo == null) return;

    // Captured before the await: _reset() clears _selectedUser, and the
    // confirmation sheet needs the recipient's name after that point.
    final recipientName = _selectedUser!.displayName;

    setState(() => _sending = true);

    try {
      final listId = await ref
          .read(listRepositoryProvider)
          .createList(
            title: _listNameController.text,
            ownerUid: uid,
            assignedToUid: assignedTo,
            items: _items
                .map(
                  (e) =>
                      DraftItem(name: e.controller.text, quantity: e.quantity),
                )
                .toList(),
          );

      await ref
          .read(userRepositoryProvider)
          .sendNotification(
            targetUid: assignedTo,
            fromUid: uid,
            listId: listId,
            message:
                'Sent you a new list: "${_listNameController.text.trim()}"',
          );
      if (!mounted) return;
      setState(() => _sending = false);
      await showListSentSheet(context, recipientName);

      if (!mounted) return;
      _reset();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.genericError)));
    }
  }

  void _reset() {
    setState(() {
      _listNameController.clear();
      for (final item in _items) {
        item.dispose();
      }
      _items
        ..clear()
        ..add(_ItemEntry());
      _selectedUser = null;
      _listNameError = null;
      _userError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              LabeledField(
                label: AppStrings.chooseYourUser,
                child: SelectField(
                  value: _selectedUser?.displayName,
                  hintText: AppStrings.select,
                  errorText: _userError,
                  onTap: _pickUser,
                ),
              ),
              const SizedBox(height: 20),

              // Each item gets its own numbered label, and every row but the
              // last carries a Delete link -- the trailing row is the blank
              // "Item name" slot you type the next item into, so there is
              // nothing there to delete yet. Matches the design.
              for (var i = 0; i < _items.length; i++) ...[
                Text(
                  _items.length > 1
                      ? AppStrings.itemNameNumbered(i + 1)
                      : AppStrings.itemName,
                  style: AppTextStyles.fieldLabel,
                ),
                const SizedBox(height: 8),
                ItemRow(
                  controller: _items[i].controller,
                  quantity: _items[i].quantity,
                  onQuantityChanged: (q) =>
                      setState(() => _items[i].quantity = q),
                  onChanged: (_) => setState(() {}),
                ),
                if (_items.length > 1) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => _removeItem(i),
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
                  onTap: _addItem,
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
                        Text(AppStrings.addItem, style: AppTextStyles.rowLabel),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Pinned action bar, matching the Figma frame.
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
            label: AppStrings.send,
            loading: _sending,
            onPressed: _isValid && !_sending ? _send : null,
          ),
        ),
      ],
    );
  }
}

class _ItemEntry {
  _ItemEntry() : quantity = 0;

  final TextEditingController controller = TextEditingController();
  int quantity;

  void dispose() => controller.dispose();
}
