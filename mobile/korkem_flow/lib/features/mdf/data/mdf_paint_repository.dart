import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_paint.dart';

final mdfPaintRepositoryProvider = Provider<MdfPaintRepository>(
  (ref) => MdfPaintRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfPaintBoardProvider = FutureProvider.autoDispose<MdfPaintBoard>(
  (ref) => ref.watch(mdfPaintRepositoryProvider).board(),
);

/// «Отдел краски» — `korkem_manufacturing.api.mdf_paint`.
class MdfPaintRepository {
  const MdfPaintRepository(this._client);

  static const _base = 'korkem_manufacturing.api.mdf_paint';

  final FrappeClient _client;

  Future<MdfPaintBoard> board() async =>
      _board(await _client.callMethod('$_base.board'));

  /// «Покрасил — сушится».
  Future<MdfPaintBoard> startDrying(String order) async => _board(
    await _client.callMethod(
      '$_base.start_drying',
      post: true,
      params: {'order': order},
    ),
  );

  /// Put to dry by mistake.
  Future<MdfPaintBoard> stopDrying(String order) async => _board(
    await _client.callMethod(
      '$_base.stop_drying',
      post: true,
      params: {'order': order},
    ),
  );

  /// «Краска клиента принесена» — with what he brought.
  Future<MdfPaintBoard> clientPaintIn(String order, {String? note}) async =>
      _board(
        await _client.callMethod(
          '$_base.client_paint_in',
          post: true,
          params: {'order': order, 'note': ?note},
        ),
      );

  /// The drying hours and the discount for the customer's own paint.
  Future<MdfPaintBoard> settings({
    int? dryHours,
    double? clientPaintDiscount,
  }) async => _board(
    await _client.callMethod(
      '$_base.settings',
      post: true,
      params: {
        'dry_hours': ?dryHours,
        'client_paint_discount': ?clientPaintDiscount,
      },
    ),
  );

  static MdfPaintBoard _board(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return MdfPaintBoard.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{},
    );
  }
}
