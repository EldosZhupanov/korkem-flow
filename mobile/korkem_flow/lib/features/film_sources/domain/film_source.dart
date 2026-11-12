import 'package:flutter/foundation.dart';

/// Where film is bought (owner, 11.11.2026): a maker's branch in a city or
/// a wholesaler — its own person, its own telephones, and whose films it
/// sells. One maker has several; one wholesaler sells several makers.
@immutable
class FilmSource {
  const FilmSource({
    required this.id,
    required this.name,
    this.makers = const [],
    this.card = const {},
  });

  factory FilmSource.fromJson(Map<String, dynamic> json) => FilmSource(
    id: '${json['supplier']}',
    name: '${json['name'] ?? json['supplier']}',
    makers: [for (final m in json['makers'] as List? ?? const []) '$m'],
    card: {
      for (final key in cardKeys)
        if ('${json[key] ?? ''}'.trim().isNotEmpty) key: '${json[key]}'.trim(),
    },
  );

  /// The card's fields, in the order they are shown and as the server
  /// names them.
  static const cardKeys = [
    'kind',
    'city',
    'contact',
    'phone',
    'phone2',
    'whatsapp',
    'address',
    'lead',
    'min_order',
    // The hour the day's orders are taken until (owner, 12.11.2026).
    'order_until',
    'note',
  ];

  final String id;
  final String name;

  /// The makers whose film it sells.
  final List<String> makers;

  /// The filled fields of the card, by [cardKeys].
  final Map<String, String> card;

  String? get city => card['city'];
  String? get phone => card['phone'];
  String? get contact => card['contact'];

  /// «Астана · Айгуль · +7 701 …» — whom to ring, in one line.
  String get line => [?city, ?contact, ?phone].join(' · ');
}

/// Every source and the makers one can be ticked for.
@immutable
class FilmSources {
  const FilmSources({
    this.sources = const [],
    this.makers = const [],
    this.canEdit = false,
  });

  factory FilmSources.fromJson(Map<String, dynamic> json) => FilmSources(
    sources: [
      for (final s in json['sources'] as List? ?? const [])
        if (s is Map<String, dynamic>) FilmSource.fromJson(s),
    ],
    makers: [for (final m in json['makers'] as List? ?? const []) '$m'],
    canEdit: json['can_edit'] == true,
  );

  final List<FilmSource> sources;
  final List<String> makers;
  final bool canEdit;
}

/// A maker's own card: its site, a note, and where its film is bought.
@immutable
class FilmMaker {
  const FilmMaker({
    required this.name,
    this.site,
    this.note,
    this.sources = const [],
    this.canEdit = false,
  });

  factory FilmMaker.fromJson(Map<String, dynamic> json) => FilmMaker(
    name: '${json['maker']}',
    site: _s(json['site']),
    note: _s(json['note']),
    sources: [
      for (final s in json['sources'] as List? ?? const [])
        if (s is Map<String, dynamic>) FilmSource.fromJson(s),
    ],
    canEdit: json['can_edit'] == true,
  );

  final String name;
  final String? site;
  final String? note;
  final List<FilmSource> sources;
  final bool canEdit;
}

String? _s(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}
