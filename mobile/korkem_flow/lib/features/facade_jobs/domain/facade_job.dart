import 'package:meta/meta.dart';

/// Where a facade stands on the floor. The wire values are the server's.
enum FacadeJobStatus {
  queued('В очереди'),
  inWork('В работе'),
  done('Готово');

  const FacadeJobStatus(this.wire);

  final String wire;

  static FacadeJobStatus fromWire(String? value) => FacadeJobStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => FacadeJobStatus.queued);
}

/// One facade line to make. Sizes and options only — the server sends no
/// price here, whatever the price switch says.
@immutable
class FacadeJob {
  const FacadeJob({
    required this.line,
    required this.salesOrder,
    required this.widthMm,
    required this.heightMm,
    required this.qty,
    required this.milling,
    required this.finish,
    required this.status,
    this.customer,
    this.dueOn,
    this.areaM2 = 0,
    this.doubleSided = false,
    this.customerMaterial = false,
  });

  factory FacadeJob.fromJson(Map<String, dynamic> json) => FacadeJob(
    line: '${json['line'] ?? ''}',
    salesOrder: '${json['sales_order'] ?? ''}',
    customer: json['customer'] as String?,
    dueOn: DateTime.tryParse('${json['due_on'] ?? ''}'),
    widthMm: (json['width_mm'] as num?)?.toInt() ?? 0,
    heightMm: (json['height_mm'] as num?)?.toInt() ?? 0,
    qty: (json['qty'] as num?)?.toInt() ?? 0,
    areaM2: (json['area_m2'] as num?)?.toDouble() ?? 0,
    milling: json['milling'] as String? ?? '',
    finish: json['finish'] as String? ?? '',
    doubleSided: json['double_sided'] == true,
    customerMaterial: json['customer_material'] == true,
    status: FacadeJobStatus.fromWire(json['status'] as String?),
  );

  final String line;
  final String salesOrder;
  final String? customer;
  final DateTime? dueOn;
  final int widthMm;
  final int heightMm;
  final int qty;
  final double areaM2;
  final String milling;
  final String finish;
  final bool doubleSided;
  final bool customerMaterial;
  final FacadeJobStatus status;

  FacadeJob withStatus(FacadeJobStatus next) => FacadeJob(
    line: line,
    salesOrder: salesOrder,
    customer: customer,
    dueOn: dueOn,
    widthMm: widthMm,
    heightMm: heightMm,
    qty: qty,
    areaM2: areaM2,
    milling: milling,
    finish: finish,
    doubleSided: doubleSided,
    customerMaterial: customerMaterial,
    status: next,
  );
}
