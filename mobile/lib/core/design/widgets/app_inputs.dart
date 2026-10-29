import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../localization/tr.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// Stand-alone rounded text field (filled, no border), e.g. inside a sheet.
///
/// Set [ltr] for e-mail, passwords, numbers and URLs so the text and caret
/// stay left-to-right in the Arabic UI.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofocus = false,
    this.ltr = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.prefix,
    this.suffix,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.style,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autofocus;
  final bool ltr;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final Widget? prefix;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final field = CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      prefix: prefix,
      suffix: suffix,
      style: style ?? AppTypography.body.copyWith(color: c.label),
      placeholderStyle: AppTypography.body.copyWith(color: c.placeholder),
      cursorColor: c.accent,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.ms,
        vertical: AppSpacing.ms - 1,
      ),
      decoration: BoxDecoration(
        color: c.tertiaryFill,
        borderRadius: BorderRadius.circular(AppRadius.medium - 2),
      ),
    );
    return ltr
        ? Directionality(textDirection: TextDirection.ltr, child: field)
        : field;
  }
}

/// Text field row for forms inside an `AppListSection` (borderless, with an
/// optional leading label and inline validation message).
class AppTextFormRow extends StatelessWidget {
  const AppTextFormRow({
    super.key,
    this.controller,
    this.placeholder,
    this.prefixLabel,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.ltr = false,
    this.autofillHints,
    this.suffix,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final String? prefixLabel;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool ltr;
  final Iterable<String>? autofillHints;

  /// Trailing accessory (e.g. a "show password" eye button).
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final field = CupertinoTextFormFieldRow(
      controller: controller,
      placeholder: placeholder,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      enabled: enabled,
      // In RTL the LTR content still reads from the leading edge.
      textAlign: ltr && Directionality.of(context) == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.start,
      textDirection: ltr ? TextDirection.ltr : null,
      style: AppTypography.body.copyWith(color: c.label),
      placeholderStyle: AppTypography.body.copyWith(color: c.placeholder),
      cursorColor: c.accent,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.xs + 2,
        AppSpacing.sm,
        AppSpacing.xs + 2,
      ),
      prefix: prefixLabel == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 88),
              child: Text(prefixLabel!,
                  style: AppTypography.body.copyWith(color: c.label)),
            ),
    );
    if (suffix == null) return field;
    return Row(children: [Expanded(child: field), suffix!]);
  }
}

/// iOS search field with a localised placeholder.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return CupertinoSearchTextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      placeholder: placeholder ?? context.tr('بحث', 'Search'),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppTypography.body.copyWith(color: c.label),
      placeholderStyle: AppTypography.body.copyWith(color: c.placeholder),
      cursorColor: c.accent,
      backgroundColor: c.tertiaryFill,
      borderRadius: BorderRadius.circular(AppRadius.medium - 2),
    );
  }
}

/// Sliding segmented control, full width, with a selection haptic.
class AppSegmentedControl<T extends Object> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  /// Value → label, in reading order (mirrored automatically in RTL).
  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: AppColors.tertiaryFill,
        thumbColor: AppColors.tertiaryGroupedBackground,
        children: {
          for (final entry in segments.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subheadline
                    .weight(
                        entry.key == value ? FontWeight.w600 : FontWeight.w500)
                    .copyWith(
                        color:
                            entry.key == value ? c.accent : c.secondaryLabel),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v == null || v == value) return;
          HapticFeedback.selectionClick();
          onChanged(v);
        },
      ),
    );
  }
}
