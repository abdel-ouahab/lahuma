import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../data/contact_picker.dart';
import '../../data/fajr_call_platform.dart';
import '../../data/fajr_notifications.dart';
import '../../domain/fajr_call_list.dart';
import '../../domain/fajr_contact.dart';
import '../fajr_call_providers.dart';
import '../widgets/contact_form_sheet.dart';
import '../widgets/fajr_call_labels.dart';
import '../widgets/fajr_form_rows.dart';
import '../widgets/prayer_settings_sheet.dart';
import 'fajr_call_lists_screen.dart';

final contactPickerProvider = Provider((ref) => const ContactPicker());

/// SIMs / calling accounts (Android, dual SIM). Empty elsewhere.
final phoneAccountsProvider = FutureProvider<List<PhoneAccountOption>>(
    (ref) => ref.watch(fajrCallPlatformProvider).phoneAccounts());

String _newId() => 'l${DateTime.now().microsecondsSinceEpoch}';

/// The international code for numbers typed in local format, from the
/// device region (`ar_DZ` → 213).
String? _deviceDialCode() {
  final country =
      WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  return country == null ? null : kDialCodes[country.toUpperCase()];
}

/// Creates or edits a Fajr list. Changes are kept in a draft until "Save".
class FajrCallEditScreen extends ConsumerStatefulWidget {
  const FajrCallEditScreen({super.key, this.listId});

  /// Null for a new list.
  final String? listId;

  @override
  ConsumerState<FajrCallEditScreen> createState() =>
      _FajrCallEditScreenState();
}

class _FajrCallEditScreenState extends ConsumerState<FajrCallEditScreen> {
  FajrCallList? _original;
  late FajrCallList _draft;
  TextEditingController? _name;
  bool _advanced = false;
  bool _saving = false;
  bool _initialised = false;

  bool get _isNew => _original == null;
  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  bool get _dirty => _isNew || _draft != _original;

  /// Builds the draft once the lists are loaded (a deep link can open this
  /// screen before they are), so an existing list is never mistaken for a
  /// new one.
  void _initDraft(FajrCallState state) {
    _initialised = true;
    final existing =
        widget.listId == null ? null : state.listById(widget.listId!);
    _original = existing;
    _draft = existing ??
        FajrCallList(
          id: _newId(),
          // The first list is for one's parents; that is what Lahuma is for.
          name: state.lists.isEmpty
              ? context.tr('والداي', 'My parents')
              : context.tr('قائمة جديدة', 'New list'),
          enabled: true,
          mode: _android ? FajrCallMode.auto : FajrCallMode.manual,
        );
    _name = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  void _update(FajrCallList next) => setState(() => _draft = next);

  // ── Contacts ──────────────────────────────────────────────────────────

  Future<void> _addFromContacts() async {
    final picked = await ref.read(contactPickerProvider).pick();
    if (picked == null || !mounted) return;
    final contact = await ContactFormSheet.show(
      context,
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      dialCode: _deviceDialCode(),
      name: picked.name,
      phone: picked.phone,
    );
    if (contact != null) _addContact(contact);
  }

  Future<void> _addManually() async {
    final contact = await ContactFormSheet.show(
      context,
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      dialCode: _deviceDialCode(),
    );
    if (contact != null) _addContact(contact);
  }

  void _addContact(FajrContact contact) {
    if (_draft.contacts.any((c) => c.phone == contact.phone)) {
      AppToast.show(context,
          context.tr('هذا الرقم في القائمة', 'That number is already listed'),
          icon: CupertinoIcons.info_circle);
      return;
    }
    _update(_draft.copyWith(contacts: [..._draft.contacts, contact]));
  }

  Future<void> _editContact(FajrContact contact) async {
    final edited = await ContactFormSheet.show(
      context,
      id: contact.id,
      dialCode: _deviceDialCode(),
      initial: contact,
    );
    if (edited == null) return;
    _update(_draft.copyWith(contacts: [
      for (final c in _draft.contacts) c.id == contact.id ? edited : c,
    ]));
  }

  void _removeContact(FajrContact contact) {
    final before = _draft.contacts;
    _update(_draft.copyWith(
        contacts: [for (final c in before) if (c.id != contact.id) c]));
    AppToast.show(
      context,
      context.tr('حُذف ${contact.name}', 'Removed ${contact.name}'),
      icon: CupertinoIcons.trash,
      actionLabel: context.tr('تراجع', 'Undo'),
      onAction: () => _update(_draft.copyWith(contacts: before)),
    );
  }

  void _reorder(int from, int to) {
    final contacts = [..._draft.contacts];
    contacts.insert(to, contacts.removeAt(from));
    _update(_draft.copyWith(contacts: contacts));
  }

  // ── Time ──────────────────────────────────────────────────────────────

  Future<void> _pickFixedTime() async {
    final now = DateTime.now();
    final t = _draft.fixedTime;
    final picked = await showAppDatePicker(
      context,
      title: context.tr('وقت الاتصال', 'Call time'),
      mode: CupertinoDatePickerMode.time,
      initial: DateTime(now.year, now.month, now.day, t.hour, t.minute),
    );
    if (picked != null) {
      _update(_draft.copyWith(
          fixedTime: TimeOfDayHm(picked.hour, picked.minute)));
    }
  }

  Future<void> _pickSim(List<PhoneAccountOption> accounts) async {
    final options = [null, ...accounts.map((a) => a.id)];
    final picked = await showAppPicker<String?>(
      context,
      title: context.tr('الاتصال من', 'Call from'),
      items: options,
      selected: _draft.phoneAccountId,
      labelOf: (id) => id == null
          ? context.tr('الشريحة الافتراضية', 'Default SIM')
          : accounts.firstWhere((a) => a.id == id).label,
    );
    if (!mounted) return;
    _update(picked == null
        ? _draft.copyWith(clearPhoneAccount: true)
        : _draft.copyWith(phoneAccountId: picked));
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _name!.text.trim();
    final list = _draft.copyWith(
        name: name.isEmpty ? context.tr('والداي', 'My parents') : name);
    if (list.enabled && list.contacts.isEmpty) {
      AppToast.show(context,
          context.tr('أضف شخصًا واحدًا على الأقل', 'Add at least one person'),
          icon: CupertinoIcons.person_badge_plus_fill);
      return;
    }
    final prayer = ref.read(fajrCallProvider).prayer;
    if (list.startMode == FajrStartMode.fajr && !prayer.hasLocation) {
      await PrayerSettingsSheet.show(context);
      if (!mounted) return;
    }
    setState(() => _saving = true);
    await ref.read(fajrCallProvider.notifier).saveList(list);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _original = list;
      _draft = list;
    });
    HapticFeedback.lightImpact();

    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(StorageKeys.fajrCallPermissionsShown) ?? false;
    if (!mounted) return;
    if (list.enabled && !shown) {
      context.pushReplacement('${FajrCallListsScreen.path}/permissions?first=1');
    } else {
      AppToast.show(context, context.tr('حُفظت القائمة', 'List saved'),
          icon: CupertinoIcons.checkmark_alt);
      if (context.canPop()) context.pop();
    }
  }

  Future<void> _testNow() async {
    final names = _draft.contacts.map((c) => c.name).join(context.isArabic ? '، ' : ', ');
    final ok = await showAppDialog<bool>(
      context,
      title: context.tr('اتصال حقيقي الآن؟', 'Place real calls now?'),
      message: context.tr(
        'سيتصل التطبيق الآن فعلًا بـ $names من شريحتك، وقد يكلّفك ذلك رصيدًا.',
        'The app will really call $names now from your SIM, which may cost credit.',
      ),
      actions: [
        AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
        AppDialogAction(
            label: context.tr('اتصل الآن', 'Call now'),
            value: true,
            isDefault: true),
      ],
    );
    if (ok != true || !mounted) return;
    final started = await ref.read(fajrCallProvider.notifier).runNow(_draft);
    if (!mounted) return;
    AppToast.show(
      context,
      started
          ? context.tr('بدأ الاتصال. يمكنك إيقافه من الإشعار.',
              'Calling started. Stop it from the notification.')
          : context.tr('تعذّر البدء. راجع الأذونات.',
              "Couldn't start. Check the permissions."),
      icon: started
          ? CupertinoIcons.phone_fill
          : CupertinoIcons.exclamationmark_circle,
    );
  }

  Future<void> _delete() async {
    final ok = await showAppDialog<bool>(
      context,
      title: context.tr('حذف القائمة؟', 'Delete this list?'),
      message: context.tr('يبقى سجلّها محفوظًا حتى تمسحه.',
          'Its log is kept until you clear it.'),
      actions: [
        AppDialogAction(label: context.tr('إلغاء', 'Cancel'), value: false),
        AppDialogAction(
            label: context.tr('حذف', 'Delete'),
            value: true,
            isDestructive: true),
      ],
    );
    if (ok != true || !mounted) return;
    await ref.read(fajrCallProvider.notifier).deleteList(_draft.id);
    if (mounted && context.canPop()) context.pop();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showAppDialog<bool>(
      context,
      title: context.tr('تجاهل التغييرات؟', 'Discard changes?'),
      actions: [
        AppDialogAction(label: context.tr('متابعة التعديل', 'Keep editing'), value: false),
        AppDialogAction(
            label: context.tr('تجاهل', 'Discard'),
            value: true,
            isDestructive: true),
      ],
    );
    return discard ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fajrCallProvider);
    if (!state.loaded) {
      return const AppScaffold(child: AppLoader());
    }
    if (!_initialised) _initDraft(state);
    final now = ref.watch(fajrClockProvider)();
    final schedule = ref.watch(fajrScheduleProvider);
    final fajrToday = schedule.prayerTimes.fajrOn(state.prayer, now);
    final next = _draft.contacts.isEmpty
        ? null
        : schedule.next(_draft.copyWith(enabled: true), state.prayer, from: now);
    final accounts =
        ref.watch(phoneAccountsProvider).valueOrNull ?? const <PhoneAccountOption>[];
    final effective = state.effectiveMode(_draft);
    final auto = _draft.mode == FajrCallMode.auto;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _original = _draft);
          // Leave on the next frame, once canPop reflects the decision.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => context.mounted ? context.pop() : null);
        }
      },
      child: AppScaffold(
        title: _isNew
            ? context.tr('قائمة جديدة', 'New list')
            : context.tr('تعديل القائمة', 'Edit list'),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // ── Name & switch ───────────────────────────────────
                  AppListSection(
                    header: context.tr('اسم القائمة', 'List name'),
                    children: [
                      AppTextFormRow(
                        controller: _name,
                        placeholder: context.tr('والداي', 'My parents'),
                        onChanged: (v) => _update(_draft.copyWith(name: v)),
                      ),
                      AppListTile(
                        title: context.tr('مفعّلة', 'On'),
                        trailing: AppSwitch(
                          value: _draft.enabled,
                          onChanged: (v) =>
                              _update(_draft.copyWith(enabled: v)),
                        ),
                      ),
                    ],
                  ),

                  // ── Time ────────────────────────────────────────────
                  AppListSection(
                    header: context.tr('وقت الاتصال', 'Call time'),
                    footer: next == null
                        ? null
                        : context.tr(
                            'أول نداء: ${formatFire(context, next, now)}',
                            'First call: ${formatFire(context, next, now)}'),
                    children: [
                      AppPaddedRow(
                        child: AppSegmentedControl<FajrStartMode>(
                          segments: {
                            FajrStartMode.fajr:
                                context.tr('وقت الفجر', 'At Fajr'),
                            FajrStartMode.fixed:
                                context.tr('وقت محدد', 'Fixed time'),
                          },
                          value: _draft.startMode,
                          onChanged: (m) =>
                              _update(_draft.copyWith(startMode: m)),
                        ),
                      ),
                      if (_draft.startMode == FajrStartMode.fajr) ...[
                        // The location lives in Settings; this row only
                        // offers it when it is still missing.
                        AppListTile(
                          title: context.tr('الفجر اليوم', 'Fajr today'),
                          subtitle: state.prayer.hasLocation
                              ? state.prayer.placeName
                              : context.tr('حدّد موقعك في الإعدادات',
                                  'Set your location in Settings'),
                          value: fajrToday == null
                              ? null
                              : formatClock(context, fajrToday),
                          onTap: state.prayer.hasLocation
                              ? null
                              : () => PrayerSettingsSheet.show(context),
                        ),
                        AppStepperRow(
                          title: context.tr('التوقيت', 'Timing'),
                          value: _draft.fajrOffsetMinutes,
                          min: FajrCallList.minFajrOffset,
                          max: FajrCallList.maxFajrOffset,
                          step: 5,
                          label: (m) => minutesOffset(context, m),
                          onChanged: (m) =>
                              _update(_draft.copyWith(fajrOffsetMinutes: m)),
                        ),
                      ] else
                        AppListTile(
                          title: context.tr('الوقت', 'Time'),
                          value: formatClock(
                              context,
                              DateTime(2000, 1, 1, _draft.fixedTime.hour,
                                  _draft.fixedTime.minute)),
                          onTap: _pickFixedTime,
                        ),
                      AppListTile(
                        title: context.tr('كل يوم', 'Every day'),
                        subtitle: _draft.repeatDaily
                            ? null
                            : context.tr('مرة واحدة ثم تتوقف',
                                'Once, then it switches off'),
                        trailing: AppSwitch(
                          value: _draft.repeatDaily,
                          onChanged: (v) =>
                              _update(_draft.copyWith(repeatDaily: v)),
                        ),
                      ),
                      if (_draft.repeatDaily)
                        WeekdayChips(
                          selected: _draft.weekdays,
                          onChanged: (d) =>
                              _update(_draft.copyWith(weekdays: d)),
                        ),
                    ],
                  ),

                  // ── Contacts ────────────────────────────────────────
                  _ContactsSection(
                    contacts: _draft.contacts,
                    onEdit: _editContact,
                    onRemove: _removeContact,
                    onReorder: _reorder,
                  ),
                  AppListSection(
                    hasLeading: true,
                    footer: context.tr(
                      'تأكّد أنهم يوافقون على أن تتصل بهم عند الفجر. تبقى الأسماء والأرقام على جهازك ولا تُرفع إلى أي مكان.',
                      'Make sure they agree to be called at Fajr. Names and numbers stay on your phone and are never uploaded.',
                    ),
                    children: [
                      AppListTile(
                        leading: const AppIconTile(
                            icon: CupertinoIcons.person_crop_circle_badge_plus,
                            color: AppColors.tileGreen),
                        title: context.tr('من جهات الاتصال', 'From contacts'),
                        onTap: _addFromContacts,
                      ),
                      AppListTile(
                        leading: const AppIconTile(
                            icon: CupertinoIcons.number,
                            color: AppColors.tileBlue),
                        title: context.tr('إدخال رقم', 'Enter a number'),
                        onTap: _addManually,
                      ),
                    ],
                  ),

                  // ── How ─────────────────────────────────────────────
                  if (_android)
                    AppListSection(
                      header: context.tr('طريقة الإيقاظ', 'How to wake them'),
                      footer: auto
                          ? (effective == FajrCallMode.auto
                              ? context.tr(
                                  'يتصل الهاتف بهم واحدًا تلو الآخر من شريحتك، وقد يكلّف ذلك رصيدًا.',
                                  'Your phone calls them one by one from your SIM, which may cost credit.')
                              : context.tr(
                                  'يلزم السماح بالمكالمات للاتصال التلقائي. حتى ذلك الحين يصلك تنبيه بقائمة الاتصال.',
                                  'Automatic calls need the call permissions. Until then you get a reminder with the call list.'))
                          : context.tr(
                              'يصلك تنبيه عند الوقت، وتتصل بكل شخص بلمسة.',
                              'You get a reminder at the time and call each person with one tap.'),
                      children: [
                        AppPaddedRow(
                          child: AppSegmentedControl<FajrCallMode>(
                            segments: {
                              for (final m in FajrCallMode.values)
                                m: modeLabel(context, m),
                            },
                            value: _draft.mode,
                            onChanged: (m) =>
                                _update(_draft.copyWith(mode: m)),
                          ),
                        ),
                        if (auto && effective != FajrCallMode.auto)
                          AppListTile(
                            title: context.tr('منح الأذونات', 'Grant permissions'),
                            onTap: () => context.push(
                                '${FajrCallListsScreen.path}/permissions'),
                          ),
                      ],
                    ),

                  // ── Advanced (auto calls only) ──────────────────────
                  if (_android && auto) ...[
                    AppListSection(
                      children: [
                        AppListTile(
                          title: context.tr('إعدادات متقدمة', 'Advanced'),
                          chevron: false,
                          trailing: AnimatedRotation(
                            turns: _advanced ? 0.25 : 0,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            child: AppDirectionalIcon(
                              CupertinoIcons.chevron_forward,
                              size: 15,
                              color: context.palette.tertiaryLabel,
                            ),
                          ),
                          onTap: () => setState(() => _advanced = !_advanced),
                        ),
                        if (_advanced) ..._advancedRows(accounts),
                      ],
                    ),
                  ],

                  // ── More ────────────────────────────────────────────
                  if (!_isNew)
                    AppListSection(
                      hasLeading: true,
                      children: [
                        AppListTile(
                          leading: const AppIconTile(
                              icon: CupertinoIcons.list_bullet,
                              color: AppColors.tilePurple),
                          title: context.tr('السجل', 'Log'),
                          onTap: () => context.push(
                              '${FajrCallListsScreen.path}/${_draft.id}/log'),
                        ),
                        AppListTile(
                          leading: const AppIconTile(
                              icon: CupertinoIcons.phone_fill,
                              color: AppColors.tileGreen),
                          title: context.tr('افتح قائمة الإيقاظ الآن',
                              'Open the wake list now'),
                          onTap: _draft.contacts.isEmpty
                              ? null
                              : () => context.push(FajrNotifications.wakeRoute(
                                  _draft.id, DateTime.now())),
                        ),
                        if (_android && effective == FajrCallMode.auto)
                          AppListTile(
                            leading: const AppIconTile(
                                icon: CupertinoIcons.play_fill,
                                color: AppColors.tileOrange),
                            title: context.tr('جرّب الآن', 'Test now'),
                            subtitle: context.tr('اتصال حقيقي بالقائمة',
                                'Places real calls to the list'),
                            onTap: _draft.contacts.isEmpty || _dirty
                                ? null
                                : _testNow,
                          ),
                        AppListTile(
                          leading: const AppIconTile(
                              icon: CupertinoIcons.trash,
                              color: AppColors.tileRed),
                          title: context.tr('حذف القائمة', 'Delete list'),
                          destructive: true,
                          chevron: false,
                          onTap: _delete,
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),

            // ── Sticky save ───────────────────────────────────────────
            _SaveBar(
              saving: _saving,
              onSave: _dirty ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _advancedRows(List<PhoneAccountOption> accounts) => [
        AppSliderRow(
          title: context.tr('مدة الرنين', 'Ring for'),
          value: _draft.ringTimeoutSec,
          min: FajrCallList.minRingTimeoutSec,
          max: FajrCallList.maxRingTimeoutSec,
          step: 5,
          label: (s) => seconds(context, s),
          onChanged: (s) => _update(_draft.copyWith(ringTimeoutSec: s)),
        ),
        AppSliderRow(
          title: context.tr('الانتظار بعد الرد', 'Wait after an answer'),
          value: _draft.waitAfterAnswerSec,
          min: 0,
          max: FajrCallList.maxWaitAfterAnswerSec,
          step: 5,
          label: (s) => seconds(context, s),
          onChanged: (s) => _update(_draft.copyWith(waitAfterAnswerSec: s)),
        ),
        AppSliderRow(
          title: context.tr('الفاصل بين الأرقام', 'Gap between numbers'),
          value: _draft.gapBetweenSec,
          min: 0,
          max: FajrCallList.maxGapBetweenSec,
          label: (s) => seconds(context, s),
          onChanged: (s) => _update(_draft.copyWith(gapBetweenSec: s)),
        ),
        AppListTile(
          title: context.tr('توقّف عند أول رد', 'Stop after the first answer'),
          trailing: AppSwitch(
            value: _draft.stopAfterFirstAnswer,
            onChanged: (v) =>
                _update(_draft.copyWith(stopAfterFirstAnswer: v)),
          ),
        ),
        AppListTile(
          title: context.tr('أعد الاتصال بمن لم يرد', 'Retry if no answer'),
          trailing: AppSwitch(
            value: _draft.retryOnNoAnswer,
            onChanged: (v) => _update(_draft.copyWith(retryOnNoAnswer: v)),
          ),
        ),
        if (_draft.retryOnNoAnswer)
          AppStepperRow(
            title: context.tr('عدد المحاولات', 'Retries'),
            value: _draft.maxRetries,
            min: 1,
            max: FajrCallList.maxRetriesLimit,
            label: (n) => ltr('$n'),
            onChanged: (n) => _update(_draft.copyWith(maxRetries: n)),
          ),
        AppListTile(
          title: context.tr('كرّر القائمة كاملة', 'Repeat the whole list'),
          trailing: AppSwitch(
            value: _draft.repeatWholeLoop,
            onChanged: (v) => _update(_draft.copyWith(repeatWholeLoop: v)),
          ),
        ),
        if (_draft.repeatWholeLoop)
          AppStepperRow(
            title: context.tr('مرات التكرار', 'Extra rounds'),
            value: _draft.loopRepeats,
            min: 1,
            max: FajrCallList.maxLoopRepeats,
            label: (n) => ltr('$n'),
            onChanged: (n) => _update(_draft.copyWith(loopRepeats: n)),
          ),
        if (accounts.length > 1)
          AppListTile(
            title: context.tr('الاتصال من', 'Call from'),
            value: _draft.phoneAccountId == null
                ? context.tr('الشريحة الافتراضية', 'Default SIM')
                : accounts
                        .where((a) => a.id == _draft.phoneAccountId)
                        .map((a) => a.label)
                        .firstOrNull ??
                    context.tr('الشريحة الافتراضية', 'Default SIM'),
            onTap: () => _pickSim(accounts),
          ),
      ];
}

/// The people on the list, as an inset-grouped card: drag the handle to
/// reorder, swipe to remove, tap to edit.
class _ContactsSection extends StatelessWidget {
  const _ContactsSection({
    required this.contacts,
    required this.onEdit,
    required this.onRemove,
    required this.onReorder,
  });

  final List<FajrContact> contacts;
  final ValueChanged<FajrContact> onEdit;
  final ValueChanged<FajrContact> onRemove;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin + AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.screenMargin,
          AppSpacing.xs + 2),
      child: Text(
        context.tr('من سنوقظ؟ (بالترتيب)', 'Who to wake (in order)'),
        style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
      ),
    );
    if (contacts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          AppListSection(children: [
            AppListTile(
              title: context.tr('لا أحد بعد', 'Nobody yet'),
              subtitle: context.tr('أضف أمّك وأباك أو من تحب.',
                  'Add your mother, father or anyone you love.'),
            ),
          ]),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screenMargin,
              0, AppSpacing.screenMargin, AppSpacing.sm),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: ColoredBox(
              color: c.secondaryGroupedBackground,
              child: ReorderableList(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: contacts.length,
                onReorderItem: onReorder,
                itemBuilder: (context, i) {
                  final contact = contacts[i];
                  return _ContactRow(
                    key: ValueKey(contact.id),
                    index: i,
                    contact: contact,
                    last: i == contacts.length - 1,
                    onTap: () => onEdit(contact),
                    onRemove: () => onRemove(contact),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    super.key,
    required this.index,
    required this.contact,
    required this.last,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final FajrContact contact;
  final bool last;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Dismissible(
      key: ValueKey('dismiss-${contact.id}'),
      // Swipe towards the leading edge, as in iOS lists.
      direction:
          rtl ? DismissDirection.startToEnd : DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: c.destructive,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
        child: Icon(CupertinoIcons.trash, color: c.onAccent,
            semanticLabel: context.tr('حذف', 'Delete')),
      ),
      child: ColoredBox(
        color: c.secondaryGroupedBackground,
        child: Column(
          children: [
            Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: context.tr('حذف', 'Delete')):
                    onRemove,
              },
              child: AppListTile(
                leading: AppIconTile(
                  icon: relationIcon(contact.relation),
                  color: relationColor(contact.relation),
                ),
                title: contact.name,
                subtitle: ltr(contact.phone),
                onTap: onTap,
                chevron: false,
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: Semantics(
                    label: context.tr('اسحب لتغيير الترتيب', 'Drag to reorder'),
                    child: SizedBox.square(
                      dimension: AppSpacing.minTouchTarget,
                      child: Icon(CupertinoIcons.line_horizontal_3,
                          color: c.tertiaryLabel),
                    ),
                  ),
                ),
              ),
            ),
            if (!last)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.md + 30 + 12),
                child: Container(height: AppSpacing.hairline, color: c.separator),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.barBackground,
        border: Border(
            top: BorderSide(color: c.separator, width: AppSpacing.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
              AppSpacing.md, AppSpacing.sm),
          child: AppButton.filled(
            label: context.tr('حفظ القائمة', 'Save list'),
            expand: true,
            loading: saving,
            onPressed: onSave,
          ),
        ),
      ),
    );
  }
}
