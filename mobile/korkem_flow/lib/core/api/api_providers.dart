import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/config/app_config.dart';

const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 30);

/// A bare client with no credential attached and no base URL.
///
/// Sign-in happens *before* a credential exists, so it cannot travel through
/// the interceptor below — and the server it targets is the one the user just
/// typed, not the one already stored. Kept separate from [dioProvider] so the
/// two never form a cycle through [sessionProvider].
final authDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );
});

/// The authenticated client every feature uses.
///
/// Rebuilt whenever the session changes, so signing in or switching servers
/// cannot leave a stale credential attached to in-flight configuration.
final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionProvider).value;
  final baseUrl = session?.serverUrl ?? ref.watch(appConfigProvider).baseUrl;

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );

  final credentials = session?.credentials;
  if (credentials != null) {
    // Header auth rather than a cookie jar: whichever variant is in play, the
    // credential is one header and there is no cookie state to keep in sync.
    final header = credentials.header;
    dio.options.headers[header.key] = header.value;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        // 401 means the credential the app holds is no longer accepted. Drop it
        // once, here, rather than letting every screen invent its own recovery.
        if (error.response?.statusCode == 401 &&
            session?.isAuthenticated == true) {
          unawaited(ref.read(sessionProvider.notifier).signOut());
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

final frappeClientProvider = Provider<FrappeClient>(
  (ref) => FrappeClient(ref.watch(dioProvider)),
);
