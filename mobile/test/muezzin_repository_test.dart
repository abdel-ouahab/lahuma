import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/adhan/data/muezzin_repository.dart';

void main() {
  final row = {
    'id': 'a',
    'nameAr': 'أذان الجزائر',
    'regularUrl': '/adhan/algeria/v2/regular.mp3',
    'fajrUrl': 'https://cdn.example.com/adhan/algeria/v2/fajr.mp3',
    'regularShortUrl': '/adhan/algeria/v2/regular_short.caf',
    'fajrShortUrl': '',
    'version': 2,
  };

  test('relative file urls are resolved against the API origin', () {
    final m = MuezzinRepository.parse({
      'muezzins': [row]
    }, base: Uri.parse('http://10.0.2.2:4000/api')).single;

    expect(m.regularUrl, 'http://10.0.2.2:4000/adhan/algeria/v2/regular.mp3');
    expect(m.regularShortUrl,
        'http://10.0.2.2:4000/adhan/algeria/v2/regular_short.caf');
    // Absolute and empty urls are left alone.
    expect(m.fajrUrl, 'https://cdn.example.com/adhan/algeria/v2/fajr.mp3');
    expect(m.fajrShortUrl, '');
  });
}
