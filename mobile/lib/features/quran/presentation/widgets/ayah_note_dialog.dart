import 'package:flutter/material.dart';
import '../../../../core/localization/tr.dart';

/// Edit dialog for a personal note on an ayah. Returns the new text, or null
/// if cancelled. Saving an empty note deletes it.
Future<String?> showAyahNoteDialog(
  BuildContext context, {
  required String surahName,
  required int ayahNumber,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
          '$surahName · ${ctx.tr('الآية $ayahNumber', 'Ayah $ayahNumber')}'),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: ctx.tr('اكتب ما تأمّلته في هذه الآية',
              'Write what you reflected on in this ayah'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.tr('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(ctx.tr('حفظ الملاحظة', 'Save note')),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
