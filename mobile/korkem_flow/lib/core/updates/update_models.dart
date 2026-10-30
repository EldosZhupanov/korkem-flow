import 'package:flutter/foundation.dart';

/// Сборка новее той, что сейчас в руках у человека.
@immutable
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    required this.url,
    required this.notes,
    required this.mandatory,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    return AppUpdate(
      version: '${json['version'] ?? ''}',
      build: switch (json['build']) {
        final int value => value,
        final String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
      url: '${json['url'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      mandatory: json['mandatory'] == true || json['mandatory'] == 1,
    );
  }

  final String version;
  final int build;
  final String url;
  final String notes;

  /// Обновление, которое нельзя отложить.
  ///
  /// Ставится сервером, когда старая версия перестала работать, а не для того,
  /// чтобы поторопить: человек в цехе, которому загородили экран ради удобства
  /// разработчика, в следующий раз не откроет приложение вовсе.
  final bool mandatory;
}
