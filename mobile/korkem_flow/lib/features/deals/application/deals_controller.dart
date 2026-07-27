import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/features/deals/data/deal_repository.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:meta/meta.dart';

final dealRepositoryProvider = Provider<DealRepository>(
  (ref) => DealRepository(ref.watch(frappeClientProvider)),
);

/// Active list filters. Kept separate from the page state so changing a filter
/// resets pagination without the controller having to know about the UI.
@immutable
class DealFilter {
  const DealFilter({this.status, this.search});

  final DealStatus? status;
  final String? search;

  DealFilter copyWith({
    DealStatus? status,
    String? search,
    bool clear = false,
  }) {
    if (clear) return const DealFilter();
    return DealFilter(
      status: status ?? this.status,
      search: search ?? this.search,
    );
  }

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

  void setStatus(DealStatus? status) =>
      state = DealFilter(status: status, search: state.search);

  void setSearch(String? search) =>
      state = DealFilter(status: state.status, search: search);

  void clear() => state = const DealFilter();
}

/// Paginated list state.
@immutable
class DealsPage {
  const DealsPage({
    this.deals = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<Deal> deals;
  final bool hasMore;
  final bool isLoadingMore;

  DealsPage copyWith({
    List<Deal>? deals,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return DealsPage(
      deals: deals ?? this.deals,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final dealsControllerProvider =
    AsyncNotifierProvider<DealsController, DealsPage>(DealsController.new);

class DealsController extends AsyncNotifier<DealsPage> {
  static const _pageSize = 20;

  @override
  Future<DealsPage> build() async {
    // Re-runs whenever the filter changes, which resets pagination for free.
    final filter = ref.watch(dealFilterProvider);
    final deals = await ref
        .read(dealRepositoryProvider)
        .fetchPage(
          pageSize: _pageSize,
          status: filter.status,
          search: filter.search,
        );

    return DealsPage(deals: deals, hasMore: deals.length == _pageSize);
  }

  /// Appends the next page. Safe to call repeatedly from a scroll listener:
  /// it is a no-op while a fetch is in flight or the list is exhausted.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final filter = ref.read(dealFilterProvider);

    try {
      final next = await ref
          .read(dealRepositoryProvider)
          .fetchPage(
            pageSize: _pageSize,
            offset: current.deals.length,
            status: filter.status,
            search: filter.search,
          );

      state = AsyncData(
        current.copyWith(
          deals: [...current.deals, ...next],
          hasMore: next.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } on Exception {
      // Keep the pages already loaded; surface the failure without discarding
      // data the user can still read.
      state = AsyncData(current.copyWith(isLoadingMore: false, hasMore: false));
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// Optimistic status change: the row updates immediately and rolls back if
  /// the backend rejects it.
  Future<void> changeStatus(Deal deal, DealStatus status) async {
    final current = state.value;
    if (current == null) return;

    final index = current.deals.indexWhere((d) => d.id == deal.id);
    if (index < 0) return;

    final optimistic = [...current.deals];
    optimistic[index] = Deal(
      id: deal.id,
      organization: deal.organization,
      status: status,
      nextStep: deal.nextStep,
      mobileNo: deal.mobileNo,
      modified: DateTime.now(),
    );
    state = AsyncData(current.copyWith(deals: optimistic));

    try {
      await ref.read(dealRepositoryProvider).updateStatus(deal.id, status);
    } on Exception {
      state = AsyncData(current);
      rethrow;
    }
  }
}
