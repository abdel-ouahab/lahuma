import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../fajr_call_providers.dart';
import '../screens/fajr_call_lists_screen.dart';
import 'fajr_call_labels.dart';

/// Home status line for the next Fajr call, shown only while a list is on:
/// "نداء الفجر القادم: غدًا 4:36 ص · 3 أشخاص".
class FajrCallStatusCard extends ConsumerWidget {
  const FajrCallStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(fajrUpcomingProvider);
    if (upcoming == null) return const SizedBox.shrink();
    final now = ref.watch(fajrClockProvider)();
    final c = context.palette;
    final line =
        '${formatFire(context, upcoming.at, now)} · ${peopleCount(context, upcoming.list.contacts.length)}';
    return AppCard(
      onTap: () => context.go(FajrCallListsScreen.path),
      semanticLabel:
          '${context.tr('نداء الفجر القادم', 'Next Fajr call')}، $line',
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms + 2),
      child: Row(
        children: [
          const AppIconTile(
              icon: CupertinoIcons.sunrise_fill,
              color: AppColors.tileOrange,
              size: 32),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('نداء الفجر القادم', 'Next Fajr call'),
                  style: AppTypography.footnote
                      .copyWith(color: c.secondaryLabel),
                ),
                Text(line,
                    style: AppTypography.headline.copyWith(color: c.label)),
              ],
            ),
          ),
          AppDirectionalIcon(CupertinoIcons.chevron_forward,
              size: 15, color: c.tertiaryLabel),
        ],
      ),
    );
  }
}
