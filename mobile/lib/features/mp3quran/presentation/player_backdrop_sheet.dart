import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/localization/tr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/player_backdrop.dart';
import 'mp3quran_providers.dart';

String playerBackdropLabel(BuildContext context, PlayerBackdrop b) {
  return switch (b) {
    PlayerBackdrop.none => context.tr('بدون فيديو', 'No video'),
    PlayerBackdrop.flame => context.tr('شعلة هادئة', 'Low flame'),
    PlayerBackdrop.rain => context.tr('مطر خفيف', 'Gentle rain'),
    PlayerBackdrop.wind => context.tr('رياح', 'Wind'),
    PlayerBackdrop.forest => context.tr('غابة', 'Forest'),
    PlayerBackdrop.sea => context.tr('بحر', 'Sea'),
  };
}

/// Bottom sheet for picking the Now Playing background. A pick applies at
/// once; the sheet stays open and only covers the controls, so the new
/// scene plays above it as a live preview.
class PlayerBackdropSheet extends ConsumerWidget {
  const PlayerBackdropSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Light barrier: the point is to see the background change.
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (_) => const PlayerBackdropSheet(),
    );
  }

  static const _sheet = Color(0xF5072620);
  static const _gold = AppColors.toastAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(playerBackdropProvider);
    final notifier = ref.read(playerBackdropProvider.notifier);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 10, AppSpacing.lg, AppSpacing.md + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('خلفية المشغّل', 'Player background'),
            style: GoogleFonts.cairo(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          // The sheet gets at most 9/16 of the screen, so on a wide or short
          // screen the cards are cut to the height left; below the minimum
          // (large text, landscape) the grid scrolls instead.
          Flexible(
            child: LayoutBuilder(builder: (context, box) {
              final rows = (PlayerBackdrop.values.length / _columns).ceil();
              final cellWidth =
                  (box.maxWidth - _columnGap * (_columns - 1)) / _columns;
              final fit = (box.maxHeight - _rowGap * (rows - 1)) / rows;
              final cardHeight = math.max(
                  _minCardHeight, math.min(cellWidth / 0.6, fit));
              return GridView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: cardHeight > fit
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: _rowGap,
                  crossAxisSpacing: _columnGap,
                  mainAxisExtent: cardHeight,
                ),
                children: [
                  for (final b in PlayerBackdrop.values)
                    _BackdropCard(
                      backdrop: b,
                      label: playerBackdropLabel(context, b),
                      selected: b == selected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        notifier.select(b);
                      },
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  static const _columns = 3;
  static const _rowGap = AppSpacing.md;
  static const _columnGap = AppSpacing.sm + 4;

  /// A thumbnail still worth looking at, plus its label.
  static const _minCardHeight = 120.0;
}

class _BackdropCard extends StatelessWidget {
  const _BackdropCard({
    required this.backdrop,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PlayerBackdrop backdrop;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    const gold = PlayerBackdropSheet._gold;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius + 3),
                  border: Border.all(
                    color: selected ? gold : Colors.white.withValues(alpha: 0.1),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radius - 1),
                  child: backdrop.hasVideo
                      ? Image.asset(
                          backdrop.poster,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 240,
                        )
                      // The screen as it is without a video.
                      : const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary,
                                AppColors.prayerSilhouette,
                                AppColors.primaryDark,
                              ],
                              stops: [0, 0.55, 1],
                            ),
                          ),
                          child: SizedBox.expand(),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.cairo(
                fontSize: 13,
                height: 1.3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? gold : Colors.white.withValues(alpha: 0.72),
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
