import 'package:flutter/foundation.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Lifecycle status of the design stage on a Sales Order.
enum OrderDesignStatus {
  notAssigned,
  assigned,
  delivered;

  String localized(AppLocalizations l10n) => switch (this) {
    notAssigned => l10n.orderDesignStatusNotAssigned,
    assigned => l10n.orderDesignStatusAssigned,
    delivered => l10n.orderDesignStatusDelivered,
  };

  StatusIntent get intent => switch (this) {
    notAssigned => StatusIntent.info,
    assigned => StatusIntent.warning,
    delivered => StatusIntent.success,
  };

  static OrderDesignStatus fromTaskStatus(String? taskStatus) {
    if (taskStatus == null || taskStatus.isEmpty) {
      return OrderDesignStatus.notAssigned;
    }
    final normalized = taskStatus.trim().toLowerCase();
    if (normalized == 'done' ||
        normalized == 'completed' ||
        normalized == 'delivered') {
      return OrderDesignStatus.delivered;
    }
    return OrderDesignStatus.assigned;
  }
}

/// An attached file or drawing linked to the Sales Order.
@immutable
class OrderDesignAttachment {
  const OrderDesignAttachment({
    required this.name,
    required this.fileName,
    this.fileUrl,
    this.fileSize,
    this.creation,
  });

  factory OrderDesignAttachment.fromJson(Map<String, dynamic> json) {
    DateTime? creation;
    if (json['creation'] is String) {
      creation = DateTime.tryParse(json['creation'] as String);
    }
    return OrderDesignAttachment(
      name: '${json['name'] ?? ''}',
      fileName: '${json['file_name'] ?? json['name'] ?? ''}',
      fileUrl: json['file_url'] as String?,
      fileSize: json['file_size'] is num
          ? (json['file_size'] as num).toInt()
          : null,
      creation: creation,
    );
  }

  final String name;
  final String fileName;
  final String? fileUrl;
  final int? fileSize;
  final DateTime? creation;
}

/// The complete state of the design stage for one Sales Order.
@immutable
class OrderDesign {
  const OrderDesign({
    required this.salesOrder,
    this.taskId,
    this.taskTitle,
    this.designer,
    this.dueDate,
    this.status = OrderDesignStatus.notAssigned,
    this.attachments = const [],
    this.deliveredAt,
  });

  final String salesOrder;
  final String? taskId;
  final String? taskTitle;
  final String? designer;
  final DateTime? dueDate;
  final OrderDesignStatus status;
  final List<OrderDesignAttachment> attachments;
  final DateTime? deliveredAt;

  bool get isAssigned => status != OrderDesignStatus.notAssigned;
  bool get isDelivered => status == OrderDesignStatus.delivered;
  bool get hasAttachments => attachments.isNotEmpty;
  int get fileCount => attachments.length;

  /// Whether the deadline has passed without completion.
  bool isLateAt(DateTime now) =>
      dueDate != null && !isDelivered && dueDate!.isBefore(now);
}
