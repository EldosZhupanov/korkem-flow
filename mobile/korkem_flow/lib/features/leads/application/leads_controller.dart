import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/crm/status_catalog_providers.dart';
import 'package:korkem_flow/core/crm/status_catalog_repository.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/leads/data/lead_repository.dart';
import 'package:korkem_flow/features/leads/domain/lead.dart';
import 'package:meta/meta.dart';

final leadRepositoryProvider = Provider<LeadRepository>(
  (ref) => LeadRepository(ref.watch(frappeClientProvider)),
);

/// The stages configured for leads on this site.
final leadStatusCatalogProvider = Provider<AsyncValue<StatusCatalog>>(
  (ref) => ref.watch(
    statusCatalogProvider(StatusCatalogRepository.leadStatusDoctype),
  ),
);

@immutable
class LeadFilter {
  const LeadFilter({this.status, this.search});

  /// The stored stage value, not an enum — see [CrmStatus].
  final String? status;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is LeadFilter && other.status == status && other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

final leadFilterProvider = NotifierProvider<LeadFilterNotifier, LeadFilter>(
  LeadFilterNotifier.new,
);

class LeadFilterNotifier extends Notifier<LeadFilter> {
  @override
  LeadFilter build() => const LeadFilter();

  void setStatus(String? status) =>
      state = LeadFilter(status: status, search: state.search);

  void setSearch(String? search) =>
      state = LeadFilter(status: state.status, search: search);

  void clear() => state = const LeadFilter();
}

final leadsControllerProvider =
    AsyncNotifierProvider<LeadsController, PagedList<Lead>>(
      LeadsController.new,
    );

class LeadsController extends PagedListController<Lead> {
  @override
  Future<List<Lead>> fetchPage({
    required int offset,
    required int pageSize,
  }) {
    // Watched, not read: changing a filter rebuilds the controller, which
    // resets pagination without the UI having to say so.
    final filter = ref.watch(leadFilterProvider);

    return ref
        .watch(leadRepositoryProvider)
        .fetchPage(
          pageSize: pageSize,
          offset: offset,
          status: filter.status,
          search: filter.search,
        );
  }
}
