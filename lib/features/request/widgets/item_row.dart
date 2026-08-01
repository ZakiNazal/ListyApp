import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

/// An item line on the Request screen: a text field with an inline
/// minus / count / plus stepper on the trailing edge, exactly as drawn in the
/// Figma "Item name" field.
///
/// Removal is not part of this widget. The design puts a "Delete" link beneath
/// the field rather than an X inside it, so the parent owns that affordance.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.controller,
    required this.quantity,
    required this.onQuantityChanged,
    this.onChanged,
  });

  final TextEditingController controller;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.input,
      textDirection: TextDirection.ltr,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: AppStrings.typeHere,
        suffixIcon: _Stepper(quantity: quantity, onChanged: onQuantityChanged),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            // Quantity floors at zero, matching the design's initial "0" state.
            onTap: quantity > 0 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.rowLabel,
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: quantity < 9999 ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? AppColors.label : AppColors.gray20,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? AppColors.label : AppColors.gray20,
        ),
      ),
    );
  }
}

/// Read-only variant used by the Item Lists screen.
class ItemListTile extends StatelessWidget {
  const ItemListTile({
    super.key,
    required this.name,
    required this.quantity,
    this.done = false,
  });

  final String name;
  final int quantity;

  /// Ticked-off items are struck through here too, so the summary view agrees
  /// with the detail view.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.rowLabelBold.copyWith(
      decoration: done ? TextDecoration.lineThrough : null,
      color: done ? AppColors.gray30 : AppColors.label,
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gray20)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gutter,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$quantity', style: style),
        ],
      ),
    );
  }
}
