import 'package:flutter/foundation.dart';

/// The four core lifecycle stages of an incoming request.
enum EnquiryFlowStep {
  enquiry(1),
  measurement(2),
  proposal(3),
  order(4);

  const EnquiryFlowStep(this.number);
  final int number;
}

/// A captured customer utterance from voice, text, or channel.
@immutable
class CaptureSummary {
  const CaptureSummary({
    required this.id,
    required this.spokenText,
    required this.status,
    this.customerHint,
    this.productHint,
    this.dueHint,
    this.enquiry,
    this.task,
    this.creation,
  });

  factory CaptureSummary.fromJson(Map<String, dynamic> json) {
    DateTime? creation;
    if (json['creation'] is String) {
      creation = DateTime.tryParse(json['creation'] as String);
    }

    return CaptureSummary(
      id: '${json['name'] ?? ''}',
      spokenText: '${json['spoken_text'] ?? ''}',
      customerHint: json['customer_hint'] as String?,
      productHint: json['product_hint'] as String?,
      dueHint: json['due_hint'] as String?,
      status: '${json['status'] ?? 'Recorded'}',
      enquiry: json['enquiry'] as String?,
      task: json['task'] as String?,
      creation: creation,
    );
  }

  final String id;
  final String spokenText;
  final String? customerHint;
  final String? productHint;
  final String? dueHint;
  final String status;
  final String? enquiry;
  final String? task;
  final DateTime? creation;

  bool get isConverted =>
      status == 'Converted' && (enquiry?.isNotEmpty ?? false);
}

/// A matching customer candidate returned when resolving an ambiguous name.
@immutable
class CustomerCandidate {
  const CustomerCandidate({
    required this.name,
    required this.customerName,
    this.mobileNo,
  });

  factory CustomerCandidate.fromJson(Map<String, dynamic> json) {
    return CustomerCandidate(
      name: '${json['name'] ?? ''}',
      customerName: '${json['customer_name'] ?? json['name'] ?? ''}',
      mobileNo: json['mobile_no'] as String?,
    );
  }

  final String name;
  final String customerName;
  final String? mobileNo;
}

/// The response payload when a capture is converted to a customer and enquiry.
@immutable
class ConvertResult {
  const ConvertResult({
    required this.capture,
    required this.customer,
    required this.customerCreated,
    required this.enquiry,
    this.task,
  });

  factory ConvertResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;

    return ConvertResult(
      capture: '${message['capture'] ?? ''}',
      customer: '${message['customer'] ?? ''}',
      customerCreated:
          message['customer_created'] == true ||
          message['customer_created'] == 1,
      enquiry: '${message['enquiry'] ?? ''}',
      task: message['task'] as String?,
    );
  }

  final String capture;
  final String customer;
  final bool customerCreated;
  final String enquiry;
  final String? task;
}

/// The response payload when measurement is recorded.
@immutable
class MeasurementResult {
  const MeasurementResult({
    required this.enquiry,
    required this.measuredOn,
    this.address,
    this.taskClosed,
    this.dimensions,
    this.notes,
  });

  factory MeasurementResult.fromJson(
    Map<String, dynamic> json, {
    String? dimensions,
    String? notes,
  }) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;

    return MeasurementResult(
      enquiry: '${message['enquiry'] ?? ''}',
      address: message['address'] as String?,
      taskClosed: message['task_closed'] as String?,
      measuredOn: '${message['measured_on'] ?? ''}',
      dimensions: dimensions,
      notes: notes,
    );
  }

  final String enquiry;
  final String? address;
  final String? taskClosed;
  final String measuredOn;
  final String? dimensions;
  final String? notes;
}

/// An individual line item in a commercial proposal (Quotation).
@immutable
class ProposalItem {
  const ProposalItem({
    required this.itemCode,
    this.qty = 1.0,
    this.rate = 0.0,
    this.description,
  });

  final String itemCode;
  final double qty;
  final double rate;
  final String? description;

  double get amount => qty * rate;

  Map<String, dynamic> toJson() => {
    'item_code': itemCode.trim(),
    'qty': qty,
    'rate': rate,
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
  };
}

/// The response payload when a quotation proposal draft is created.
@immutable
class ProposalResult {
  const ProposalResult({
    required this.quotation,
    required this.status,
    required this.itemsCount,
    this.customer,
    this.validTill,
    this.items = const [],
  });

  factory ProposalResult.fromJson(
    Map<String, dynamic> json, {
    List<ProposalItem> items = const [],
  }) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;

    final count = message['items'] is int
        ? message['items'] as int
        : items.length;

    return ProposalResult(
      quotation: '${message['quotation'] ?? ''}',
      status: '${message['status'] ?? 'drafted'}',
      itemsCount: count,
      customer: message['customer'] as String?,
      validTill: message['valid_till'] as String?,
      items: items,
    );
  }

  final String quotation;
  final String status;
  final int itemsCount;
  final String? customer;
  final String? validTill;
  final List<ProposalItem> items;
}

/// The response payload when a quotation is accepted and converted to
/// a Sales Order.
@immutable
class OrderAcceptResult {
  const OrderAcceptResult({
    required this.quotation,
    required this.salesOrder,
    required this.status,
    required this.total,
    required this.deliverOn,
  });

  factory OrderAcceptResult.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;

    final totalVal = message['total'];
    final parsedTotal = totalVal is num
        ? totalVal.toDouble()
        : (double.tryParse('$totalVal') ?? 0.0);

    return OrderAcceptResult(
      quotation: '${message['quotation'] ?? ''}',
      salesOrder: '${message['sales_order'] ?? ''}',
      status: '${message['status'] ?? 'accepted'}',
      total: parsedTotal,
      deliverOn: '${message['deliver_on'] ?? ''}',
    );
  }

  final String quotation;
  final String salesOrder;
  final String status;
  final double total;
  final String deliverOn;
}

/// Refusal with matching candidates when customer name is ambiguous.
class AmbiguousCustomerException implements Exception {
  const AmbiguousCustomerException({
    required this.message,
    required this.candidates,
  });

  final String message;
  final List<CustomerCandidate> candidates;

  @override
  String toString() => message;
}
