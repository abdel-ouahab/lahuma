import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/quran/domain/surah.dart';

void main() {
  test('Surah.fromJson parses required fields', () {
    final surah = Surah.fromJson({
      'number': 1,
      'name': 'الفاتحة',
      'englishName': 'Al-Faatiha',
      'numberOfAyahs': 7,
    });

    expect(surah.number, 1);
    expect(surah.arabicName, 'الفاتحة');
    expect(surah.englishName, 'Al-Faatiha');
    expect(surah.ayahCount, 7);
  });
}
