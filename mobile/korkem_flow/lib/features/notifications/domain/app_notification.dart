import 'package:flutter/widgets.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';

/// One row of `Notification Log`.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.subject,
    required this.isRead,
    this.documentType,
    this.documentName,
    this.fromUser,
    this.createdAt,
  });

  final String id;
  final NotificationType type;

  /// Already stripped of the HTML Frappe stores it as.
  final String subject;

  final bool isRead;

  /// What the notification is about. Together these address a record, so the
  /// row can open it.
  final String? documentType;
  final String? documentName;

  final String? fromUser;
  final DateTime? createdAt;

  /// The same notification, marked read — for the optimistic update.
  AppNotification asRead() => AppNotification(
    id: id,
    type: type,
    subject: subject,
    isRead: true,
    documentType: documentType,
    documentName: documentName,
    fromUser: fromUser,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) => other is AppNotification && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The `Notification Type` values Frappe emits.
enum NotificationType {
  assignment('Assignment', AppIcons.task),
  mention('Mention', AppIcons.conversation),
  share('Share', AppIcons.share),
  alert('Alert', AppIcons.warning),
  energyPoint('Energy Point', AppIcons.success);

  const NotificationType(this.wireValue, this.icon);

  final String wireValue;
  final IconData icon;

  static NotificationType fromWire(String? value) {
    for (final type in NotificationType.values) {
      if (type.wireValue == value) return type;
    }
    // Frappe apps may register their own types; an unknown one is still a
    // notification worth showing, just without a specific icon.
    return NotificationType.alert;
  }
}
