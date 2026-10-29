import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/design/widgets/app_entrance.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/lahuma_icon_button.dart';
import '../../domain/juz_data.dart';
import '../../domain/surah.dart';
import '../../mushaf/presentation/widgets/mushaf_entry_card.dart';
import '../providers/quran_providers.dart';
import '../../../mp3quran/presentation/mp3quran_reciters_screen.dart';
import '../widgets/surah_card.dart';
import '../../../../core/design/widgets/app_states.dart' show AppSkeletonList;

class SurahListScreen extends ConsumerStatefulWidget {
  const SurahListScreen({super.key, this.initialTab = 0});

  /// 0 = surahs, 1 = juz', 2 = reciters.
  final int initialTab;

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void didUpdateWidget(SurahListScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) {
      _tabController.animateTo(widget.initialTab.clamp(0, 2));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _tabController.animateTo(0);
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final surahListAsync = ref.watch(surahListProvider);
    final query = ref.watch(surahSearchQueryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Row(
                children: [
                  Text(
                    context.tr('القرآن الكريم', 'The Holy Quran'),
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                  const Spacer(),
                  LahumaIconButton(
                    icon: Icons.search_rounded,
                    tooltip: context.tr('بحث عن سورة', 'Search surahs'),
                    onTap: _focusSearch,
                  ),
                ],
              ),
            ),

            // ── Mushaf ──────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: MushafEntryCard(),
            ),

            // ── Tab Bar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceElevatedDark
                      : AppColors.surfaceElevatedLight,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight,
                  labelStyle: GoogleFonts.cairo(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.cairo(
                      fontSize: 14, fontWeight: FontWeight.w400),
                  tabs: [
                    Tab(text: context.tr('السور', 'Surahs')),
                    Tab(text: context.tr('الأجزاء', 'Juz\'')),
                    Tab(text: context.tr('القرّاء', 'Reciters')),
                  ],
                ),
              ),
            ),

            // ── Search (surahs tab only) ────────────────────────────────────
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) =>
                  _tabController.index == 0 ? child! : const SizedBox.shrink(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: TextField(
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.tr('ابحث بالاسم أو الرقم...',
                        'Search by name or number...'),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color:
                          isDark ? AppColors.mutedDark : AppColors.mutedLight,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.surfaceElevatedDark
                        : AppColors.surfaceElevatedLight,
                  ),
                  onChanged: (value) =>
                      ref.read(surahSearchQueryProvider.notifier).state = value,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Surahs ────────────────────────────────────────────────
                  surahListAsync.when(
                    data: (surahs) {
                      final filtered = filterSurahs(surahs, query);
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            context.tr('لا توجد نتائج', 'No results'),
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.mutedDark
                                  : AppColors.mutedLight,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final surah = filtered[index];
                          return SurahListItem(
                            surah: surah,
                            onTap: () => context.push('/quran/${surah.number}'),
                          ).listEntrance(index);
                        },
                      );
                    },
                    loading: () => const AppSkeletonList(
                      itemCount: 10,
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                      spacing: AppSpacing.sm,
                    ),
                    error: (e, _) => ErrorRetry(
                      error: e,
                      onRetry: () => ref.invalidate(surahListProvider),
                    ),
                  ),

                  // ── Juz' ──────────────────────────────────────────────────
                  _JuzList(surahs: surahListAsync.valueOrNull),

                  // ── Reciters ──────────────────────────────────────────────
                  const Mp3QuranRecitersList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.surahs});

  /// Used to name the surah each juz' starts in; null while loading/offline.
  final List<Surah>? surahs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      itemCount: juzStarts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final juz = juzStarts[index];
        final surahName = surahs
            ?.where((s) => s.number == juz.surah)
            .map((s) => context.isArabic ? s.arabicName : s.englishName)
            .firstOrNull;
        final subtitle = surahName == null
            ? null
            : context.tr('يبدأ من سورة $surahName · الآية ${juz.ayah}',
                'Starts at $surahName · ayah ${juz.ayah}');

        return Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => context.push('/quran/${juz.surah}?ayah=${juz.ayah}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceElevatedDark
                          : AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${juz.juz}',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('الجزء ${arabicJuzNames[index]}',
                              'Juz\' ${juz.juz}'),
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
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
                ],
              ),
            ),
          ),
        ).listEntrance(index);
      },
    );
  }
}
