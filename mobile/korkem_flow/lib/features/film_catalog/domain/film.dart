import 'package:flutter/foundation.dart';

/// One PVC film — its maker's own (owner, 10.11.2026): «Белый Матовый» from
/// KIRA and from JS Group are two films of two shades. Everything is per
/// running metre; there is no m² on a film.
@immutable
class Film {
  const Film({
    required this.item,
    required this.maker,
    required this.colour,
    this.label,
    this.title = '',
    this.widthMm,
    this.thicknessMm,
    this.enabled = true,
    this.unit,
    this.onHand = 0,
    this.held = 0,
    this.minStock,
    this.code,
    this.type,
    this.collection,
    this.hex,
    this.ral,
    this.supplier,
    this.priceM,
    this.retailM,
    this.wholesaleM,
    this.priceSince = const {},
    this.low = false,
    this.url,
  });

  factory Film.fromJson(Map<String, dynamic> json) => Film(
    item: '${json['item'] ?? ''}',
    title: '${json['title'] ?? ''}',
    maker: '${json['maker'] ?? ''}',
    colour: '${json['colour'] ?? ''}',
    label: _s(json['label']),
    widthMm: _d(json['width_mm']),
    thicknessMm: _d(json['thickness_mm']),
    enabled: json['enabled'] != false,
    unit: _s(json['unit']),
    onHand: _d(json['on_hand']) ?? 0,
    held: _d(json['held']) ?? 0,
    minStock: _d(json['min_stock']),
    code: _s(json['code']),
    type: _s(json['type']),
    collection: _s(json['collection']),
    hex: _s(json['hex']),
    ral: _s(json['ral']),
    supplier: _s(json['supplier']),
    priceM: _d(json['price_m']),
    retailM: _d(json['retail_m']),
    wholesaleM: _d(json['wholesale_m']),
    priceSince: {
      if (json['price_since'] case final Map<String, dynamic> since)
        for (final e in since.entries)
          if (e.value case final Map<String, dynamic> v)
            e.key: (date: '${v['date'] ?? ''}', via: _s(v['via'])),
    },
    low: json['low'] == true,
    url: _s(json['url']),
  );

  final String item;
  final String title;
  final String maker;
  final String colour;

  /// How an order names this film: «KIRA · Белый Матовый» — the maker is
  /// part of the name, the same colour of another maker is another film.
  final String? label;
  final double? widthMm;
  final double? thicknessMm;

  /// Off: no longer made — kept for old orders, offered for no new one.
  final bool enabled;
  final String? unit;

  /// On hand and promised to orders, in the stock's unit (metres).
  final double onHand;
  final double held;
  final double? minStock;
  final String? code;
  final String? type;

  /// The maker's collection it belongs to — ALDA, Solid Color…
  final String? collection;

  /// The sample's colour, «#F4F3EE».
  final String? hex;
  final String? ral;
  final String? supplier;

  /// What the supplier charges us per running metre; null when hidden.
  final double? priceM;

  /// What the department sells a metre at: over the counter, to the trade.
  final double? retailM;
  final double? wholesaleM;

  /// Since when each price stands and where it came from — «приход»,
  /// «продажа», or the card (null) — by `price_m`, `retail_m`,
  /// `wholesale_m` (owner, 11.11.2026: prices change).
  final Map<String, ({String date, String? via})> priceSince;

  /// What a metre earns over what it cost, when both are known.
  double? get marginM =>
      retailM != null && priceM != null ? retailM! - priceM! : null;

  /// Less on hand than the film's minimum: time to order.
  final bool low;
  final String? url;

  /// What is free: on hand and not promised.
  double get free => onHand - held;

  /// The sample as a colour, or null when none is set.
  int? get argb {
    final h = hex;
    if (h == null || h.length != 7) return null;
    final v = int.tryParse(h.substring(1), radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }
}

/// The catalogue, maker by maker, and the lists to pick from.
@immutable
class FilmCatalog {
  const FilmCatalog({
    this.films = const [],
    this.unassigned = const [],
    this.makers = const [],
    this.types = const [],
    this.suppliers = const [],
    this.sourcesByMaker = const {},
    this.collections = const {},
    this.canEdit = false,
  });

  factory FilmCatalog.fromJson(Map<String, dynamic> json) => FilmCatalog(
    films: [
      for (final f in json['films'] as List? ?? const [])
        if (f is Map<String, dynamic>) Film.fromJson(f),
    ],
    unassigned: [
      for (final c in json['unassigned'] as List? ?? const []) '$c',
    ],
    makers: [for (final m in json['makers'] as List? ?? const []) '$m'],
    types: [for (final t in json['types'] as List? ?? const []) '$t'],
    suppliers: [
      for (final s in json['suppliers'] as List? ?? const [])
        if (s is Map<String, dynamic> && s['enabled'] != false)
          (id: '${s['supplier']}', name: '${s['name'] ?? s['supplier']}'),
    ],
    sourcesByMaker: {
      if (json['sources_by_maker'] case final Map<String, dynamic> by)
        for (final e in by.entries)
          e.key: [for (final s in e.value as List? ?? const []) '$s'],
    },
    collections: {
      if (json['collections'] case final Map<String, dynamic> by)
        for (final e in by.entries)
          e.key: [for (final s in e.value as List? ?? const []) '$s'],
    },
    canEdit: json['can_edit'] == true,
  );

  final List<Film> films;

  /// Colours of the old order-form list that no film carries: «не указан».
  final List<String> unassigned;
  final List<String> makers;
  final List<String> types;
  final List<({String id, String name})> suppliers;

  /// Maker → the suppliers that sell its film (owner, 11.11.2026: the same
  /// maker is bought in Astana and in Almaty).
  final Map<String, List<String>> sourcesByMaker;

  /// Maker → its own collections (owner, 11.11.2026): each maker groups its
  /// films its own way.
  final Map<String, List<String>> collections;
  final bool canEdit;

  /// The collections of [maker], by name.
  List<String> collectionsOf(String maker) =>
      collections[maker] ?? const <String>[];

  /// Where a film of [maker] may have come from: the maker's own sources,
  /// or every supplier while none is named for it.
  List<({String id, String name})> suppliersFor(String maker) {
    final ids = sourcesByMaker[maker] ?? const <String>[];
    final own = [
      for (final s in suppliers)
        if (ids.contains(s.id)) s,
    ];
    return own.isEmpty ? suppliers : own;
  }

  /// The makers to show as tabs: the list's, then any a film names that the
  /// list has lost — a film is never hidden for want of its maker.
  List<String> get tabs {
    final out = [...makers];
    for (final f in films) {
      if (f.maker.isNotEmpty && !out.contains(f.maker)) out.add(f.maker);
    }
    return out;
  }

  /// One maker's films — of one collection and of one type when given,
  /// found by a search when given; the archive's last. With [archived]
  /// only those in the archive, or (false) only those out of it.
  List<Film> of(
    String maker, {
    String? type,
    String? collection,
    String search = '',
    bool? archived,
  }) {
    final q = search.trim().toLowerCase();
    final out =
        [
          for (final f in films)
            if (f.maker == maker &&
                (archived == null || f.enabled != archived) &&
                (type == null || f.type == type) &&
                (collection == null || f.collection == collection) &&
                (q.isEmpty ||
                    f.colour.toLowerCase().contains(q) ||
                    (f.code ?? '').toLowerCase().contains(q)))
              f,
        ]..sort((a, b) {
          if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
          return a.colour.toLowerCase().compareTo(b.colour.toLowerCase());
        });
    return out;
  }
}

double? _d(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s.replaceAll(',', '.')),
  _ => null,
};

String? _s(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// One line of a film's history of changes (owner, 11.11.2026): who
/// changed what, and when.
@immutable
class FilmChange {
  const FilmChange({
    required this.when,
    required this.who,
    required this.what,
    this.before,
    this.after,
    this.via,
  });

  factory FilmChange.fromJson(Map<String, dynamic> json) => FilmChange(
    when: '${json['when'] ?? ''}',
    who: '${json['who'] ?? ''}',
    what: '${json['what'] ?? ''}',
    before: _s(json['before']),
    after: _s(json['after']),
    via: _s(json['via']),
  );

  final String when;
  final String who;
  final String what;
  final String? before;
  final String? after;

  /// Where the change came from when not the card: «приход», «продажа».
  final String? via;

  /// «название: Альда бел → Альда белый», or just «в архив».
  String get line =>
      (before == null && after == null
          ? what
          : '$what: ${before ?? '—'} → ${after ?? '—'}') +
      (via == null ? '' : ' ($via)');
}
