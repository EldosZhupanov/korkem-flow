import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/offcuts/domain/offcut.dart';

final offcutRepositoryProvider = Provider<OffcutRepository>(
  (ref) => OffcutRepository(ref.watch(frappeClientProvider)),
);

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final offcutShelfProvider = FutureProvider.autoDispose<OffcutShelf>(
  (ref) => ref.watch(offcutRepositoryProvider).shelf(),
);

// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final offcutSuggestionProvider = FutureProvider.autoDispose
    .family<OffcutSuggestion, String>(
      (ref, order) => ref.watch(offcutRepositoryProvider).suggest(order),
    );

/// `korkem_manufacturing.api.offcut_stock` — offcuts on the shelf and the
/// parts of an order they hold (owner, 18.11.2026).
class OffcutRepository {
  const OffcutRepository(this._client);

  static const _base = 'korkem_manufacturing.api.offcut_stock';

  final FrappeClient _client;

  Future<OffcutShelf> shelf() async =>
      OffcutShelf.fromJson(_map(await _client.callMethod('$_base.listing')));

  Future<OffcutShelf> add({
    required int thicknessMm,
    required int lengthMm,
    required int widthMm,
    String? cell,
    String? note,
  }) async => OffcutShelf.fromJson(
    _map(
      await _client.callMethod(
        '$_base.add',
        post: true,
        params: {
          'thickness_mm': thicknessMm,
          'length_mm': lengthMm,
          'width_mm': widthMm,
          'cell': ?cell,
          'note': ?note,
        },
      ),
    ),
  );

  /// Taken from the shelf into work.
  Future<OffcutShelf> use(String offcut) async => OffcutShelf.fromJson(
    _map(
      await _client.callMethod(
        '$_base.use',
        post: true,
        params: {'offcut': offcut},
      ),
    ),
  );

  Future<OffcutShelf> scrap(String offcut) async => OffcutShelf.fromJson(
    _map(
      await _client.callMethod(
        '$_base.scrap',
        post: true,
        params: {'offcut': offcut},
      ),
    ),
  );

  Future<OffcutSuggestion> suggest(String order) async =>
      OffcutSuggestion.fromJson(
        _map(
          await _client.callMethod(
            '$_base.suggest',
            params: {'order': order},
          ),
        ),
      );

  /// «Взять»: the offered offcut into the order.
  Future<OffcutSuggestion> take(String offcut, String order) async =>
      OffcutSuggestion.fromJson(
        _map(
          await _client.callMethod(
            '$_base.take',
            post: true,
            params: {'offcut': offcut, 'order': order},
          ),
        ),
      );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по обрезкам.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
