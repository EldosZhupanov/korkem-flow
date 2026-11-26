import 'package:flutter/foundation.dart';

/// «Когда будет готово» from the shop's load (owner, 25.11.2026): the day,
/// the working days to it, and whether the shop's pace is known or the
/// lanes' least days are all there is to go by.
@immutable
class MdfReadyEstimate {
  const MdfReadyEstimate({
    required this.readyOn,
    this.days = 0,
    this.known = false,
  });

  factory MdfReadyEstimate.fromJson(Map<String, dynamic> j) => MdfReadyEstimate(
    readyOn: '${j['ready_on'] ?? ''}',
    days: j['days'] is num ? (j['days'] as num).toInt() : 0,
    known: j['known'] == true,
  );

  /// `yyyy-MM-dd`.
  final String readyOn;
  final int days;
  final bool known;

  DateTime? get day => DateTime.tryParse(readyOn);
}

/// A film the order is pressed with: on the shelf, or when it can come.
typedef MdfDueFilm = ({
  String decor,
  double? freeM,
  bool short,
  DateTime? comesOn,
  String? supplier,
});

/// One day's m² already due, and how many orders.
typedef MdfDueDay = ({DateTime date, double m2, int orders});

/// «Срок» (owner, 27.11.2026): the earliest day the shop makes the order, a
/// safe one after it, each day's load and the film it waits for.
@immutable
class MdfDueOptions {
  const MdfDueOptions({
    required this.earliest,
    required this.safe,
    this.known = false,
    this.films = const [],
    this.capacityM2,
    this.days = const [],
  });

  factory MdfDueOptions.fromJson(Map<String, dynamic> j) {
    DateTime day(Object? v) => DateTime.tryParse('$v') ?? DateTime.now();
    return MdfDueOptions(
      earliest: day(j['earliest']),
      safe: day(j['safe']),
      known: j['known'] == true,
      capacityM2: j['capacity_m2'] is num
          ? (j['capacity_m2'] as num).toDouble()
          : null,
      films: [
        for (final f in j['films'] as List? ?? const [])
          if (f is Map)
            (
              decor: '${f['decor']}',
              freeM: f['free_m'] is num ? (f['free_m'] as num).toDouble() : null,
              short: f['short'] == true,
              comesOn: DateTime.tryParse('${f['comes_on'] ?? ''}'),
              supplier: f['supplier'] == null ? null : '${f['supplier']}',
            ),
      ],
      days: [
        for (final d in j['days'] as List? ?? const [])
          if (d is Map)
            (
              date: day(d['date']),
              m2: d['m2'] is num ? (d['m2'] as num).toDouble() : 0,
              orders: d['orders'] is num ? (d['orders'] as num).toInt() : 0,
            ),
      ],
    );
  }

  final DateTime earliest;
  final DateTime safe;
  final bool known;
  final List<MdfDueFilm> films;

  /// The shop's m² a working day; null — too few orders to tell.
  final double? capacityM2;
  final List<MdfDueDay> days;

  /// The m² already due on [day].
  double dueOn(DateTime day) => days
      .where(
        (d) =>
            d.date.year == day.year &&
            d.date.month == day.month &&
            d.date.day == day.day,
      )
      .fold(0, (s, d) => s + d.m2);
}
