import 'package:flutter/foundation.dart';

/// «Каталог красок» (owner, 19.11.2026): every colour by system, what the
/// shop knows of each — `korkem_manufacturing.api.paint_catalogue`.
@immutable
class PaintCatalogue {
  const PaintCatalogue({
    this.systems = const [],
    this.families = const [],
    this.colours = const [],
    this.customer = const [],
    this.kgPerM2 = 0,
    this.usageDays = 90,
    this.canEdit = false,
  });

  factory PaintCatalogue.fromJson(Map<String, dynamic> json) => PaintCatalogue(
    systems: [
      for (final s in json['systems'] as List? ?? const [])
        if (s is Map)
          (name: _s(s['name']), count: (s['count'] as num?)?.toInt() ?? 0),
    ],
    families: [for (final f in json['families'] as List? ?? const []) '$f'],
    colours: [
      for (final c in json['colours'] as List? ?? const [])
        if (c is Map<String, dynamic>) PaintColour.fromJson(c),
    ],
    customer: [for (final k in json['customer'] as List? ?? const []) '$k'],
    kgPerM2: _d(json['kg_per_m2']) ?? 0,
    usageDays: (json['usage_days'] as num?)?.toInt() ?? 90,
    canEdit: json['can_edit'] == true,
  );

  /// The colour systems — RAL Classic, RAL Design… — a null name is the
  /// colours filed under none.
  final List<({String? name, int count})> systems;
  final List<String> families;
  final List<PaintColour> colours;

  /// The colours an order's customer had painted, the latest first.
  final List<String> customer;

  /// Kilograms of coloured paint one m² takes, by the shop's recipe.
  final double kgPerM2;
  final int usageDays;
  final bool canEdit;

  /// The colours of one system, hidden ones left out unless asked.
  List<PaintColour> of(String? system, {bool hidden = false}) => [
    for (final c in colours)
      if (c.system == system && (hidden || !c.hidden)) c,
  ];

  PaintColour? byKey(String key) =>
      colours.where((c) => c.key == key).firstOrNull;
}

/// How near a colour is to another, to the eye.
enum PaintLook {
  same,
  close,
  other;

  static PaintLook? parse(Object? raw) => switch (raw) {
    'same' => same,
    'close' => close,
    'other' => other,
    _ => null,
  };
}

/// One colour of the catalogue.
@immutable
class PaintColour {
  const PaintColour({
    required this.key,
    required this.code,
    required this.name,
    required this.value,
    this.system,
    this.hex,
    this.family,
    this.onList = false,
    this.kg = 0,
    this.enoughM2,
    this.areaM2 = 0,
    this.orders = 0,
    this.top = false,
    this.trend = false,
    this.starred = false,
    this.hidden = false,
    this.note,
    this.delta,
    this.look,
  });

  factory PaintColour.fromJson(Map<String, dynamic> json) => PaintColour(
    key: '${json['key']}',
    code: '${json['code'] ?? ''}',
    name: '${json['name'] ?? ''}',
    value: '${json['value'] ?? ''}',
    system: _s(json['system']),
    hex: _s(json['hex']),
    family: _s(json['family']),
    onList: json['on_list'] == true,
    kg: _d(json['kg']) ?? 0,
    enoughM2: _d(json['enough_m2']),
    areaM2: _d(json['area_m2']) ?? 0,
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    top: json['top'] == true,
    trend: json['trend'] == true,
    starred: json['starred'] == true,
    hidden: json['hidden'] == true,
    note: _s(json['note']),
    delta: _d(json['delta']),
    look: PaintLook.parse(json['look']),
  );

  /// «ral9010» — one colour however it is written.
  final String key;

  /// «RAL 9010».
  final String code;

  /// «Чисто-белый».
  final String name;

  /// As the «Краска» list names it, or would: «RAL 9010 Чисто-белый».
  final String value;
  final String? system;

  /// «#F1ECE1» — roughly, as a screen can show it.
  final String? hex;
  final String? family;

  /// On the «Краска» list: orders can take it.
  final bool onList;

  /// Kilograms on the shelf, and the m² they paint.
  final double kg;
  final double? enoughM2;

  /// Painted over the last days, and in how many orders.
  final double areaM2;
  final int orders;
  final bool top;
  final bool trend;
  final bool starred;
  final bool hidden;
  final String? note;

  /// From the colour asked about, for «Похожие».
  final double? delta;
  final PaintLook? look;

  /// The shade as a colour value, or null when none is known.
  int? get argb => paintArgb(hex);

  /// Ours: painted lately, or starred.
  bool get popular => orders > 0 || starred;

  /// «RAL 9010 Чисто-белый» — the code and the name, once.
  String get title =>
      code.isEmpty || name.startsWith(code) ? name : '$code $name';

  bool matches(String query) {
    final q = query.trim().toLowerCase().replaceAll('ё', 'е');
    if (q.isEmpty) return true;
    final hay = '$code $name $value ${note ?? ''}'
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(' ', '');
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }
}

/// «#F1ECE1» as a colour value.
int? paintArgb(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? null : 0xFF000000 | v;
}

/// What to do with a colour no supplier has.
enum PaintSwapWay {
  replace,
  tint,
  wait;

  static PaintSwapWay parse(Object? raw) => switch (raw) {
    'tint' => tint,
    'wait' => wait,
    _ => replace,
  };
}

/// One colour of an order swapped — asked of the customer, or agreed.
@immutable
class PaintSwap {
  const PaintSwap({
    required this.key,
    required this.from,
    required this.way,
    this.to,
    this.agreed = false,
    this.look,
    this.waitUntil,
    this.askedAt,
    this.agreedAt,
    this.agreedBy,
    this.agreedVia,
  });

  factory PaintSwap.fromJson(Map<String, dynamic> json) => PaintSwap(
    key: '${json['key']}',
    from: '${json['from'] ?? ''}',
    way: PaintSwapWay.parse(json['how']),
    to: _s(json['to']),
    agreed: json['status'] == 'agreed',
    look: PaintLook.parse(json['look']),
    waitUntil: _s(json['wait_until']),
    askedAt: _s(json['asked_at']),
    agreedAt: _s(json['agreed_at']),
    agreedBy: _s(json['agreed_by']),
    agreedVia: _s(json['agreed_via']),
  );

  final String key;
  final String from;
  final PaintSwapWay way;
  final String? to;
  final bool agreed;
  final PaintLook? look;
  final String? waitUntil;
  final String? askedAt;
  final String? agreedAt;
  final String? agreedBy;

  /// «whatsapp», «phone», «in_person».
  final String? agreedVia;
}

String? _s(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}

double? _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
