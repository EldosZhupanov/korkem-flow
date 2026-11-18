import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/my_work.dart';
import 'package:korkem_flow/features/mdf/domain/order_scan.dart';

final myWorkRepositoryProvider = Provider<MyWorkRepository>(
  (ref) => MyWorkRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final myWorkProvider = FutureProvider.autoDispose<MyWork>(
  (ref) => ref.watch(myWorkRepositoryProvider).work(),
);

/// «Мои заказы»: the signed-in worker's own stages.
class MyWorkRepository {
  MyWorkRepository(this._client);

  final FrappeClient _client;

  static const _base = 'korkem_manufacturing.api.my_work';

  Future<MyWork> work() async =>
      MyWork.fromJson(_map(await _client.callMethod('$_base.work')));

  /// «Сделал» — or, [undo], taken back the same day.
  Future<MyWork> done(
    String order,
    MdfStage stage, {
    bool undo = false,
  }) async => MyWork.fromJson(
    _map(
      await _client.callMethod(
        '$_base.done',
        post: true,
        params: {'order': order, 'stage': stage.name, 'undo': undo ? 1 : 0},
      ),
    ),
  );

  /// A sticker scanned, or a number typed: the order and its stages.
  Future<OrderScan> scan(String code) async => OrderScan.fromJson(
    _map(
      await _client.callMethod('$_base.scan', params: {'code': code}),
    ),
  );

  /// «Сделал» from a scan — or, [undo], taken back; answers the scan again.
  Future<OrderScan> tick(
    String order,
    MdfStage stage, {
    bool undo = false,
  }) async => OrderScan.fromJson(
    _map(
      await _client.callMethod(
        '$_base.tick',
        post: true,
        params: {'order': order, 'stage': stage.name, 'undo': undo ? 1 : 0},
      ),
    ),
  );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по моим заказам.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
