import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/facade_prices/data/facade_price_repository.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_price_table.dart';

final facadePriceControllerProvider =
    AsyncNotifierProvider<FacadePriceController, FacadePriceTable>(
      FacadePriceController.new,
    );

class FacadePriceController extends AsyncNotifier<FacadePriceTable> {
  @override
  Future<FacadePriceTable> build() =>
      ref.watch(facadePriceRepositoryProvider).fetch();

  /// On failure the table on screen stays as it was and the error is
  /// rethrown for the caller to show.
  Future<void> save({
    required String milling,
    required String finish,
    required double pricePerM2,
    bool enabled = true,
  }) async {
    final table = await ref
        .read(facadePriceRepositoryProvider)
        .save(
          milling: milling,
          finish: finish,
          pricePerM2: pricePerM2,
          enabled: enabled,
        );
    state = AsyncValue.data(table);
  }
}
