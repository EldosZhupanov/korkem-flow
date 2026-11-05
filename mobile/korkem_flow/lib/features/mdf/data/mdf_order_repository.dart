import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/mdf/domain/film_shortage.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';

final mdfOrderRepositoryProvider = Provider<MdfOrderRepository>(
  (ref) => MdfOrderRepository(
    ref.watch(frappeClientProvider),
    ref.watch(mutationOutboxProvider),
  ),
);

/// What the list is filtered by.
typedef MdfListQuery = ({
  String search,
  MdfStatus? status,
  bool overdue,
  bool withDebt,
});

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfOrdersProvider = FutureProvider.autoDispose
    .family<List<MdfOrderRow>, MdfListQuery>(
      (ref, query) => ref.watch(mdfOrderRepositoryProvider).listing(query),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final filmShortageProvider = FutureProvider.autoDispose<FilmShortage>(
  (ref) => ref.watch(mdfOrderRepositoryProvider).filmShortage(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfOrderProvider = FutureProvider.autoDispose.family<MdfOrder, String>(
  (ref, name) => ref.watch(mdfOrderRepositoryProvider).card(name),
);

/// «Заказы МДФ» (`korkem_manufacturing.api.mdf_orders`).
class MdfOrderRepository {
  MdfOrderRepository(this._client, [MutationOutbox? outbox])
    : _outbox = outbox ?? MutationOutbox();

  static const _base = 'korkem_manufacturing.api.mdf_orders';

  final FrappeClient _client;
  final MutationOutbox _outbox;

  Future<List<MdfOrderRow>> listing(MdfListQuery query) async {
    final data = _map(
      await _client.callMethod(
        '$_base.listing',
        params: {
          if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
          if (query.status != null) 'status': query.status!.wire,
          if (query.overdue) 'overdue': 1,
          if (query.withDebt) 'with_debt': 1,
        },
      ),
    );
    return [
      for (final r in data['orders'] as List? ?? const [])
        if (r is Map) MdfOrderRow.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  Future<MdfOrder> card(String name) async => MdfOrder.fromJson(
    _map(await _client.callMethod('$_base.card', params: {'order': name})),
  );

  /// Instant arithmetic for the screen; saves nothing.
  Future<MdfPricing> price({
    required List<MdfLineInput> lines,
    String? finish,
    double? defaultRate,
  }) async => MdfPricing.fromJson(
    _map(
      await _client.callMethod(
        '$_base.price',
        post: true,
        params: {
          'lines': jsonEncode([for (final l in lines) l.toJson()]),
          'finish': ?finish,
          'default_rate': ?defaultRate,
        },
      ),
    ),
  );

  Future<MdfOrder> saveDraft({
    required String customer,
    required String deliveryDate,
    required MdfHead head,
    required List<MdfLineInput> lines,
    String? order,
    String? notes,
  }) => _post('save_draft', {
    'customer': customer,
    'delivery_date': deliveryDate,
    'head': jsonEncode(head.toJson()),
    'lines': jsonEncode([for (final l in lines) l.toJson()]),
    'order': ?order,
    'notes': ?notes,
  });

  Future<MdfOrder> accept(String order) => _post('accept', {'order': order});

  /// A customer written down on the card: name and phone. The same phone
  /// twice gives back the customer already on file.
  Future<FacadeCustomer> newCustomer(String name, {String? phone}) async =>
      FacadeCustomer.fromJson(
        _map(
          await _client.callMethod(
            '$_base.new_customer',
            post: true,
            params: {'name': name, 'phone': ?phone},
          ),
        ),
      );

  /// The film open orders still need, by film, and what to buy.
  Future<FilmShortage> filmShortage() async => FilmShortage.fromJson(
    _map(await _client.callMethod('$_base.film_shortage')),
  );

  /// The head of the last order this manager wrote, or null for the first.
  Future<MdfHead?> lastHead() async {
    final head = _map(await _client.callMethod('$_base.last_head'));
    return head.isEmpty ? null : MdfHead.fromJson(head);
  }

  Future<void> deleteDraft(String order) async {
    await _client.callMethod(
      '$_base.delete_draft',
      post: true,
      params: {'order': order},
    );
  }

  Future<MdfOrder> cancel(String order, String reason) =>
      _post('cancel', {'order': order, 'reason': reason});

  Future<MdfOrder> setStage(
    String order,
    MdfStage stage, {
    required bool done,
  }) => _post('set_stage', {
    'order': order,
    'stage': stage.name,
    'done': done ? 1 : 0,
  });

  /// A reason puts it on hold; none takes it off.
  Future<MdfOrder> hold(String order, String? reason) =>
      _post('hold', {'order': order, 'reason': ?reason});

  Future<MdfOrder> handOver(String order, {String? comment}) =>
      _post('hand_over', {'order': order, 'comment': ?comment});

  /// Written once even if the network drops halfway (idempotency key).
  Future<void> addPayment(
    String order, {
    required double amount,
    required String method,
  }) async {
    await _outbox.execute(
      _client,
      '$_base.add_payment',
      params: {'order': order, 'amount': amount, 'method': method},
    );
  }

  Future<MdfOrder> _post(String method, Map<String, dynamic> params) async =>
      MdfOrder.fromJson(
        _map(
          await _client.callMethod(
            '$_base.$method',
            post: true,
            params: params,
          ),
        ),
      );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по заказу МДФ.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
