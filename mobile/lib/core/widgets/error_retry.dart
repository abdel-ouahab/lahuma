import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization/tr.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Explains what failed and offers a retry. Used wherever content loads
/// from the network.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offline = error is ApiException &&
        (error as ApiException).message == ApiException.offline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 44,
              color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              offline
                  ? context.tr('لا يوجد اتصال بالإنترنت', 'You are offline')
                  : context.tr('تعذّر تحميل المحتوى', 'Could not load this'),
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              offline
                  ? context.tr(
                      'السور التي فتحتها من قبل تعمل دون اتصال. اتصل بالإنترنت ثم أعد المحاولة.',
                      'Surahs you have opened before work offline. Connect to the internet and try again.')
                  : context.tr('أعد المحاولة بعد قليل.', 'Try again in a moment.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                height: 1.6,
                color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.tr('إعادة المحاولة', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
