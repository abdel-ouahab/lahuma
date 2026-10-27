import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../domain/reciter.dart';
import '../providers/reciter_providers.dart';

/// Reciters uploaded through the Lahuma admin panel, shown above the
/// MP3Quran list in the Reciters tab. Each row opens the reciter's player.
///
/// The parent passes only reciters that have audio (see [playableReciters]);
/// when the backend is unreachable the parent simply leaves this out.
class LahumaRecitersSection extends ConsumerWidget {
  const LahumaRecitersSection({super.key, required this.reciters});

  final List<Reciter> reciters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final activeId = ref.watch(activeReciterProvider)?.id;
    // Only touch the audio service once one of these reciters is loaded.
    final playing = activeId != null &&
        (ref.watch(audioPlayerStateProvider).valueOrNull?.playing ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListSection(
          header: context.tr('قرّاء لهما', 'Lahuma reciters'),
          hasLeading: true,
          margin: EdgeInsetsDirectional.zero,
          children: [
            for (final r in reciters)
              AppListTile(
                leading: const AppIconTile(
                    icon: CupertinoIcons.mic_fill, color: AppColors.accent),
                title: r.displayName,
                subtitle: context.tr('${r.audioUrls.length} سورة',
                    '${r.audioUrls.length} surahs'),
                trailing: r.id == activeId && playing
                    ? Icon(CupertinoIcons.waveform, size: 18, color: c.accent)
                    : null,
                onTap: () => context.push('/quran/reciters/${r.id}'),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xs, AppSpacing.lg, 0, 0),
          child: Text(
            context.tr('قرّاء MP3Quran', 'MP3Quran reciters'),
            style: AppTypography.footnote.copyWith(color: c.secondaryLabel),
          ),
        ),
      ],
    );
  }
}
