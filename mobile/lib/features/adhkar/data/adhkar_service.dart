import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/dhikr.dart';

/// Why adhkar could not be loaded. The UI maps each kind to localized text.
enum AdhkarFailure { offline, malformed, empty, generic }

class AdhkarException implements Exception {
  const AdhkarException(this.failure, [this.detail]);

  final AdhkarFailure failure;

  /// Developer-facing detail; never shown to the user.
  final String? detail;

  @override
  String toString() => 'AdhkarException(${failure.name}: $detail)';
}

/// Where the raw dataset is kept after the first successful fetch.
abstract class AdhkarCache {
  Future<String?> read();
  Future<void> write(String raw);
  Future<void> clear();
}

/// [AdhkarCache] in its own Hive box, opened on first use.
class HiveAdhkarCache implements AdhkarCache {
  static const String _key = 'dataset';

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(StorageKeys.adhkarCacheBox)) {
      return Hive.box<String>(StorageKeys.adhkarCacheBox);
    }
    return Hive.openBox<String>(StorageKeys.adhkarCacheBox);
  }

  @override
  Future<String?> read() async => (await _box()).get(_key);

  @override
  Future<void> write(String raw) async => (await _box()).put(_key, raw);

  @override
  Future<void> clear() async => (await _box()).delete(_key);
}

/// Loads morning and evening adhkar from the open-source dataset of
/// github.com/nawafalqari/ayah (`src/data/adkar.json`), which credits
/// islambook.com as its source.
///
/// The URL is pinned to one commit, so the text shown is exactly the text
/// that was reviewed; moving to a newer commit means reviewing it again.
///
/// Offline-first: once a valid copy is cached, it is used without touching
/// the network. Only data that parses is ever cached.
class AdhkarService {
  AdhkarService({Dio? dio, AdhkarCache? cache})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _cache = cache ?? HiveAdhkarCache();

  static const String sourceCommit = 'f2b2071f815f3bbe940570a681bc6e68a2ebcf13';
  static const String sourceUrl =
      'https://raw.githubusercontent.com/nawafalqari/ayah/$sourceCommit/src/data/adkar.json';

  final Dio _dio;
  final AdhkarCache _cache;

  /// Returns the cached adhkar, fetching them when there is no usable copy.
  /// With [refresh], the network is tried first and the cache is the
  /// fallback.
  Future<AdhkarCollection> load({bool refresh = false}) async {
    if (!refresh) {
      final cached = await _fromCache();
      if (cached != null) return cached;
    }
    try {
      return await _fetch();
    } on AdhkarException {
      final cached = await _fromCache();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<AdhkarCollection?> _fromCache() async {
    final String? raw;
    try {
      raw = await _cache.read();
    } catch (_) {
      return null;
    }
    if (raw == null) return null;
    try {
      return parse(raw);
    } on AdhkarException {
      // A corrupt copy must not block a fresh download.
      await _cache.clear();
      return null;
    }
  }

  Future<AdhkarCollection> _fetch() async {
    final String raw;
    try {
      // raw.githubusercontent.com answers `text/plain`; decode it ourselves.
      final response = await _dio.get<String>(
        sourceUrl,
        options: Options(responseType: ResponseType.plain),
      );
      raw = response.data ?? '';
    } on DioException catch (e) {
      throw AdhkarException(_failureOf(e), e.message);
    } catch (e) {
      throw AdhkarException(AdhkarFailure.generic, '$e');
    }

    final collection = parse(raw);
    await _cache.write(raw);
    return collection;
  }

  static AdhkarFailure _failureOf(DioException e) => switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          AdhkarFailure.offline,
        _ => AdhkarFailure.generic,
      };

  /// Parses the dataset: a JSON object whose keys are category names
  /// ("أذكار الصباح", "أذكار المساء", …), each a list of
  /// `{category, count, description, reference, content}` with every value
  /// a string (`count` is zero-padded, e.g. "03").
  ///
  /// Throws [AdhkarFailure.malformed] when the shape is wrong and
  /// [AdhkarFailure.empty] when neither period has a usable entry. Single
  /// entries without text are skipped.
  static AdhkarCollection parse(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException catch (e) {
      throw AdhkarException(AdhkarFailure.malformed, e.message);
    }
    if (json is! Map<String, dynamic>) {
      throw const AdhkarException(
          AdhkarFailure.malformed, 'top level is not an object');
    }

    final byPeriod = <AdhkarPeriod, List<Dhikr>>{};
    for (final period in AdhkarPeriod.values) {
      final list = json[period.sourceKey];
      if (list == null) {
        throw AdhkarException(
            AdhkarFailure.malformed, 'missing "${period.sourceKey}"');
      }
      if (list is! List) {
        throw AdhkarException(
            AdhkarFailure.malformed, '"${period.sourceKey}" is not a list');
      }
      byPeriod[period] = [
        for (final (i, item) in list.indexed)
          if (_entry(period, i, item) case final dhikr?) dhikr,
      ];
    }

    final collection = AdhkarCollection(byPeriod);
    if (collection.isEmpty) {
      throw const AdhkarException(AdhkarFailure.empty);
    }
    return collection;
  }

  static Dhikr? _entry(AdhkarPeriod period, int index, Object? item) {
    if (item is! Map) return null;
    final text = cleanText(_string(item['content']));
    if (text.isEmpty) return null;

    final count = int.tryParse(_string(item['count']).trim()) ?? 1;
    var virtue = cleanText(_string(item['description']));
    if (_withheldVirtues.contains((skeleton(text), skeleton(virtue)))) {
      virtue = '';
    }

    // References in this dataset start with ". " left over from the
    // sentence they were cut from: ". [البقرة - 201]."
    final reference = cleanText(_string(item['reference']))
        .replaceFirst(RegExp(r'^[.\s]+'), '');

    return Dhikr(
      period: period,
      index: index,
      text: text,
      count: count < 1 ? 1 : count,
      virtue: virtue.isEmpty ? null : virtue,
      reference: reference.isEmpty ? null : reference,
    );
  }

  static String _string(Object? value) => value is String
      ? value
      : value is num
          ? '$value'
          : '';

  /// Whitespace-only clean-up; letters and diacritics are never changed.
  /// Drops a harakah stranded after a space (e.g. "وَأَنَّ ُ مُحَمّـداً" in the
  /// source), which no letter carries and which would render as a dotted
  /// circle.
  static String cleanText(String value) => value
      .replaceAll(RegExp(r'\s+[\u064B-\u0652]+(?=\s)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// [value] reduced to its letters: no spaces, harakat or tatweel. Compares
  /// Arabic text regardless of how its diacritics were typed or ordered.
  static String skeleton(String value) =>
      value.replaceAll(RegExp(r'[\s\u064B-\u0652\u0640.،]'), '');

  /// Virtues the source attaches to the wrong dhikr or quotes inaccurately,
  /// as (dhikr, virtue) letter skeletons. They are hidden rather than
  /// rewritten, so the app never shows a religious claim it did not take
  /// verbatim from the source.
  static const Set<(String, String)> _withheldVirtues = {
    // The virtue of «لا إله إلا الله وحده لا شريك له…» said 100 times
    // (al-Bukhari 3293, Muslim 2691), attached here to the istighfar.
    (
      'أستغفراللهوأتوبإليه',
      'مائةحسنةومحيتعنهمائةسيئةوكانتلهحرزامنالشيطانحتىيمسى',
    ),
    // The hadith (Abu Dawud 5088, al-Tirmidhi 3388) says «لم يضره شيء»;
    // "من الله" is not in it.
    (
      'بسماللهالذيلايضرمعاسمهشيءفيالأرضولافيالسماءوهوالسميعالعليم',
      'لميضرهمناللهشيء',
    ),
  };
}
