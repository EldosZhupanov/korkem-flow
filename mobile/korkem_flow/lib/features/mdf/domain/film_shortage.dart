import 'package:flutter/foundation.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// One film across the open orders: needed, held, free, and what to buy.
@immutable
class FilmToBuy {
  const FilmToBuy({
    required this.decor,
    required this.title,
    required this.unit,
    required this.orders,
    required this.needed,
    required this.held,
    required this.free,
    required this.toBuy,
    this.onBooks = true,
  });

  factory FilmToBuy.fromJson(Map<String, dynamic> json) => FilmToBuy(
    decor: '${json['decor']}',
    title: '${json['title'] ?? json['decor']}',
    unit: '${json['unit'] ?? 'м'}',
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    needed: _d(json['needed']),
    held: _d(json['held']),
    free: _d(json['free']),
    toBuy: _d(json['to_buy']),
    onBooks: json['item'] != null,
  );

  final String decor;
  final String title;
  final String unit;
  final int orders;
  final double needed;
  final double held;
  final double free;
  final double toBuy;

  /// False when the film is not even a material in stock yet.
  final bool onBooks;
}

/// One order's need for one film.
@immutable
class FilmNeed {
  const FilmNeed({
    required this.order,
    required this.customerName,
    required this.deliveryDate,
    required this.decor,
    required this.needed,
    required this.short,
  });

  factory FilmNeed.fromJson(Map<String, dynamic> json) => FilmNeed(
    order: '${json['order']}',
    customerName: '${json['customer_name'] ?? ''}',
    deliveryDate: '${json['delivery_date'] ?? ''}',
    decor: '${json['decor']}',
    needed: _d(json['needed']),
    short: _d(json['short']),
  );

  final String order;
  final String customerName;
  final String deliveryDate;
  final String decor;
  final double needed;
  final double short;
}

@immutable
class FilmShortage {
  const FilmShortage({
    required this.films,
    required this.orders,
    required this.neededTotal,
    required this.toBuyTotal,
  });

  factory FilmShortage.fromJson(Map<String, dynamic> json) => FilmShortage(
    films: [
      for (final f in json['by_film'] as List? ?? const [])
        if (f is Map) FilmToBuy.fromJson(Map<String, dynamic>.from(f)),
    ],
    orders: [
      for (final o in json['orders'] as List? ?? const [])
        if (o is Map) FilmNeed.fromJson(Map<String, dynamic>.from(o)),
    ],
    neededTotal: _d(json['needed_total']),
    toBuyTotal: _d(json['to_buy_total']),
  );

  final List<FilmToBuy> films;
  final List<FilmNeed> orders;
  final double neededTotal;
  final double toBuyTotal;
}
