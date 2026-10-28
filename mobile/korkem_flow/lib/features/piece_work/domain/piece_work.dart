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

  /// The operation a finished facade is paid under
  /// (`piece_rates.FACADE_OPERATION` on the server).
  static const facadeOperation = 'Фасад';

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
    this.dailyBonusThreshold,
    this.dailyBonus,
    this.monthlyBonusThreshold,
    this.monthlyBonus,
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
      dailyBonusThreshold: _num(rules['daily_bonus_threshold']),
      dailyBonus: _num(rules['daily_bonus']),
      monthlyBonusThreshold: _num(rules['monthly_bonus_threshold']),
      monthlyBonus: _num(rules['monthly_bonus']),
    );
  }

  final List<PieceRate> rates;
  final bool canEdit;
  final String? shiftEnd;
  final double? overtimeFactor;
  final double? weekendFactor;
  final bool saturdayIsWeekend;
  final bool sundayIsWeekend;

  /// Threshold bonuses; `null` when the company pays none.
  final double? dailyBonusThreshold;
  final double? dailyBonus;
  final double? monthlyBonusThreshold;
  final double? monthlyBonus;

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

  /// How [operation] is paid — [PieceRate.perPart] or [PieceRate.perM2] —
  /// or `null` when it has no rate.
  String? rateTypeFor(String operation) {
    for (final r in rates) {
      if (r.operation == operation && r.enabled) return r.rateType;
    }
    return null;
  }
}

double? _num(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// The way to one bonus: earned so far against the threshold.
@immutable
class BonusStep {
  const BonusStep({
    required this.earned,
    required this.threshold,
    required this.bonus,
    required this.left,
    required this.reached,
  });

  factory BonusStep.fromJson(Map<String, dynamic> json) => BonusStep(
    earned: _num(json['earned']) ?? 0,
    threshold: _num(json['threshold']) ?? 0,
    bonus: _num(json['bonus']) ?? 0,
    left: _num(json['left']) ?? 0,
    reached: json['reached'] == true,
  );

  final double earned;
  final double threshold;
  final double bonus;
  final double left;
  final bool reached;

  /// 0…1 for a progress bar.
  double get fraction =>
      threshold <= 0 ? 0 : (earned / threshold).clamp(0, 1).toDouble();
}

/// Today's and this month's way to a bonus; either is `null` when the
/// company pays no such bonus.
@immutable
class BonusProgress {
  const BonusProgress({this.today, this.month});

  factory BonusProgress.fromJson(Map<String, dynamic> json) {
    BonusStep? step(Object? raw) =>
        raw is Map ? BonusStep.fromJson(Map<String, dynamic>.from(raw)) : null;
    return BonusProgress(
      today: step(json['today']),
      month: step(json['month']),
    );
  }

  final BonusStep? today;
  final BonusStep? month;

  bool get isEmpty => today == null && month == null;
}

/// One worker's line on the pay sheet. Every figure is the server's.
@immutable
class PayrollRow {
  const PayrollRow({
    required this.employee,
    required this.employeeName,
    required this.piece,
    required this.pending,
    required this.dailyBonus,
    required this.monthlyBonus,
    required this.bonus,
    required this.fine,
    required this.advance,
    required this.toPay,
    this.paid = 0,
    double? left,
  }) : left = left ?? toPay - paid;

  factory PayrollRow.fromJson(Map<String, dynamic> json) => PayrollRow(
    employee: '${json['employee'] ?? ''}',
    employeeName: '${json['employee_name'] ?? json['employee'] ?? ''}',
    piece: _num(json['piece']) ?? 0,
    pending: _num(json['pending']) ?? 0,
    dailyBonus: _num(json['daily_bonus']) ?? 0,
    monthlyBonus: _num(json['monthly_bonus']) ?? 0,
    bonus: _num(json['bonus']) ?? 0,
    fine: _num(json['fine']) ?? 0,
    advance: _num(json['advance']) ?? 0,
    toPay: _num(json['to_pay']) ?? 0,
    paid: _num(json['paid']) ?? 0,
    left: _num(json['left']),
  );

  final String employee;
  final String employeeName;
  final double piece;
  final double pending;
  final double dailyBonus;
  final double monthlyBonus;
  final double bonus;
  final double fine;
  final double advance;
  final double toPay;

  /// Already paid out for this period («Выплачено»), and what is left of
  /// [toPay] after it.
  final double paid;
  final double left;
}

/// The pay sheet for a period.
@immutable
class PayrollStatement {
  const PayrollStatement({
    required this.fromDate,
    required this.toDate,
    required this.rows,
    required this.totalToPay,
    this.totalLeft = 0,
    this.canMarkPaid = false,
  });

  factory PayrollStatement.fromJson(Map<String, dynamic> json) =>
      PayrollStatement(
        fromDate: '${json['from_date'] ?? ''}',
        toDate: '${json['to_date'] ?? ''}',
        rows: [
          for (final row in json['rows'] as List? ?? const [])
            if (row is Map) PayrollRow.fromJson(Map<String, dynamic>.from(row)),
        ],
        totalToPay: _num(json['total_to_pay']) ?? 0,
        totalLeft: _num(json['total_left']) ?? _num(json['total_to_pay']) ?? 0,
        canMarkPaid: json['can_mark_paid'] == true,
      );

  final String fromDate;
  final String toDate;
  final List<PayrollRow> rows;
  final double totalToPay;

  /// What is still to be paid out, and whether this person hands pay over.
  final double totalLeft;
  final bool canMarkPaid;
}

/// An advance, a fine or a one-off bonus.
@immutable
class PayAdjustment {
  const PayAdjustment({
    required this.adjustment,
    required this.employee,
    required this.employeeName,
    required this.kind,
    required this.amount,
    required this.onDate,
    required this.reason,
    required this.status,
    this.createdBy,
  });

  factory PayAdjustment.fromJson(Map<String, dynamic> json) => PayAdjustment(
    adjustment: '${json['adjustment'] ?? ''}',
    employee: '${json['employee'] ?? ''}',
    employeeName: '${json['employee_name'] ?? json['employee'] ?? ''}',
    kind: '${json['kind'] ?? ''}',
    amount: _num(json['amount']) ?? 0,
    onDate: '${json['on_date'] ?? ''}',
    reason: '${json['reason'] ?? ''}',
    status: '${json['status'] ?? ''}',
    createdBy: json['created_by'] as String?,
  );

  static const advance = 'Аванс';
  static const fine = 'Штраф';
  static const bonus = 'Премия';
  static const List<String> kinds = [advance, fine, bonus];

  final String adjustment;
  final String employee;
  final String employeeName;

  /// One of [kinds] — the server's own words.
  final String kind;
  final double amount;
  final String onDate;
  final String reason;
  final String status;
  final String? createdBy;

  bool get isPending => status == PieceWorkEntry.pending;
}

/// A colleague, by name only — for a crew or an adjustment.
@immutable
class Worker {
  const Worker({required this.user, required this.name});

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    user: '${json['user'] ?? ''}',
    name: '${json['name'] ?? json['user'] ?? ''}',
  );

  final String user;
  final String name;
}
