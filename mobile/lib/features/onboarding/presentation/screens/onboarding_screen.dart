import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design.dart';
import '../../../../core/localization/tr.dart';
import '../../../settings/presentation/settings_providers.dart';

/// The introduction, shown once after the first launch.
// Phase 1 placeholder: the pages arrive in Phase 2.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const path = '/onboarding';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      child: Center(
        child: AppButton.filled(
          label: context.tr('ابدأ', 'Start'),
          onPressed: () async {
            await ref
                .read(settingsRepositoryProvider)
                .setOnboardingCompleted(true);
            if (context.mounted) context.go('/home');
          },
        ),
      ),
    );
  }
}
