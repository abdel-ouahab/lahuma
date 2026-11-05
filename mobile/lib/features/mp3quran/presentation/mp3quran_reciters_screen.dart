import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../../../core/widgets/error_retry.dart';
import '../../quran/presentation/providers/reciter_providers.dart';
import '../../quran/presentation/widgets/lahuma_reciters_section.dart';
import '../domain/mp3quran_models.dart';
import 'mp3quran_providers.dart';

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
/// uploaded to the Lahuma backend (when it is reachable and has any), then
/// favourites, then everyone else. Used by the Reciters tab and by
/// [Mp3QuranRecitersScreen].
class Mp3QuranRecitersList extends ConsumerWidget {
  const Mp3QuranRecitersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final async = ref.watch(mp3RecitersProvider);
    final query = ref.watch(mp3RecitersSearchProvider);
    final favorites = ref.watch(reciterFavoritesProvider);
    final photos = ref.watch(reciterPhotosProvider).valueOrNull;
    // The backend is optional: while it loads or fails, the section is left
    // out and the MP3Quran list works on its own.
    final lahuma = playableReciters(
        ref.watch(reciterListProvider).valueOrNull ?? const [], query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: AppSearchField(
            placeholder: context.tr('ابحث عن قارئ', 'Search reciters'),
            onChanged: (v) =>
                ref.read(mp3RecitersSearchProvider.notifier).state = v,
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
              final list = filterReciters(all, query);
              final starred =
                  list.where((r) => favorites.contains(r.id)).toList();
              final rest =
                  list.where((r) => !favorites.contains(r.id)).toList();

              Widget tile(Mp3Reciter r) => _ReciterTile(
                    reciter: r,
                    photoUrl: photos?.urlFor(r.name),
                    favorite: favorites.contains(r.id),
                    onToggleFavorite: () =>
                        ref.read(reciterFavoritesProvider.notifier).toggle(r),
                  );

              final items = <Widget>[
                if (lahuma.isNotEmpty) LahumaRecitersSection(reciters: lahuma),
                if (starred.isNotEmpty) ...[
                  _SectionLabel(context.tr('المفضلة', 'Favorites')),
                  for (final r in starred) tile(r),
                ],
                if (rest.isNotEmpty) ...[
                  _SectionLabel(
                    starred.isEmpty && lahuma.isEmpty
                        ? context.tr('القرّاء', 'Reciters')
                        : context.tr('جميع القرّاء', 'All reciters'),
                    count: rest.length,
                  ),
                  for (final r in rest) tile(r),
                ],
              ];

              return RefreshIndicator(
                color: c.accent,
                onRefresh: () async {
                  ref.invalidate(mp3RecitersProvider);
                  ref.invalidate(reciterListProvider);
                  ref.invalidate(reciterPhotosProvider);
                  try {
                    await ref.read(mp3RecitersProvider.future);
                  } catch (_) {}
                },
                child: items.isEmpty
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
                                    : context.tr('لا يوجد قارئ بهذا الاسم',
                                        'No reciter by that name'),
                                style: AppTypography.subheadline
                                    .copyWith(color: c.secondaryLabel),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          MediaQuery.paddingOf(context).bottom + AppSpacing.md,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) => Padding(
                          padding: EdgeInsets.only(
                            top: items[i] is _SectionLabel && i > 0
                                ? AppSpacing.md
                                : 0,
                            bottom: AppSpacing.sm,
                          ),
                          child: items[i].listEntrance(i),
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.count});

  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTypography.footnote
                  .weight(FontWeight.w600)
                  .copyWith(color: c.secondaryLabel),
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: AppTypography.footnote.copyWith(color: c.tertiaryLabel),
            ),
        ],
      ),
    );
  }
}

/// One reciter: portrait on the leading edge, then the name with its
/// favourite star, and one playable row per edition under the name.
class _ReciterTile extends StatelessWidget {
  const _ReciterTile({
    required this.reciter,
    required this.photoUrl,
    required this.favorite,
    required this.onToggleFavorite,
  });

  final Mp3Reciter reciter;
  final String? photoUrl;
  final bool favorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return AppCard(
      color: c.secondaryGroupedBackground,
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.ms, AppSpacing.ms, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Portrait(reciter: reciter, url: photoUrl, gilded: favorite),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reciter.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headline
                            .weight(FontWeight.w700)
                            .copyWith(color: c.label),
                      ),
                    ),
                    Semantics(
                      button: true,
                      selected: favorite,
                      label: favorite
                          ? context.tr(
                              'إزالة من المفضلة', 'Remove from favorites')
                          : context.tr('إضافة إلى المفضلة', 'Add to favorites'),
                      excludeSemantics: true,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize:
                            const Size.square(AppSpacing.minTouchTarget),
                        onPressed: onToggleFavorite,
                        child: Icon(
                          favorite
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                          size: 20,
                          color: favorite ? c.gold : c.tertiaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final m in reciter.moshaf)
                  _EditionRow(
                    moshaf: m,
                    onTap: () =>
                        context.push('/quran/mp3quran/${reciter.id}/${m.id}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A play glyph, the riwaya with its style beside it, and how much of the
/// Quran the edition covers: "كامل" for a full mushaf, otherwise the number
/// of surahs.
class _EditionRow extends ConsumerWidget {
  const _EditionRow({required this.moshaf, required this.onTap});

  final Mp3Moshaf moshaf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final label = moshaf.label;
    final coverage = moshaf.isComplete
        ? context.tr('كامل', 'Complete')
        : _surahCount(context, moshaf.surahNumbers.length);
    final saved = ref
        .watch(surahDownloadsProvider.select((s) => s.savedIn(moshaf).length));
    final savedLabel = saved == 0
        ? null
        : context.isArabic
            ? 'على الجهاز: ${_surahCount(context, saved)}'
            : 'On this phone: ${_surahCount(context, saved)}';

    return Semantics(
      button: true,
      label: [
        label.riwaya,
        if (label.style != null) label.style!,
        coverage,
        if (savedLabel != null) savedLabel,
      ].join('، '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration:
                    BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
                // Media glyphs keep their direction in RTL.
                child:
                    Icon(CupertinoIcons.play_fill, size: 13, color: c.accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.riwaya,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subheadline
                            .weight(FontWeight.w600)
                            .copyWith(color: c.label, height: 1.3),
                      ),
                      if (label.style != null)
                        Text(
                          label.style!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption1
                              .copyWith(color: c.secondaryLabel, height: 1.3),
                        ),
                      if (savedLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.download_done_rounded,
                                  size: 14, color: c.accent),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  savedLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption1
                                      .weight(FontWeight.w600)
                                      .copyWith(color: c.accent, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (moshaf.isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.accentTint,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    coverage,
                    style: AppTypography.caption1
                        .weight(FontWeight.w600)
                        .copyWith(color: c.accent),
                  ),
                )
              else
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    coverage,
                    style: AppTypography.caption1
                        .copyWith(color: c.secondaryLabel),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  static String _surahCount(BuildContext context, int n) {
    if (!context.isArabic) return n == 1 ? '1 surah' : '$n surahs';
    if (n == 1) return 'سورة واحدة';
    if (n == 2) return 'سورتان';
    if (n <= 10) return '$n سور';
    return '$n سورة';
  }
}

/// The reciter's photo when Quran.com has one, otherwise the first letter of
/// their name on a zellige tone picked from their id. A gold ring marks a
/// favourite.
class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.reciter,
    required this.url,
    required this.gilded,
  });

  final Mp3Reciter reciter;
  final String? url;
  final bool gilded;

  static const double size = 52;

  static const _tones = [
    AppColors.tileGreen,
    AppColors.tileBlue,
    AppColors.tileTeal,
    AppColors.tileIndigo,
    AppColors.tilePurple,
    AppColors.tileRed,
    AppColors.tileOrange,
    AppColors.tileYellow,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final monogram = _Monogram(
      letter: _initial(reciter.name),
      tone: c.resolve(_tones[reciter.id % _tones.length]),
    );
    final photo = url == null
        ? monogram
        : Image.network(
            url!,
            fit: BoxFit.cover,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, __, ___) => monogram,
            frameBuilder: (_, child, frame, sync) => sync
                ? child
                : AnimatedSwitcher(
                    duration: AppMotion.standard,
                    child: frame == null ? monogram : child,
                  ),
          );

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: gilded ? c.gold : c.separator,
            width: gilded ? 1.5 : AppSpacing.hairline,
          ),
        ),
        child: ClipOval(child: photo),
      ),
    );
  }

  /// First letter of the name, skipping a "الشيخ" honorific.
  static String _initial(String name) {
    final words =
        name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final first = words.firstWhere(
      (w) => w != 'الشيخ' && w != 'شيخ',
      orElse: () => words.isEmpty ? '' : words.first,
    );
    return first.isEmpty ? '' : String.fromCharCode(first.runes.first);
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.letter, required this.tone});

  final String letter;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return ColoredBox(
      color: Color.alphaBlend(tone.withValues(alpha: c.isDark ? 0.22 : 0.13),
          c.secondaryGroupedBackground),
      child: Center(
        child: Text(
          letter,
          style: AppTypography.title2.copyWith(color: tone, height: 1.1),
        ),
      ),
    );
  }
}
