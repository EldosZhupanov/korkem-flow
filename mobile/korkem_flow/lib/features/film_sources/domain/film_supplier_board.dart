import 'package:flutter/foundation.dart';

/// The suppliers' board (owner, 12.11.2026): each source with what its film
/// sold, what lies on the shelf, what is on its way and what to order —
/// the best seller first.
@immutable
class FilmSupplierBoard {
  const FilmSupplierBoard({
    this.allTime = false,
    this.soldM = 0,
    this.amount,
    this.onHandM = 0,
    this.comingM = 0,
    this.comingCount = 0,
    this.reorderFilms = 0,
    this.owed,
    this.owedSuppliers = 0,
    this.rows = const [],
  });

  factory FilmSupplierBoard.fromJson(Map<String, dynamic> json) =>
      FilmSupplierBoard(
        allTime: json['period'] == 'all',
        soldM: _d(json['sold_m']) ?? 0,
        amount: _d(json['amount']),
        onHandM: _d(json['on_hand_m']) ?? 0,
        comingM: _d(json['coming_m']) ?? 0,
        comingCount: (json['coming_count'] as num?)?.toInt() ?? 0,
        reorderFilms: (json['reorder_films'] as num?)?.toInt() ?? 0,
        owed: _d(json['owed']),
        owedSuppliers: (json['owed_suppliers'] as num?)?.toInt() ?? 0,
        rows: [
          for (final r in json['suppliers'] as List? ?? const [])
            if (r is Map<String, dynamic>) FilmSupplierRow.fromJson(r),
        ],
      );

  /// Counted over all time, not this month.
  final bool allTime;

  /// Metres sold to customers over the period, and what they were charged
  /// — null for someone who does not see money.
  final double soldM;
  final double? amount;
  final double onHandM;
  final double comingM;
  final int comingCount;

  /// How many films ran low and are to be ordered.
  final int reorderFilms;

  /// What we owe the sources for film taken on credit, and how many of
  /// them — null for someone who does not see money.
  final double? owed;
  final int owedSuppliers;
  final List<FilmSupplierRow> rows;

  /// The best seller's metres: the length of a full bar.
  double get topM => rows.fold(0, (m, r) => r.soldM > m ? r.soldM : m);

  FilmSupplierRow? row(String id) {
    for (final r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// One source's line on the board.
@immutable
class FilmSupplierRow {
  const FilmSupplierRow({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.soldM = 0,
    this.amount,
    this.share = 0,
    this.onHandM = 0,
    this.coming,
    this.leadDays,
    this.promisedDays,
    this.lateDays = 0,
    this.reorder = const [],
    this.idleFilms = 0,
    this.idleM = 0,
    this.owed,
    this.onTime,
    this.rolls = 0,
    this.priceChange,
  });

  factory FilmSupplierRow.fromJson(Map<String, dynamic> json) {
    final coming = json['coming'];
    final idle = json['idle'];
    return FilmSupplierRow(
      id: '${json['supplier']}',
      name: '${json['name'] ?? json['supplier']}',
      phone: _s(json['phone']),
      whatsapp: _s(json['whatsapp']),
      soldM: _d(json['sold_m']) ?? 0,
      amount: _d(json['amount']),
      share: _d(json['share']) ?? 0,
      onHandM: _d(json['on_hand_m']) ?? 0,
      coming: coming is Map<String, dynamic>
          ? FilmSupplierComing.fromJson(coming)
          : null,
      leadDays: (json['lead_days'] as num?)?.toInt(),
      promisedDays: (json['promised_days'] as num?)?.toInt(),
      lateDays: (json['late_days'] as num?)?.toInt() ?? 0,
      reorder: [
        for (final o in json['reorder'] as List? ?? const [])
          if (o is Map<String, dynamic>) FilmSupplierOrder.fromJson(o),
      ],
      idleFilms: idle is Map ? (idle['films'] as num?)?.toInt() ?? 0 : 0,
      idleM: idle is Map ? _d(idle['metres']) ?? 0 : 0,
      owed: _d(json['owed']),
      onTime: (json['on_time'] as num?)?.toInt(),
      rolls: (json['rolls'] as num?)?.toInt() ?? 0,
      priceChange: _d(json['price_change']),
    );
  }

  final String id;
  final String name;
  final String? phone;
  final String? whatsapp;

  /// Metres of its film sold over the period, what they brought, and its
  /// share of all the film sold, in percent.
  final double soldM;
  final double? amount;
  final double share;
  final double onHandM;

  /// What is on its way; null when nothing is.
  final FilmSupplierComing? coming;

  /// How many days a roll takes, against how many were promised; null
  /// while no roll of its was ordered ahead.
  final int? leadDays;
  final int? promisedDays;
  final int lateDays;

  /// Its films that ran low.
  final List<FilmSupplierOrder> reorder;

  /// Its films lying on the shelf unmoved, and their metres.
  final int idleFilms;
  final double idleM;

  /// What we owe it for film taken on credit; null when nothing, or for
  /// someone who does not see money.
  final double? owed;

  /// How many of its last [rolls] rolls came no later than promised; null
  /// while none was ordered ahead.
  final int? onTime;
  final int rolls;

  /// Its last price for a metre against the one before, in percent.
  final double? priceChange;

  /// Under this share of rolls on time, the source is not to be relied on.
  static const double reliable = 0.8;

  /// Where an order is written to: its WhatsApp, else its telephone.
  String? get writeTo => whatsapp ?? phone;

  /// Nothing to do about it: nothing ran low, late or idle.
  bool get fine =>
      reorder.isEmpty &&
      lateDays == 0 &&
      idleFilms == 0 &&
      (coming?.lateDays ?? 0) == 0;
}

/// What is on its way from a source.
@immutable
class FilmSupplierComing {
  const FilmSupplierComing({
    required this.metres,
    this.count = 1,
    this.due,
    this.lateDays = 0,
  });

  factory FilmSupplierComing.fromJson(Map<String, dynamic> json) =>
      FilmSupplierComing(
        metres: _d(json['metres']) ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 1,
        due: _s(json['due']),
        lateDays: (json['late_days'] as num?)?.toInt() ?? 0,
      );

  final double metres;
  final int count;

  /// The nearest day a roll is due.
  final String? due;
  final int lateDays;
}

/// A film that ran low, to be ordered from the source.
@immutable
class FilmSupplierOrder {
  const FilmSupplierOrder({
    required this.item,
    required this.title,
    required this.metres,
    this.free = 0,
  });

  factory FilmSupplierOrder.fromJson(Map<String, dynamic> json) =>
      FilmSupplierOrder(
        item: '${json['item']}',
        title: '${json['title'] ?? json['item']}',
        metres: _d(json['metres']) ?? 0,
        free: _d(json['free']) ?? 0,
      );

  final String item;
  final String title;

  /// How many metres to order, and how many are left.
  final double metres;
  final double free;
}

double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

String? _s(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}
