// Sheets, dialogs, pickers and the side panel, each over the screen that
// opens it. The shared helpers (app_overlays.dart) are checked with the
// longest real content they're given anywhere in the app.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/design/widgets/app_overlays.dart';
import 'package:lahuma/core/localization/tr.dart';
import 'package:lahuma/features/dedication/presentation/dedication_sheet.dart';
import 'package:lahuma/features/fajr_call/presentation/screens/fajr_call_edit_screen.dart';
import 'package:lahuma/features/fajr_call/presentation/widgets/contact_form_sheet.dart';
import 'package:lahuma/features/fajr_call/presentation/widgets/prayer_settings_sheet.dart';
import 'package:lahuma/features/home/presentation/home_screen.dart';
import 'package:lahuma/features/home/presentation/home_sidebar.dart';
import 'package:lahuma/features/khatma/presentation/screens/khatma_setup_screen.dart';
import 'package:lahuma/features/khatma/presentation/widgets/page_picker_sheet.dart';
import 'package:lahuma/features/quran/mushaf/presentation/screens/mushaf_screen.dart';
import 'package:lahuma/features/quran/mushaf/presentation/widgets/ayah_sheet.dart';
import 'package:lahuma/features/quran/presentation/providers/quran_providers.dart';
import 'package:lahuma/features/quran/presentation/screens/surah_reading_screen.dart';
import 'package:lahuma/features/quran/presentation/widgets/ayah_action_sheet.dart';
import 'package:lahuma/features/quran/presentation/widgets/ayah_note_dialog.dart';
import 'package:lahuma/features/quran/presentation/widgets/ayah_text_sheet.dart';
import 'package:lahuma/features/quran/presentation/widgets/reader_options_sheet.dart';
import 'package:lahuma/features/settings/presentation/screens/settings_screen.dart';
import 'package:lahuma/features/tasbih/presentation/screens/tasbih_screen.dart';
import 'package:lahuma/features/tasbih/presentation/tasbih_providers.dart';
import 'package:lahuma/features/tasbih/presentation/widgets/tasbih_sheets.dart';
import 'package:lahuma/features/wird/presentation/goal_sheet.dart';

import 'fakes.dart';
import 'harness.dart';

/// Opens an overlay from a context on [screen].
Future<void> Function(WidgetTester) over(
        Type screen, void Function(BuildContext context) open) =>
    (tester) async {
      // A block body: an arrow would await the sheet's future, which only
      // completes when the sheet closes.
      open(pageContext(tester, screen));
    };

/// Same, with the screen's WidgetRef (it must be a Consumer widget).
Future<void> Function(WidgetTester) overRef(
        Type screen, void Function(BuildContext context, WidgetRef ref) open) =>
    (tester) async {
      final element = pageContext(tester, screen);
      open(element, element as WidgetRef);
    };

/// Every sheet, dialog and panel, over the screen that opens it.
final overlayCases = <ScreenCase>[
  // ── Home ────────────────────────────────────────────────────────────────
  ScreenCase('home_sidebar',
      route: '/home',
      open: over(HomeScreen, (c) => unawaited(HomeSidebar.show(c)))),
  ScreenCase('goal_sheet',
      route: '/home', open: over(HomeScreen, (c) => GoalSheet.show(c))),

  // ── Settings ────────────────────────────────────────────────────────────
  ScreenCase('dedication_sheet',
      route: '/settings',
      hasInput: true,
      open: over(SettingsScreen, (c) => DedicationSheet.show(c))),
  ScreenCase('prayer_settings_sheet',
      route: '/settings',
      prefs: fajrPrefs,
      open: over(SettingsScreen, (c) => PrayerSettingsSheet.show(c))),
  ScreenCase('city_picker_sheet',
      route: '/settings',
      prefs: fajrPrefs,
      hasInput: true,
      open: (tester) async {
        unawaited(PrayerSettingsSheet.show(pageContext(tester, SettingsScreen)));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        final c = pageContext(tester, SettingsScreen);
        await tapVisible(
            tester, find.text(c.tr('اختر مدينة', 'Choose a city')));
      }),

  // ── Fajr Call ───────────────────────────────────────────────────────────
  ScreenCase('contact_form_sheet',
      route: '/home/fajr-call/l1',
      prefs: fajrPrefs,
      hasInput: true,
      open: over(
          FajrCallEditScreen,
          (c) => ContactFormSheet.show(c,
              id: 'c9',
              dialCode: '+213',
              name: 'عبد الرحمن بن عبد العزيز',
              phone: '+213 551 23 45 67'))),

  // ── Surah reader ────────────────────────────────────────────────────────
  ScreenCase('ayah_action_sheet',
      route: '/quran/2',
      open: over(
          SurahReadingScreen,
          (c) => AyahActionSheet.show(c,
              surahName: 'سُورَةُ البَقَرَةِ',
              ayahNumber: 255,
              isBookmarked: true,
              hasNote: true,
              onPlay: () {},
              onBookmark: () {},
              onShare: () {},
              onCopy: () {},
              onTafseer: () {},
              onTranslation: () {},
              onNote: () {}))),
  ScreenCase('ayah_translation_sheet',
      route: '/quran/2',
      open: over(
          SurahReadingScreen,
          (c) => AyahTextSheet.show(c,
              title: c.tr('الترجمة', 'Translation'),
              ayahNumber: 62,
              provider: translationProvider(2),
              rtl: false))),
  ScreenCase('ayah_tafsir_sheet',
      route: '/quran/2',
      open: over(
          SurahReadingScreen,
          (c) => AyahTextSheet.show(c,
              title: c.tr('التفسير الميسر', 'Tafsir'),
              ayahNumber: 62,
              provider: tafsirProvider(2),
              rtl: true))),
  ScreenCase('reader_options_sheet',
      route: '/quran/2',
      hasInput: true,
      open: over(
          SurahReadingScreen,
          (c) => ReaderOptionsSheet.show(c, ayahCount: 286, onJump: (_) {}))),
  ScreenCase('ayah_note_dialog',
      route: '/quran/2',
      hasInput: true,
      open: over(
          SurahReadingScreen,
          (c) => showAyahNoteDialog(c,
              surahName: 'سُورَةُ البَقَرَةِ', ayahNumber: 255))),

  // ── Mushaf ──────────────────────────────────────────────────────────────
  ScreenCase('mushaf_ayah_sheet',
      route: '/mushaf?page=3',
      open: over(MushafScreen, (c) => showAyahSheet(c, surah: 2, ayah: 25))),

  // ── Khatma ──────────────────────────────────────────────────────────────
  ScreenCase('page_picker_sheet',
      route: '/khatma/setup',
      open: over(
          KhatmaSetupScreen,
          (c) => showPagePickerSheet(c,
              title: c.tr('أول صفحة', 'First page'), initial: 1))),

  // ── Tasbih ──────────────────────────────────────────────────────────────
  ScreenCase('tasbih_target_sheet',
      route: '/tasbih',
      open: overRef(TasbihScreen,
          (c, ref) => showTargetSheet(c, ref, ref.read(tasbihProvider).adhkar.first))),
  ScreenCase('tasbih_add_sheet',
      route: '/tasbih',
      hasInput: true,
      open: overRef(TasbihScreen, (c, ref) => showAddDhikrSheet(c, ref))),
  ScreenCase('tasbih_settings_sheet',
      route: '/tasbih',
      open: over(TasbihScreen, (c) => showTasbihSettingsSheet(c))),
  ScreenCase('tasbih_stats_sheet',
      route: '/tasbih',
      open: over(TasbihScreen, (c) => showTasbihStatsSheet(c))),

  // ── Shared helpers, with the longest real content ───────────────────────
  ScreenCase('app_dialog',
      route: '/settings',
      open: over(
          SettingsScreen,
          (c) => showAppDialog<bool>(c,
                  title: c.tr('العمل في الخلفية', 'Run in the background'),
                  message: c.tr(
                    'ليُرفع الأذان والتطبيق مغلق، يحتاج تطبيق «إحسان» أن يعمل في الخلفية: في وقت كل صلاة يظهر إشعار ويُرفع الأذان بصوت الإشعارات. اختر «السماح» في النافذة التالية. لا يزيد هذا من استهلاك البطارية إلا وقت الأذان.',
                    'To play the adhan with the app closed, Ihsan needs to run in the background: at each prayer time a notification appears and the adhan plays at notification volume. Choose "Allow" in the next window. The app only wakes at prayer times.',
                  ),
                  actions: [
                    AppDialogAction(label: c.tr('لاحقًا', 'Later'), value: false),
                    AppDialogAction(
                        label: c.tr('فتح الإعدادات', 'Open settings'), value: true),
                    AppDialogAction(
                        label: c.tr('متابعة', 'Continue'),
                        value: true,
                        isDefault: true),
                  ]))),
  ScreenCase('app_text_input_dialog',
      route: '/settings',
      hasInput: true,
      open: over(
          SettingsScreen,
          (c) => showAppTextInputDialog(c,
              title: c.tr('ملاحظة على الآية', 'Note on this ayah'),
              message: c.tr('سورة البقرة، الآية 255', 'Al-Baqarah, ayah 255'),
              initialValue: c.tr(
                  'آية الكرسي: أعظم آية في كتاب الله، من قرأها حين يصبح أجير من الجن حتى يمسي.',
                  'Ayat al-Kursi: the greatest verse in the Book of Allah.'),
              maxLines: 4))),
  ScreenCase('app_action_sheet',
      route: '/settings',
      open: over(
          SettingsScreen,
          (c) => showAppActionSheet<int>(c,
                  title: c.tr('تذكير قبل الصلاة', 'Reminder before prayer'),
                  message: c.tr('«اقترب وقت صلاة …»', '"Prayer is coming up"'),
                  actions: [
                    for (final m in const [0, 5, 10, 15, 20, 30, 45, 60])
                      AppSheetAction(
                          label: m == 0
                              ? c.tr('بدون تذكير', 'No reminder')
                              : c.tr('قبل $m دقيقة من وقت الصلاة',
                                  '$m minutes before the prayer time'),
                          value: m,
                          isDefault: m == 15),
                  ]))),
  ScreenCase('app_picker',
      route: '/settings',
      open: over(
          SettingsScreen,
          (c) => showAppPicker<int>(c,
              title: c.tr('مدة الختمة', 'Khatma length'),
              items: [for (var d = 3; d <= 365; d++) d],
              selected: 30,
              labelOf: (d) => c.tr('$d يومًا', '$d days')))),
  ScreenCase('app_date_picker',
      route: '/settings',
      open: over(
          SettingsScreen,
          (c) => showAppDatePicker(c,
              title: c.tr('تاريخ البدء', 'Start date'), initial: fixedNow))),
  ScreenCase('app_time_picker',
      route: '/settings',
      open: over(
          SettingsScreen,
          (c) => showAppDatePicker(c,
              title: c.tr('وقت التنبيه', 'Alarm time'),
              initial: fixedNow,
              mode: CupertinoDatePickerMode.time))),
  ScreenCase('app_toast',
      route: '/settings',
      open: over(
          SettingsScreen,
          (c) => AppToast.show(
              c,
              c.tr('حُذفت العلامة المرجعية من سورة البقرة، الآية 255',
                  'Bookmark removed from Al-Baqarah, ayah 255'),
              icon: CupertinoIcons.bookmark,
              actionLabel: c.tr('تراجع', 'Undo'),
              onAction: () {}))),
];
