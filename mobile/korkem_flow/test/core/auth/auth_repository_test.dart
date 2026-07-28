import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/auth_repository.dart';

/// Serves canned responses off the real Dio pipeline, so the code under test
/// exercises its actual request construction rather than a mock of it.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  Map<String, dynamic> body, {
  int status = 200,
  List<String>? setCookie,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      'set-cookie': ?setCookie,
    },
  );
}

const _base = 'https://korkem.example.kz';
const _sidCookie =
    'sid=abc123def; Expires=Tue, 04 Aug 2026 09:00:00 GMT; Path=/; HttpOnly';

void main() {
  late _FakeAdapter adapter;
  late AuthRepository repository;

  void serve(ResponseBody Function(RequestOptions options) handler) {
    adapter = _FakeAdapter(handler);
    repository = AuthRepository(Dio()..httpClientAdapter = adapter);
  }

  group('signIn', () {
    test('prefers API keys when the user may mint them', () async {
      serve((options) {
        if (options.path.endsWith('/login')) {
          return _json({'message': 'Logged In'}, setCookie: [_sidCookie]);
        }
        if (options.path.endsWith('get_logged_user')) {
          return _json({'message': 'aidos@korkem.kz'});
        }
        return _json({
          'message': {'api_key': 'K123', 'api_secret': 'S456'},
        });
      });

      final credentials = await repository.signIn(
        baseUrl: _base,
        user: 'AIDOS@korkem.kz',
        password: 'secret',
      );

      expect(credentials, isA<ApiKeyCredentials>());
      expect(credentials.header.key, 'Authorization');
      expect(credentials.header.value, 'token K123:S456');
      // The server's spelling of the user wins over whatever was typed.
      expect(credentials.user, 'aidos@korkem.kz');
    });

    test(
      'falls back to the session cookie when generate_keys is refused',
      () async {
        // This is the *common* path: generate_keys calls only_for(
        // "System Manager") and most real accounts are plain Sales Users.
        serve((options) {
          if (options.path.endsWith('/login')) {
            return _json({'message': 'Logged In'}, setCookie: [_sidCookie]);
          }
          if (options.path.endsWith('get_logged_user')) {
            return _json({'message': 'rep1@korkem.kz'});
          }
          return _json({'exc_type': 'PermissionError'}, status: 403);
        });

        final credentials = await repository.signIn(
          baseUrl: _base,
          user: 'rep1@korkem.kz',
          password: 'secret',
        );

        expect(credentials, isA<SessionCredentials>());
        expect(credentials.header.key, 'Cookie');
        expect(credentials.header.value, 'sid=abc123def');
      },
    );

    test('reports a wrong password as such, not as an expired session', () {
      serve((options) => _json({'message': 'Invalid login'}, status: 401));

      expect(
        () => repository.signIn(
          baseUrl: _base,
          user: 'rep1@korkem.kz',
          password: 'wrong',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('password'),
          ),
        ),
      );
    });

    test('rejects a login that returns no usable session cookie', () {
      serve(
        (options) => _json({'message': 'Logged In'}, setCookie: ['sid=Guest']),
      );

      expect(
        () => repository.signIn(
          baseUrl: _base,
          user: 'rep1@korkem.kz',
          password: 'secret',
        ),
        throwsA(isA<ServerFailure>()),
      );
    });

    test(
      'does not double the slash when the server URL has a trailing one',
      () async {
        serve((options) {
          if (options.path.endsWith('/login')) {
            return _json({'message': 'Logged In'}, setCookie: [_sidCookie]);
          }
          if (options.path.endsWith('get_logged_user')) {
            return _json({'message': 'a@b.kz'});
          }
          return _json({'exc_type': 'PermissionError'}, status: 403);
        });

        await repository.signIn(
          baseUrl: '$_base/',
          user: 'a@b.kz',
          password: 'secret',
        );

        expect(
          adapter.requests.first.uri.toString(),
          '$_base/api/method/login',
        );
      },
    );
  });

  group('verify', () {
    test('returns the user the credential actually belongs to', () async {
      serve((options) => _json({'message': 'aidos@korkem.kz'}));

      final user = await repository.verify(
        baseUrl: _base,
        credentials: const SessionCredentials(user: 'stale@old.kz', sid: 'x'),
      );

      expect(user, 'aidos@korkem.kz');
      expect(adapter.requests.single.headers['Cookie'], 'sid=x');
    });

    test('treats a Guest identity as an expired credential', () {
      // A dead sid does not 401 — Frappe answers cheerfully as Guest, which is
      // exactly the case a naive status-code check would miss.
      serve((options) => _json({'message': 'Guest'}));

      expect(
        () => repository.verify(
          baseUrl: _base,
          credentials: const SessionCredentials(user: 'a@b.kz', sid: 'dead'),
        ),
        throwsA(isA<AuthFailure>()),
      );
    });
  });
}
