import 'package:flutter/foundation.dart';

/// «К заказу» (owner, 12.11.2026): what is to be ordered from the suppliers,
/// filled up over the day and sent to each in one message.
@immutable
class FilmWanted {
  const FilmWanted({
    this.groups = const [],
    this.count = 0,
    this.metres = 0,
    this.waiting = 0,
    this.canEdit = false,
  });

  factory FilmWanted.fromJson(Map<String, dynamic> json) => FilmWanted(
    groups: [
      for (final g in json['suppliers'] as List? ?? const [])
        if (g is Map<String, dynamic>) FilmWantGroup.fromJson(g),
    ],
    count: (json['count'] as num?)?.toInt() ?? 0,
    metres: _d(json['metres']) ?? 0,
    waiting: (json['waiting'] as num?)?.toInt() ?? 0,
    canEdit: json['can_edit'] == true,
  );

  final List<FilmWantGroup> groups;

  /// Lines still to send, and their metres.
  final int count;
  final double metres;

  /// Suppliers the list went to who have not answered yet.
  final int waiting;
  final bool canEdit;

  /// The suppliers with something to send.
  List<FilmWantGroup> get toSend => [
    for (final g in groups)
      if (g.open.isNotEmpty) g,
  ];
}

/// One supplier's part of the list: what is to be sent, and what was sent.
@immutable
class FilmWantGroup {
  const FilmWantGroup({
    required this.name,
    this.supplier,
    this.city,
    this.contact,
    this.phone,
    this.whatsapp,
    this.orderUntil,
    this.open = const [],
    this.sent = const [],
    this.sentAt,
  });

  factory FilmWantGroup.fromJson(Map<String, dynamic> json) => FilmWantGroup(
    supplier: _s(json['supplier']),
    name: '${json['name'] ?? ''}',
    city: _s(json['city']),
    contact: _s(json['contact']),
    phone: _s(json['phone']),
    whatsapp: _s(json['whatsapp']),
    orderUntil: _s(json['order_until']),
    open: [
      for (final l in json['open'] as List? ?? const [])
        if (l is Map<String, dynamic>) FilmWant.fromJson(l),
    ],
    sent: [
      for (final l in json['sent'] as List? ?? const [])
        if (l is Map<String, dynamic>) FilmWant.fromJson(l),
    ],
    sentAt: _s(json['sent_at']),
  );

  /// Null: films nobody is named for yet.
  final String? supplier;
  final String name;
  final String? city;
  final String? contact;
  final String? phone;
  final String? whatsapp;

  /// The hour the supplier takes the day's orders until: «16:00».
  final String? orderUntil;
  final List<FilmWant> open;
  final List<FilmWant> sent;

  /// When the list last went out: «2026-11-12 10:20».
  final String? sentAt;

  /// Where the list is written to: its WhatsApp, else its telephone.
  String? get writeTo => whatsapp ?? phone;

  double get openM => open.fold(0, (s, l) => s + l.metres);

  /// [lines] film by film, in the order each film first came: one film
  /// wanted by two customers and the shelf is one row.
  static List<List<FilmWant>> byFilm(List<FilmWant> lines) {
    final out = <String, List<FilmWant>>{};
    for (final l in lines) {
      out.putIfAbsent(l.item, () => []).add(l);
    }
    return out.values.toList();
  }
}

/// One want: a film, so many metres, for a customer or for the shelf.
@immutable
class FilmWant {
  const FilmWant({
    required this.item,
    required this.title,
    required this.metres,
    this.id,
    this.supplier,
    this.customer,
    this.customerName,
    this.auto = false,
    this.at,
    this.by,
    this.free,
    this.priceM,
  });

  factory FilmWant.fromJson(Map<String, dynamic> json) => FilmWant(
    id: _s(json['id']),
    item: '${json['item']}',
    title: '${json['title'] ?? json['item']}',
    metres: _d(json['metres']) ?? 0,
    supplier: _s(json['supplier']),
    customer: _s(json['customer']),
    customerName: _s(json['customer_name']),
    auto: json['auto'] == true,
    at: _s(json['at']),
    by: _s(json['by']),
    free: _d(json['free']),
    priceM: _d(json['price_m']),
  );

  /// Null: offered by itself — the film ran low — not on the list yet.
  final String? id;
  final String item;
  final String title;
  final double metres;
  final String? supplier;

  /// Wanted for this customer; null — for the shelf.
  final String? customer;
  final String? customerName;
  final bool auto;

  /// When it was put on the list («14:55»), and by whom.
  final String? at;
  final String? by;
  final double? free;

  /// The card's purchase price — a starting point when it comes.
  final double? priceM;
}

/// A film for a delivery window, with what the list wanted of it.
typedef FilmReceiveWant = ({
  String item,
  double metres,
  String? customer,
  String? customerName,
  List<String> orders,
});

/// An MDF order whose facades take a film and lack it — where a roll of
/// it may go «в производство» (owner, 13.11.2026).
typedef FilmForProduction = ({
  String order,
  String customerName,
  String? deliveryDate,
  double needed,
  double short,
});

FilmForProduction filmForProductionOf(Map<String, dynamic> json) => (
  order: '${json['order'] ?? ''}',
  customerName: '${json['customer_name'] ?? ''}',
  deliveryDate: json['delivery_date'] as String?,
  needed: _d(json['needed']) ?? 0,
  short: _d(json['short']) ?? 0,
);

double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

String? _s(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}
