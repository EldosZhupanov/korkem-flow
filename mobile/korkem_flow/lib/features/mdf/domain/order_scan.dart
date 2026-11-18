import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

/// What an order's sticker says: its name behind this prefix, so that a
/// scanner's burst is never taken for something typed.
const orderQrPrefix = 'KORKEM:ORDER:';

/// The QR on an order's sticker and on the shop's copy.
String orderQrData(String order) => '$orderQrPrefix$order';

/// The order's number as people say it: «SAL-ORD-2026-00245» → «245».
String orderShortNumber(String order) {
  final digits = RegExp(r'(\d+)\s*$').firstMatch(order)?.group(1);
  return digits == null ? order : '${int.parse(digits)}';
}

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

/// One stage of a scanned order. [mine] — the scanner may tick it;
/// [waitingFor] — the stages still before it.
@immutable
class ScanStage {
  const ScanStage({
    required this.stage,
    this.doneOn,
    this.mine = false,
    this.byMe = false,
    this.waitingFor = const [],
  });

  factory ScanStage.fromJson(Map<String, dynamic> json) => ScanStage(
    stage: MdfStage.parse(json['stage']) ?? MdfStage.ready,
    doneOn: _s(json['done_on']),
    mine: json['mine'] == true,
    byMe: json['by_me'] == true,
    waitingFor: [
      for (final s in json['waiting_for'] as List? ?? const [])
        ?MdfStage.parse(s),
    ],
  );

  final MdfStage stage;
  final String? doneOn;
  final bool mine;
  final bool byMe;
  final List<MdfStage> waitingFor;

  bool get done => doneOn != null;

  /// «Сделал» is his to press now.
  bool get canDo => mine && !done && waitingFor.isEmpty;
}

/// An order as its sticker opens it on the floor (owner, 18.11.2026).
@immutable
class OrderScan {
  const OrderScan({
    required this.order,
    required this.customer,
    this.decor,
    this.deliveryDate,
    this.areaM2 = 0,
    this.handedOver = false,
    this.onHold = false,
    this.manager = false,
    this.stages = const [],
  });

  factory OrderScan.fromJson(Map<String, dynamic> json) => OrderScan(
    order: '${json['order']}',
    customer: '${json['customer'] ?? ''}',
    decor: _s(json['decor']),
    deliveryDate: _s(json['delivery_date']),
    areaM2: _d(json['area_m2']),
    handedOver: json['handed_over'] == true,
    onHold: json['on_hold'] == true,
    manager: json['manager'] == true,
    stages: [
      for (final s in json['stages'] as List? ?? const [])
        if (s is Map) ScanStage.fromJson(Map<String, dynamic>.from(s)),
    ],
  );

  final String order;
  final String customer;
  final String? decor;
  final String? deliveryDate;
  final double areaM2;
  final bool handedOver;
  final bool onHold;

  /// The scanner is a manager: every stage is his, and the order opens.
  final bool manager;
  final List<ScanStage> stages;

  String get number => orderShortNumber(order);
}
