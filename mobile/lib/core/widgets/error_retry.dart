import '../design/design.dart';
import '../localization/tr.dart';
import '../network/api_exception.dart';

/// Explains what failed and offers a retry. Used wherever content loads
/// from the network.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException &&
        (error as ApiException).message == ApiException.offline;

    return AppEmptyState(
      icon: offline
          ? CupertinoIcons.wifi_slash
          : CupertinoIcons.exclamationmark_triangle,
      title: offline
          ? context.tr('لا يوجد اتصال بالإنترنت', 'You are offline')
          : context.tr('تعذّر تحميل المحتوى', 'Could not load this'),
      message: offline
          ? context.tr(
              'السور التي فتحتها من قبل تعمل دون اتصال. اتصل بالإنترنت ثم أعد المحاولة.',
              'Surahs you have opened before work offline. Connect to the internet and try again.')
          : context.tr('أعد المحاولة بعد قليل.', 'Try again in a moment.'),
      action: AppButton.tinted(
        label: context.tr('إعادة المحاولة', 'Try again'),
        icon: CupertinoIcons.arrow_clockwise,
        onPressed: onRetry,
      ),
    );
  }
}
