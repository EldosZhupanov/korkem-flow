import 'dart:convert';

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
    'display_data',
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

  Future<void> reject(String id, {String? reason}) {
    final trimmed = reason?.trim();
    return _client.runDocMethod(
      doctype,
      id,
      'reject',
      args: trimmed != null && trimmed.isNotEmpty
          ? <String, dynamic>{'reason': trimmed}
          : null,
    );
  }

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
      preview: _parsePreview(json['preview'] ?? json['display_data']),
    );
  }

  static ActionPreview? _parsePreview(Object? raw) {
    if (raw == null) return null;
    if (raw is ActionPreview) return raw.isNotEmpty ? raw : null;

    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        decoded = jsonDecode(trimmed);
      } on Object catch (_) {
        return null;
      }
    }

    if (decoded is! Map && decoded is! List) return null;

    if (decoded is List) {
      final fields = _parseFieldsList(decoded);
      return fields.isEmpty ? null : ActionPreview(fields: fields);
    }

    final map = decoded! as Map;

    // Check nested 'preview' if present inside display_data
    final nested = map['preview'];
    if (nested != null) {
      final parsed = _parsePreview(nested);
      if (parsed != null && parsed.isNotEmpty) return parsed;
    }

    final title = _text(
      map['title'] ?? map['summary'] ?? map['description'] ?? map['message'],
    );

    final rawFields =
        map['fields'] ?? map['changes'] ?? map['items'] ?? map['rows'];
    var fields = const <ActionPreviewField>[];

    if (rawFields is List) {
      fields = _parseFieldsList(rawFields);
    } else if (rawFields is Map) {
      fields = _parseFieldsMap(rawFields);
    }

    if (title == null && fields.isEmpty) return null;

    return ActionPreview(title: title, fields: fields);
  }

  static List<ActionPreviewField> _parseFieldsList(List<dynamic> list) {
    final result = <ActionPreviewField>[];
    for (final item in list) {
      if (item is! Map) continue;
      final label = _text(
        item['label'] ??
            item['field'] ??
            item['title'] ??
            item['name'] ??
            item['key'],
      );
      final value = _text(item['value'] ?? item['new'] ?? item['val']);
      if (label != null && value != null) {
        result.add(ActionPreviewField(label: label, value: value));
      }
    }
    return result;
  }

  static List<ActionPreviewField> _parseFieldsMap(Map<dynamic, dynamic> map) {
    final result = <ActionPreviewField>[];
    for (final entry in map.entries) {
      final label = _text(entry.key);
      final value = _text(entry.value);
      if (label != null && value != null) {
        result.add(ActionPreviewField(label: label, value: value));
      }
    }
    return result;
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final str = (value is String ? value : '$value').trim();
    return str.isEmpty ? null : str;
  }
}
