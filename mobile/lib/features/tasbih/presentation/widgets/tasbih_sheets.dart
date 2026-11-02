import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/tasbih.dart';
import '../tasbih_providers.dart';
import 'beads_painter.dart';
import 'tasbih_labels.dart';

const int _unlimited = 0;
const int _otherNumber = -1;

List<TextInputFormatter> get _countFormatters => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(5),
    ];

int? _parseCount(String? text) {
  final n = int.tryParse(text?.trim() ?? '');
  return n != null && n > 0 ? n : null;
}

/// Picks [dhikr]'s target: common counts, no limit, or another number.
Future<void> showTargetSheet(
    BuildContext context, WidgetRef ref, TasbihDhikr dhikr) async {
  final notifier = ref.read(tasbihProvider.notifier);
  final options = {
    ...tasbihTargetOptions,
    if (dhikr.defaultTarget != null) dhikr.defaultTarget!,
    if (dhikr.target != null) dhikr.target!,
  }.toList()
    ..sort();

  final choice = await showAppBottomSheet<int>(
    context,
    title: context.tr('الهدف', 'Target'),
    builder: (ctx) {
      final c = ctx.palette;
      final check =
          Icon(CupertinoIcons.checkmark_alt, size: 20, color: c.accent);
      return AppListSection(
        header: dhikr.text,
        children: [
          for (final t in options)
            AppListTile(
              title: formatCount(t),
              subtitle: t == dhikr.defaultTarget
                  ? ctx.tr('الافتراضي', 'Default')
                  : null,
              trailing: dhikr.target == t ? check : null,
              chevron: false,
              onTap: () => Navigator.of(ctx).pop(t),
            ),
          AppListTile(
            title: ctx.tr('بلا حدّ', 'No limit'),
            subtitle: ctx.tr('عُدّ دون هدف', 'Count without a target'),
            trailing: dhikr.target == null ? check : null,
            chevron: false,
            onTap: () => Navigator.of(ctx).pop(_unlimited),
          ),
          AppListTile(
            title: ctx.tr('عدد آخر…', 'Another number…'),
            onTap: () => Navigator.of(ctx).pop(_otherNumber),
          ),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) return;

  if (choice == _otherNumber) {
    final text = await showAppTextInputDialog(
      context,
      title: context.tr('عدد آخر', 'Another number'),
      message: context.tr('كم مرة تريد أن تذكر «${dhikr.text}»؟',
          'How many times for «${dhikr.text}»?'),
      initialValue: dhikr.target?.toString(),
      placeholder: '33',
      confirmLabel: context.tr('تم', 'Done'),
      keyboardType: TextInputType.number,
      inputFormatters: _countFormatters,
    );
    final n = _parseCount(text);
    if (n != null) notifier.setTarget(dhikr.id, n);
    return;
  }
  notifier.setTarget(dhikr.id, choice == _unlimited ? null : choice);
}

/// Asks for a new dhikr's text and target, then adds and selects it.
Future<void> showAddDhikrSheet(BuildContext context, WidgetRef ref) async {
  final result = await showAppBottomSheet<({String text, int? target})>(
    context,
    title: context.tr('ذكر جديد', 'New dhikr'),
    builder: (_) => const _AddDhikrForm(),
  );
  if (result == null) return;
  ref.read(tasbihProvider.notifier).addCustom(result.text, result.target);
}

class _AddDhikrForm extends StatefulWidget {
  const _AddDhikrForm();

  @override
  State<_AddDhikrForm> createState() => _AddDhikrFormState();
}

class _AddDhikrFormState extends State<_AddDhikrForm> {
  final _text = TextEditingController();
  final _number = TextEditingController();
  int _target = 33;

  @override
  void dispose() {
    _text.dispose();
    _number.dispose();
    super.dispose();
  }

  int? get _chosen => switch (_target) {
        _unlimited => null,
        _otherNumber => _parseCount(_number.text),
        _ => _target,
      };

  bool get _valid =>
      _text.text.trim().isNotEmpty &&
      (_target != _otherNumber || _chosen != null);

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final label = AppTypography.footnote.copyWith(color: c.secondaryLabel);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.md,
          AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _text,
            autofocus: true,
            placeholder:
                context.tr('مثال: سبحان الله وبحمده', 'e.g. سبحان الله وبحمده'),
            minLines: 1,
            maxLines: 3,
            maxLength: 120,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(context.tr('عدد المرات', 'How many times'), style: label),
          const SizedBox(height: AppSpacing.sm),
          AppSegmentedControl<int>(
            segments: {
              33: '33',
              100: '100',
              _unlimited: context.tr('بلا حدّ', 'No limit'),
              _otherNumber: context.tr('عدد آخر', 'Other'),
            },
            value: _target,
            onChanged: (v) => setState(() => _target = v),
          ),
          if (_target == _otherNumber) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _number,
              ltr: true,
              placeholder: '33',
              keyboardType: TextInputType.number,
              inputFormatters: _countFormatters,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton.filled(
            label: context.tr('إضافة الذكر', 'Add dhikr'),
            expand: true,
            onPressed: _valid
                ? () => Navigator.of(context)
                    .pop((text: _text.text.trim(), target: _chosen))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Bead material, tap sound and haptics; changes apply as they are made.
Future<void> showTasbihSettingsSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: context.tr('إعدادات المسبحة', 'Tasbih settings'),
    builder: (_) => Consumer(builder: (context, ref, _) {
      final settings = ref.watch(tasbihProvider.select((s) => s.settings));
      void update(TasbihSettings s) =>
          ref.read(tasbihProvider.notifier).updateSettings(s);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListSection(
            header: context.tr('الحبّات', 'Beads'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.ms),
                child: Row(
                  children: [
                    for (final m in BeadMaterial.values)
                      Expanded(
                        child: _MaterialOption(
                          material: m,
                          selected: settings.material == m,
                          onTap: () => update(settings.copyWith(material: m)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          AppListSection(
            footer: defaultTargetPlatform == TargetPlatform.android
                ? context.tr('يتبع صوت النقر إعداد «أصوات اللمس» في جهازك.',
                    'The tap sound follows your device\'s touch sounds setting.')
                : null,
            children: [
              AppListTile(
                title: context.tr('صوت النقر', 'Tap sound'),
                trailing: AppSwitch(
                  value: settings.sound,
                  onChanged: (v) => update(settings.copyWith(sound: v)),
                ),
              ),
              AppListTile(
                title: context.tr('الاهتزاز', 'Haptics'),
                subtitle: context.tr('نقرة خفيفة مع كل حبّة، وأقوى عند الهدف',
                    'A light tap per bead, a stronger one at the target'),
                trailing: AppSwitch(
                  value: settings.haptics,
                  onChanged: (v) => update(settings.copyWith(haptics: v)),
                ),
              ),
            ],
          ),
        ],
      );
    }),
  );
}

class _MaterialOption extends StatelessWidget {
  const _MaterialOption({
    required this.material,
    required this.selected,
    required this.onTap,
  });

  final BeadMaterial material;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: material.label(context),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              padding: const EdgeInsets.all(3),
              decoration: ShapeDecoration(
                shape: CircleBorder(
                  side: BorderSide(
                    color: selected ? c.accent : CupertinoColors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: BeadSwatch(material: material, size: 48),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              material.label(context),
              style: AppTypography.footnote
                  .weight(selected ? FontWeight.w600 : FontWeight.w400)
                  .copyWith(color: selected ? c.accent : c.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's count, the all-time count, and each dhikr's all-time count.
Future<void> showTasbihStatsSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: context.tr('الإحصاءات', 'Statistics'),
    builder: (_) => Consumer(builder: (context, ref, _) {
      final state = ref.watch(tasbihProvider);
      final today = ref.watch(tasbihTodayProvider);
      final rows = [...state.adhkar]..sort((a, b) =>
          state.stats.totalOf(b.id).compareTo(state.stats.totalOf(a.id)));

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListSection(
            children: [
              AppListTile(
                title: context.tr('اليوم', 'Today'),
                value: formatCount(today),
              ),
              AppListTile(
                title: context.tr('منذ البداية', 'All time'),
                value: formatCount(state.stats.allTime),
              ),
            ],
          ),
          AppListSection(
            header: context.tr('لكل ذكر، منذ البداية', 'Per dhikr, all time'),
            children: [
              for (final d in rows)
                AppListTile(
                  title: d.text,
                  value: formatCount(state.stats.totalOf(d.id)),
                ),
            ],
          ),
        ],
      );
    }),
  );
}
