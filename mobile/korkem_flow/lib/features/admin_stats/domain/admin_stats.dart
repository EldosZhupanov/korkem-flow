import 'package:meta/meta.dart';

/// The four outcome numbers that prove whether the shop owner can avoid
/// hiring an administrator.
///
/// An administrator's job is to catch what was said and ensure somebody acts
/// on it. The measure is outcome rather than vanity activity: how much was
/// caught, handed to a person via a task, turned into orders, and how much
/// went stale (>24 hours unassigned).
@immutable
class AdminStats {
  const AdminStats({
    required this.days,
    required this.caught,
    required this.handedOver,
    required this.converted,
    required this.dismissed,
    required this.stale,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : json);

    int asInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return AdminStats(
      days: asInt(message['days'], 30),
      caught: asInt(message['caught']),
      handedOver: asInt(message['handed_over']),
      converted: asInt(message['converted']),
      dismissed: asInt(message['dismissed']),
      stale: asInt(message['stale']),
    );
  }

  final int days;
  final int caught;
  final int handedOver;
  final int converted;
  final int dismissed;
  final int stale;

  /// True when no captures have been recorded at all for this time window.
  bool get isEmpty => caught == 0;
}
