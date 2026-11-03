import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/core/constants/storage_keys.dart';
import 'package:lahuma/core/network/api_client.dart';
import 'package:lahuma/core/network/api_exception.dart';
import 'package:lahuma/features/auth/data/auth_api.dart';
import 'package:lahuma/features/auth/presentation/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request with [status] and [body], without a network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  int status;
  Map<String, dynamic> body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _savedUser = {'id': 'u1', 'email': 'a@b.co', 'name': 'Old name'};

void main() {
  late ApiClient client;
  late _FakeAdapter server;

  setUp(() {
    client = ApiClient(baseUrl: 'http://test/api');
    server = _FakeAdapter(200, {});
    client.dio.httpClientAdapter = server;
  });

  void savedSession() => SharedPreferences.setMockInitialValues({
        StorageKeys.authToken: 'old-token',
        StorageKeys.authUser: jsonEncode(_savedUser),
      });

  Future<AuthNotifier> restore() async {
    final notifier = AuthNotifier(AuthApi(client), client);
    addTearDown(notifier.dispose);
    await notifier.restored;
    return notifier;
  }

  test('a valid saved session is confirmed and the user refreshed', () async {
    savedSession();
    server.body = {
      'user': {'id': 'u1', 'email': 'a@b.co', 'name': 'New name'},
    };

    final auth = await restore();

    expect(server.requests.single.path, '/auth/me');
    expect(server.requests.single.headers['Authorization'], 'Bearer old-token');
    expect(auth.state?.name, 'New name');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.authUser), contains('New name'));
  });

  test('an expired token signs out', () async {
    savedSession();
    server
      ..status = 401
      ..body = {'error': 'Invalid or expired session.'};

    final auth = await restore();
    await pumpEventQueue();

    expect(auth.state, isNull);
    expect(client.dio.options.headers.containsKey('Authorization'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.authToken), isNull);
  });

  test('a deleted account signs out', () async {
    savedSession();
    server
      ..status = 404
      ..body = {'error': 'User not found.'};

    final auth = await restore();

    expect(auth.state, isNull);
  });

  test('a server error keeps the saved session', () async {
    savedSession();
    server
      ..status = 500
      ..body = {'error': 'Something went wrong. Please try again.'};

    final auth = await restore();

    expect(auth.state?.name, 'Old name');
  });

  test('guests make no request', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = await restore();
    expect(auth.state, isNull);
    expect(server.requests, isEmpty);
  });

  test('a 401 on a signed-in request ends the session', () async {
    var expired = 0;
    client.onUnauthorized = () => expired++;
    client.setAuthToken('t');
    server
      ..status = 401
      ..body = {'error': 'Invalid or expired session.'};

    await expectLater(
        client.dio.get('/anything'), throwsA(isA<DioException>()));
    expect(expired, 1);
  });

  test('a 401 without a token (wrong password) does not', () async {
    var expired = 0;
    client.onUnauthorized = () => expired++;
    server
      ..status = 401
      ..body = {'error': 'Invalid email or password.'};

    await expectLater(
      AuthApi(client).login(email: 'a@b.co', password: 'wrongpass'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', 'Invalid email or password.')),
    );
    expect(expired, 0);
  });
}
