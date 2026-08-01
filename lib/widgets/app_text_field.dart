import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'app_chevron.dart';

/// A labelled input matching the Request screen: a bold caption above a
/// rounded, hairline-bordered field.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.suffix,
    this.errorText,
  });

  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? suffix;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      style: AppTextStyles.input,
      // The app is English-only, so never let the platform flip the field.
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}

/// A tappable field that looks like an input but opens a picker, used by
/// "Choose your user".
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onTap,
    this.errorText,
  });

  final String? value;
  final String hintText;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              enabledBorder: errorText == null
                  ? null
                  : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : hintText,
                    style: hasValue ? AppTextStyles.input : AppTextStyles.hint,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const AppChevron.down(size: 12),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: AppTextStyles.profileMeta
                  .copyWith(color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}
