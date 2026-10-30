import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';

/// Reads the mobile dashboard in a single call.
///
/// The aggregation is server-side (`korkem_ai.korkem_ai.dashboard.get_summary`)
/// rather than six client-side counts: latency, not query cost, is what makes a
/// dashboard feel slow on a factory network.
class DashboardRepository {
  const DashboardRepository(this._client);

  static const method = 'korkem_ai.korkem_ai.dashboard.get_summary';

  final FrappeClient _client;

  Future<DashboardSummary> fetch() async {
    final response = await _client.callMethod(method);

    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const ServerFailure('Unexpected dashboard response.');
    }

    return _parse(message);
  }

  static DashboardSummary _parse(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'];

    return DashboardSummary(
      user: json['user'] as String? ?? '',
      metrics: <String, int?>{
        if (rawMetrics is Map)
          for (final entry in rawMetrics.entries)
            '${entry.key}': switch (entry.value) {
              final int value => value,
              // Frappe hands integers back as strings in some code paths;
              // anything else (including null) means "no permission".
              final String value => int.tryParse(value),
              _ => null,
            },
      },
      attention: switch (json['attention']) {
        final List<dynamic> raw =>
          raw
              .whereType<Map<String, dynamic>>()
              .map(_attention)
              .nonNulls
              .toList(growable: false),
        _ => const [],
      },
    );
  }

  static AttentionItem? _attention(Map<String, dynamic> json) {
    final kind = AttentionKind.fromWire(json['kind'] as String?);
    final title = json['title'] as String?;
    if (kind == null || title == null) return null;

    final subtitle = (json['subtitle'] as String?)?.trim();

    return AttentionItem(
      kind: kind,
      name: '${json['name']}',
      title: title,
      subtitle: (subtitle?.isEmpty ?? true) ? null : subtitle,
      due: DateTime.tryParse('${json['due']}'),
    );
  }
}
