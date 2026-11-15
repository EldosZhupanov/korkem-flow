import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';

final cncRepositoryProvider = Provider<CncRepository>(
  (ref) => CncRepository(ref.watch(frappeClientProvider)),
);

/// What the list is filtered by.
typedef CncQuery = ({CncStatus? status, String search});

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final cncListingProvider = FutureProvider.autoDispose
    .family<CncListing, CncQuery>(
      (ref, q) => ref.watch(cncRepositoryProvider).listing(q),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final cncServicesProvider = FutureProvider.autoDispose<List<CncService>>(
  (ref) => ref.watch(cncRepositoryProvider).services(includeDisabled: true),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final cncSettingsProvider = FutureProvider.autoDispose<CncSettings>(
  (ref) => ref.watch(cncRepositoryProvider).settings(),
);

/// Услуги ЧПУ — `korkem_manufacturing.api.cnc_orders` (owner, 15.11.2026).
class CncRepository {
  const CncRepository(this._client);

  static const _base = 'korkem_manufacturing.api.cnc_orders';

  final FrappeClient _client;

  Future<Object?> _get(String method, [Map<String, Object?>? params]) async =>
      (await _client.callMethod('$_base.$method', params: params))['message'];

  Future<Object?> _post(String method, Map<String, Object?> params) async =>
      (await _client.callMethod(
        '$_base.$method',
        post: true,
        params: params,
      ))['message'];

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  static List<CncService> _services(Object? v) => [
    for (final r in v is List ? v : const <Object>[])
      if (r is Map) CncService.fromJson(Map<String, dynamic>.from(r)),
  ];

  Future<List<CncService>> services({bool includeDisabled = false}) async =>
      _services(
        await _get('services', {'include_disabled': includeDisabled ? 1 : 0}),
      );

  Future<List<CncService>> saveService({
    required String title,
    required String unit,
    String? group,
    double? price,
    double? priceTrade,
    double? minutes,
    String? id,
    bool enabled = true,
  }) async => _services(
    await _post('save_service', {
      'title': title,
      'unit': unit,
      'group': ?group,
      'price': ?price,
      'price_trade': ?priceTrade,
      'minutes': ?minutes,
      'service_id': ?id,
      'enabled': enabled ? 1 : 0,
    }),
  );

  Future<CncSettings> settings() async =>
      CncSettings.fromJson(_map(await _get('settings')));

  Future<CncSettings> setSettings({
    double? urgentPct,
    double? minOrder,
    double? dayMinutes,
  }) async => CncSettings.fromJson(
    _map(
      await _post('set_settings', {
        'urgent_pct': ?urgentPct,
        'min_order': ?minOrder,
        'day_minutes': ?dayMinutes,
      }),
    ),
  );

  Future<List<CncMaterial>> materials() async => [
    for (final r in (await _get('materials')) as List? ?? const [])
      if (r is Map)
        (
          item: '${r['item']}',
          title: '${r['title'] ?? ''}',
          unit: '${r['unit'] ?? ''}',
          onHand: (r['on_hand'] as num?)?.toDouble() ?? 0,
          cost: (r['cost'] as num?)?.toDouble() ?? 0,
        ),
  ];

  Future<CncQuote> price(
    List<CncLineInput> lines, {
    String? customer,
    List<String> tags = const [],
  }) async => CncQuote.fromJson(
    _map(
      await _post('price', {
        'lines': jsonEncode([for (final l in lines) l.toJson()]),
        'customer': ?customer,
        'tags': jsonEncode(tags),
      }),
    ),
  );

  Future<CncCard> saveDraft({
    required String customer,
    required List<CncLineInput> lines,
    String? deliveryDate,
    List<CncIntake> intake = const [],
    bool terms = false,
    List<String> tags = const [],
    String? notes,
    String? order,
  }) async => _card(
    await _post('save_draft', {
      'customer': customer,
      'lines': jsonEncode([for (final l in lines) l.toJson()]),
      'delivery_date': ?deliveryDate,
      'intake': jsonEncode([for (final i in intake) cncIntakeJson(i)]),
      'terms': terms ? 1 : 0,
      'tags': jsonEncode(tags),
      'notes': ?notes,
      'order': ?order,
    }),
  );

  static CncCard _card(Object? v) => CncCard.fromJson(_map(v));

  Future<CncCard> card(String order) async =>
      _card(await _get('card', {'order': order}));

  Future<CncCard> accept(String order) async =>
      _card(await _post('accept', {'order': order}));

  Future<CncCard> start(String order) async =>
      _card(await _post('start', {'order': order}));

  Future<CncCard> ready(String order, {bool done = true}) async =>
      _card(await _post('ready', {'order': order, 'done': done ? 1 : 0}));

  Future<CncCard> hold(String order, String? reason) async =>
      _card(await _post('hold', {'order': order, 'reason': ?reason}));

  Future<CncCard> handOver(
    String order, {
    String? comment,
    String? takenBy,
    String? takenPhone,
  }) async => _card(
    await _post('hand_over', {
      'order': order,
      'comment': ?comment,
      'taken_by': ?takenBy,
      'taken_phone': ?takenPhone,
    }),
  );

  /// A draft is deleted (null comes back); an accepted order is cancelled.
  Future<CncCard?> cancel(String order, String reason) async {
    final body = _map(await _post('cancel', {'order': order, 'reason': reason}));
    return body['deleted'] == true ? null : CncCard.fromJson(body);
  }

  Future<CncCard> addPayment(
    String order,
    double amount,
    String method,
  ) async => _card(
    await _post('add_payment', {
      'order': order,
      'amount': amount,
      'method': method,
    }),
  );

  Future<CncListing> listing(CncQuery q) async => CncListing.fromJson(
    _map(
      await _get('listing', {
        'status': ?q.status?.wire,
        if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
      }),
    ),
  );
}
