import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';

final pieceWorkRepositoryProvider = Provider<PieceWorkRepository>((ref) {
  return PieceWorkRepository(ref.watch(frappeClientProvider));
});

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final pieceRatesProvider = FutureProvider.autoDispose<PieceRates>(
  (ref) => ref.watch(pieceWorkRepositoryProvider).rates(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final myPieceWorkProvider = FutureProvider.autoDispose<MyPieceWork>(
  (ref) => ref.watch(pieceWorkRepositoryProvider).myWork(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final pendingPieceWorkProvider =
    FutureProvider.autoDispose<List<PieceWorkEntry>>(
      (ref) => ref.watch(pieceWorkRepositoryProvider).pending(),
    );

/// Piece-rate pay. Amounts are always the server's; nothing is multiplied here.
class PieceWorkRepository {
  const PieceWorkRepository(this._client);

  static const _base = 'korkem_manufacturing.api.piece_work';

  final FrappeClient _client;

  Future<PieceRates> rates() async =>
      PieceRates.fromJson(_map(await _client.callMethod('$_base.rates')));

  Future<MyPieceWork> myWork() async =>
      MyPieceWork.fromJson(_map(await _client.callMethod('$_base.my_work')));

  Future<List<PieceWorkEntry>> pending() async {
    final raw = (await _client.callMethod('$_base.pending'))['message'];
    return [
      for (final row in raw is List ? raw : const [])
        if (row is Map) PieceWorkEntry.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> approve(String entry) async {
    await _client.callMethod(
      '$_base.approve',
      post: true,
      params: {'entry': entry},
    );
  }

  Future<void> reject(String entry, String reason) async {
    await _client.callMethod(
      '$_base.reject',
      post: true,
      params: {'entry': entry, 'reason': reason},
    );
  }

  Future<PieceRates> setRate({
    required String operation,
    required String rateType,
    required double rate,
    bool enabled = true,
  }) async => PieceRates.fromJson(
    _map(
      await _client.callMethod(
        '$_base.set_rate',
        post: true,
        params: {
          'operation': operation,
          'rate_type': rateType,
          'rate': rate,
          'enabled': enabled ? 1 : 0,
        },
      ),
    ),
  );

  Future<PieceRates> saveRules({
    required bool saturdayIsWeekend,
    required bool sundayIsWeekend,
    String? shiftEnd,
    double? overtimeFactor,
    double? weekendFactor,
  }) async => PieceRates.fromJson(
    _map(
      await _client.callMethod(
        '$_base.save_rules',
        post: true,
        params: {
          'shift_end': shiftEnd ?? '',
          'overtime_factor': overtimeFactor ?? '',
          'weekend_factor': weekendFactor ?? '',
          'saturday_is_weekend': saturdayIsWeekend ? 1 : 0,
          'sunday_is_weekend': sundayIsWeekend ? 1 : 0,
        },
      ),
    ),
  );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по сдельной оплате.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
