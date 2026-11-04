import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../prayer_times/presentation/prayer_times_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/onboarding_pages.dart';

/// The introduction's current page, and finishing it.
class OnboardingController extends StateNotifier<int> {
  OnboardingController(this._ref) : super(0);

  final Ref _ref;

  int get pageCount => onboardingPages.length;
  OnboardingPage get page => onboardingPages[state];
  bool get isLast => state == pageCount - 1;

  void pageChanged(int index) {
    if (index != state) state = index.clamp(0, pageCount - 1);
  }

  /// Marks the introduction seen (Skip and Start both do). After the first
  /// run Home comes next, and its prayer times may now ask for the location
  /// they need: the introduction itself never shows a permission prompt.
  Future<void> complete({required bool firstRun}) async {
    await _ref.read(settingsRepositoryProvider).setOnboardingCompleted(true);
    if (firstRun) {
      unawaited(_ref.read(prayerTimesProvider.notifier).refresh(request: true));
    }
  }
}

final onboardingControllerProvider =
    StateNotifierProvider.autoDispose<OnboardingController, int>(
        (ref) => OnboardingController(ref));
