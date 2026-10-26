import 'package:meta/meta.dart';

/// One piece-work accrual, as the server recorded it.
@immutable
class PieceWorkEntry {
  const PieceWorkEntry({
    required this.entry,
    required this.employeeName,
    required this.operation,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.factor,
    required this.shift,
    required this.amount,
    required this.status,
    this.reason,
    this.isReversal = false,
  });

  factory PieceWorkEntry.fromJson(Map<String, dynamic> json) => PieceWorkEntry(
    entry: '${json['entry'] ?? ''}',
    employeeName: '${json['employee_name'] ?? json['employee'] ?? ''}',
    operation: '${json['operation'] ?? ''}',
    quantity: _num(json['quantity']) ?? 0,
    unit: '${json['unit'] ?? ''}',
    rate: _num(json['rate']) ?? 0,
    factor: _num(json['factor']) ?? 1,
    shift: '${json['shift'] ?? ''}',
    amount: _num(json['amount']) ?? 0,
    status: '${json['status'] ?? ''}',
    reason: json['reason'] as String?,
    isReversal: json['is_reversal'] == true,
  );

  static const pending = 'Pending Approval';
  static const approved = 'Approved';
  static const paid = 'Paid';
  static const reversed = 'Reversed';

  final String entry;
  final String employeeName;
  final String operation;
  final double quantity;
  final String unit;
  final double rate;
  final double factor;
  final String shift;
  final double amount;
  final String status;
  final String? reason;
  final bool isReversal;
}

/// The worker's own pay over a period, and what the manager may do.
@immutable
class MyPieceWork {
  const MyPieceWork({
    required this.entries,
    required this.pending,
    required this.approved,
    required this.paid,
  });

  factory MyPieceWork.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : const <String, dynamic>{};
    return MyPieceWork(
      entries: [
        for (final row in json['entries'] as List? ?? const [])
          if (row is Map)
            PieceWorkEntry.fromJson(Map<String, dynamic>.from(row)),
      ],
      pending: _num(totals['pending']) ?? 0,
      approved: _num(totals['approved']) ?? 0,
      paid: _num(totals['paid']) ?? 0,
    );
  }

  final List<PieceWorkEntry> entries;
  final double pending;
  final double approved;
  final double paid;
}

/// One rate: what a unit of an operation pays.
@immutable
class PieceRate {
  const PieceRate({
    required this.operation,
    required this.rateType,
    required this.rate,
    this.enabled = true,
  });

  factory PieceRate.fromJson(Map<String, dynamic> json) => PieceRate(
    operation: '${json['operation'] ?? ''}',
    rateType: '${json['rate_type'] ?? perPart}',
    rate: _num(json['rate']) ?? 0,
    enabled: json['enabled'] != false,
  );

  static const perPart = 'KZT_PER_PART';
  static const perM2 = 'KZT_PER_M2';

  final String operation;
  final String rateType;
  final double rate;
  final bool enabled;
}

/// Rates, coefficients, and whether this person may change them.
@immutable
class PieceRates {
  const PieceRates({
    required this.rates,
    required this.canEdit,
    this.shiftEnd,
    this.overtimeFactor,
    this.weekendFactor,
    this.saturdayIsWeekend = false,
    this.sundayIsWeekend = true,
  });

  factory PieceRates.fromJson(Map<String, dynamic> json) {
    final rules = json['rules'] is Map
        ? Map<String, dynamic>.from(json['rules'] as Map)
        : const <String, dynamic>{};
    return PieceRates(
      rates: [
        for (final row in json['rates'] as List? ?? const [])
          if (row is Map) PieceRate.fromJson(Map<String, dynamic>.from(row)),
      ],
      canEdit: json['can_edit'] == true,
      shiftEnd: rules['shift_end'] as String?,
      overtimeFactor: _num(rules['overtime_factor']),
      weekendFactor: _num(rules['weekend_factor']),
      saturdayIsWeekend: rules['saturday_is_weekend'] == true,
      sundayIsWeekend: rules['sunday_is_weekend'] != false,
    );
  }

  final List<PieceRate> rates;
  final bool canEdit;
  final String? shiftEnd;
  final double? overtimeFactor;
  final double? weekendFactor;
  final bool saturdayIsWeekend;
  final bool sundayIsWeekend;

  /// The per-piece rate for [operation], or `null` when it pays nothing
  /// automatically — then no estimate is shown rather than a made-up one.
  double? perPieceFor(String operation) {
    for (final r in rates) {
      if (r.operation == operation &&
          r.enabled &&
          r.rateType == PieceRate.perPart) {
        return r.rate;
      }
    }
    return null;
  }
}

double? _num(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};
