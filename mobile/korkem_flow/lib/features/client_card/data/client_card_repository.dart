import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';

final clientCardRepositoryProvider = Provider<ClientCardRepository>(
  (ref) => ClientCardRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final clientCardProvider = FutureProvider.autoDispose
    .family<ClientCard, String>(
      (ref, customer) => ref.watch(clientCardRepositoryProvider).card(customer),
    );

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final clientHistoryProvider = FutureProvider.autoDispose
    .family<List<ClientEvent>, String>(
      (ref, customer) =>
          ref.watch(clientCardRepositoryProvider).history(customer),
    );

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final toWriteProvider = FutureProvider.autoDispose<ToWrite>(
  (ref) => ref.watch(clientCardRepositoryProvider).todo(),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final dailySummaryProvider = FutureProvider.autoDispose<DailySummary>(
  (ref) => ref.watch(clientCardRepositoryProvider).summary(),
);

/// `korkem_manufacturing.api.customer_messages` — the customer's card,
/// «Кому написать» and «Итоги дня» (owner, 18.11.2026).
class ClientCardRepository {
  const ClientCardRepository(this._client);

  static const _base = 'korkem_manufacturing.api.customer_messages';

  final FrappeClient _client;

  Future<ClientCard> card(String customer) async => ClientCard.fromJson(
    _map(
      await _client.callMethod('$_base.card', params: {'customer': customer}),
    ),
  );

  /// One payment for all he owes: the oldest orders closed first.
  Future<
    ({
      List<({String order, int? number, double amount})> split,
      ClientCard card,
    })
  >
  pay(
    String customer, {
    required double amount,
    required String method,
    String? bank,
  }) async {
    final j = _map(
      await _client.callMethod(
        '$_base.pay',
        post: true,
        params: {
          'customer': customer,
          'amount': amount,
          'method': method,
          'bank': ?bank,
        },
      ),
    );
    return (
      split: [
        for (final x in j['split'] is List ? j['split'] as List : const [])
          if (x is Map)
            (
              order: '${x['order']}',
              number: x['number'] is num ? (x['number'] as num).toInt() : null,
              amount: x['amount'] is num
                  ? (x['amount'] as num).toDouble()
                  : 0.0,
            ),
      ],
      card: ClientCard.fromJson(
        j['card'] is Map
            ? Map<String, dynamic>.from(j['card'] as Map)
            : const <String, dynamic>{},
      ),
    );
  }

  /// The reminder of all he owes: his phone and the words.
  Future<({String? phone, String text})> debtText(String customer) async {
    final j = _map(
      await _client.callMethod(
        '$_base.debt_text',
        params: {'customer': customer},
      ),
    );
    final phone = '${j['phone'] ?? ''}';
    return (phone: phone.isEmpty ? null : phone, text: '${j['text'] ?? ''}');
  }

  /// The reminder was sent: the card after it.
  Future<ClientCard> reminded(String customer) async => ClientCard.fromJson(
    _map(
      await _client.callMethod(
        '$_base.reminded',
        post: true,
        params: {'customer': customer},
      ),
    ),
  );

  Future<List<ClientEvent>> history(String customer) async => _events(
    await _client.callMethod('$_base.history', params: {'customer': customer}),
  );

  Future<List<ClientEvent>> addNote(String customer, String text) async =>
      _events(
        await _client.callMethod(
          '$_base.add_note',
          post: true,
          params: {'customer': customer, 'text': text},
        ),
      );

  static List<ClientEvent> _events(Map<String, dynamic> response) => [
    for (final e
        in response['message'] is List ? response['message'] as List : const [])
      if (e is Map) ClientEvent.fromJson(Map<String, dynamic>.from(e)),
  ];

  Future<ToWrite> todo() async =>
      ToWrite.fromJson(_map(await _client.callMethod('$_base.todo')));

  /// The manager has sent it: the server remembers the day.
  Future<ToWrite> mark(
    ToWriteKind kind, {
    String? order,
    String? customer,
  }) async => ToWrite.fromJson(
    _map(
      await _client.callMethod(
        '$_base.mark',
        post: true,
        params: {
          'kind': kind.wire,
          'order': ?order,
          'customer': ?customer,
        },
      ),
    ),
  );

  /// One order's message: its customer's phone and the words.
  Future<ToWriteRow> textFor(
    String order, {
    ToWriteKind kind = ToWriteKind.ready,
  }) async => ToWriteRow.fromJson(
    _map(
      await _client.callMethod(
        '$_base.text_for',
        params: {'order': order, 'kind': kind.wire},
      ),
    ),
  );

  Future<Map<ToWriteKind, MessageTemplate>> templates() async =>
      _templates(_map(await _client.callMethod('$_base.templates')));

  Future<Map<ToWriteKind, MessageTemplate>> setTemplate(
    ToWriteKind kind,
    String text,
  ) async => _templates(
    _map(
      await _client.callMethod(
        '$_base.set_template',
        post: true,
        params: {'kind': kind.wire, 'text': text},
      ),
    ),
  );

  Future<DailySummary> summary() async => DailySummary.fromJson(
    _map(await _client.callMethod('$_base.summary_preview')),
  );

  Future<DailySummary> setSummary({
    bool? enabled,
    int? hour,
    bool? morning,
  }) async => DailySummary.fromJson(
    _map(
      await _client.callMethod(
        '$_base.summary_settings',
        post: true,
        params: {
          if (enabled != null) 'enabled': enabled ? '1' : '0',
          if (hour != null) 'hour': '$hour',
          if (morning != null) 'morning': morning ? '1' : '0',
        },
      ),
    ),
  );

  static Map<ToWriteKind, MessageTemplate> _templates(Map<String, dynamic> j) =>
      {
        for (final kind in ToWriteKind.values)
          if (j[kind.wire] is Map)
            kind: (
              text: '${(j[kind.wire] as Map)['text'] ?? ''}',
              byDefault: '${(j[kind.wire] as Map)['default'] ?? ''}',
            ),
      };

  static Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response;
    return raw is Map<String, dynamic> ? raw : const {};
  }
}
