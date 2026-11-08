import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_tags.dart';

export 'package:korkem_flow/features/mdf/domain/mdf_tags.dart';

/// Where an MDF order is (`korkem_manufacturing.services.mdf_orders`).
enum MdfStatus {
  draft,
  accepted,
  inShop,
  ready,
  handedOver,
  onHold,
  cancelled;

  static MdfStatus parse(Object? raw) => switch (raw) {
    'accepted' => accepted,
    'in_shop' => inShop,
    'ready' => ready,
    'handed_over' => handedOver,
    'on_hold' => onHold,
    'cancelled' => cancelled,
    _ => draft,
  };

  String get wire => switch (this) {
    draft => 'draft',
    accepted => 'accepted',
    inShop => 'in_shop',
    ready => 'ready',
    handedOver => 'handed_over',
    onHold => 'on_hold',
    cancelled => 'cancelled',
  };
}

/// What a group of positions is coated with (owner, 09.11.2026): a type
/// first, then a colour from that type's own list — a paint never lands in
/// a film group. The type decides the stage: a film is pressed, a paint is
/// painted, a raw facade neither.
enum MdfCoating {
  pvc,
  paint,
  raw;

  static MdfCoating? parse(Object? raw) {
    for (final c in values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}

/// The shop stages, in the order the shop works (OnayBaza's ticks).
enum MdfStage {
  cut,
  mill,
  sand,
  paint,
  vacuum,

  /// «Готово»: checked and packed — the order is ready only then.
  ready;

  /// What «+ этап» may add for a rework.
  static const List<MdfStage> extra = [paint, vacuum];

  static MdfStage? parse(Object? raw) {
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

/// One row of the list.
@immutable
class MdfOrderRow {
  const MdfOrderRow({
    required this.name,
    required this.status,
    required this.createdOn,
    required this.deliveryDate,
    required this.customerName,
    required this.areaM2,
    required this.total,
    required this.paid,
    required this.debt,
    this.overdue = false,
    this.dueSoon = false,
    this.phone,
    this.decorTop,
    this.milling,
    this.edgeProfile,
    this.stage,
    this.tags = const [],
    this.customerTags = const [],
  });

  factory MdfOrderRow.fromJson(Map<String, dynamic> json) => MdfOrderRow(
    name: '${json['name']}',
    status: MdfStatus.parse(json['status']),
    overdue: json['overdue'] == true,
    dueSoon: json['due_soon'] == true,
    createdOn: '${json['created_on'] ?? ''}',
    deliveryDate: '${json['delivery_date'] ?? ''}',
    customerName: '${json['customer_name'] ?? ''}',
    phone: _s(json['phone']),
    decorTop: _s(json['decor_top']),
    milling: _s(json['milling']),
    edgeProfile: _s(json['edge_profile']),
    areaM2: _d(json['area_m2']),
    total: _d(json['total']),
    paid: _d(json['paid']),
    debt: _d(json['debt']),
    stage: MdfStage.parse(json['stage']),
    tags: MdfOrderTag.parse(json['tags']),
    customerTags: MdfCustomerTag.parse(json['customer_tags']),
  );

  final String name;
  final MdfStatus status;
  final bool overdue;
  final bool dueSoon;
  final List<MdfOrderTag> tags;
  final List<MdfCustomerTag> customerTags;

  bool get urgent => tags.contains(MdfOrderTag.urgent);
  final String createdOn;
  final String deliveryDate;
  final String customerName;
  final String? phone;
  final String? decorTop;
  final String? milling;
  final String? edgeProfile;
  final double areaM2;
  final double total;
  final double paid;
  final double debt;
  final MdfStage? stage;
}

/// The head of the order: what every line shares unless it says otherwise.
@immutable
class MdfHead {
  const MdfHead({
    this.thicknessMm,
    this.finish,
    this.decorTop,
    this.decorBottom,
    this.patina,
    this.milling,
    this.edgeProfile,
    this.extraName,
    this.defaultRate,
    this.material,
    this.filmRates = const {},
    this.tags = const [],
  });

  factory MdfHead.fromJson(Map<String, dynamic> json) => MdfHead(
    thicknessMm: json['thickness_mm'] == null ? null : _i(json['thickness_mm']),
    finish: _s(json['finish']),
    decorTop: _s(json['decor_top']),
    decorBottom: _s(json['decor_bottom']),
    patina: _s(json['patina']),
    milling: _s(json['milling']),
    edgeProfile: _s(json['edge_profile']),
    extraName: _s(json['extra_name']),
    defaultRate: json['default_rate'] == null ? null : _d(json['default_rate']),
    material: _s(json['material']),
    filmRates: {
      if (json['film_rates'] is Map)
        for (final e in (json['film_rates'] as Map).entries)
          '${e.key}': _d(e.value),
    },
    tags: MdfOrderTag.parse(json['tags']),
  );

  final int? thicknessMm;
  final String? finish;
  final String? decorTop;
  final String? decorBottom;
  final String? patina;
  final String? milling;
  final String? edgeProfile;
  final String? extraName;
  final double? defaultRate;

  /// The board of every position that does not name its own.
  final String? material;

  /// Each film group's price per m² (an order of several films).
  final Map<String, double> filmRates;

  /// Urgent, a rework, a warranty job.
  final List<MdfOrderTag> tags;

  Map<String, dynamic> toJson() => {
    'thickness_mm': ?thicknessMm,
    'finish': ?finish,
    'decor_top': ?decorTop,
    'decor_bottom': ?decorBottom,
    'patina': ?patina,
    'milling': ?milling,
    'edge_profile': ?edgeProfile,
    'extra_name': ?extraName,
    'default_rate': ?defaultRate,
    'material': ?material,
    if (filmRates.isNotEmpty) 'film_rates': filmRates,
    // None sent is none kept: the server clears an order's tags.
    if (tags.isNotEmpty) 'tags': [for (final t in tags) t.wire],
  };
}

/// A line as typed: sizes, pieces, the line's own milling, note and price.
@immutable
class MdfLineInput {
  const MdfLineInput({
    required this.heightMm,
    required this.widthMm,
    required this.qty,
    this.milling,
    this.note,
    this.rate,
    this.film,
    this.filmBack,
    this.material,
    this.edge,
    this.patina,
    this.thicknessMm,
    this.coating,
  });

  final int heightMm;
  final int widthMm;
  final int qty;
  final String? milling;
  final String? note;

  /// Its group's coating; [film] is a colour from that coating's list.
  final MdfCoating? coating;

  /// Its own thickness; null — the order's.
  final int? thicknessMm;

  /// Typed by hand; null means the film group's price, else the price list.
  final double? rate;

  /// The film group the position is in, and its back film if the back side
  /// was switched on for it.
  final String? film;
  final String? filmBack;

  /// Its own board; null — the order's.
  final String? material;

  /// The radius of its edges (R3 unless the manager says; R0 is a sharp
  /// corner) and its patina, rare.
  final String? edge;
  final String? patina;

  Map<String, dynamic> toJson() => {
    'height_mm': heightMm,
    'width_mm': widthMm,
    'qty': qty,
    'milling': ?milling,
    'note': ?note,
    'rate': ?rate,
    'film': ?film,
    'film_back': ?filmBack,
    'material': ?material,
    'edge': ?edge,
    'patina': ?patina,
    'thickness_mm': ?thicknessMm,
    'coating': ?coating?.name,
  };
}

/// A line as the server priced it.
@immutable
class MdfLine {
  const MdfLine({
    required this.heightMm,
    required this.widthMm,
    required this.qty,
    required this.areaM2,
    required this.rateM2,
    required this.amount,
    this.milling,
    this.note,
    this.manualRate = false,
    this.noPrice = false,
    this.film,
    this.filmBack,
    this.material,
    this.thicknessMm,
    this.edge,
    this.patina,
    this.coating,
  });

  factory MdfLine.fromJson(Map<String, dynamic> json) => MdfLine(
    heightMm: _i(json['height_mm']),
    widthMm: _i(json['width_mm']),
    qty: _i(json['qty']),
    milling: _s(json['milling']),
    note: _s(json['note']),
    areaM2: _d(json['area_m2']),
    rateM2: _d(json['rate_m2']),
    amount: _d(json['amount']),
    manualRate: json['manual_rate'] == true,
    noPrice: json['no_price'] == true,
    film: _s(json['film']),
    filmBack: _s(json['film_back']),
    material: _s(json['material']),
    thicknessMm: json['thickness_mm'] == null ? null : _i(json['thickness_mm']),
    edge: _s(json['edge']),
    patina: _s(json['patina']),
    coating: MdfCoating.parse(json['coating']),
  );

  final int heightMm;
  final int widthMm;
  final int qty;
  final String? milling;
  final String? note;
  final double areaM2;
  final double rateM2;
  final double amount;
  final bool manualRate;
  final bool noPrice;
  final String? film;
  final String? filmBack;
  final String? material;
  final int? thicknessMm;
  final String? edge;
  final String? patina;
  final MdfCoating? coating;
}

/// One film's positions, in the order the films first appear; positions keep
/// their number in the whole order.
typedef MdfFilmGroup = ({
  MdfCoating? coating,
  String? film,
  List<(int, MdfLine)> lines,
  int pieces,
  double areaM2,
  double amount,
});

/// The order's positions by film, for the card and the printouts.
List<MdfFilmGroup> mdfFilmGroups(List<MdfLine> lines) {
  final order = <(MdfCoating?, String?)>[];
  final by = <(MdfCoating?, String?), List<(int, MdfLine)>>{};
  for (var i = 0; i < lines.length; i++) {
    final key = (lines[i].coating, lines[i].film);
    if (!by.containsKey(key)) order.add(key);
    (by[key] ??= []).add((i + 1, lines[i]));
  }
  return [
    for (final key in order)
      (
        coating: key.$1,
        film: key.$2,
        lines: by[key]!,
        pieces: by[key]!.fold(0, (sum, l) => sum + l.$2.qty),
        areaM2: double.parse(
          by[key]!
              .fold<double>(0, (sum, l) => sum + l.$2.areaM2)
              .toStringAsFixed(2),
        ),
        amount: by[key]!.fold<double>(0, (sum, l) => sum + l.$2.amount),
      ),
  ];
}

/// What `price` answers: the lines priced and the totals.
@immutable
class MdfPricing {
  const MdfPricing({
    required this.lines,
    required this.pieces,
    required this.areaM2,
    required this.total,
  });

  factory MdfPricing.fromJson(Map<String, dynamic> json) => MdfPricing(
    lines: [
      for (final l in json['lines'] as List? ?? const [])
        if (l is Map) MdfLine.fromJson(Map<String, dynamic>.from(l)),
    ],
    pieces: _i(json['pieces']),
    areaM2: _d(json['area_m2']),
    total: _d(json['total']),
  );

  static const empty = MdfPricing(lines: [], pieces: 0, areaM2: 0, total: 0);

  final List<MdfLine> lines;
  final int pieces;
  final double areaM2;
  final double total;
}

/// One entry of the order's history: when, who, what.
@immutable
class MdfHistoryEntry {
  const MdfHistoryEntry({
    required this.at,
    required this.by,
    required this.text,
  });

  factory MdfHistoryEntry.fromJson(Map<String, dynamic> json) =>
      MdfHistoryEntry(
        at: '${json['at'] ?? ''}',
        by: '${json['by'] ?? ''}',
        text: '${json['text'] ?? ''}',
      );

  final String at;
  final String by;
  final String text;
}

@immutable
class MdfPayment {
  const MdfPayment({
    required this.amount,
    required this.date,
    this.method,
    this.bank,
  });

  factory MdfPayment.fromJson(Map<String, dynamic> json) => MdfPayment(
    amount: _d(json['amount']),
    date: '${json['date'] ?? ''}',
    method: _s(json['method']),
    bank: _s(json['bank']),
  );

  final double amount;
  final String date;

  /// Перевод, наличные, карта — and the bank of a transfer or a card.
  final String? method;
  final String? bank;
}

/// The whole card.
@immutable
class MdfOrder {
  const MdfOrder({
    required this.name,
    required this.status,
    required this.customer,
    required this.customerName,
    required this.createdOn,
    required this.deliveryDate,
    required this.head,
    required this.lines,
    required this.pieces,
    required this.areaM2,
    required this.total,
    required this.paid,
    required this.debt,
    required this.payments,
    required this.stages,
    this.overdue = false,
    this.phone,
    this.readyOn,
    this.handedOverOn,
    this.holdReason,
    this.notes,
    this.history = const [],
    this.stageWorkers = const {},
    this.customerTags = const [],
    this.extraStages = const {},
  });

  factory MdfOrder.fromJson(Map<String, dynamic> json) => MdfOrder(
    name: '${json['name']}',
    status: MdfStatus.parse(json['status']),
    overdue: json['overdue'] == true,
    customer: '${json['customer'] ?? ''}',
    customerName: '${json['customer_name'] ?? ''}',
    phone: _s(json['phone']),
    createdOn: '${json['created_on'] ?? ''}',
    deliveryDate: '${json['delivery_date'] ?? ''}',
    head: MdfHead.fromJson(
      json['head'] is Map
          ? Map<String, dynamic>.from(json['head'] as Map)
          : const {},
    ),
    lines: [
      for (final l in json['lines'] as List? ?? const [])
        if (l is Map) MdfLine.fromJson(Map<String, dynamic>.from(l)),
    ],
    pieces: _i(json['pieces']),
    areaM2: _d(json['area_m2']),
    total: _d(json['total']),
    paid: _d(json['paid']),
    debt: _d(json['debt']),
    payments: [
      for (final p in json['payments'] as List? ?? const [])
        if (p is Map) MdfPayment.fromJson(Map<String, dynamic>.from(p)),
    ],
    stages: {
      for (final s in json['stages'] as List? ?? const [])
        if (s is Map && MdfStage.parse(s['stage']) != null)
          MdfStage.parse(s['stage'])!: _s(s['done_on']),
    },
    readyOn: _s(json['ready_on']),
    handedOverOn: _s(json['handed_over_on']),
    holdReason: _s(json['hold_reason']),
    notes: _s(json['notes']),
    history: [
      for (final h in json['history'] as List? ?? const [])
        if (h is Map) MdfHistoryEntry.fromJson(Map<String, dynamic>.from(h)),
    ],
    stageWorkers: {
      for (final s in json['stages'] as List? ?? const [])
        if (s is Map &&
            MdfStage.parse(s['stage']) != null &&
            _s(s['worker_name']) != null)
          MdfStage.parse(s['stage'])!: _s(s['worker_name'])!,
    },
    customerTags: MdfCustomerTag.parse(json['customer_tags']),
    extraStages: {
      for (final s in json['stages'] as List? ?? const [])
        if (s is Map &&
            s['extra'] == true &&
            MdfStage.parse(s['stage']) != null)
          MdfStage.parse(s['stage'])!,
    },
  );

  final String name;
  final MdfStatus status;
  final bool overdue;
  final String customer;
  final String customerName;
  final String? phone;
  final String createdOn;
  final String deliveryDate;
  final MdfHead head;
  final List<MdfLine> lines;
  final int pieces;
  final double areaM2;
  final double total;
  final double paid;
  final double debt;
  final List<MdfPayment> payments;

  /// The stages this order goes through, each with the day it was ticked.
  final Map<MdfStage, String?> stages;
  final String? readyOn;
  final String? handedOverOn;
  final String? holdReason;
  final String? notes;

  /// Newest first: changes, holds, hand-overs with a debt.
  final List<MdfHistoryEntry> history;

  /// Who did a ticked stage, when the manager said.
  final Map<MdfStage, String> stageWorkers;

  /// The customer's tags (VIP, prepay only …), from the customer list.
  final List<MdfCustomerTag> customerTags;

  /// The stages «+ этап» added for a rework.
  final Set<MdfStage> extraStages;

  List<MdfOrderTag> get tags => head.tags;

  bool get isDraft => status == MdfStatus.draft;
}
