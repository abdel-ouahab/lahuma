import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/mp3quran/data/reciter_photos_api.dart';
import 'package:lahuma/features/mp3quran/domain/mp3quran_models.dart';
import 'package:lahuma/features/mp3quran/domain/reciter_photos.dart';

void main() {
  group('ReciterPhotos.urlFor', () {
    final photos = ReciterPhotos({
      'عبد الباسط عبد الصمد': 'abdelbasset',
      'مشاري راشد العفاسي': 'afasy',
      'أبو بكر الشاطرى': 'shatri',
      'سعود الشريم': 'shuraim',
    });

    test('matches MP3Quran spellings of the same reciter', () {
      expect(photos.urlFor('عبدالباسط عبدالصمد'), 'abdelbasset');
      expect(photos.urlFor('مشاري العفاسي'), 'afasy');
      expect(photos.urlFor('شيخ أبو بكر الشاطري'), 'shatri');
      expect(photos.urlFor('سعود الشريم'), 'shuraim');
    });

    test('does not match other reciters', () {
      expect(photos.urlFor('ماهر المعيقلي'), isNull);
      expect(photos.urlFor('سعود'), isNull);
      expect(photos.urlFor(''), isNull);
    });

    test('drops a first/last pair shared by two photos', () {
      final ambiguous = ReciterPhotos({
        'محمد صديق المنشاوي': 'a',
        'محمد صالح المنشاوي': 'b',
      });
      expect(ambiguous.urlFor('محمد صديق المنشاوي'), 'a');
      expect(ambiguous.urlFor('محمد المنشاوي'), isNull);
    });
  });

  test('parse makes picture paths absolute and skips missing ones', () {
    final photos = ReciterPhotosApi.parse({
      'reciters': [
        {
          'profile_picture': 'images/reciters/6/afasy.jpeg',
          'translated_name': {'name': 'مشاري راشد العفاسي'},
        },
        {
          'profile_picture': '',
          'translated_name': {'name': 'ياسر الدوسري'},
        },
      ],
    });
    expect(photos.urlFor('مشاري العفاسي'),
        'https://static.qurancdn.com/images/reciters/6/afasy.jpeg');
    expect(photos.urlFor('ياسر الدوسري'), isNull);
    expect(ReciterPhotosApi.parse('<html>').isEmpty, isTrue);
  });

  test('Mp3Moshaf.label splits riwaya and style', () {
    Mp3Moshaf m(String name, [int surahs = 114]) => Mp3Moshaf(
          id: 1,
          name: name,
          server: 'https://x/',
          surahNumbers: [for (var i = 1; i <= surahs; i++) i],
        );
    expect(
        m('حفص عن عاصم - مرتل').label, (riwaya: 'حفص عن عاصم', style: 'مرتل'));
    expect(m('المصحف المجود - المصحف المجود').label,
        (riwaya: 'المصحف المجود', style: null));
    expect(m('ورش عن نافع').label, (riwaya: 'ورش عن نافع', style: null));
    expect(m('x').isComplete, isTrue);
    expect(m('x', 38).isComplete, isFalse);
  });
}
