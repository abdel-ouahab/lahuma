import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../quran/mushaf/presentation/mushaf_providers.dart';
import '../../domain/khatma.dart';
import '../../domain/khatma_planner.dart';
import '../../domain/quran_pages.dart';
import '../khatma_providers.dart';
import '../widgets/khatma_labels.dart';
import '../widgets/page_picker_sheet.dart';

/// Creates a khatma, or edits the active one: duration (days or an end
/// date), where to start, the unit to show it in, and the reminders, with
/// a live preview of the daily portion.
class KhatmaSetupScreen extends ConsumerStatefulWidget {
  const KhatmaSetupScreen({super.key, this.edit = false, this.initialDays});

  static const String path = '/khatma/setup';
  static const String editPath = '/khatma/edit';

  /// The setup screen with [days] already chosen.
  static String pathFor(int days) => '$path?days=$days';

  static const List<int> presets = [7, 10, 15, 30, 60];
  static const int maxDays = 730;

  final bool edit;

  /// The duration to start from instead of 30 days (ignored when editing).
  final int? initialDays;

  @override
  ConsumerState<KhatmaSetupScreen> createState() => _KhatmaSetupScreenState();
}

class _KhatmaSetupScreenState extends ConsumerState<KhatmaSetupScreen> {
  bool _initialised = false;
  bool _saving = false;

  bool _byDate = false;
  int _days = 30;
  late DateTime _endDate;
  bool _fromStart = true;
  int _startPage = 1;
  ReadingUnit _unit = ReadingUnit.pages;
  bool _morning = true;
  int _morningMinutes = Khatma.defaultMorningMinutes;
  bool _evening = false;
  int _eveningMinutes = Khatma.defaultEveningMinutes;

  DateTime get _today => dateOnly(ref.read(khatmaClockProvider)());

  void _init(Khatma? k) {
    _initialised = true;
    final today = _today;
    final initial = widget.initialDays;
    if (initial != null) _days = initial.clamp(1, KhatmaSetupScreen.maxDays);
    _endDate = KhatmaPlanner.endDateFor(today, _days);
    if (!widget.edit || k == null) return;
    _days = math.max(1, KhatmaPlanner.remainingDays(k.endDate, today));
    _endDate = daysBetween(today, k.endDate) < 0 ? today : k.endDate;
    _unit = k.displayUnit;
    _morning = k.morningEnabled;
    _morningMinutes = k.morningMinutes;
    _evening = k.eveningEnabled;
    _eveningMinutes = k.eveningMinutes;
  }

  DateTime get _end =>
      _byDate ? _endDate : KhatmaPlanner.endDateFor(_today, _days);

  /// The last page read when today began: what the plan counts from.
  int _position(Khatma? k) {
    if (widget.edit && k != null) {
      return math.min(
          KhatmaPlanner.dayPlan(k, _today).startPage, k.lastPageRead);
    }
    return (_fromStart ? 1 : _startPage) - 1;
  }

  Future<void> _customDays() async {
    final picked = await showAppPicker<int>(
      context,
      title: context.tr('عدد الأيام', 'Number of days'),
      items: [for (var d = 1; d <= KhatmaSetupScreen.maxDays; d++) d],
      selected: _days,
      labelOf: (d) => daysLabel(context, d),
    );
    if (picked != null) setState(() => _days = picked);
  }

  Future<void> _pickEndDate() async {
    final today = _today;
    final picked = await showAppDatePicker(
      context,
      title: context.tr('تاريخ الختم', 'Finish by'),
      initial: _endDate,
      minimum: today,
      maximum: addDays(today, KhatmaSetupScreen.maxDays),
    );
    if (picked != null) setState(() => _endDate = dateOnly(picked));
  }

  Future<void> _pickPage() async {
    final page = await showPagePickerSheet(
      context,
      title: context.tr('أبدأ من صفحة', 'Start from page'),
      initial: _startPage,
      confirmLabel: context.tr('تم', 'Done'),
    );
    if (page != null) setState(() => _startPage = page);
  }

  Future<void> _pickSurah() async {
    final arabic = context.isArabic;
    final current = QuranPages.surahAt(_startPage);
    final surah = await showAppPicker<int>(
      context,
      title: context.tr('أبدأ من سورة', 'Start from surah'),
      items: [for (var s = 1; s <= 114; s++) s],
      selected: current,
      labelOf: (s) {
        final page = QuranPages.surahStartPage(s);
        return '$s. ${QuranPages.surahName(page, arabic: arabic)}';
      },
    );
    if (surah != null) {
      setState(() => _startPage = QuranPages.surahStartPage(surah));
    }
  }

  Future<void> _pickTime(bool morning) async {
    final minutes = morning ? _morningMinutes : _eveningMinutes;
    final today = _today;
    final picked = await showAppDatePicker(
      context,
      title: morning
          ? context.tr('وقت التذكير اليومي', 'Daily reminder time')
          : context.tr('وقت التذكير المسائي', 'Evening reminder time'),
      mode: CupertinoDatePickerMode.time,
      initial: DateTime(
          today.year, today.month, today.day, minutes ~/ 60, minutes % 60),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (morning) {
        _morningMinutes = m;
      } else {
        _eveningMinutes = m;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    if (_morning || _evening) {
      final notifications = ref.read(localNotificationsProvider);
      if (!await notifications.areEnabled()) {
        await notifications.requestPermission();
      }
    }
    final notifier = ref.read(khatmaProvider.notifier);
    if (widget.edit) {
      await notifier.edit(
        endDate: _end,
        displayUnit: _unit,
        morningEnabled: _morning,
        morningMinutes: _morningMinutes,
        eveningEnabled: _evening,
        eveningMinutes: _eveningMinutes,
      );
    } else {
      await notifier.create(
        endDate: _end,
        startPage: _fromStart ? 1 : _startPage,
        displayUnit: _unit,
        morningEnabled: _morning,
        morningMinutes: _morningMinutes,
        eveningEnabled: _evening,
        eveningMinutes: _eveningMinutes,
      );
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(khatmaProvider);
    if (!state.loaded) return const AppScaffold(child: AppLoader());
    final active = state.active;
    if (!_initialised) _init(active);
    final today = _today;
    final mushafPage = ref.watch(mushafProvider.select((m) => m.lastPage));

    return AppScaffold(
      title: widget.edit
          ? context.tr('تعديل الختمة', 'Edit khatma')
          : context.tr('ختمة جديدة', 'New khatma'),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: AppSpacing.screenInsets,
                  child: _Preview(
                    position: _position(active),
                    endDate: _end,
                    today: today,
                    unit: _unit,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Duration ─────────────────────────────────────────
                AppListSection(
                  header: context.tr('المدة', 'Duration'),
                  footer: widget.edit
                      ? context.tr('ما قرأته اليوم يبقى محسوبًا من ورد اليوم.',
                          "What you read today still counts towards today's portion.")
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.ms),
                      child: AppSegmentedControl<bool>(
                        segments: {
                          false: context.tr('عدد الأيام', 'Number of days'),
                          true: context.tr('تاريخ الختم', 'End date'),
                        },
                        value: _byDate,
                        onChanged: (v) => setState(() {
                          if (v && !_byDate) {
                            _endDate = KhatmaPlanner.endDateFor(today, _days);
                          } else if (!v && _byDate) {
                            _days =
                                KhatmaPlanner.remainingDays(_endDate, today);
                          }
                          _byDate = v;
                        }),
                      ),
                    ),
                    if (_byDate)
                      AppListTile(
                        title: context.tr('أختم يوم', 'Finish on'),
                        value: dateLabel(context, _endDate),
                        onTap: _pickEndDate,
                      )
                    else
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.ms, 0, AppSpacing.ms, AppSpacing.ms),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final d in KhatmaSetupScreen.presets)
                              _Chip(
                                label: daysLabel(context, d),
                                selected: _days == d,
                                onTap: () => setState(() => _days = d),
                              ),
                            _Chip(
                              label: KhatmaSetupScreen.presets.contains(_days)
                                  ? context.tr('مدة أخرى…', 'Other…')
                                  : daysLabel(context, _days),
                              selected:
                                  !KhatmaSetupScreen.presets.contains(_days),
                              onTap: _customDays,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // ── Start point ──────────────────────────────────────
                if (!widget.edit)
                  AppListSection(
                    header: context.tr('نقطة البداية', 'Start from'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.ms),
                        child: AppSegmentedControl<bool>(
                          segments: {
                            true: context.tr('أول المصحف', 'The beginning'),
                            false: context.tr('موضع معيّن', 'A given place'),
                          },
                          value: _fromStart,
                          onChanged: (v) => setState(() => _fromStart = v),
                        ),
                      ),
                      if (!_fromStart) ...[
                        AppListTile(
                          title: context.tr('الصفحة', 'Page'),
                          value: pageLabel(context, _startPage),
                          onTap: _pickPage,
                        ),
                        AppListTile(
                          title: context.tr('أو اختر سورة', 'Or pick a surah'),
                          onTap: _pickSurah,
                          chevron: true,
                        ),
                        if (mushafPage > 1 && mushafPage != _startPage)
                          AppListTile(
                            title: context.tr('حيث توقفت في المصحف',
                                'Where I stopped in the Mushaf'),
                            value: ltr('$mushafPage'),
                            onTap: () =>
                                setState(() => _startPage = mushafPage),
                          ),
                      ],
                    ],
                  ),

                // ── Unit ─────────────────────────────────────────────
                AppListSection(
                  header: context.tr('عرض الورد بـ', 'Show the portion in'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.ms),
                      child: AppSegmentedControl<ReadingUnit>(
                        segments: {
                          for (final u in ReadingUnit.values)
                            u: unitName(context, u),
                        },
                        value: _unit,
                        onChanged: (u) => setState(() => _unit = u),
                      ),
                    ),
                  ],
                ),

                // ── Reminders ────────────────────────────────────────
                AppListSection(
                  header: context.tr('التذكير', 'Reminders'),
                  footer: context.tr(
                      'يتغيّر نص التذكير كلما سجّلت تقدّمك، ولا يصلك المسائي إن أتممت وردك.',
                      "The reminder's text follows your progress; the evening one is skipped once today's portion is done."),
                  children: [
                    AppListTile(
                      title: context.tr('تذكير يومي بالورد', 'Daily reminder'),
                      trailing: AppSwitch(
                        value: _morning,
                        onChanged: (v) => setState(() => _morning = v),
                      ),
                    ),
                    if (_morning)
                      AppListTile(
                        title: context.tr('الوقت', 'Time'),
                        value: minutesLabel(context, _morningMinutes),
                        onTap: () => _pickTime(true),
                      ),
                    AppListTile(
                      title: context.tr('تذكير مسائي إن لم أُتمّ وردي',
                          'Evening reminder if not done'),
                      trailing: AppSwitch(
                        value: _evening,
                        onChanged: (v) => setState(() => _evening = v),
                      ),
                    ),
                    if (_evening)
                      AppListTile(
                        title: context.tr('الوقت', 'Time'),
                        value: minutesLabel(context, _eveningMinutes),
                        onTap: () => _pickTime(false),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                  AppSpacing.sm, AppSpacing.screenMargin, AppSpacing.sm),
              child: AppButton.filled(
                label: widget.edit
                    ? context.tr('حفظ التعديل', 'Save changes')
                    : context.tr('ابدأ الختمة', 'Start the khatma'),
                icon: widget.edit
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.book_fill,
                expand: true,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "ستقرأ نحو 20 صفحة (جزء واحد) يوميًا" and when the khatma ends.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.position,
    required this.endDate,
    required this.today,
    required this.unit,
  });

  final int position;
  final DateTime endDate;
  final DateTime today;
  final ReadingUnit unit;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final daily = KhatmaPlanner.dailyTarget(
        lastPageRead: position, endDate: endDate, today: today);
    final days = KhatmaPlanner.remainingDays(endDate, today);
    final pages = KhatmaPlanner.remainingPages(position);
    return AppCard(
      child: Row(
        children: [
          AppIconTile(
              icon: CupertinoIcons.book_fill, color: c.accent, size: 44),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                      'ستقرأ نحو ${amountWithPages(context, daily, unit)} يوميًا',
                      "You'll read about ${amountWithPages(context, daily, unit)} a day"),
                  style: AppTypography.headline.copyWith(color: c.label),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.tr(
                      '${pagesLabel(context, pages)} في ${daysLabel(context, days)} · تختم ${dateLabel(context, endDate)}',
                      '${pagesLabel(context, pages)} in ${daysLabel(context, days)} · done by ${dateLabel(context, endDate)}'),
                  style:
                      AppTypography.footnote.copyWith(color: c.secondaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.of(context),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: ShapeDecoration(
            color: selected ? c.accent : c.tertiaryFill,
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            style: AppTypography.subheadline.copyWith(
              color: selected ? c.onAccent : c.label,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
