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
import 'package:url_launcher/url_launcher.dart';

/// Что сейчас известно про обновление.
@immutable
class UpdateState {
  const UpdateState({
    this.available,
    this.progress,
    this.failure,
    this.dismissed = false,
    this.isChecking = false,
    this.currentVersion,
    this.currentBuild,
  });

  final AppUpdate? available;

  /// Ноль до единицы, пока файл качается; `null`, когда не качается.
  final double? progress;
  final String? failure;
  final bool dismissed;
  final bool isChecking;
  final String? currentVersion;
  final int? currentBuild;

  bool get downloading => progress != null;
  bool get hasUpdate => available != null;

  UpdateState copyWith({
    AppUpdate? available,
    double? progress,
    String? failure,
    bool? dismissed,
    bool? isChecking,
    String? currentVersion,
    int? currentBuild,
    bool clearProgress = false,
    bool clearFailure = false,
    bool clearAvailable = false,
  }) {
    return UpdateState(
      available: clearAvailable ? null : (available ?? this.available),
      progress: clearProgress ? null : (progress ?? this.progress),
      failure: clearFailure ? null : (failure ?? this.failure),
      dismissed: dismissed ?? this.dismissed,
      isChecking: isChecking ?? this.isChecking,
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuild: currentBuild ?? this.currentBuild,
    );
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Проверяет обновления и ставит их с подтверждением пользователя.
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
    if (Platform.isLinux) return 'Linux';
    return null;
  }

  void dismiss() {
    if (state.available?.mandatory == true) return;
    state = state.copyWith(dismissed: true);
  }

  Future<void> check({bool force = false}) async {
    final platform = _platform;
    if (platform == null) return;

    try {
      final info = await PackageInfo.fromPlatform();
      if (!ref.mounted) return;

      state = state.copyWith(
        isChecking: true,
        clearFailure: true,
        dismissed: force ? false : null,
      );

      final build = int.tryParse(info.buildNumber) ?? 0;
      final update = await ref
          .read(updateRepositoryProvider)
          .check(
            platform: platform,
            build: build,
            serverUrl: ref.read(sessionProvider).value?.serverUrl,
          );

      if (!ref.mounted) return;

      state = state.copyWith(
        available: update,
        clearAvailable: update == null,
        isChecking: false,
        currentVersion: info.version,
        currentBuild: build,
      );
    } on Object catch (error) {
      debugPrint('Update check failed: $error');
      if (ref.mounted) {
        state = state.copyWith(isChecking: false);
      }
    }
  }

  /// Скачать и отдать системе на установку.
  ///
  /// На мобильных (Android) файл скачивается во внутреннее хранилище и
  /// открывается через Intent установщика пакетов. На десктопе сохраняется
  /// в каталог Загрузок и открывается системой либо скачивается в браузере.
  Future<void> download() async {
    final update = state.available;
    if (update == null || state.downloading) return;

    state = state.copyWith(progress: 0, clearFailure: true);
    try {
      Directory directory;
      String filename;

      if (Platform.isAndroid) {
        directory = await getApplicationSupportDirectory();
        filename = 'korkem-${update.build}.apk';
      } else {
        try {
          final downloads = await getDownloadsDirectory();
          directory = downloads ?? await getApplicationSupportDirectory();
        } on Object catch (_) {
          directory = await getApplicationSupportDirectory();
        }

        final path = Uri.parse(update.url).path;
        if (path.endsWith('.tar.gz')) {
          filename = 'korkem-${update.build}.tar.gz';
        } else if (path.endsWith('.zip')) {
          filename = 'korkem-${update.build}.zip';
        } else if (path.endsWith('.exe')) {
          filename = 'korkem-${update.build}.exe';
        } else {
          filename = 'korkem-${update.build}'
              '${Platform.isWindows ? ".zip" : ".tar.gz"}';
        }
      }

      final file = File('${directory.path}/$filename');

      await Dio().downloadUri(
        Uri.parse(update.url),
        file.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(progress: received / total);
          }
        },
      );

      state = state.copyWith(clearProgress: true);

      if (Platform.isAndroid) {
        await OpenFilex.open(
          file.path,
          type: 'application/vnd.android.package-archive',
        );
      } else {
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          await openExternalUrl();
        }
      }
    } on Object catch (error) {
      state = state.copyWith(clearProgress: true, failure: '$error');
    }
  }

  Future<void> openExternalUrl() async {
    final update = state.available;
    if (update == null) return;
    final uri = Uri.parse(update.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('Could not launch URL: $e');
    }
  }
}
