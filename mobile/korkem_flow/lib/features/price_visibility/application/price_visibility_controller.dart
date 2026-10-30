import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/price_visibility/data/price_visibility_repository.dart';
import 'package:korkem_flow/features/price_visibility/domain/price_visibility.dart';

final priceVisibilityControllerProvider =
    AsyncNotifierProvider<PriceVisibilityController, PriceVisibility>(
      PriceVisibilityController.new,
    );

/// The administrator's switch, as the server last reported it.
class PriceVisibilityController extends AsyncNotifier<PriceVisibility> {
  @override
  Future<PriceVisibility> build() =>
      ref.watch(priceVisibilityRepositoryProvider).fetch();

  /// Flips the switch. On failure the previous state stays on screen and the
  /// error is rethrown for the caller to show — a switch that silently snaps
  /// back reads as "saved".
  Future<void> setFloorSeesPrices({required bool value}) async {
    final saved = await ref
        .read(priceVisibilityRepositoryProvider)
        .save(floorSeesPrices: value);
    state = AsyncValue.data(saved);
  }
}
