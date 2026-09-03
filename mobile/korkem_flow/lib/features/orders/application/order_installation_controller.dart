import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/orders/data/order_installation_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_installation.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final orderInstallationProvider = FutureProvider.autoDispose
    .family<OrderInstallation, String>(
      (ref, salesOrder) => ref
          .watch(orderInstallationRepositoryProvider)
          .fetchInstallation(salesOrder),
    );

final orderInstallationActionsProvider =
    Provider<OrderInstallationActionsController>(
      OrderInstallationActionsController.new,
    );

class OrderInstallationActionsController {
  const OrderInstallationActionsController(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> schedule({
    required String salesOrder,
    required String installer,
    required String installOn,
  }) async {
    final repo = _ref.read(orderInstallationRepositoryProvider);
    final result = await repo.scheduleInstallation(
      salesOrder: salesOrder,
      installer: installer,
      installOn: installOn,
    );
    _ref.invalidate(orderInstallationProvider(salesOrder));
    return result;
  }

  Future<Map<String, dynamic>> complete({
    required String salesOrder,
    String? notes,
  }) async {
    final repo = _ref.read(orderInstallationRepositoryProvider);
    final result = await repo.completeInstallation(
      salesOrder: salesOrder,
      notes: notes,
    );
    _ref.invalidate(orderInstallationProvider(salesOrder));
    return result;
  }
}
