import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../adhan/presentation/adhan_providers.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../domain/prayer_times.dart';
import 'prayer_painters.dart';

/// Top of the prayer-times frame: the title, a greeting for the time of
/// day, and two chips — the adhan switch's state (opens adhan settings) and
/// the city (opens the location sheet) — over a painted sky that follows
/// the day. Its bottom edge is solid [AppColors.prayerSilhouette].
class PrayerHero extends ConsumerWidget {
  const PrayerHero({
    super.key,
    required this.city,
    required this.current,
    required this.onPickCity,
  });

  /// Empty when unknown.
  final String city;

  /// The prayer whose time it is now; null before Fajr. Picks the sky and
  /// the greeting.
  final PrayerKind? current;
  final VoidCallback onPickCity;

  /// Room under the chips for the rooftops.
  static const double _sceneHeight = 58;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adhanOn = ref.watch(adhanProvider.select((s) => s.settings.enabled));
    final c = context.palette;
    final (sky, night) = switch (current) {
      null || PrayerKind.isha => (AppColors.skyNight, true),
      PrayerKind.fajr => (AppColors.skyDawn, false),
      PrayerKind.maghrib => (AppColors.skyDusk, false),
      _ => (AppColors.skyDay, false),
    };
    final greeting = switch (current) {
      null => context.tr('ليلة مباركة', 'Have a blessed night'),
      PrayerKind.fajr || PrayerKind.sunrise => context.tr(
          'صباح الخير · أذكار الصباح بانتظارك',
          'Good morning · Your morning adhkar are waiting'),
      PrayerKind.dhuhr => context.tr('نهارك مبارك', 'Have a blessed day'),
      _ => context.tr('مساء الخير · أذكار المساء بانتظارك',
          'Good evening · Your evening adhkar are waiting'),
    };
    final place = city.isEmpty ? context.tr('موقعك', 'Your location') : city;
    final adhanLabel = adhanOn
        ? context.tr('الأذان مفعّل', 'Adhan on')
        : context.tr('الأذان متوقف', 'Adhan off');

    return CustomPaint(
      painter: PrayerSkyPainter(
        sky: sky,
        night: night,
        textDirection: Directionality.of(context),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.ml, AppSpacing.ml, AppSpacing.ml, _sceneHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('أوقات الصلاة', 'Prayer times'),
              style:
                  AppTypography.title2.copyWith(color: CupertinoColors.white),
            ),
            Text(
              greeting,
              style: AppTypography.footnote.copyWith(
                  color: CupertinoColors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: AppSpacing.md),
            // The adhan chip always shows its whole label; the city chip
            // takes what is left and truncates a long name instead.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeroChip(
                  semanticLabel: adhanLabel,
                  onTap: () => context.push(AdhanSettingsScreen.path),
                  children: [
                    Icon(CupertinoIcons.gear_alt_fill,
                        size: 17, color: c.resolve(AppColors.prayerGold)),
                    const SizedBox(width: AppSpacing.xs + 2),
                    _ChipText(adhanLabel, truncate: false),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: ShapeDecoration(
                        color: adhanOn ? c.success : c.tertiaryLabel,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: _HeroChip(
                    semanticLabel:
                        context.tr('المدينة: $place', 'City: $place'),
                    onTap: onPickCity,
                    children: [
                      Icon(CupertinoIcons.location_solid,
                          size: 16, color: c.resolve(AppColors.prayerGreen)),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Flexible(child: _ChipText(place)),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Icon(CupertinoIcons.chevron_down,
                          size: 13, color: c.secondaryLabel),
                    ],
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

class _ChipText extends StatelessWidget {
  const _ChipText(this.text, {this.truncate = true});

  final String text;

  /// Ellipsize when space runs out; false keeps the whole label.
  final bool truncate;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.visible,
        style: AppTypography.subheadline
            .weight(FontWeight.w600)
            .copyWith(color: context.palette.label),
      );
}

/// A frosted pill on the sky, with a 44-pt hit area.
class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.children,
    required this.onTap,
    required this.semanticLabel,
  });

  final List<Widget> children;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppSpacing.minTouchTarget),
        onPressed: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.ms, vertical: AppSpacing.xs),
          decoration: ShapeDecoration(
            color: c.isDark
                ? c.secondaryGroupedBackground.withValues(alpha: 0.92)
                : CupertinoColors.white.withValues(alpha: 0.94),
            shape: const StadiumBorder(),
            shadows: [
              BoxShadow(
                color: c.shadow(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
