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
    this.urgent = false,
    this.thicknessMm,
    this.decorTop,
    this.decorBottom,
    this.edgeProfile,
    this.colorGroup,
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
    urgent: json['urgent'] == true,
    thicknessMm: (json['thickness_mm'] as num?)?.toInt(),
    decorTop: json['decor_top'] as String?,
    decorBottom: json['decor_bottom'] as String?,
    edgeProfile: json['edge_profile'] as String?,
    colorGroup: json['color_group'] as String?,
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

  /// The order is urgent; the server already put it at the head of the queue.
  final bool urgent;

  /// What the floor reads beyond the size (`services/facade_spec.py`).
  final int? thicknessMm;
  final String? decorTop;
  final String? decorBottom;
  final String? edgeProfile;

  /// The batch label the shop sorts by; the face decor unless set by hand.
  final String? colorGroup;

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
    urgent: urgent,
    thicknessMm: thicknessMm,
    decorTop: decorTop,
    decorBottom: decorBottom,
    edgeProfile: edgeProfile,
    colorGroup: colorGroup,
  );
}

/// One member of the crew that made a facade, and their share in %
/// (`null` — the server splits equally).
typedef CrewShare = ({String user, double? share});
