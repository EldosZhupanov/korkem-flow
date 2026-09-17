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
  static const _fallbackManifestUrl = 'https://korkem.asia/downloads/latest.json';

  Future<AppUpdate?> check({
    required String platform,
    required int build,
    String? serverUrl,
  }) async {
    final base = normaliseServerUrl(serverUrl ?? _config.baseUrl);

    if (base.isNotEmpty) {
      try {
        final response = await _dio.getUri<Map<String, dynamic>>(
          Uri.parse(base)
              .resolve(_path)
              .replace(
                queryParameters: {'platform': platform, 'build': '$build'},
              ),
        );

        final message = response.data?['message'];
        if (message is Map<String, dynamic>) {
          if (message['available'] != true) return null;

          var update = AppUpdate.fromJson(message);
          // Повышаем до https, если официальный сервер по ошибке вернул http
          if (update.url.startsWith('http://') &&
              (update.url.contains('korkem.asia') ||
                  update.url.contains('84.235.253.172'))) {
            update = AppUpdate(
              version: update.version,
              build: update.build,
              url: update.url.replaceFirst('http://', 'https://'),
              notes: update.notes,
              mandatory: update.mandatory,
            );
          }
          // Адрес без https не открываем даже если сервер его прислал:
          // сервер тоже может быть настроен неверно, а подменённый
          // установочный файл — это подменённое приложение.
          if (!update.url.startsWith('https://')) return null;
          return update;
        }
      } on Object {
        // Если основной API недоступен, пробуем статический манифест ниже.
      }
    }

    // Резервный канал: статический latest.json на веб-сайте korkem.asia
    try {
      final fallbackResponse = await _dio.getUri<Map<String, dynamic>>(
        Uri.parse(_fallbackManifestUrl),
      );
      final data = fallbackResponse.data;
      if (data is Map<String, dynamic>) {
        final remoteBuild = switch (data['build_number']) {
          final int value => value,
          final String value => int.tryParse(value) ?? 0,
          _ => 0,
        };
        if (remoteBuild > build) {
          final version = '${data['version'] ?? '0.3.0'}';
          final platforms = data['platforms'] as Map<String, dynamic>?;
          final platKey = platform.toLowerCase();
          final platData = platforms?[platKey] as Map<String, dynamic>?;
          var fileUrl = '';
          if (platKey == 'android') {
            final apk = platData?['apk'] as Map<String, dynamic>?;
            fileUrl = '${apk?['url'] ?? '/files/korkem-flow.apk'}';
          } else if (platKey == 'windows') {
            final zip = platData?['zip'] as Map<String, dynamic>?;
            fileUrl = '${zip?['url'] ?? '/files/korkem-flow-windows-x64.zip'}';
          } else if (platKey == 'linux') {
            final tar = platData?['tar_gz'] as Map<String, dynamic>?;
            fileUrl = '${tar?['url'] ?? '/files/korkem-flow-linux-x64.tar.gz'}';
          }
          if (fileUrl.isNotEmpty) {
            if (!fileUrl.startsWith('http')) {
              fileUrl = 'https://korkem.asia$fileUrl';
            }
            final releaseNotes = data['release_notes'] as Map<String, dynamic>?;
            final notes = releaseNotes?['ru'] ?? '';
            return AppUpdate(
              version: version,
              build: remoteBuild,
              url: fileUrl,
              notes: notes.toString(),
              mandatory: false,
            );
          }
        }
      }
    } on Object {
      // Игнорируем сетевые ошибки резервного источника
    }

    return null;
  }
}
