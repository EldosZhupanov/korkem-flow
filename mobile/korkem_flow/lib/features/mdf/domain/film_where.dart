/// A film the order lacks — where to get it (owner, 19.11.2026: «в Алмате
/// дёшево, логистика 5 дней, в Астане чуть дороже, но 2 дня»).
library;

import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';

String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
double? _dn(Object? v) => v is num ? v.toDouble() : null;
double _d(Object? v) => v is num ? v.toDouble() : 0;
int? _in(Object? v) => v is num ? v.toInt() : null;
List<Object?> _list(Object? v) => v is List ? v : const [];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

class FilmWhere {
  const FilmWhere({
    required this.order,
    required this.accepted,
    required this.needBy,
    required this.urgent,
    required this.films,
  });

  factory FilmWhere.fromJson(Map<String, dynamic> j) => FilmWhere(
    order: '${j['order'] ?? ''}',
    accepted: j['accepted'] == true,
    needBy: '${j['need_by'] ?? ''}',
    urgent: j['urgent'] == true,
    films: [
      for (final f in _list(j['films']))
        if (f is Map) FilmLack.fromJson(_map(f)),
    ],
  );

  final String order;

  /// Film is ordered under an accepted order only.
  final bool accepted;

  /// The day the shop wants the film, ISO.
  final String needBy;
  final bool urgent;
  final List<FilmLack> films;
}

/// One film the shelf cannot give.
class FilmLack {
  const FilmLack({
    required this.film,
    required this.item,
    required this.short,
    this.maker,
    this.unit,
    this.sources = const [],
    this.ordered = const [],
    this.nowhere,
    this.lookalikes = const [],
  });

  factory FilmLack.fromJson(Map<String, dynamic> j) => FilmLack(
    film: '${j['film'] ?? ''}',
    item: '${j['item'] ?? ''}',
    maker: _s(j['maker']),
    short: _d(j['short']),
    unit: _s(j['unit']),
    sources: [
      for (final s in _list(j['sources']))
        if (s is Map) FilmSourceOffer.fromJson(_map(s)),
    ],
    ordered: [
      for (final o in _list(j['ordered']))
        if (o is Map) FilmOrdered.fromJson(_map(o)),
    ],
    nowhere: _s(j['nowhere']),
    lookalikes: [
      for (final m in _list(j['lookalikes']))
        if (m is Map) DecorMatch.fromJson(_map(m)),
    ],
  );

  final String film;
  final String item;
  final String? maker;
  final double short;
  final String? unit;
  final List<FilmSourceOffer> sources;
  final List<FilmOrdered> ordered;

  /// The day everyone was rung and no one had it, ISO; null when not said.
  final String? nowhere;

  /// What is like it at the other makers — on our shelf first.
  final List<DecorMatch> lookalikes;
}

/// One place the film may be bought: a branch of a maker's dealer.
class FilmSourceOffer {
  const FilmSourceOffer({
    required this.supplier,
    required this.name,
    this.city,
    this.contact,
    this.phone,
    this.whatsapp,
    this.lead,
    this.days,
    this.times = 0,
    this.priceOn,
    this.priceKnown = false,
    this.priceM,
    this.deliveryM,
    this.landedM,
    this.comesOn,
    this.inTime,
    this.advised = false,
  });

  factory FilmSourceOffer.fromJson(Map<String, dynamic> j) => FilmSourceOffer(
    supplier: '${j['supplier'] ?? ''}',
    name: '${j['name'] ?? ''}',
    city: _s(j['city']),
    contact: _s(j['contact']),
    phone: _s(j['phone']),
    whatsapp: _s(j['whatsapp']),
    lead: _s(j['lead']),
    days: _in(j['days']),
    times: _in(j['times']) ?? 0,
    priceOn: _s(j['price_on']),
    priceKnown: j['price_known'] == true,
    priceM: _dn(j['price_m']),
    deliveryM: _dn(j['delivery_m']),
    landedM: _dn(j['landed_m']),
    comesOn: _s(j['comes_on']),
    inTime: j['in_time'] is bool ? j['in_time'] as bool : null,
    advised: j['advised'] == true,
  );

  final String supplier;
  final String name;
  final String? city;
  final String? contact;
  final String? phone;
  final String? whatsapp;
  final String? lead;

  /// Days it takes to come, from the source's card; null when unsaid.
  final int? days;

  /// How often this very film was bought there.
  final int times;

  /// The day of the last price paid there, ISO.
  final String? priceOn;

  /// Whether [priceM] is what was paid there — else it is the card's price.
  final bool priceKnown;
  final double? priceM;

  /// What the bringing cost a metre from there, of late.
  final double? deliveryM;

  /// [priceM] with [deliveryM] — what a metre costs at the door.
  final double? landedM;
  final String? comesOn;

  /// Whether it comes before the shop wants it; null when the days are unsaid.
  final bool? inTime;

  /// The one the program advises.
  final bool advised;
}

/// Metres already put on «К заказу» for this order.
class FilmOrdered {
  const FilmOrdered({
    required this.line,
    required this.supplier,
    required this.metres,
    required this.status,
    this.note,
  });

  factory FilmOrdered.fromJson(Map<String, dynamic> j) => FilmOrdered(
    line: '${j['line'] ?? ''}',
    supplier: '${j['supplier'] ?? ''}',
    metres: _d(j['metres']),
    status: '${j['status'] ?? ''}',
    note: _s(j['note']),
  );

  final String line;
  final String supplier;
  final double metres;
  final String status;
  final String? note;
}
