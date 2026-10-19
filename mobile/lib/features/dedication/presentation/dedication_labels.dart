import 'package:flutter/widgets.dart';
import '../../../core/localization/tr.dart';
import '../data/dedication_repository.dart';

/// Wording for each dedication target, shared by the home card, the sheet and
/// the reader's closing dua.
extension DedicationLabels on DedicationTarget {
  String chip(BuildContext c) => switch (this) {
        DedicationTarget.parents => c.tr('والداي', 'My parents'),
        DedicationTarget.father => c.tr('أبي', 'My father'),
        DedicationTarget.mother => c.tr('أمي', 'My mother'),
        DedicationTarget.other => c.tr('غيرهما', 'Someone else'),
      };

  String title(BuildContext c) => switch (this) {
        DedicationTarget.parents => c.tr('إهداء إلى والديّ', 'Dedicated to my parents'),
        DedicationTarget.father => c.tr('إهداء إلى أبي', 'Dedicated to my father'),
        DedicationTarget.mother => c.tr('إهداء إلى أمي', 'Dedicated to my mother'),
        DedicationTarget.other => c.tr('إهداء ثواب القراءة', 'Dedicating this reading'),
      };

  String dua(BuildContext c) => switch (this) {
        DedicationTarget.parents => c.tr(
            'اللهم اجعل هذا القرآن صدقةً جاريةً لوالديّ',
            'O Allah, make this recitation an ongoing charity for my parents'),
        DedicationTarget.father => c.tr(
            'اللهم اجعل هذا القرآن صدقةً جاريةً لأبي',
            'O Allah, make this recitation an ongoing charity for my father'),
        DedicationTarget.mother => c.tr(
            'اللهم اجعل هذا القرآن صدقةً جاريةً لأمي',
            'O Allah, make this recitation an ongoing charity for my mother'),
        DedicationTarget.other => c.tr(
            'اللهم اجعل ثواب هذا القرآن صدقةً جاريةً لمن أهديته له',
            'O Allah, make the reward of this recitation an ongoing charity for the one I dedicate it to'),
      };
}
