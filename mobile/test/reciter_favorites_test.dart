import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/mp3quran/data/reciter_favorites_repository.dart';
import 'package:lahuma/features/mp3quran/domain/mp3quran_models.dart';
import 'package:lahuma/features/mp3quran/presentation/mp3quran_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const a = Mp3Reciter(id: 1, name: 'أ', moshaf: []);
const b = Mp3Reciter(id: 2, name: 'ب', moshaf: []);
const c = Mp3Reciter(id: 3, name: 'ج', moshaf: []);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ReciterFavoritesNotifier> loaded() async {
    final n = ReciterFavoritesNotifier(ReciterFavoritesRepository());
    await Future<void>.delayed(Duration.zero);
    return n;
  }

  test('toggle adds then removes and persists across instances', () async {
    final n = await loaded();
    expect(n.toggle(b), isTrue);
    expect(n.toggle(c), isTrue);
    expect(n.toggle(c), isFalse);
    expect(n.state, {2});

    final reopened = await loaded();
    expect(reopened.state, {2});
  });

  test('ignores corrupt stored ids', () async {
    SharedPreferences.setMockInitialValues({
      'mp3quran.favoriteReciters': ['3', 'oops'],
    });
    expect((await loaded()).state, {3});
  });

  test('favourites are pinned first, keeping order within groups', () {
    expect(sortFavoritesFirst([a, b, c], {3, 2}), [b, c, a]);
    expect(sortFavoritesFirst([a, b, c], {}), [a, b, c]);
  });
}
