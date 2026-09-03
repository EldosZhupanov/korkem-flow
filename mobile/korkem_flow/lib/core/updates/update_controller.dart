import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/updates/update_models.dart';
import 'package:korkem_flow/core/updates/update_repository.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Что сейчас известно про обновление.
@immutable
class UpdateState {
  const UpdateState({this.available, this.progress, this.failure});

  final AppUpdate? available;

  /// Ноль до единицы, пока файл качается; `null`, когда не качается.
  final double? progress;
  final String? failure;

  bool get downloading => progress != null;

  UpdateState copyWith({
    AppUpdate? available,
    double? progress,
    String? failure,
    bool clearProgress = false,
    bool clearFailure = false,
  }) {
    return UpdateState(
      available: available ?? this.available,
      progress: clearProgress ? null : (progress ?? this.progress),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Проверяет обновления и ставит их.
///
/// Существует потому, что пересылка файла обновляет приложение у одного
/// человека — того, кому файл переслали. Google Play делает это сам, и туда мы
/// идём; до Play и там, где Play нет, это делает узел.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    // Проверка одна на запуск и молчаливая: неудача проверки — не событие
    // для человека. Он про обновление не спрашивал.
    unawaited(check());
    return const UpdateState();
  }

  /// Платформа в терминах сервера.
  ///
  /// Спрашиваем только там, где умеем поставить: предложить обновление и не
  /// суметь его поставить хуже, чем не предлагать.
  static String? get _platform {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    return null;
  }

  Future<void> check() async {
    final platform = _platform;
    if (platform == null) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      final update = await ref
          .read(updateRepositoryProvider)
          .check(
            platform: platform,
            build: build,
            serverUrl: ref.read(sessionProvider).value?.serverUrl,
          );
      if (update != null) state = state.copyWith(available: update);
    } on Object catch (error) {
      // Молча в интерфейсе, но не молча совсем: «почему обновление не
      // приходит» — вопрос, на который должен быть ответ хотя бы в журнале.
      debugPrint('Update check failed: $error');
    }
  }

  /// Скачать и отдать системе на установку.
  ///
  /// Файл кладётся в личный каталог приложения, а не в общие «Загрузки»:
  /// установочный файл, лежащий у всех на виду, может быть подменён между
  /// скачиванием и запуском.
  Future<void> download() async {
    final update = state.available;
    if (update == null || state.downloading) return;

    state = state.copyWith(progress: 0, clearFailure: true);
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/korkem-${update.build}.apk');

      await Dio().downloadUri(
        Uri.parse(update.url),
        file.path,
        onReceiveProgress: (received, total) {
          if (total > 0) state = state.copyWith(progress: received / total);
        },
      );

      state = state.copyWith(clearProgress: true);
      // Дальше решает система: она покажет своё окно установки и спросит
      // разрешение ставить из этого источника. Ставить приложение мимо этого
      // окна нельзя и не нужно — человек должен видеть, что именно ставится.
      await OpenFilex.open(file.path);
    } on Object catch (error) {
      state = state.copyWith(clearProgress: true, failure: '$error');
    }
  }
}
