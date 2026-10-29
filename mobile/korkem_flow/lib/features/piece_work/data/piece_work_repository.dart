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

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final bonusProgressProvider = FutureProvider.autoDispose<BonusProgress>(
  (ref) => ref.watch(pieceWorkRepositoryProvider).progress(),
);

/// A calendar month, as the pay sheet is usually read.
typedef PayPeriod = ({DateTime from, DateTime to});

PayPeriod monthOf(DateTime day) => (
  from: DateTime(day.year, day.month),
  to: DateTime(day.year, day.month + 1, 0),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final payrollStatementProvider = FutureProvider.autoDispose
    .family<PayrollStatement, PayPeriod>(
      (ref, period) => ref.watch(pieceWorkRepositoryProvider).statement(period),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final payAdjustmentsProvider = FutureProvider.autoDispose
    .family<List<PayAdjustment>, PayPeriod>(
      (ref, period) =>
          ref.watch(pieceWorkRepositoryProvider).adjustments(period),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final workersProvider = FutureProvider.autoDispose<List<Worker>>(
  (ref) => ref.watch(pieceWorkRepositoryProvider).workers(),
);

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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

  static const _payroll = 'korkem_manufacturing.api.payroll';

  /// Only the bonus fields: the other rules are left as they are.
  Future<PieceRates> saveBonusRules({
    double? dailyThreshold,
    double? dailyBonus,
    double? monthlyThreshold,
    double? monthlyBonus,
  }) async => PieceRates.fromJson(
    _map(
      await _client.callMethod(
        '$_base.save_rules',
        post: true,
        params: {
          'daily_bonus_threshold': dailyThreshold ?? '',
          'daily_bonus': dailyBonus ?? '',
          'monthly_bonus_threshold': monthlyThreshold ?? '',
          'monthly_bonus': monthlyBonus ?? '',
        },
      ),
    ),
  );

  Future<List<Worker>> workers() async {
    final raw = (await _client.callMethod('$_payroll.workers'))['message'];
    return [
      for (final row in raw is List ? raw : const [])
        if (row is Map) Worker.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<BonusProgress> progress() async => BonusProgress.fromJson(
    _map(await _client.callMethod('$_payroll.my_progress')),
  );

  Future<PayrollStatement> statement(PayPeriod period) async =>
      PayrollStatement.fromJson(
        _map(
          await _client.callMethod(
            '$_payroll.statement',
            params: {
              'from_date': _day(period.from),
              'to_date': _day(period.to),
            },
          ),
        ),
      );

  /// «Выплачено»: a worker's [period] is paid out. The server refuses a
  /// period that has not ended, overlaps another payout, or still has
  /// something waiting for approval.
  Future<void> markPaid(String employee, PayPeriod period) async {
    await _client.callMethod(
      '$_payroll.mark_paid',
      post: true,
      params: {
        'employee': employee,
        'from_date': _day(period.from),
        'to_date': _day(period.to),
      },
    );
  }

  /// The sheet as CSV text, for accounting.
  Future<String> statementCsv(PayPeriod period) async {
    final data = _map(
      await _client.callMethod(
        '$_payroll.statement_csv',
        params: {'from_date': _day(period.from), 'to_date': _day(period.to)},
      ),
    );
    return '${data['csv'] ?? ''}';
  }

  Future<List<PayAdjustment>> adjustments(PayPeriod period) async {
    final raw = (await _client.callMethod(
      '$_payroll.adjustments',
      params: {'from_date': _day(period.from), 'to_date': _day(period.to)},
    ))['message'];
    return [
      for (final row in raw is List ? raw : const [])
        if (row is Map) PayAdjustment.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<PayAdjustment> addAdjustment({
    required String employee,
    required String kind,
    required double amount,
    required String reason,
  }) async => PayAdjustment.fromJson(
    _map(
      await _client.callMethod(
        '$_payroll.add_adjustment',
        post: true,
        params: {
          'employee': employee,
          'kind': kind,
          'amount': amount,
          'reason': reason,
        },
      ),
    ),
  );

  Future<void> approveAdjustment(String adjustment) async {
    await _client.callMethod(
      '$_payroll.approve_adjustment',
      post: true,
      params: {'adjustment': adjustment},
    );
  }

  Future<void> reverseAdjustment(String adjustment, String reason) async {
    await _client.callMethod(
      '$_payroll.reverse_adjustment',
      post: true,
      params: {'adjustment': adjustment, 'reason': reason},
    );
  }

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по сдельной оплате.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
