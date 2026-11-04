import '../../../../core/design/design.dart';
import '../../data/onboarding_pages.dart';
import 'onboarding_chrome.dart';

/// The living miniature for page [id]. It plays while [active] (its page is
/// the current one) and rests otherwise.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.id, required this.active});

  final OnboardingPageId id;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // Phase 2 placeholders; the miniatures arrive in phase 3.
    final icon = switch (id) {
      OnboardingPageId.welcome => CupertinoIcons.heart,
      OnboardingPageId.readAndListen => CupertinoIcons.book,
      OnboardingPageId.khatma => CupertinoIcons.circle_grid_hex,
      OnboardingPageId.prayer => CupertinoIcons.compass,
      OnboardingPageId.fajrCall => CupertinoIcons.phone,
      OnboardingPageId.remembrance => CupertinoIcons.circle_grid_3x3,
      OnboardingPageId.start => CupertinoIcons.star,
    };
    return OnboardingArtFrame(
      child: Center(
        child: Icon(icon, size: 72, color: context.palette.accent),
      ),
    );
  }
}
