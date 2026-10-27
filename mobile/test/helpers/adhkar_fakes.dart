import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:lahuma/features/adhkar/data/adhkar_service.dart';

/// Copy of the pinned upstream file (commit in AdhkarService.sourceCommit).
final String fixture = File('test/fixtures/adkar.json').readAsStringSync();

class MemoryCache implements AdhkarCache {
  MemoryCache([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String raw) async => value = raw;
  @override
  Future<void> clear() async => value = null;
}

/// Answers every request with [body], or fails with [error].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({this.body, this.error});
  final String? body;
  final DioExceptionType? error;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (error != null) {
      throw DioException(requestOptions: options, type: error!);
    }
    return ResponseBody.fromString(body!, 200, headers: {
      Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
    });
  }

  @override
  void close({bool force = false}) {}
}

AdhkarService service(FakeAdapter adapter, MemoryCache cache) =>
    AdhkarService(dio: Dio()..httpClientAdapter = adapter, cache: cache);
