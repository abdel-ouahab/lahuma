import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/quran/mushaf/data/mushaf_repository.dart';
import 'package:lahuma/features/quran/mushaf/domain/mushaf_meta.dart';
import 'package:lahuma/features/quran/mushaf/presentation/mushaf_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MushafMeta (Madinah Mushaf page breaks)', () {
    test('surahs start on their printed pages', () {
      expect(MushafMeta.surahStartPage(1), 1);
      expect(MushafMeta.surahStartPage(2), 2);
      expect(MushafMeta.surahStartPage(3), 50);
      expect(MushafMeta.surahStartPage(18), 293);
      expect(MushafMeta.surahStartPage(36), 440);
      expect(MushafMeta.surahStartPage(114), 604);
    });

    test('juz\' start on their printed pages', () {
      expect(MushafMeta.juzStartPage(1), 1);
      expect(MushafMeta.juzStartPage(2), 22);
      expect(MushafMeta.juzStartPage(15), 282);
      expect(MushafMeta.juzStartPage(30), 582);
      for (var j = 2; j <= MushafMeta.juzCount; j++) {
        expect(MushafMeta.juzStartPage(j),
            greaterThan(MushafMeta.juzStartPage(j - 1)));
      }
    });

    test('page headers name the opening surah and juz\'', () {
      expect(MushafMeta.surahOf(1), 1);
      expect(MushafMeta.juzOf(1), 1);
      expect(MushafMeta.surahOf(50), 3);
      expect(MushafMeta.juzOf(582), 30);
      expect(MushafMeta.surahOf(604), 112);
    });

    test('86 Makki and 28 Madani surahs despite the data\'s spellings', () {
      final makki = [
        for (var s = 1; s <= MushafMeta.surahCount; s++)
          if (MushafMeta.isMakki(s)) s,
      ];
      expect(makki.length, 86);
      expect(MushafMeta.isMakki(1), isTrue);
      expect(MushafMeta.isMakki(2), isFalse);
    });

    test('ayah text and counts', () {
      expect(MushafMeta.ayahCount(2), 286);
      expect(MushafMeta.surahName(1), 'الفاتحة');
      expect(MushafMeta.ayahText(112, 1), isNotEmpty);
    });
  });

  group('MushafNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<ProviderContainer> loaded() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(mushafProvider);
      await pumpEventQueue();
      return container;
    }

    test('starts on page 1 and remembers the last page', () async {
      var container = await loaded();
      expect(container.read(mushafProvider).loaded, isTrue);
      expect(container.read(mushafProvider).lastPage, 1);
      await container.read(mushafProvider.notifier).setLastPage(255);

      container = await loaded();
      expect(container.read(mushafProvider).lastPage, 255);
    });

    test('toggles bookmarks, newest first, and persists them', () async {
      var container = await loaded();
      final notifier = container.read(mushafProvider.notifier);
      expect(await notifier.toggleBookmark(10), isTrue);
      expect(await notifier.toggleBookmark(20), isTrue);
      expect(container.read(mushafProvider).bookmarks.map((b) => b.page),
          [20, 10]);

      container = await loaded();
      expect(container.read(mushafProvider).isBookmarked(10), isTrue);
      expect(
          await container.read(mushafProvider.notifier).toggleBookmark(10),
          isFalse);
      expect((await MushafRepository().getBookmarks()).map((b) => b.page),
          [20]);
    });
  });
}
