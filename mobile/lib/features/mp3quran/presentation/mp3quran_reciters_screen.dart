import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/widgets/app_entrance.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_retry.dart';
import '../../quran/presentation/providers/reciter_providers.dart';
import '../../quran/presentation/widgets/lahuma_reciters_section.dart';
import '../domain/mp3quran_models.dart';
import 'mp3quran_providers.dart';
import '../../../core/design/widgets/app_states.dart' show AppSkeletonList;

/// Standalone page wrapper around [Mp3QuranRecitersList].
class Mp3QuranRecitersScreen extends StatelessWidget {
  const Mp3QuranRecitersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('قرّاء mp3quran', 'MP3Quran reciters'),
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
      ),
      body: const Mp3QuranRecitersList(),
    );
  }
}

/// Searchable, refreshable list of MP3Quran reciters, headed by the reciters
/// uploaded to the Lahuma backend (when it is reachable and has any). Used
/// by the Reciters tab and by [Mp3QuranRecitersScreen].
class Mp3QuranRecitersList extends ConsumerWidget {
  const Mp3QuranRecitersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(mp3RecitersProvider);
    final query = ref.watch(mp3RecitersSearchProvider);
    final favorites = ref.watch(reciterFavoritesProvider);
    // The backend is optional: while it loads or fails, the section is left
    // out and the MP3Quran list works on its own.
    final lahuma = playableReciters(
        ref.watch(reciterListProvider).valueOrNull ?? const [], query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: TextField(
            onChanged: (v) =>
                ref.read(mp3RecitersSearchProvider.notifier).state = v,
            style: GoogleFonts.cairo(fontSize: 14),
            decoration: InputDecoration(
              hintText: context.tr('ابحث عن قارئ', 'Search reciters'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.surfaceElevatedLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const AppSkeletonList(circleLeading: true),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(mp3RecitersProvider),
            ),
            data: (all) {
              final list =
                  sortFavoritesFirst(filterReciters(all, query), favorites);
              final header = lahuma.isEmpty
                  ? null
                  : LahumaRecitersSection(reciters: lahuma);
              final headerCount = header == null ? 0 : 1;
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(mp3RecitersProvider);
                  ref.invalidate(reciterListProvider);
                  try {
                    await ref.read(mp3RecitersProvider.future);
                  } catch (_) {}
                },
                child: list.isEmpty && header == null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 240,
                            child: Center(
                              child: Text(
                                all.isEmpty
                                    ? context.tr('لا يوجد قرّاء متاحون',
                                        'No reciters available')
                                    : context.tr('لا توجد نتائج', 'No results'),
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.mutedDark
                                      : AppColors.mutedLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          MediaQuery.paddingOf(context).bottom + AppSpacing.md,
                        ),
                        itemCount: headerCount + list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          if (i < headerCount) return header!.listEntrance(i);
                          final reciter = list[i - headerCount];
                          return _ReciterTile(
                            reciter: reciter,
                            favorite: favorites.contains(reciter.id),
                            onToggleFavorite: () => ref
                                .read(reciterFavoritesProvider.notifier)
                                .toggle(reciter),
                          ).listEntrance(i);
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReciterTile extends StatelessWidget {
  const _ReciterTile({
    required this.reciter,
    required this.favorite,
    required this.onToggleFavorite,
  });

  final Mp3Reciter reciter;
  final bool favorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reciter.name,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleFavorite,
                visualDensity: VisualDensity.compact,
                tooltip: favorite
                    ? context.tr('إزالة من المفضلة', 'Remove from favorites')
                    : context.tr('إضافة إلى المفضلة', 'Add to favorites'),
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite
                      ? AppColors.primary
                      : (isDark ? AppColors.mutedDark : AppColors.mutedLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in reciter.moshaf)
                ActionChip(
                  avatar: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    '${m.name} · ${m.surahNumbers.length}',
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                  onPressed: () =>
                      context.push('/quran/mp3quran/${reciter.id}/${m.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
