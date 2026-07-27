import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/config/app_config.dart';

/// Base Dio instance.
///
/// Auth is applied as an `Authorization` header rather than a cookie: cookie
/// sessions carry a CSRF token and Frappe rejects every unsafe method without
/// `X-Frappe-CSRF-Token` (reproduced live — docs/backend_api_audit.md §1).
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );

  return dio;
});

final frappeClientProvider = Provider<FrappeClient>(
  (ref) => FrappeClient(ref.watch(dioProvider)),
);
