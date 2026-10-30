import 'package:flutter/foundation.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Lifecycle status of the installation stage on a Sales Order.
enum OrderInstallationStatus {
  notScheduled,
  scheduled,
  completed;

  String localized(AppLocalizations l10n) => switch (this) {
    notScheduled => l10n.orderInstallationStatusNotScheduled,
    scheduled => l10n.orderInstallationStatusScheduled,
    completed => l10n.orderInstallationStatusCompleted,
  };

  StatusIntent get intent => switch (this) {
    notScheduled => StatusIntent.info,
    scheduled => StatusIntent.warning,
    completed => StatusIntent.success,
  };

  static OrderInstallationStatus fromTaskStatus(String? taskStatus) {
    if (taskStatus == null || taskStatus.isEmpty) {
      return OrderInstallationStatus.notScheduled;
    }
    final normalized = taskStatus.trim().toLowerCase();
    if (normalized == 'done' ||
        normalized == 'completed' ||
        normalized == 'delivered') {
      return OrderInstallationStatus.completed;
    }
    return OrderInstallationStatus.scheduled;
  }
}

/// The complete state of the installation stage for one Sales Order.
@immutable
class OrderInstallation {
  const OrderInstallation({
    required this.salesOrder,
    this.taskId,
    this.installer,
    this.installDate,
    this.status = OrderInstallationStatus.notScheduled,
    this.notes,
  });

  final String salesOrder;
  final String? taskId;
  final String? installer;
  final DateTime? installDate;
  final OrderInstallationStatus status;
  final String? notes;

  bool get isScheduled => status != OrderInstallationStatus.notScheduled;
  bool get isCompleted => status == OrderInstallationStatus.completed;

  /// Whether the install date has passed without completion.
  bool isLateAt(DateTime now) =>
      installDate != null && !isCompleted && installDate!.isBefore(now);
}
