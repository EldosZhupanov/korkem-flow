import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/mdf/domain/film_shortage.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_batch.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_cash.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_debts.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_margin.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_report.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_tags.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_volume.dart';

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

  /// An order's tag code (urgent, rework) or a customer's (vip …).
  String? tag,
});

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfOrdersProvider = FutureProvider.autoDispose
    .family<List<MdfOrderRow>, MdfListQuery>(
      (ref, query) => ref.watch(mdfOrderRepositoryProvider).listing(query),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfPlanProvider = FutureProvider.autoDispose<MdfPlan>(
  (ref) => ref.watch(mdfOrderRepositoryProvider).plan(),
);

/// The days a cash book or a report covers, both ends included (`yyyy-MM-dd`).
typedef MdfPeriod = ({String since, String until});

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfCashProvider = FutureProvider.autoDispose.family<MdfCash, MdfPeriod>(
  (ref, p) => ref
      .watch(mdfOrderRepositoryProvider)
      .cash(since: p.since, until: p.until),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfReportProvider = FutureProvider.autoDispose
    .family<MdfReport, MdfPeriod>(
      (ref, p) => ref
          .watch(mdfOrderRepositoryProvider)
          .report(since: p.since, until: p.until),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfVolumeProvider = FutureProvider.autoDispose
    .family<MdfVolume, MdfPeriod>(
      (ref, p) => ref
          .watch(mdfOrderRepositoryProvider)
          .volume(since: p.since, until: p.until),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfWorkersProvider = FutureProvider.autoDispose<List<MdfWorker>>(
  (ref) => ref.watch(mdfOrderRepositoryProvider).workers(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfDictionariesProvider = FutureProvider.autoDispose<MdfDictionaries>(
  (ref) => ref.watch(mdfOrderRepositoryProvider).dictionaries(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfCustomersProvider = FutureProvider.autoDispose<List<FacadeCustomer>>(
  (ref) => ref.watch(mdfOrderRepositoryProvider).customerList(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfDebtsProvider = FutureProvider.autoDispose<MdfDebts>(
  (ref) => ref.watch(mdfOrderRepositoryProvider).debts(),
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

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfMarginProvider = FutureProvider.autoDispose.family<MdfMargin, String>(
  (ref, name) => ref.watch(mdfOrderRepositoryProvider).margin(name),
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
          'tag': ?query.tag,
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
    Map<String, double> filmRates = const {},
    List<MdfOrderTag> tags = const [],
  }) async => MdfPricing.fromJson(
    _map(
      await _client.callMethod(
        '$_base.price',
        post: true,
        params: {
          'lines': jsonEncode([for (final l in lines) l.toJson()]),
          'finish': ?finish,
          'default_rate': ?defaultRate,
          if (filmRates.isNotEmpty) 'film_rates': jsonEncode(filmRates),
          if (tags.isNotEmpty)
            'tags': jsonEncode([for (final t in tags) t.wire]),
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

  /// «Изменить заказ» after it was accepted: the reason goes into its
  /// history; the payments stay.
  Future<MdfOrder> changeOrder(
    String order, {
    required List<MdfLineInput> lines,
    required String reason,
    MdfHead? head,
    String? deliveryDate,
  }) => _post('change_order', {
    'order': order,
    'lines': jsonEncode([for (final l in lines) l.toJson()]),
    'reason': reason,
    if (head != null) 'head': jsonEncode(head.toJson()),
    'delivery_date': ?deliveryDate,
  });

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

  /// Who owes what: by customer and by order.
  Future<MdfDebts> debts() async =>
      MdfDebts.fromJson(_map(await _client.callMethod('$_base.debts')));

  /// The parts of every open order of one film (and milling), as one list.
  Future<MdfBatch> batch({String? decor, String? milling}) async =>
      MdfBatch.fromJson(
        _map(
          await _client.callMethod(
            '$_base.batch',
            params: {'decor': ?decor, 'milling': ?milling},
          ),
        ),
      );

  /// «Жоспар»: what waits at each stage, and the intake by day.
  Future<MdfPlan> plan() async =>
      MdfPlan.fromJson(_map(await _client.callMethod('$_base.plan')));

  /// «Касса» for the days [since, until] (`yyyy-MM-dd`).
  Future<MdfCash> cash({required String since, required String until}) async =>
      MdfCash.fromJson(
        _map(
          await _client.callMethod(
            '$_base.cash',
            params: {'since': since, 'until': until},
          ),
        ),
      );

  /// «Отчёт по заказам» for the orders dated [since, until].
  Future<MdfReport> report({
    required String since,
    required String until,
  }) async => MdfReport.fromJson(
    _map(
      await _client.callMethod(
        '$_base.report',
        params: {'since': since, 'until': until},
      ),
    ),
  );

  /// The order form's lists.
  Future<MdfDictionaries> dictionaries() async => MdfDictionaries.fromJson(
    _map(await _client.callMethod('$_base.dictionaries')),
  );

  Future<MdfDictionaries> dictionaryAdd(MdfDictKind kind, String value) =>
      _dict('dictionary_add', {'kind': kind.wire, 'value': value});

  Future<MdfDictionaries> dictionaryRename(
    MdfDictKind kind,
    String option,
    String value,
  ) => _dict('dictionary_rename', {
    'kind': kind.wire,
    'option': option,
    'value': value,
  });

  /// A value an order or a material uses is only switched off.
  Future<MdfDictionaries> dictionaryRemove(MdfDictKind kind, String option) =>
      _dict('dictionary_remove', {'kind': kind.wire, 'option': option});

  Future<MdfDictionaries> _dict(
    String method,
    Map<String, dynamic> params,
  ) async => MdfDictionaries.fromJson(
    _map(
      await _client.callMethod('$_base.$method', post: true, params: params),
    ),
  );

  /// «Заказчик»: every customer, by name.
  Future<List<FacadeCustomer>> customerList() async {
    final response = await _client.callMethod('$_base.customer_list');
    final raw = response['message'] ?? response['data'];
    // By name, by alphabet (owner, 09.11.2026).
    return [
      for (final c in raw is List ? raw : const <Object>[])
        if (c is Map) FacadeCustomer.fromJson(Map<String, dynamic>.from(c)),
    ]..sort((a, b) => mdfNaturalCompare(a.title, b.title));
  }

  Future<FacadeCustomer> customerAdd(
    String name, {
    String? phone,
    String? organization,
    List<String> tags = const [],
  }) async => FacadeCustomer.fromJson(
    _map(
      await _client.callMethod(
        '$_base.customer_add',
        post: true,
        params: {
          'name': name,
          'phone': ?phone,
          'organization': ?organization,
          'tags': jsonEncode(tags),
        },
      ),
    ),
  );

  Future<FacadeCustomer> customerUpdate(
    String customer,
    String name, {
    String? phone,
    String? organization,
    List<String> tags = const [],
  }) async => FacadeCustomer.fromJson(
    _map(
      await _client.callMethod(
        '$_base.customer_update',
        post: true,
        params: {
          'customer': customer,
          'name': name,
          'phone': ?phone,
          'organization': ?organization,
          'tags': jsonEncode(tags),
        },
      ),
    ),
  );

  /// Deleted when the customer has no orders; disabled otherwise.
  Future<void> customerRemove(String customer) async {
    await _client.callMethod(
      '$_base.customer_remove',
      post: true,
      params: {'customer': customer},
    );
  }

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

  /// [worker] — the Employee who did it, for the work volume.
  Future<MdfOrder> setStage(
    String order,
    MdfStage stage, {
    required bool done,
    String? worker,
  }) => _post('set_stage', {
    'order': order,
    'stage': stage.name,
    'done': done ? 1 : 0,
    'worker': ?worker,
  });

  /// «+ этап»: paint or vacuum for a rework, or taken off again.
  Future<MdfOrder> extraStage(
    String order,
    MdfStage stage, {
    required bool on,
  }) => _post('extra_stage', {
    'order': order,
    'stage': stage.name,
    'on': on ? 1 : 0,
  });

  /// Who can be named on a stage: the company's active employees.
  Future<List<MdfWorker>> workers() async {
    final response = await _client.callMethod('$_base.workers');
    final raw = response['message'] ?? response['data'];
    return [
      for (final w in raw is List ? raw : const <Object>[])
        if (w is Map) MdfWorker.fromJson(Map<String, dynamic>.from(w)),
    ];
  }

  /// What the order earned: its total less material and work.
  Future<MdfMargin> margin(String order) async => MdfMargin.fromJson(
    _map(await _client.callMethod('$_base.margin', params: {'order': order})),
  );

  /// «Объём работ» for the stages ticked in [since, until].
  Future<MdfVolume> volume({
    required String since,
    required String until,
  }) async => MdfVolume.fromJson(
    _map(
      await _client.callMethod(
        '$_base.volume',
        params: {'since': since, 'until': until},
      ),
    ),
  );

  /// The customer's own paint: what he brought, and whether it is here.
  Future<MdfOrder> setClientPaint(String order, {String? note, bool? received}) =>
      _post('set_client_paint', {
        'order': order,
        'note': ?note,
        if (received != null) 'received': received ? 1 : 0,
      });

  /// A reason puts it on hold; none takes it off.
  Future<MdfOrder> hold(String order, String? reason) =>
      _post('hold', {'order': order, 'reason': ?reason});

  /// [takenBy] — who came for it when not the customer, with a phone.
  Future<MdfOrder> handOver(
    String order, {
    String? comment,
    String? takenBy,
    String? takenPhone,
  }) => _post('hand_over', {
    'order': order,
    'comment': ?comment,
    'taken_by': ?takenBy,
    'taken_phone': ?takenPhone,
  });

  /// A hand-over undone, with a reason (the same day, or by the owner).
  Future<MdfOrder> returnToWork(String order, String reason) =>
      _post('return_to_work', {'order': order, 'reason': reason});

  /// A payment entered wrong: cancelled on the server and entered again.
  Future<MdfOrder> fixPayment(
    String order, {
    required String entry,
    required String reason,
    required double amount,
    required String method,
    String? bank,
  }) => _post('fix_payment', {
    'order': order,
    'entry': entry,
    'reason': reason,
    'amount': amount,
    'method': method,
    'bank': ?bank,
  });

  Future<MdfOrder> deletePayment(
    String order, {
    required String entry,
    required String reason,
  }) => _post('delete_payment', {
    'order': order,
    'entry': entry,
    'reason': reason,
  });

  /// Written once even if the network drops halfway (idempotency key).
  Future<void> addPayment(
    String order, {
    required double amount,
    required String method,
    String? bank,
  }) async {
    await _outbox.execute(
      _client,
      '$_base.add_payment',
      params: {
        'order': order,
        'amount': amount,
        'method': method,
        'bank': ?bank,
      },
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
