import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/updates/update_models.dart';

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  return UpdateRepository(
    ref.watch(authDioProvider),
    ref.watch(appConfigProvider),
  );
});

/// Спрашивает узел, вышло ли что-то новее.
///
/// Через неавторизованный клиент намеренно: приложение, устаревшее настолько,
/// что уже не может войти, — именно то, которому нужно обновиться.
class UpdateRepository {
  const UpdateRepository(this._dio, this._config);

  final Dio _dio;
  final AppConfig _config;

  static const _path = '/api/method/korkem_ai.korkem_ai.updates.latest';

  Future<AppUpdate?> check({
    required String platform,
    required int build,
    String? serverUrl,
  }) async {
    final base = normaliseServerUrl(serverUrl ?? _config.baseUrl);
    if (base.isEmpty) return null;

    final response = await _dio.getUri<Map<String, dynamic>>(
      Uri.parse(base)
          .resolve(_path)
          .replace(
            queryParameters: {'platform': platform, 'build': '$build'},
          ),
    );

    final message = response.data?['message'];
    if (message is! Map<String, dynamic>) return null;
    if (message['available'] != true) return null;

    final update = AppUpdate.fromJson(message);
    // Адрес без https не открываем даже если сервер его прислал: сервер тоже
    // может быть настроен неверно, а подменённый установочный файл — это
    // подменённое приложение.
    if (!update.url.startsWith('https://')) return null;
    return update;
  }
}
