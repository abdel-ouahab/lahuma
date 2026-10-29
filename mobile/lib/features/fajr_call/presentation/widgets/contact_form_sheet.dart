import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/fajr_contact.dart';
import 'fajr_call_labels.dart';

/// Add or edit one person: name, number and relation.
class ContactFormSheet extends StatefulWidget {
  const ContactFormSheet({
    super.key,
    required this.id,
    required this.dialCode,
    this.initial,
    this.prefillName,
    this.prefillPhone,
  });

  final String id;
  final String? dialCode;
  final FajrContact? initial;
  final String? prefillName;
  final String? prefillPhone;

  static Future<FajrContact?> show(
    BuildContext context, {
    required String id,
    required String? dialCode,
    FajrContact? initial,
    String? name,
    String? phone,
  }) =>
      showAppBottomSheet<FajrContact>(
        context,
        title: initial == null
            ? context.tr('إضافة شخص', 'Add a person')
            : context.tr('تعديل', 'Edit'),
        builder: (_) => ContactFormSheet(
          id: id,
          dialCode: dialCode,
          initial: initial,
          prefillName: name,
          prefillPhone: phone,
        ),
      );

  @override
  State<ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<ContactFormSheet> {
  late final _name = TextEditingController(
      text: widget.initial?.name ?? widget.prefillName ?? '');
  late final _phone = TextEditingController(
      text: widget.initial?.rawPhone ?? widget.prefillPhone ?? '');
  late ContactRelation? _relation = widget.initial?.relation;
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickRelation() async {
    final r = await showAppActionSheet<ContactRelation>(
      context,
      title: context.tr('صلة القرابة', 'Relation'),
      actions: [
        for (final r in ContactRelation.values)
          AppSheetAction(
            label: relationLabel(context, r),
            value: r,
            icon: relationIcon(r),
            isDefault: r == _relation,
          ),
      ],
    );
    if (r != null) setState(() => _relation = r);
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(FajrContact.fromInput(
      id: widget.id,
      name: _name.text,
      phone: _phone.text,
      relation: _relation,
      dialCode: widget.dialCode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListSection(
            children: [
              AppTextFormRow(
                controller: _name,
                placeholder:
                    context.tr('الاسم (مثلًا: أمي)', 'Name (e.g. Mum)'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.tr('اكتب اسمًا', 'Enter a name')
                    : null,
              ),
              AppTextFormRow(
                controller: _phone,
                placeholder: context.tr('رقم الهاتف', 'Phone number'),
                keyboardType: TextInputType.phone,
                ltr: true,
                autofillHints: const [AutofillHints.telephoneNumber],
                onFieldSubmitted: (_) => _save(),
                validator: (v) =>
                    normalizePhone(v ?? '').replaceAll('+', '').length < 3
                        ? context.tr(
                            'اكتب رقمًا صحيحًا', 'Enter a valid number')
                        : null,
              ),
              AppListTile(
                title: context.tr('صلة القرابة', 'Relation'),
                value: _relation == null
                    ? context.tr('اختياري', 'Optional')
                    : relationLabel(context, _relation),
                onTap: _pickRelation,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: AppButton.filled(
              label: context.tr('حفظ', 'Save'),
              expand: true,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
