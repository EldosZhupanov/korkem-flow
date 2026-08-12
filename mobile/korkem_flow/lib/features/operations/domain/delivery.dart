/// One message the system decided to send, as the operations screen sees it.
///
/// Deliberately carries no credential and no third-party conversation: [body]
/// is the notification this system composed, which is the thing an
/// administrator is being asked to judge.
class NotificationDelivery {
  const NotificationDelivery({
    required this.name,
    required this.event,
    required this.recipient,
    required this.status,
    this.channel,
    this.attempts = 0,
    this.eventKey,
    this.body,
    this.error,
    this.nextAttemptAt,
    this.sentAt,
    this.failedAt,
    this.reference,
  });

  factory NotificationDelivery.fromJson(Map<String, dynamic> json) =>
      NotificationDelivery(
        name: json['name'] as String? ?? '',
        event: json['event'] as String? ?? '',
        recipient: json['recipient_user'] as String? ?? '',
        status: json['status'] as String? ?? pending,
        channel: json['channel'] as String?,
        attempts: (json['attempt_count'] as num? ?? 0).toInt(),
        eventKey: json['event_key'] as String?,
        body: json['body'] as String?,
        error: json['error'] as String?,
        nextAttemptAt: json['next_attempt_at'] as String?,
        sentAt: json['sent_at'] as String?,
        failedAt: json['failed_at'] as String?,
        reference: json['reference_name'] as String?,
      );

  static const pending = 'Pending';
  static const sending = 'Sending';
  static const sent = 'Sent';
  static const retrying = 'Retrying';
  static const failed = 'Failed';
  static const deadLetter = 'Dead Letter';
  static const suppressed = 'Suppressed';
  static const cancelled = 'Cancelled';

  /// The states an administrator may ask to try again from. `Sent` is not one:
  /// re-sending a message that arrived is the duplicate the whole delivery
  /// model exists to prevent. `Suppressed` is not one either — there was nobody
  /// to send to, and that is not fixed by trying harder.
  static const Set<String> retryable = {retrying, failed, deadLetter};

  final String name;
  final String event;
  final String recipient;
  final String status;
  final String? channel;
  final int attempts;
  final String? eventKey;
  final String? body;
  final String? error;
  final String? nextAttemptAt;
  final String? sentAt;
  final String? failedAt;
  final String? reference;

  bool get canRetry => retryable.contains(status);
  bool get canCancel => status != sent && status != cancelled;
}

/// One instruction on the dispatch board.
class WorkInstructionRow {
  const WorkInstructionRow({
    required this.name,
    required this.sender,
    required this.employee,
    required this.instruction,
    required this.status,
    this.channel,
    this.salesOrder,
    this.workOrder,
    this.dueDate,
    this.response,
    this.responseSeconds,
    this.company,
  });

  factory WorkInstructionRow.fromJson(Map<String, dynamic> json) =>
      WorkInstructionRow(
        name: json['name'] as String? ?? '',
        sender: json['owner'] as String? ?? '',
        employee: json['employee_user'] as String? ?? '',
        instruction: json['instruction'] as String? ?? '',
        status: json['status'] as String? ?? '',
        channel: json['channel'] as String?,
        salesOrder: json['sales_order'] as String?,
        workOrder: json['work_order'] as String?,
        dueDate: json['due_date'] as String?,
        response: json['response'] as String?,
        responseSeconds: (json['response_seconds'] as num?)?.toInt(),
        company: json['company'] as String?,
      );

  final String name;
  final String sender;
  final String employee;
  final String instruction;
  final String status;
  final String? channel;
  final String? salesOrder;
  final String? workOrder;
  final String? dueDate;
  final String? response;
  final int? responseSeconds;
  final String? company;

  /// Still waiting for a real answer. A question is *not* an answer, which is
  /// why `Clarification Requested` counts as open here.
  bool get isOpen => const {
    'Draft',
    'Sent',
    'Clarification Requested',
  }.contains(status);
}
