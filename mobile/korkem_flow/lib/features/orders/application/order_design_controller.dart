import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/features/orders/data/order_design_repository.dart';
import 'package:korkem_flow/features/orders/domain/order_design.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final orderDesignProvider = FutureProvider.autoDispose
    .family<OrderDesign, String>(
      (ref, salesOrder) =>
          ref.watch(orderDesignRepositoryProvider).fetchDesign(salesOrder),
    );

final orderDesignActionsProvider = Provider<OrderDesignActionsController>(
  OrderDesignActionsController.new,
);

class OrderDesignActionsController {
  const OrderDesignActionsController(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> assign({
    required String salesOrder,
    required String designer,
    required String dueOn,
  }) async {
    final repo = _ref.read(orderDesignRepositoryProvider);
    final result = await repo.assignDesign(
      salesOrder: salesOrder,
      designer: designer,
      dueOn: dueOn,
    );
    _ref.invalidate(orderDesignProvider(salesOrder));
    return result;
  }

  Future<Map<String, dynamic>> deliver({
    required String salesOrder,
  }) async {
    final repo = _ref.read(orderDesignRepositoryProvider);
    final result = await repo.deliverDesign(salesOrder: salesOrder);
    _ref.invalidate(orderDesignProvider(salesOrder));
    return result;
  }

  Future<OrderDesignAttachment> attachFile({
    required String salesOrder,
    required String fileName,
    String? fileUrl,
    String? content,
  }) async {
    final repo = _ref.read(orderDesignRepositoryProvider);
    final result = await repo.attachFile(
      salesOrder: salesOrder,
      fileName: fileName,
      fileUrl: fileUrl,
      content: content,
    );
    _ref.invalidate(orderDesignProvider(salesOrder));
    return result;
  }
}
