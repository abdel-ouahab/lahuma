import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/tr.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/design/widgets/app_states.dart'
    show AppShimmer, AppSkeletonText;

/// Shows one ayah's entry from a secondary edition (tafsir or translation) in
/// a bottom sheet.
class AyahTextSheet extends ConsumerWidget {
  const AyahTextSheet({
    super.key,
    required this.title,
    required this.ayahNumber,
    required this.provider,
    required this.rtl,
  });

  /// e.g. "التفسير الميسّر · البقرة".
  final String title;
  final int ayahNumber;
  final FutureProvider<Map<int, String>> provider;

  /// Text direction of the edition (Arabic tafsir vs English translation).
  final bool rtl;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required int ayahNumber,
    required FutureProvider<Map<int, String>> provider,
    required bool rtl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AyahTextSheet(
        title: title,
        ayahNumber: ayahNumber,
        provider: provider,
        rtl: rtl,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(provider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              Text(
                context.tr('الآية $ayahNumber', 'Ayah $ayahNumber'),
                style:
                    GoogleFonts.cairo(fontSize: 12, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: async.when(
                  data: (map) => SingleChildScrollView(
                    child: Directionality(
                      textDirection:
                          rtl ? TextDirection.rtl : TextDirection.ltr,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          map[ayahNumber] ?? '',
                          style: rtl
                              ? GoogleFonts.scheherazadeNew(
                                  fontSize: 22,
                                  height: 1.9,
                                  color: isDark
                                      ? AppColors.textDark
                                      : AppColors.textLight,
                                )
                              : GoogleFonts.cairo(
                                  fontSize: 15,
                                  height: 1.7,
                                  color: isDark
                                      ? AppColors.textDark
                                      : AppColors.textLight,
                                ),
                        ),
                      ),
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: AppShimmer(
                      child: AppSkeletonText(lines: 4, lineHeight: 14),
                    ),
                  ),
                  error: (e, _) => ErrorRetry(
                    error: e,
                    onRetry: () => ref.invalidate(provider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
