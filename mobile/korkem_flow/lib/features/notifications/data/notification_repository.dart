import 'dart:convert';

import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/api/html_text.dart';
import 'package:korkem_flow/features/notifications/domain/app_notification.dart';

/// Reads and clears `Notification Log`.
class NotificationRepository {
  const NotificationRepository(this._client);

  static const doctype = 'Notification Log';

  static const listFields = [
    'name',
    'type',
    'subject',
    'document_type',
    'document_name',
    'from_user',
    'read',
    'creation',
  ];

  final FrappeClient _client;

  /// One page of *this user's* notifications.
  ///
  /// [forUser] is required and always filtered on. Frappe registers no
  /// `get_permission_query_conditions` for this doctype and grants read to the
  /// role `All`, so an unfiltered query returns **everyone's** notifications —
  /// confirmed live, where an admin's list came back full of another user's
  /// assignments. The scoping is the client's job here, and forgetting it is a
  /// privacy leak rather than a cosmetic bug.
  Future<List<AppNotification>> fetchPage({
    required String forUser,
    required int pageSize,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final rows = await _client.getList(
      doctype,
      FrappeQuery(
        fields: listFields,
        filters: [
          FrappeFilter.equals('for_user', forUser),
          if (unreadOnly) const FrappeFilter.equals('read', 0),
        ],
        orderBy: 'creation desc',
        limitStart: offset,
        limitPageLength: pageSize,
      ),
    );

    return rows.map(fromJson).toList(growable: false);
  }

  /// How many unread notifications this user has — for the badge.
  ///
  /// A count, not a page: the badge needs a number, and fetching rows to
  /// measure their length would page the very list it is summarising.
  Future<int> unreadCount(String forUser) async {
    final response = await _client.callMethod(
      'frappe.client.get_count',
      params: <String, dynamic>{
        'doctype': doctype,
        // get_count takes the same JSON-encoded triples as a list query.
        'filters': jsonEncode([
          FrappeFilter.equals('for_user', forUser).toJson(),
          const FrappeFilter.equals('read', 0).toJson(),
        ]),
      },
    );

    return switch (response['message']) {
      final int value => value,
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
  }

  /// Frappe's own whitelisted methods, not `set_value`.
  ///
  /// Both scope their update to `frappe.session.user` server-side, so a caller
  /// cannot mark somebody else's notification read — which a direct field
  /// write on this doctype would happily allow.
  Future<void> markRead(String id) => _client.callMethod(
    'frappe.desk.doctype.notification_log.notification_log.mark_as_read',
    post: true,
    params: <String, dynamic>{'docname': id},
  );

  Future<void> markAllRead() => _client.callMethod(
    'frappe.desk.doctype.notification_log.notification_log.mark_all_as_read',
    post: true,
  );

  static AppNotification fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];

    return AppNotification(
      id: '${json['name']}',
      type: NotificationType.fromWire(json['type'] as String?),
      // Stored as an HTML fragment; rendering it raw would show tag names.
      subject: subject is String ? stripHtml(subject) : '',
      isRead: switch (json['read']) {
        final int value => value != 0,
        final bool value => value,
        final String value => value == '1',
        _ => false,
      },
      documentType: _text(json['document_type']),
      documentName: _text(json['document_name']),
      fromUser: _text(json['from_user']),
      createdAt: DateTime.tryParse('${json['creation']}'),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
