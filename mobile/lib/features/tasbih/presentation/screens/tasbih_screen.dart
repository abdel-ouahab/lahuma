import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/tasbih.dart';
import '../tasbih_providers.dart';
import '../widgets/dhikr_selector.dart';
import '../widgets/misbaha.dart';
import '../widgets/tasbih_labels.dart';
import '../widgets/tasbih_sheets.dart';

enum _ChipAction { target, delete }

/// Digital misbaha: pick a dhikr, tap the beads to count towards its target,
/// undo or reset, and see today's and all-time counts.
class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  static const String path = '/tasbih';

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen> {
  int _celebration = 0;

  /// The dhikr whose target was just reached; shows the completion card.
  String? _completedId;

  /// Taps right after reaching a target are dropped, so a fast run of taps
  /// doesn't count past it by accident.
  DateTime? _lockedUntil;

  TasbihNotifier get _notifier => ref.read(tasbihProvider.notifier);

  void _count() {
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) return;

    final tap = _notifier.increment();
    if (tap == TasbihTap.ignored) return;
    final settings = ref.read(tasbihProvider).settings;
    if (settings.sound) SystemSound.play(SystemSoundType.click);
    if (settings.haptics) _haptic(tap);

    if (tap == TasbihTap.reached) {
      setState(() {
        _celebration++;
        _completedId = ref.read(tasbihProvider).currentId;
        _lockedUntil = now.add(const Duration(milliseconds: 700));
      });
    } else if (_completedId != null) {
      // Tapping on is "continue".
      setState(() => _completedId = null);
    }
  }

  void _haptic(TasbihTap tap) {
    switch (tap) {
      case TasbihTap.reached:
        HapticFeedback.heavyImpact();
        Future.delayed(
            const Duration(milliseconds: 140), HapticFeedback.vibrate);
      case TasbihTap.round:
        HapticFeedback.mediumImpact();
      case TasbihTap.counted:
        HapticFeedback.lightImpact();
      case TasbihTap.ignored:
        break;
    }
  }

  void _undo() {
    if (!_notifier.undo()) return;
    if (ref.read(tasbihProvider).settings.haptics) {
      HapticFeedback.selectionClick();
    }
    setState(() => _completedId = null);
  }

  Future<void> _reset(TasbihDhikr dhikr) async {
    final confirmed = await showAppDialog<bool>(
      context,
      title: context.tr('تصفير العدّاد؟', 'Reset the counter?'),
      message: context.tr(
          'يعود عدّ «${dhikr.text}» إلى صفر. تبقى الإحصاءات كما هي.',
          'The count for «${dhikr.text}» goes back to zero. Statistics stay as they are.'),
      actions: [
        AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
        AppDialogAction(
          label: context.tr('تصفير', 'Reset'),
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    _notifier.reset();
    setState(() => _completedId = null);
  }

  void _next() {
    _notifier.next();
    setState(() => _completedId = null);
  }

  void _select(TasbihDhikr dhikr) {
    _notifier.select(dhikr.id);
    setState(() => _completedId = null);
  }

  Future<void> _options(TasbihDhikr dhikr) async {
    final action = await showAppActionSheet<_ChipAction>(
      context,
      title: dhikr.text,
      actions: [
        AppSheetAction(
          label: context.tr('تغيير الهدف', 'Change target'),
          value: _ChipAction.target,
          icon: CupertinoIcons.scope,
        ),
        if (dhikr.custom)
          AppSheetAction(
            label: context.tr('حذف الذكر', 'Delete dhikr'),
            value: _ChipAction.delete,
            icon: CupertinoIcons.trash,
            isDestructive: true,
          ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _ChipAction.target:
        await showTargetSheet(context, ref, dhikr);
      case _ChipAction.delete:
        final confirmed = await showAppDialog<bool>(
          context,
          title: context.tr('حذف «${dhikr.text}»؟', 'Delete «${dhikr.text}»?'),
          message: context.tr('يُحذف الذكر مع عدّه وإحصاءاته.',
              'The dhikr is deleted with its count and statistics.'),
          actions: [
            AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
            AppDialogAction(
              label: context.tr('حذف', 'Delete'),
              value: true,
              isDestructive: true,
            ),
          ],
        );
        if (confirmed == true) _notifier.remove(dhikr.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasbihProvider);
    final dhikr = state.current;
    final count = state.count;

    return AppScaffold(
      title: context.tr('التسبيح', 'Tasbih'),
      trailing: AppIconButton(
        icon: CupertinoIcons.slider_horizontal_3,
        label: context.tr('إعدادات المسبحة', 'Tasbih settings'),
        onPressed: () => showTasbihSettingsSheet(context),
      ),
      child: SafeArea(
        child: !state.loaded
            ? const SizedBox.expand()
            : Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: AppSpacing.xs),
                      DhikrSelector(
                        adhkar: state.adhkar,
                        selectedId: dhikr.id,
                        isReached: state.reached,
                        onSelected: _select,
                        onOptions: _options,
                        onAdd: () => showAddDhikrSheet(context, ref),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenMargin,
                            vertical: AppSpacing.sm,
                          ),
                          child: Misbaha(
                            dhikr: dhikr,
                            count: count,
                            material: state.settings.material,
                            celebration: _celebration,
                            onTap: _count,
                          ),
                        ),
                      ),
                      _Controls(
                        target: dhikr.target,
                        canUndo: count > 0,
                        onUndo: _undo,
                        onTarget: () => showTargetSheet(context, ref, dhikr),
                        onReset: count > 0 ? () => _reset(dhikr) : null,
                      ),
                      _TodayRow(onTap: () => showTasbihStatsSheet(context)),
                    ],
                  ),
                  PositionedDirectional(
                    start: AppSpacing.screenMargin,
                    end: AppSpacing.screenMargin,
                    bottom: AppSpacing.sm,
                    child: AnimatedSwitcher(
                      duration: AppMotion.of(context),
                      switchInCurve: AppMotion.curve,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _completedId == dhikr.id
                          ? _CompletionCard(
                              key: ValueKey(dhikr.id),
                              dhikr: dhikr,
                              onContinue: () =>
                                  setState(() => _completedId = null),
                              onNext: _next,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Undo · target · reset.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.target,
    required this.canUndo,
    required this.onUndo,
    required this.onTarget,
    required this.onReset,
  });

  final int? target;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onTarget;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenInsets,
      child: Row(
        children: [
          Expanded(
            child: _RoundAction(
              icon: CupertinoIcons.arrow_uturn_left,
              directional: true,
              label: context.tr('تراجع', 'Undo'),
              onPressed: canUndo ? onUndo : null,
            ),
          ),
          AppButton.tinted(
            label: targetLabel(context, target),
            icon: target == null ? CupertinoIcons.infinite : CupertinoIcons.scope,
            small: true,
            onPressed: onTarget,
          ),
          Expanded(
            child: _RoundAction(
              icon: CupertinoIcons.arrow_counterclockwise,
              label: context.tr('تصفير', 'Reset'),
              onPressed: onReset,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.directional = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Mirror the glyph in Arabic (it points "back").
  final bool directional;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final color = onPressed == null ? c.tertiaryLabel : c.accent;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppSpacing.minTouchTarget),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.tertiaryFill,
                shape: BoxShape.circle,
              ),
              child: directional
                  ? AppDirectionalIcon(icon, size: 20, color: color)
                  : Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption1.copyWith(
                color: onPressed == null ? c.tertiaryLabel : c.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1,240 تسبيحة اليوم … الإحصاءات ›" — opens the stats sheet.
class _TodayRow extends ConsumerWidget {
  const _TodayRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final today = ref.watch(tasbihTodayProvider);
    return Semantics(
      button: true,
      child: CupertinoButton(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screenMargin,
            AppSpacing.sm, AppSpacing.screenMargin - AppSpacing.xs, 0),
        minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(CupertinoIcons.chart_bar_alt_fill,
                size: 16, color: c.secondaryLabel),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                tasbihatToday(context, today),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
              ),
            ),
            Text(
              context.tr('الإحصاءات', 'Statistics'),
              style: AppTypography.footnote.copyWith(color: c.accent),
            ),
            AppDirectionalIcon(CupertinoIcons.chevron_forward,
                size: 13, color: c.accent),
          ],
        ),
      ),
    );
  }
}

/// Shown when a target is reached: keep counting, or go to the next dhikr.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    super.key,
    required this.dhikr,
    required this.onContinue,
    required this.onNext,
  });

  final TasbihDhikr dhikr;
  final VoidCallback onContinue;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      liveRegion: true,
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.checkmark_seal_fill,
                    size: 30, color: c.success),
                const SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('تقبّل الله منك', 'May Allah accept it'),
                        style: AppTypography.headline.copyWith(color: c.label),
                      ),
                      Text(
                        context.tr(
                            'أتممت ${ltr(formatCount(dhikr.target ?? 0))} من «${dhikr.text}»',
                            'You completed ${formatCount(dhikr.target ?? 0)} of «${dhikr.text}»'),
                        style: AppTypography.footnote
                            .copyWith(color: c.secondaryLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.ms),
            Row(
              children: [
                Expanded(
                  child: AppButton.tinted(
                    label: context.tr('متابعة العدّ', 'Keep counting'),
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: AppButton.filled(
                    label: context.tr('الذكر التالي', 'Next dhikr'),
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
