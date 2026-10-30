import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/one_c/domain/one_c.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';

final oneCRepositoryProvider = Provider<OneCRepository>(
  (ref) => OneCRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final oneCSettingsProvider = FutureProvider.autoDispose<OneCSettings>(
  (ref) => ref.watch(oneCRepositoryProvider).settings(),
);

/// «Обмен с 1С» (`korkem_manufacturing.api.accounting_export`). Files only, one
/// direction: 1C loads them with its own «Загрузка из табличного документа».
class OneCRepository {
  OneCRepository(this._client);

  static const _base = 'korkem_manufacturing.api.accounting_export';

  final FrappeClient _client;

  Future<OneCSettings> settings() async =>
      OneCSettings.fromJson(_map(await _client.callMethod('$_base.settings')));

  Future<OneCSettings> setEnabled({required bool enabled}) async =>
      OneCSettings.fromJson(
        _map(
          await _client.callMethod(
            '$_base.set_enabled',
            post: true,
            params: {'enabled': enabled ? 1 : 0},
          ),
        ),
      );

  Future<OneCExport> export(String table, PayPeriod period) async =>
      OneCExport.fromJson(
        _map(
          await _client.callMethod(
            '$_base.export',
            params: {
              'table': table,
              'from_date': _day(period.from),
              'to_date': _day(period.to),
            },
          ),
        ),
      );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по обмену с 1С.');
    }
    return Map<String, dynamic>.from(raw);
  }
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
