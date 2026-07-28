import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';

/// Reads and resolves `Pending Action`.
class PendingActionRepository {
  const PendingActionRepository(this._client);

  static const doctype = 'Pending Action';

  static const listFields = [
    'name',
    'status',
    'agent_skill',
    'entity_type',
    'entity_name',
    'action_class',
    'expires_at',
    'resolved_by',
    'resolved_at',
  ];

  final FrappeClient _client;

  Future<List<PendingAction>> fetchPage({
    required int pageSize,
    int offset = 0,
    PendingActionStatus? status,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: listFields,
        filters: [
          if (status != null) FrappeFilter.equals('status', status.wireValue),
        ],
        // Oldest first: the one that has kept an agent waiting longest is the
        // one that should be resolved next.
        orderBy: 'creation asc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(fromJson).toList(growable: false);
  }

  /// Approves the proposal, which executes the underlying command server-side.
  ///
  /// `approve` and `reject` are whitelisted **document** methods, so they go
  /// through `run_doc_method` — the only verified route to them. The backend
  /// re-validates status, expiry and the target's existence, so a stale
  /// proposal cannot succeed against nothing.
  Future<void> approve(String id) =>
      _client.runDocMethod(doctype, id, 'approve');

  Future<void> reject(String id) => _client.runDocMethod(doctype, id, 'reject');

  static PendingAction fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: '${json['name']}',
      status: PendingActionStatus.fromWire(json['status'] as String?),
      agentSkill: _text(json['agent_skill']) ?? '',
      entityType: _text(json['entity_type']),
      entityName: _text(json['entity_name']),
      actionClass: _text(json['action_class']),
      expiresAt: DateTime.tryParse('${json['expires_at']}'),
      resolvedBy: _text(json['resolved_by']),
      resolvedAt: DateTime.tryParse('${json['resolved_at']}'),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
