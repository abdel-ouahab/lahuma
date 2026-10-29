import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_settings_enum.dart';
import '../../../../core/constants/features.dart';
import '../../../../core/design/widgets/app_entrance.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../adhan/presentation/adhan_providers.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../dedication/presentation/dedication_labels.dart';
import '../../../dedication/presentation/dedication_providers.dart';
import '../../../dedication/presentation/dedication_sheet.dart';
import '../../../fajr_call/presentation/fajr_call_providers.dart';
import '../../../fajr_call/presentation/widgets/prayer_settings_sheet.dart';
import '../../../wird/presentation/goal_sheet.dart';
import '../../../wird/presentation/wird_providers.dart';
import '../../data/settings_repository.dart';
import '../settings_providers.dart';
import '../theme_mode_switcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeOptionProvider);
    final fontSize = ref.watch(readerFontSizeProvider);
    final showTranslation = ref.watch(showTranslationProvider);
    final goal = ref.watch(wirdProvider.select((w) => w.goal));
    final dedication = ref.watch(dedicationProvider);
    final user = ref.watch(authProvider);
    final prayer = ref.watch(fajrCallProvider.select((s) => s.prayer));
    final adhan = ref.watch(adhanProvider.select((s) => s.settings));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final text = isDark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                context.tr('المزيد', 'More'),
                style: GoogleFonts.cairo(
                    fontSize: 22, fontWeight: FontWeight.w700, color: text),
              ),
            ),

            // ── Account ──────────────────────────────────────────────────
            if (Features.accounts) ...[
              _Card(
                isDark: isDark,
                children: [
                  _NavTile(
                    icon: Icons.person_outline_rounded,
                    label: user?.name ?? context.tr('تسجيل الدخول', 'Sign in'),
                    detail: user?.email ??
                        context.tr('اختياري. التطبيق يعمل بدون حساب.',
                            'Optional. The app works without an account.'),
                    isDark: isDark,
                    onTap: () => context.push('/account'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Reading ──────────────────────────────────────────────────
            _SectionHeader(title: context.tr('القراءة', 'Reading')),
            _Card(
              isDark: isDark,
              children: [
                _NavTile(
                  icon: Icons.favorite_outline_rounded,
                  label: context.tr('نية القراءة', 'Reading intention'),
                  detail: dedication.target.title(context),
                  isDark: isDark,
                  onTap: () => DedicationSheet.show(context),
                ),
                _Divider(isDark: isDark),
                _NavTile(
                  icon: Icons.flag_outlined,
                  label: context.tr('الهدف اليومي', 'Daily goal'),
                  detail: context.tr('$goal آية', '$goal ayahs'),
                  isDark: isDark,
                  onTap: () => GoalSheet.show(context),
                ),
                _Divider(isDark: isDark),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Text(context.tr('حجم خط المصحف', 'Quran text size'),
                          style: GoogleFonts.cairo(fontSize: 14, color: text)),
                    ],
                  ),
                ),
                Slider(
                  value: fontSize,
                  min: SettingsRepository.minFontSize,
                  max: SettingsRepository.maxFontSize,
                  divisions: 10,
                  label: fontSize.round().toString(),
                  onChanged: (v) =>
                      ref.read(readerFontSizeProvider.notifier).update(v),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      style: GoogleFonts.scheherazadeNew(
                          fontSize: fontSize, height: 1.8, color: text),
                    ),
                  ),
                ),
                _Divider(isDark: isDark),
                SwitchListTile(
                  value: showTranslation,
                  onChanged: (v) =>
                      ref.read(showTranslationProvider.notifier).update(v),
                  secondary: const Icon(Icons.translate_outlined,
                      size: 18, color: AppColors.primary),
                  title: Text(
                    context.tr(
                        'عرض الترجمة الإنجليزية', 'Show English translation'),
                    style: GoogleFonts.cairo(fontSize: 14, color: text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Prayer ───────────────────────────────────────────────────
            _SectionHeader(title: context.tr('الصلاة', 'Prayer')),
            _Card(
              isDark: isDark,
              children: [
                _NavTile(
                  icon: Icons.location_on_outlined,
                  label: context.tr('الموقع', 'Location'),
                  detail: prayer.hasLocation
                      ? prayer.placeName
                      : context.tr(
                          'غير محدد. يُستخدم لمواقيت الصلاة ونداء الفجر.',
                          'Not set. Used for prayer times and Fajr Call.'),
                  isDark: isDark,
                  onTap: () => PrayerSettingsSheet.show(context),
                ),
                _Divider(isDark: isDark),
                _NavTile(
                  icon: Icons.volume_up_outlined,
                  label: context.tr('الأذان', 'Adhan'),
                  detail: !adhan.enabled
                      ? context.tr('متوقف', 'Off')
                      : ref
                              .watch(adhanProvider.select((s) => s.selected))
                              ?.name(context.isArabic) ??
                          context.tr('الأذان الافتراضي', 'Default adhan'),
                  isDark: isDark,
                  onTap: () => context.push(AdhanSettingsScreen.path),
                ),
                _Divider(isDark: isDark),
                _NavTile(
                  icon: Icons.wb_twilight_rounded,
                  label: context.tr('نداء الفجر', 'Fajr Call'),
                  detail: ref.watch(fajrUpcomingProvider) == null
                      ? context.tr('متوقف', 'Off')
                      : context.tr('مفعّل', 'On'),
                  isDark: isDark,
                  onTap: () => context.go('/home/fajr-call'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Language ─────────────────────────────────────────────────
            _SectionHeader(title: context.tr('اللغة', 'Language')),
            _Card(
              isDark: isDark,
              children: [
                _SettingTile(
                  label: 'العربية',
                  isSelected: locale == AppLocaleOption.arabic,
                  isDark: isDark,
                  onTap: () => ref
                      .read(localeOptionProvider.notifier)
                      .update(AppLocaleOption.arabic),
                ),
                _Divider(isDark: isDark),
                _SettingTile(
                  label: 'English',
                  isSelected: locale == AppLocaleOption.english,
                  isDark: isDark,
                  onTap: () => ref
                      .read(localeOptionProvider.notifier)
                      .update(AppLocaleOption.english),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Appearance ───────────────────────────────────────────────
            _SectionHeader(title: context.tr('المظهر', 'Appearance')),
            _Card(
              isDark: isDark,
              children: [
                ThemeModeSwitcher(
                  builder: (context, switchTo) => _SettingTile(
                    label: context.tr('فاتح', 'Light'),
                    icon: Icons.wb_sunny_outlined,
                    isSelected: themeMode == AppThemeMode.light,
                    isDark: isDark,
                    onTap: () => switchTo(AppThemeMode.light),
                  ),
                ),
                _Divider(isDark: isDark),
                ThemeModeSwitcher(
                  builder: (context, switchTo) => _SettingTile(
                    label: context.tr('داكن', 'Dark'),
                    icon: Icons.nightlight_outlined,
                    isSelected: themeMode == AppThemeMode.dark,
                    isDark: isDark,
                    onTap: () => switchTo(AppThemeMode.dark),
                  ),
                ),
                _Divider(isDark: isDark),
                ThemeModeSwitcher(
                  builder: (context, switchTo) => _SettingTile(
                    label: context.tr('تلقائي', 'Match device'),
                    icon: Icons.brightness_auto_outlined,
                    isSelected: themeMode == AppThemeMode.system,
                    isDark: isDark,
                    onTap: () => switchTo(AppThemeMode.system),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── About ────────────────────────────────────────────────────
            _SectionHeader(title: context.tr('عن لهما', 'About Lahuma')),
            LahumaCard(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لهما',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'قرآنٌ يُتلى، وأجرٌ يُهدى.',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 16,
                      height: 1.7,
                      color: isDark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr(
                      'لهما تطبيق قرآن أُنشئ بنية أن يكون صدقة جارية للوالدين.',
                      'Lahuma is a Quran app made as an ongoing charity for parents.',
                    ),
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      height: 1.7,
                      color: isDark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight,
                    ),
                  ),
                ],
              ),
            ),
          ].listEntrance(),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.children});
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LahumaCard(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                  Text(
                    detail,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              context.isArabic
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.mutedDark : AppColors.mutedLight),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.textDark : AppColors.textLight),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
    );
  }
}
