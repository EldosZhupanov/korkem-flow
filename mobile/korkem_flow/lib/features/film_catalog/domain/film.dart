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
    this.hex,
    this.ral,
    this.supplier,
    this.priceM,
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
    hex: _s(json['hex']),
    ral: _s(json['ral']),
    supplier: _s(json['supplier']),
    priceM: _d(json['price_m']),
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

  /// The sample's colour, «#F4F3EE».
  final String? hex;
  final String? ral;
  final String? supplier;

  /// What the supplier charges us per running metre; null when hidden.
  final double? priceM;
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
    canEdit: json['can_edit'] == true,
  );

  final List<Film> films;

  /// Colours of the old order-form list that no film carries: «не указан».
  final List<String> unassigned;
  final List<String> makers;
  final List<String> types;
  final List<({String id, String name})> suppliers;
  final bool canEdit;

  /// The makers to show as tabs: the list's, then any a film names that the
  /// list has lost — a film is never hidden for want of its maker.
  List<String> get tabs {
    final out = [...makers];
    for (final f in films) {
      if (f.maker.isNotEmpty && !out.contains(f.maker)) out.add(f.maker);
    }
    return out;
  }

  /// One maker's films, of one type when given, found by a search when
  /// given; switched-off ones last.
  List<Film> of(String maker, {String? type, String search = ''}) {
    final q = search.trim().toLowerCase();
    final out =
        [
          for (final f in films)
            if (f.maker == maker &&
                (type == null || f.type == type) &&
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
