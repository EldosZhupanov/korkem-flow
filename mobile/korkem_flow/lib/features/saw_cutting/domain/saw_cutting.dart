import 'package:flutter/foundation.dart';

/// Раскрой на форматно-раскроечной пиле (owner, 28.11.2026). The server lays
/// it out (`korkem_manufacturing.services.saw_engine`); nothing is packed
/// here — these are its answers, read.

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _maps(Object? v) => [
  for (final e in v is List ? v : const <Object?>[])
    if (e is Map) Map<String, dynamic>.from(e),
];

/// Which side the saw's fence is on, as the sawyer stands.
enum FenceSide { left, right }

@immutable
class SawSheet {
  const SawSheet({
    required this.thicknessMm,
    required this.heightMm,
    required this.widthMm,
  });

  factory SawSheet.fromJson(Map<String, dynamic> json) => SawSheet(
    thicknessMm: _d(json['thickness_mm']),
    heightMm: _d(json['height_mm']),
    widthMm: _d(json['width_mm']),
  );

  final double thicknessMm;
  final double heightMm;
  final double widthMm;

  Map<String, Object> toJson() => {
    'thickness_mm': thicknessMm,
    'height_mm': heightMm.round(),
    'width_mm': widthMm.round(),
  };
}

@immutable
class SawSettings {
  const SawSettings({
    required this.kerfMm,
    required this.trimMm,
    required this.offcutMinLengthMm,
    required this.offcutMinWidthMm,
    required this.fence,
    required this.edgeDeduct,
    required this.sheets,
    required this.defaultHeightMm,
    required this.defaultWidthMm,
    required this.canEdit,
  });

  factory SawSettings.fromJson(Map<String, dynamic> json) {
    final sheet = json['default_sheet'] is Map
        ? Map<String, dynamic>.from(json['default_sheet'] as Map)
        : const <String, dynamic>{};
    return SawSettings(
      kerfMm: _d(json['kerf_mm']),
      trimMm: _d(json['trim_mm']),
      offcutMinLengthMm: _d(json['offcut_min_length_mm']),
      offcutMinWidthMm: _d(json['offcut_min_width_mm']),
      fence: json['fence_side'] == 'right' ? FenceSide.right : FenceSide.left,
      edgeDeduct: json['edge_deduct'] != false,
      sheets: [for (final s in _maps(json['sheets'])) SawSheet.fromJson(s)],
      defaultHeightMm: _d(sheet['height_mm']),
      defaultWidthMm: _d(sheet['width_mm']),
      canEdit: json['can_edit'] == true,
    );
  }

  final double kerfMm;
  final double trimMm;
  final double offcutMinLengthMm;
  final double offcutMinWidthMm;
  final FenceSide fence;
  final bool edgeDeduct;
  final List<SawSheet> sheets;
  final double defaultHeightMm;
  final double defaultWidthMm;
  final bool canEdit;
}

/// One row as entered: numbers first, the name last (owner, 28.11.2026).
/// Edges are the band on each side — top, bottom, left, right — in mm.
@immutable
class SawPart {
  const SawPart({
    required this.height,
    required this.width,
    this.qty = 1,
    this.rotate = true,
    this.edges = const [0, 0, 0, 0],
    this.name = '',
    this.order,
    this.n = 0,
  });

  factory SawPart.fromJson(Map<String, dynamic> json) => SawPart(
    n: _i(json['n']),
    height: _d(json['height']),
    width: _d(json['width']),
    qty: _i(json['qty']) == 0 ? 1 : _i(json['qty']),
    rotate: json['rotate'] != false,
    edges: [
      for (final e in [...?(json['edges'] as List?), 0, 0, 0, 0].take(4)) _d(e),
    ],
    name: '${json['name'] ?? ''}',
    order: _s(json['order']),
  );

  final int n;
  final double height;
  final double width;
  final int qty;
  final bool rotate;
  final List<double> edges;
  final String name;
  final String? order;

  SawPart copyWith({
    double? height,
    double? width,
    int? qty,
    bool? rotate,
    List<double>? edges,
    String? name,
  }) => SawPart(
    n: n,
    height: height ?? this.height,
    width: width ?? this.width,
    qty: qty ?? this.qty,
    rotate: rotate ?? this.rotate,
    edges: edges ?? this.edges,
    name: name ?? this.name,
    order: order,
  );

  Map<String, Object?> toJson() => {
    'height': height,
    'width': width,
    'qty': qty,
    'rotate': rotate,
    'edges': edges,
    'name': name,
    'order': ?order,
  };
}

/// A part as it lies on the sheet: `width` across, `height` along the
/// sheet's height; its bands as it lies.
@immutable
class SawPlaced {
  const SawPlaced({
    required this.n,
    required this.k,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotated,
    required this.edges,
  });

  factory SawPlaced.fromJson(Map<String, dynamic> json) => SawPlaced(
    n: _i(json['n']),
    k: _i(json['k']),
    x: _d(json['x']),
    y: _d(json['y']),
    width: _d(json['width']),
    height: _d(json['height']),
    rotated: json['rotated'] == true,
    edges: [
      for (final e in [...?(json['edges'] as List?), 0, 0, 0, 0].take(4)) _d(e),
    ],
  );

  final int n;
  final int k;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool rotated;
  final List<double> edges;
}

@immutable
class SawRect {
  const SawRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory SawRect.fromJson(Map<String, dynamic> json) => SawRect(
    x: _d(json['x']),
    y: _d(json['y']),
    width: _d(json['width']),
    height: _d(json['height']),
  );

  final double x;
  final double y;
  final double width;
  final double height;
}

/// What a cut is, in the sawyer's words.
enum SawCutKind { trim, strip, cross, split, trimPart }

@immutable
class SawCut {
  const SawCut({
    required this.kind,
    required this.along,
    required this.set,
    required this.length,
    required this.parts,
  });

  factory SawCut.fromJson(Map<String, dynamic> json) => SawCut(
    kind: switch (json['kind']) {
      'strip' => SawCutKind.strip,
      'cross' => SawCutKind.cross,
      'split' => SawCutKind.split,
      'trim_part' => SawCutKind.trimPart,
      _ => SawCutKind.trim,
    },
    along: json['along'] == true,
    set: _d(json['set']),
    length: _d(json['length']),
    parts: [
      for (final p in json['parts'] is List ? json['parts'] as List : const [])
        if (p is List && p.length == 2) (n: _i(p[0]), k: _i(p[1])),
    ],
  );

  final SawCutKind kind;

  /// Along the sheet's height — the rip fence; otherwise the crosscut stop.
  final bool along;
  final double set;
  final double length;
  final List<({int n, int k})> parts;
}

@immutable
class SawPlanSheet {
  const SawPlanSheet({
    required this.parts,
    required this.offcuts,
    required this.waste,
    required this.cuts,
    required this.fences,
  });

  factory SawPlanSheet.fromJson(Map<String, dynamic> json) => SawPlanSheet(
    parts: [for (final p in _maps(json['parts'])) SawPlaced.fromJson(p)],
    offcuts: [for (final r in _maps(json['offcuts'])) SawRect.fromJson(r)],
    waste: [for (final r in _maps(json['waste'])) SawRect.fromJson(r)],
    cuts: [for (final c in _maps(json['cuts'])) SawCut.fromJson(c)],
    fences: _i(json['fences']),
  );

  final List<SawPlaced> parts;
  final List<SawRect> offcuts;
  final List<SawRect> waste;
  final List<SawCut> cuts;
  final int fences;
}

@immutable
class SawPlan {
  const SawPlan({
    required this.sheets,
    required this.fences,
    required this.wastePct,
    this.tooBig = const [],
  });

  factory SawPlan.fromJson(Map<String, dynamic> json) => SawPlan(
    sheets: [for (final s in _maps(json['sheets'])) SawPlanSheet.fromJson(s)],
    fences: _i(json['fences']),
    wastePct: _d(json['waste_pct']),
    tooBig: [
      for (final n in json['too_big'] is List ? json['too_big'] as List : [])
        _i(n),
    ],
  );

  static const empty = SawPlan(sheets: [], fences: 0, wastePct: 0);

  final List<SawPlanSheet> sheets;
  final int fences;
  final double wastePct;
  final List<int> tooBig;
}

/// One layout offered: «best» — recommended, «fences» — the fewest fence
/// settings, «offcut» — the largest offcut.
@immutable
class SawChoice {
  const SawChoice({
    required this.key,
    required this.sheets,
    required this.fences,
    required this.wastePct,
    this.offcut,
  });

  factory SawChoice.fromJson(Map<String, dynamic> json) {
    final o = json['offcut'];
    return SawChoice(
      key: '${json['key'] ?? 'best'}',
      sheets: _i(json['sheets']),
      fences: _i(json['fences']),
      wastePct: _d(json['waste_pct']),
      offcut: o is List && o.length == 2
          ? (width: _d(o[0]), height: _d(o[1]))
          : null,
    );
  }

  final String key;
  final int sheets;
  final int fences;
  final double wastePct;
  final ({double width, double height})? offcut;
}

/// The layouts of parts not saved yet.
@immutable
class SawCalculation {
  const SawCalculation({
    required this.sheetHeightMm,
    required this.sheetWidthMm,
    required this.choices,
    required this.plans,
    required this.edges,
    this.trimMm = 0,
    this.fence = FenceSide.left,
  });

  factory SawCalculation.fromJson(Map<String, dynamic> json) {
    final sheet = json['sheet'] is Map
        ? Map<String, dynamic>.from(json['sheet'] as Map)
        : const <String, dynamic>{};
    final plans = json['plans'] is Map
        ? Map<String, dynamic>.from(json['plans'] as Map)
        : const <String, dynamic>{};
    final saw = json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : const <String, dynamic>{};
    return SawCalculation(
      trimMm: _d(saw['trim_mm']),
      fence: saw['fence_side'] == 'right' ? FenceSide.right : FenceSide.left,
      sheetHeightMm: _d(sheet['height_mm']),
      sheetWidthMm: _d(sheet['width_mm']),
      choices: [for (final c in _maps(json['choices'])) SawChoice.fromJson(c)],
      plans: {
        for (final e in plans.entries)
          if (e.value is Map)
            e.key: SawPlan.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
      edges: _edges(json['edges']),
    );
  }

  final double sheetHeightMm;
  final double sheetWidthMm;
  final List<SawChoice> choices;
  final Map<String, SawPlan> plans;
  final Map<String, double> edges;
  final double trimMm;
  final FenceSide fence;
}

Map<String, double> _edges(Object? v) => {
  if (v is Map)
    for (final e in v.entries) '${e.key}': _d(e.value),
};

/// The saw as it was when a job was made.
@immutable
class SawSnapshot {
  const SawSnapshot({
    required this.sheetHeightMm,
    required this.sheetWidthMm,
    required this.kerfMm,
    required this.trimMm,
    required this.fence,
    required this.edgeDeduct,
  });

  factory SawSnapshot.fromJson(Map<String, dynamic> json) => SawSnapshot(
    sheetHeightMm: _d(json['sheet_height_mm']),
    sheetWidthMm: _d(json['sheet_width_mm']),
    kerfMm: _d(json['kerf_mm']),
    trimMm: _d(json['trim_mm']),
    fence: json['fence_side'] == 'right' ? FenceSide.right : FenceSide.left,
    edgeDeduct: json['edge_deduct'] != false,
  );

  final double sheetHeightMm;
  final double sheetWidthMm;
  final double kerfMm;
  final double trimMm;
  final FenceSide fence;
  final bool edgeDeduct;
}

/// Where a job is.
enum JobStatus { draft, checked, cutting, done, cancelled }

JobStatus _status(Object? v) => switch (v) {
  'Checked' => JobStatus.checked,
  'Cutting' => JobStatus.cutting,
  'Done' => JobStatus.done,
  'Cancelled' => JobStatus.cancelled,
  _ => JobStatus.draft,
};

@immutable
class JobOrder {
  const JobOrder({required this.order, required this.customer, this.due});

  factory JobOrder.fromJson(Map<String, dynamic> json) => JobOrder(
    order: '${json['order'] ?? ''}',
    customer: '${json['customer'] ?? ''}',
    due: _s(json['due']),
  );

  final String order;
  final String customer;
  final String? due;

  /// «SO-1110» → «№1110», as the shop says it.
  String get number => '№${order.split('-').last}';
}

@immutable
class JobSheet {
  const JobSheet({
    required this.sheetNo,
    required this.done,
    this.sawnBy,
    this.sawnByName,
    this.sawnAt,
    this.defects,
    this.offcuts = const [],
  });

  factory JobSheet.fromJson(Map<String, dynamic> json) => JobSheet(
    sheetNo: _i(json['sheet_no']),
    done: json['status'] == 'Done',
    sawnBy: _s(json['sawn_by']),
    sawnByName: _s(json['sawn_by_name']),
    sawnAt: _s(json['sawn_at']),
    defects: _s(json['defects']),
    offcuts: [
      for (final o in _maps(json['offcuts']))
        (
          name: '${o['name'] ?? ''}',
          qr: '${o['qr'] ?? o['name'] ?? ''}',
          lengthMm: _d(o['length_mm']),
          widthMm: _d(o['width_mm']),
        ),
    ],
  );

  final int sheetNo;
  final bool done;
  final String? sawnBy;
  final String? sawnByName;
  final String? sawnAt;
  final String? defects;
  final List<({String name, String qr, double lengthMm, double widthMm})>
  offcuts;
}

/// One line of a job's history, as the audit trail has it.
@immutable
class JobEvent {
  const JobEvent({
    required this.action,
    required this.at,
    this.who,
    this.reason,
    this.version,
    this.sheet,
    this.sawnBy,
    this.defects,
    this.into,
  });

  factory JobEvent.fromJson(Map<String, dynamic> json) => JobEvent(
    action: '${json['action'] ?? ''}',
    at: '${json['at'] ?? ''}',
    who: _s(json['who']),
    reason: _s(json['reason']),
    version: json['version'] == null ? null : _i(json['version']),
    sheet: json['sheet'] == null ? null : _i(json['sheet']),
    sawnBy: _s(json['sawn_by']),
    defects: _s(json['defects']),
    into: _s(json['into']),
  );

  final String action;
  final String at;
  final String? who;
  final String? reason;
  final int? version;
  final int? sheet;
  final String? sawnBy;
  final String? defects;
  final String? into;
}

@immutable
class CuttingJob {
  const CuttingJob({
    required this.name,
    required this.status,
    required this.version,
    required this.title,
    required this.orders,
    required this.materialItem,
    required this.material,
    required this.thicknessMm,
    required this.saw,
    required this.parts,
    required this.edges,
    required this.choice,
    required this.choices,
    required this.plan,
    required this.sheets,
    required this.wastePct,
    required this.fences,
    required this.history,
    required this.canMake,
    this.dueDate,
    this.madeBy,
    this.checkedBy,
    this.cancelReason,
    this.defaultSawyer,
  });

  factory CuttingJob.fromJson(Map<String, dynamic> json) => CuttingJob(
    name: '${json['name'] ?? ''}',
    status: _status(json['status']),
    version: _i(json['version']),
    title: '${json['title'] ?? ''}',
    orders: [for (final o in _maps(json['orders'])) JobOrder.fromJson(o)],
    dueDate: _s(json['due_date']),
    materialItem: '${json['material_item'] ?? ''}',
    material: '${json['material'] ?? ''}',
    thicknessMm: _d(json['thickness_mm']),
    saw: SawSnapshot.fromJson(
      json['saw'] is Map
          ? Map<String, dynamic>.from(json['saw'] as Map)
          : const {},
    ),
    parts: [for (final p in _maps(json['parts'])) SawPart.fromJson(p)],
    edges: _edges(json['edges']),
    choice: '${json['choice'] ?? 'best'}',
    choices: [for (final c in _maps(json['choices'])) SawChoice.fromJson(c)],
    plan: json['plan'] is Map
        ? SawPlan.fromJson(Map<String, dynamic>.from(json['plan'] as Map))
        : SawPlan.empty,
    sheets: [for (final s in _maps(json['sheets'])) JobSheet.fromJson(s)],
    wastePct: _d(json['waste_pct']),
    fences: _i(json['fences']),
    madeBy: _s(json['made_by']),
    checkedBy: _s(json['checked_by']),
    cancelReason: _s(json['cancel_reason']),
    defaultSawyer: _s(json['default_sawyer']),
    canMake: json['can_make'] == true,
    history: [for (final h in _maps(json['history'])) JobEvent.fromJson(h)],
  );

  final String name;
  final JobStatus status;
  final int version;
  final String title;
  final List<JobOrder> orders;
  final String? dueDate;
  final String materialItem;
  final String material;
  final double thicknessMm;
  final SawSnapshot saw;
  final List<SawPart> parts;
  final Map<String, double> edges;
  final String choice;
  final List<SawChoice> choices;
  final SawPlan plan;
  final List<JobSheet> sheets;
  final double wastePct;
  final int fences;
  final String? madeBy;
  final String? checkedBy;
  final String? cancelReason;
  final String? defaultSawyer;
  final bool canMake;
  final List<JobEvent> history;

  int get sheetsDone => sheets.where((s) => s.done).length;

  /// No sheet sawn yet: the job may still be changed.
  bool get editable =>
      sheetsDone == 0 &&
      (status == JobStatus.draft || status == JobStatus.checked);

  /// The part a placed piece is a copy of.
  SawPart? part(int n) {
    for (final p in parts) {
      if (p.n == n) return p;
    }
    return null;
  }
}

@immutable
class SawMaterial {
  const SawMaterial({
    required this.item,
    required this.name,
    required this.thicknessMm,
  });

  factory SawMaterial.fromJson(Map<String, dynamic> json) => SawMaterial(
    item: '${json['item'] ?? ''}',
    name: '${json['name'] ?? ''}',
    thicknessMm: _d(json['thickness_mm']),
  );

  final String item;
  final String name;
  final double thicknessMm;
}

@immutable
class JournalRow {
  const JournalRow({
    required this.name,
    required this.status,
    required this.title,
    required this.orders,
    required this.material,
    required this.sheetsTotal,
    required this.sheetsDone,
    required this.wastePct,
    required this.sawnBy,
    this.dueDate,
  });

  factory JournalRow.fromJson(Map<String, dynamic> json) => JournalRow(
    name: '${json['name'] ?? ''}',
    status: _status(json['status']),
    title: '${json['title'] ?? ''}',
    orders: [for (final o in _maps(json['orders'])) JobOrder.fromJson(o)],
    dueDate: _s(json['due_date']),
    material: '${json['material'] ?? ''}',
    sheetsTotal: _i(json['sheets_total']),
    sheetsDone: _i(json['sheets_done']),
    wastePct: _d(json['waste_pct']),
    sawnBy: [
      for (final p in json['sawn_by'] is List ? json['sawn_by'] as List : [])
        '$p',
    ],
  );

  final String name;
  final JobStatus status;
  final String title;
  final List<JobOrder> orders;
  final String? dueDate;
  final String material;
  final int sheetsTotal;
  final int sheetsDone;
  final double wastePct;
  final List<String> sawnBy;
}

/// Jobs that cost a sheet less sawn together.
@immutable
class SawTogether {
  const SawTogether({
    required this.jobs,
    required this.material,
    required this.apart,
    required this.together,
  });

  factory SawTogether.fromJson(Map<String, dynamic> json) => SawTogether(
    jobs: [
      for (final j in json['jobs'] is List ? json['jobs'] as List : []) '$j',
    ],
    material: '${json['material'] ?? ''}',
    apart: _i(json['apart']),
    together: _i(json['together']),
  );

  final List<String> jobs;
  final String material;
  final int apart;
  final int together;
}

@immutable
class SawJournal {
  const SawJournal({
    required this.jobs,
    required this.together,
    required this.materials,
    required this.canMake,
  });

  factory SawJournal.fromJson(Map<String, dynamic> json) => SawJournal(
    jobs: [for (final j in _maps(json['jobs'])) JournalRow.fromJson(j)],
    together: [for (final t in _maps(json['together'])) SawTogether.fromJson(t)],
    materials: [for (final m in _maps(json['materials'])) SawMaterial.fromJson(m)],
    canMake: json['can_make'] == true,
  );

  final List<JournalRow> jobs;
  final List<SawTogether> together;
  final List<SawMaterial> materials;
  final bool canMake;
}

/// Why an imported line was not taken.
enum ImportProblem { noSize, noWidth, size, qty }

@immutable
class ParsedParts {
  const ParsedParts({required this.rows, required this.errors});

  factory ParsedParts.fromJson(Map<String, dynamic> json) => ParsedParts(
    rows: [for (final r in _maps(json['rows'])) SawPart.fromJson(r)],
    errors: [
      for (final e in _maps(json['errors']))
        (
          line: _i(e['line']),
          text: '${e['text'] ?? ''}',
          problem: switch (e['reason']) {
            'no_width' => ImportProblem.noWidth,
            'size' => ImportProblem.size,
            'qty' => ImportProblem.qty,
            _ => ImportProblem.noSize,
          },
        ),
    ],
  );

  final List<SawPart> rows;
  final List<({int line, String text, ImportProblem problem})> errors;
}

/// Which jobs the journal shows.
enum JournalFilter { all, check, cutting, done }
