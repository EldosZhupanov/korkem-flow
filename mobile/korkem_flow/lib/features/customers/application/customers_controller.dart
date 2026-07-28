import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/customers/data/customer_repository.dart';
import 'package:korkem_flow/features/customers/domain/customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(frappeClientProvider)),
);

final customerSearchProvider =
    NotifierProvider<CustomerSearchNotifier, String?>(
      CustomerSearchNotifier.new,
    );

class CustomerSearchNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) =>
      state = (value == null || value.isEmpty) ? null : value;
}

final customersControllerProvider =
    AsyncNotifierProvider<CustomersController, PagedList<Customer>>(
      CustomersController.new,
    );

class CustomersController extends PagedListController<Customer> {
  @override
  Future<List<Customer>> fetchPage({
    required int offset,
    required int pageSize,
  }) {
    final search = ref.watch(customerSearchProvider);

    return ref
        .read(customerRepositoryProvider)
        .fetchPage(pageSize: pageSize, offset: offset, search: search);
  }
}
