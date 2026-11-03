import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/prayer_times.dart';
import 'prayer_times_config.dart';

/// Client for the Aladhan timings API (no key needed).
class PrayerTimesApiService {
  PrayerTimesApiService([ApiClient? client])
      : _dio = (client ?? ApiClient(baseUrl: PrayerTimesConfig.baseUrl)).dio;

  final Dio _dio;

  Future<DayPrayerTimes> fetch(DateTime day, double lat, double lng) async {
    final stamp =
        '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}';
    try {
      final res = await _dio.get<Object?>(
        'timings/$stamp',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'method': PrayerTimesConfig.method,
        },
      );
      return parse(res.data, DateTime(day.year, day.month, day.day));
    } on FormatException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Timings for each day in [days] (local midnights), via the monthly
  /// `/calendar` endpoint: one request per calendar month touched.
  Future<List<DayPrayerTimes>> fetchRange(
      List<DateTime> days, double lat, double lng) async {
    final wanted = {for (final d in days) DayPrayerTimes.dayKey(d)};
    return [
      for (final d in await fetchMonths(days, lat, lng))
        if (wanted.contains(d.key)) d,
    ];
  }

  /// Every day of each calendar month [days] touch. The background
  /// reschedule keeps them all, so it can still plan a week ahead offline.
  Future<List<DayPrayerTimes>> fetchMonths(
      List<DateTime> days, double lat, double lng) async {
    final months = {for (final d in days) (d.year, d.month)};
    final result = <DayPrayerTimes>[];
    for (final (year, month) in months) {
      try {
        final res = await _dio.get<Object?>(
          'calendar/$year/$month',
          queryParameters: {
            'latitude': lat,
            'longitude': lng,
            'method': PrayerTimesConfig.method,
          },
        );
        result.addAll(parseCalendar(res.data));
      } on FormatException {
        rethrow;
      } catch (e) {
        throw ApiException.fromDioError(e);
      }
    }
    return result;
  }

  /// Parses an Aladhan `/calendar` payload (one entry per day of a month).
  static List<DayPrayerTimes> parseCalendar(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) {
      throw const FormatException('Unexpected Aladhan calendar response');
    }
    return [
      for (final entry in data) parse({'data': entry}, _gregorian(entry)),
    ];
  }

  /// `date.gregorian.date` is "DD-MM-YYYY".
  static DateTime _gregorian(Object? entry) {
    final raw = '${((entry as Map)['date'] as Map)['gregorian']['date']}';
    final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(raw);
    if (m == null) throw FormatException('Bad date: $raw');
    return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }

  /// Parses an Aladhan `/timings` payload for [day]. Throws
  /// [FormatException] when a required time is missing.
  static DayPrayerTimes parse(Object? body, DateTime day) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map || data['timings'] is! Map) {
      throw const FormatException('Unexpected Aladhan response');
    }
    final timings = data['timings'] as Map;
    final times = <PrayerKind, DateTime>{};
    for (final k in PrayerKind.values) {
      times[k] = _clock(timings[k.apiKey], day);
    }
    return DayPrayerTimes(date: day, times: times, hijri: _hijri(data['date']));
  }

  /// "04:55" or "04:55 (+01)" → [day] at that time, in the device zone.
  static DateTime _clock(Object? raw, DateTime day) {
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch('$raw');
    if (m == null) throw FormatException('Bad time: $raw');
    return DateTime(
        day.year, day.month, day.day, int.parse(m[1]!), int.parse(m[2]!));
  }

  static HijriDate? _hijri(Object? date) {
    try {
      final h = (date as Map)['hijri'] as Map;
      final month = h['month'] as Map;
      return HijriDate(
        day: int.parse('${h['day']}'),
        monthAr: '${month['ar']}',
        monthEn: '${month['en']}',
        year: int.parse('${h['year']}'),
      );
    } catch (_) {
      return null;
    }
  }
}
