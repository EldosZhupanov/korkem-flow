import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/crm/status_catalog_providers.dart';
import 'package:korkem_flow/core/crm/status_catalog_repository.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/deals/data/deal_repository.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:meta/meta.dart';

final dealRepositoryProvider = Provider<DealRepository>(
  (ref) => DealRepository(ref.watch(frappeClientProvider)),
);

/// The stages configured for deals on this site.
final dealStatusCatalogProvider = Provider<AsyncValue<StatusCatalog>>(
  (ref) => ref.watch(
    statusCatalogProvider(StatusCatalogRepository.dealStatusDoctype),
  ),
);

/// Active list filters. Kept separate from the page state so changing a filter
/// resets pagination without the controller having to know about the UI.
@immutable
class DealFilter {
  const DealFilter({this.status, this.search});

  /// The stored stage value, not an enum — see [CrmStatus].
  final String? status;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is DealFilter && other.status == status && other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

final dealFilterProvider = NotifierProvider<DealFilterNotifier, DealFilter>(
  DealFilterNotifier.new,
);

class DealFilterNotifier extends Notifier<DealFilter> {
  @override
  DealFilter build() => const DealFilter();

  void setStatus(String? status) =>
      state = DealFilter(status: status, search: state.search);

  void setSearch(String? search) =>
      state = DealFilter(status: state.status, search: search);

  void clear() => state = const DealFilter();
}

final dealsControllerProvider =
    AsyncNotifierProvider<DealsController, PagedList<Deal>>(
      DealsController.new,
    );

class DealsController extends PagedListController<Deal> {
  @override
  Future<List<Deal>> fetchPage({
    required int offset,
    required int pageSize,
  }) {
    // Watched, not read: a filter change rebuilds the controller, which resets
    // pagination for free.
    final filter = ref.watch(dealFilterProvider);

    return ref
        .read(dealRepositoryProvider)
        .fetchPage(
          pageSize: pageSize,
          offset: offset,
          status: filter.status,
          search: filter.search,
        );
  }

  /// Optimistic stage change: the row updates immediately and rolls back if the
  /// backend rejects it.
  Future<void> changeStatus(Deal deal, String status) async {
    final current = state.value;
    if (current == null) return;

    final index = current.items.indexWhere((d) => d.id == deal.id);
    if (index < 0) return;

    final optimistic = [...current.items];
    optimistic[index] = Deal(
      id: deal.id,
      organization: deal.organization,
      status: status,
      nextStep: deal.nextStep,
      mobileNo: deal.mobileNo,
      modified: deal.modified,
    );
    state = AsyncData(current.copyWith(items: optimistic));

    try {
      await ref.read(dealRepositoryProvider).updateStatus(deal.id, status);
    } on Exception {
      state = AsyncData(current);
      rethrow;
    }
  }
}
