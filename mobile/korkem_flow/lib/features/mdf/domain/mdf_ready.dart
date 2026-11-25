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
