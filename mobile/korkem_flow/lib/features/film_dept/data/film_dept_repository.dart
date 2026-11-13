import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';

final filmDeptRepositoryProvider = Provider<FilmDeptRepository>(
  (ref) => FilmDeptRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmStockProvider = FutureProvider.autoDispose<FilmCatalog>(
  (ref) => ref.watch(filmDeptRepositoryProvider).stock(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmCustomersProvider = FutureProvider.autoDispose<List<FilmCustomer>>(
  (ref) => ref.watch(filmDeptRepositoryProvider).customers(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmSalesProvider = FutureProvider.autoDispose<List<FilmSale>>(
  (ref) => ref.watch(filmDeptRepositoryProvider).sales(),
);

/// The sales of a period, and of the period as long before it — to say
/// whether it went up (owner, 13.11.2026).
// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmSalesPeriodProvider = FutureProvider.autoDispose
    .family<List<FilmSale>, ({String? since, String? until})>(
      (ref, p) => ref
          .watch(filmDeptRepositoryProvider)
          .sales(since: p.since, until: p.until),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmHistoryProvider = FutureProvider.autoDispose
    .family<List<FilmMove>, String>(
      (ref, item) => ref.watch(filmDeptRepositoryProvider).history(item),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmDeliveryOptionsProvider =
    FutureProvider.autoDispose<FilmDeliveryOptions>(
      (ref) => ref.watch(filmDeptRepositoryProvider).deliveryOptions(),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmTeamProvider = FutureProvider.autoDispose.family<FilmTeam, String?>(
  (ref, month) => ref.watch(filmDeptRepositoryProvider).team(month),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmCashProvider = FutureProvider.autoDispose
    .family<FilmCashBook, ({String? since, String? until})>(
      (ref, p) => ref.watch(filmDeptRepositoryProvider).cash(p.since, p.until),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmReportProvider = FutureProvider.autoDispose
    .family<FilmReport, String?>(
      (ref, month) => ref.watch(filmDeptRepositoryProvider).report(month),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmCustomerSalesProvider = FutureProvider.autoDispose
    .family<List<FilmSale>, String>(
      (ref, customer) =>
          ref.watch(filmDeptRepositoryProvider).sales(customer: customer),
    );

/// The film department — `korkem_manufacturing.api.film_dept`.
class FilmDeptRepository {
  const FilmDeptRepository(this._client);

  static const _base = 'korkem_manufacturing.api.film_dept';

  final FrappeClient _client;

  /// Every film still made, with what is free; the low ones first.
  Future<FilmCatalog> stock() async =>
      FilmCatalog.fromJson(_map(await _client.callMethod('$_base.stock')));

  Future<List<FilmMove>> history(String item) async => [
    for (final r in _list(
      await _client.callMethod('$_base.history', params: {'item': item}),
    ))
      FilmMove.fromJson(r),
  ];

  Future<void> receive({
    required String item,
    required double metres,
    required double priceM,
    required String supplier,
    bool updatePrice = true,
    Map<String, Object?>? delivery,
    String? receivedBy,
    String? arrivesOn,
  }) => _client.callMethod(
    '$_base.receive',
    post: true,
    params: {
      'item': item,
      'metres': metres,
      'price_m': priceM,
      'supplier': supplier,
      'update_price': updatePrice ? 1 : 0,
      // How it came, what that cost, who took it in (owner, 11.11.2026).
      if (delivery != null) 'delivery': jsonEncode(delivery),
      'received_by': ?receivedBy,
      // After today: on its way, not on the shelf until it comes.
      'arrives_on': ?arrivesOn,
    },
  );

  /// Metres put by for a customer until a day.
  Future<void> hold({
    required String item,
    required String customer,
    required double metres,
    String? until,
  }) => _client.callMethod(
    '$_base.hold',
    post: true,
    params: {
      'item': item,
      'customer': customer,
      'metres': metres,
      'until': ?until,
    },
  );

  Future<void> releaseHold(String hold) => _client.callMethod(
    '$_base.release_hold',
    post: true,
    params: {'hold': hold},
  );

  /// The roll on its way came: on the shelf today; [metres] if not as many.
  Future<void> arrived(String entry, {double? metres}) => _client.callMethod(
    '$_base.arrived',
    post: true,
    params: {'entry': entry, 'metres': ?metres},
  );

  /// The supplier is late: the roll is due another day.
  Future<void> reschedule(String entry, String arrivesOn) => _client.callMethod(
    '$_base.reschedule',
    post: true,
    params: {'entry': entry, 'arrives_on': arrivesOn},
  );

  /// The roll on its way will not come.
  Future<void> dropComing(String entry, String reason) => _client.callMethod(
    '$_base.drop_coming',
    post: true,
    params: {'entry': entry, 'reason': reason},
  );

  Future<FilmDeliveryOptions> deliveryOptions() async =>
      FilmDeliveryOptions.fromJson(
        _map(await _client.callMethod('$_base.delivery_options')),
      );

  /// The department's own cash book — `api.film_cash`.
  Future<FilmCashBook> cash(String? since, String? until) async =>
      FilmCashBook.fromJson(
        _map(
          await _client.callMethod(
            'korkem_manufacturing.api.film_cash.book',
            params: {'since': ?since, 'until': ?until},
          ),
        ),
      );

  /// «Закрыть день»: the cash counted; a gap needs a reason.
  Future<void> closeDay(String day, double counted, {String? reason}) =>
      _client.callMethod(
        'korkem_manufacturing.api.film_cash.close_day',
        post: true,
        params: {'day': day, 'counted': counted, 'reason': ?reason},
      );

  /// Given back to the employee, or paid to the carrier, today.
  Future<void> settleDelivery(String receipt, String method) =>
      _client.callMethod(
        'korkem_manufacturing.api.film_cash.settle',
        post: true,
        params: {'receipt': receipt, 'method': method},
      );

  /// The month by seller and the team's bonus — `api.film_team`.
  Future<FilmTeam> team(String? month) async => FilmTeam.fromJson(
    _map(
      await _client.callMethod(
        'korkem_manufacturing.api.film_team.team',
        params: {'month': ?month},
      ),
    ),
  );

  /// The month on one page — `api.film_team.report`.
  Future<FilmReport> report(String? month) async => FilmReport.fromJson(
    _map(
      await _client.callMethod(
        'korkem_manufacturing.api.film_team.report',
        params: {'month': ?month},
      ),
    ),
  );

  /// The owner's: the month's plan in metres and the pot's two shares.
  Future<void> setTeamSettings({
    required double planM,
    required double pct,
    required double pctBelow,
  }) => _client.callMethod(
    'korkem_manufacturing.api.film_team.set_settings',
    post: true,
    params: {'plan_m': planM, 'pct': pct, 'pct_below': pctBelow},
  );

  /// [lines] — the films, their metres and what a metre is charged at;
  /// [payments] — what is paid now, one way or several (owner, 11.11.2026);
  /// the rest is the customer's debt.
  Future<FilmSale> sell({
    required String customer,
    required List<({String item, double metres, double priceM})> lines,
    List<({double amount, String method, String? bank})> payments = const [],
    Set<String> remember = const {},
    String? seller,
    String? issuedBy,
    String? belowReason,
  }) async => FilmSale.fromJson(
    _map(
      await _client.callMethod(
        '$_base.sell',
        post: true,
        params: {
          'customer': customer,
          'lines': jsonEncode([
            for (final l in lines)
              {
                'item': l.item,
                'metres': l.metres,
                'price_m': l.priceM,
                // Typed where the card had none: remembered on the card.
                if (remember.contains(l.item)) 'remember': true,
              },
          ]),
          'payments': jsonEncode([
            for (final p in payments)
              if (p.amount > 0)
                {'amount': p.amount, 'method': p.method, 'bank': ?p.bank},
          ]),
          // Who sold it — the team's bonus is counted by seller.
          'seller': ?seller,
          // Why for less than it cost (owner, 13.11.2026).
          'below_reason': ?belowReason,
          'issued_by': ?issuedBy,
        },
      ),
    ),
  );

  Future<void> toShop({
    required String item,
    required double metres,
    String? order,
  }) => _client.callMethod(
    '$_base.to_shop',
    post: true,
    params: {'item': item, 'metres': metres, 'order': ?order},
  );

  Future<void> writeOff({
    required String item,
    required double metres,
    required String reason,
  }) => _client.callMethod(
    '$_base.write_off',
    post: true,
    params: {'item': item, 'metres': metres, 'reason': reason},
  );

  Future<FilmSale> pay(
    String entry, {
    required double amount,
    required String method,
    String? bank,
  }) async => FilmSale.fromJson(
    _map(
      await _client.callMethod(
        '$_base.pay',
        post: true,
        params: {
          'entry': entry,
          'amount': amount,
          'method': method,
          'bank': ?bank,
        },
      ),
    ),
  );

  /// A movement entered wrong, made again right: the wrong one is struck
  /// through, the right one entered the same day — with [reason].
  Future<void> correct({
    required String entry,
    required String item,
    required String reason,
    double? metres,
    double? priceM,
    String? supplier,
    String? order,
    String? why,
  }) => _client.callMethod(
    '$_base.correct',
    post: true,
    params: {
      'entry': entry,
      'item': item,
      'reason': reason,
      'metres': ?metres,
      'price_m': ?priceM,
      'supplier': ?supplier,
      'order': ?order,
      'why': ?why,
    },
  );

  Future<void> cancel(String entry, String reason) => _client.callMethod(
    '$_base.cancel',
    post: true,
    params: {'entry': entry, 'reason': reason},
  );

  /// One customer's purchases, newest first — his card (12.11.2026).
  Future<List<FilmSale>> sales({
    String? customer,
    String? since,
    String? until,
  }) async => [
    for (final r in _list(
      await _client.callMethod(
        '$_base.sales',
        params: {'customer': ?customer, 'since': ?since, 'until': ?until},
      ),
    ))
      FilmSale.fromJson(r),
  ];

  Future<FilmPrice> priceFor(String item, {String? customer}) async =>
      FilmPrice.fromJson(
        _map(
          await _client.callMethod(
            '$_base.price_for',
            params: {'item': item, 'customer': ?customer},
          ),
        ),
      );

  Future<List<FilmCustomer>> customers() async => [
    for (final r in _list(await _client.callMethod('$_base.customers')))
      FilmCustomer.fromJson(r),
  ];

  Future<void> setCustomer(
    String customer, {
    required bool wholesale,
    required double discount,
  }) => _client.callMethod(
    '$_base.set_customer',
    post: true,
    params: {
      'customer': customer,
      'tier': wholesale ? 'wholesale' : 'retail',
      'discount': discount,
    },
  );

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    return [
      for (final r in raw is List ? raw : const <Object>[])
        if (r is Map) Map<String, dynamic>.from(r),
    ];
  }
}
