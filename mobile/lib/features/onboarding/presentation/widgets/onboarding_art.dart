import '../../../../core/design/design.dart';
import '../../data/onboarding_pages.dart';
import 'art/fajr_call_art.dart';
import 'art/khatma_art.dart';
import 'art/prayer_art.dart';
import 'art/read_listen_art.dart';
import 'art/remembrance_art.dart';
import 'art/start_art.dart';
import 'art/welcome_art.dart';
import 'onboarding_chrome.dart';

/// The living miniature for page [id], in its gilded frame. It plays while
/// [active] (its page is the current one) and rests otherwise.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.id, required this.active});

  final OnboardingPageId id;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final (Size size, Widget art) = switch (id) {
      OnboardingPageId.welcome => (WelcomeArt.size, WelcomeArt(active: active)),
      OnboardingPageId.readAndListen => (
          ReadListenArt.size,
          ReadListenArt(active: active),
        ),
      OnboardingPageId.khatma => (KhatmaArt.size, KhatmaArt(active: active)),
      OnboardingPageId.prayer => (PrayerArt.size, PrayerArt(active: active)),
      OnboardingPageId.fajrCall => (
          FajrCallArt.size,
          FajrCallArt(active: active),
        ),
      OnboardingPageId.remembrance => (
          RemembranceArt.size,
          RemembranceArt(active: active),
        ),
      OnboardingPageId.start => (StartArt.size, StartArt(active: active)),
    };
    return OnboardingArtFrame(size: size, child: art);
  }
}
