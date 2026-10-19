import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/router/app_router.dart';

void main() {
  test('/quran/mp3quran is not captured by the surah route', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final m = router.configuration.findMatch(Uri.parse('/quran/mp3quran'));
    expect(m.matches.map((e) => e.route).whereType<dynamic>().length, greaterThan(0));
    expect(m.fullPath, '/quran/mp3quran');
    expect(router.configuration.findMatch(Uri.parse('/quran/5')).fullPath,
        r'/quran/:number(\d+)');
  });
}
