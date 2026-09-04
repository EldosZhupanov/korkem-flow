import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Severity level of a proactive event.
///
/// Displayed with both a semantic color intent, an icon, and a localized text
/// label so that urgency is never communicated by color alone.
enum EventSeverity {
  high,
  medium,
  low;

  static EventSeverity fromWire(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'high' => EventSeverity.high,
      'medium' => EventSeverity.medium,
      'low' => EventSeverity.low,
      _ => EventSeverity.medium,
    };
  }

  StatusIntent get intent => switch (this) {
    EventSeverity.high => StatusIntent.danger,
    EventSeverity.medium => StatusIntent.warning,
    EventSeverity.low => StatusIntent.neutral,
  };

  IconData get icon => switch (this) {
    EventSeverity.high => AppIcons.danger,
    EventSeverity.medium => AppIcons.warning,
    EventSeverity.low => AppIcons.info,
  };

  String label(AppLocalizations l10n) => switch (this) {
    EventSeverity.high => l10n.eventsSeverityHigh,
    EventSeverity.medium => l10n.eventsSeverityMedium,
    EventSeverity.low => l10n.eventsSeverityLow,
  };
}

/// The document or entity that the proactive event pertains to.
@immutable
class EventSubject {
  const EventSubject({required this.doctype, required this.name});

  final String doctype;
  final String name;

  static EventSubject? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final doctype = json['doctype']?.toString();
    final name = json['name']?.toString();
    if (doctype == null || name == null || doctype.isEmpty || name.isEmpty) {
      return null;
    }
    return EventSubject(doctype: doctype, name: name);
  }

  /// Maps the Frappe doctype + document name to an application route, if known.
  String? get route => switch (doctype) {
    'Sales Order' => Routes.order(name),
    'Work Order' => Routes.workOrder(name),
    'CRM Deal' || 'Deal' => Routes.deal(name),
    'CRM Lead' || 'Lead' => Routes.lead(name),
    'CRM Organization' || 'Customer' => Routes.customer(name),
    'Item' => Routes.stockItem(name),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventSubject && other.doctype == doctype && other.name == name;

  @override
  int get hashCode => Object.hash(doctype, name);
}

/// An actionable proposal attached to the event.
@immutable
class EventAction {
  const EventAction({required this.id, required this.label});

  final String id;
  final String label;

  static EventAction? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id']?.toString();
    final label = json['label']?.toString();
    if (id == null || label == null || id.isEmpty || label.isEmpty) {
      return null;
    }
    return EventAction(id: id, label: label);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAction && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// A situation noticed proactively by KORKEM (e.g. deadline at risk).
@immutable
class ProactiveEvent {
  const ProactiveEvent({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    this.detail,
    this.noticedAt,
    this.subject,
    this.actions = const <EventAction>[],
  });

  final String id;
  final String kind;
  final EventSeverity severity;
  final String title;
  final String? detail;
  final DateTime? noticedAt;
  final EventSubject? subject;
  final List<EventAction> actions;

  static ProactiveEvent? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final kind = json['kind']?.toString() ?? 'generic';
    final severity = EventSeverity.fromWire(json['severity']?.toString());
    final title = json['title']?.toString() ?? '';
    final detail = json['detail']?.toString();

    DateTime? noticedAt;
    final rawNoticedAt = json['noticed_at']?.toString();
    if (rawNoticedAt != null && rawNoticedAt.isNotEmpty) {
      noticedAt = DateTime.tryParse(rawNoticedAt);
    }

    final subject = EventSubject.fromJson(json['subject']);

    final rawActions = json['actions'];
    final actions = <EventAction>[];
    if (rawActions is List) {
      for (final item in rawActions) {
        final action = EventAction.fromJson(item);
        if (action != null) {
          actions.add(action);
        }
      }
    }

    return ProactiveEvent(
      id: id,
      kind: kind,
      severity: severity,
      title: title,
      detail: detail,
      noticedAt: noticedAt,
      subject: subject,
      actions: List.unmodifiable(actions),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ProactiveEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
