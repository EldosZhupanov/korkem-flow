import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// One page of a list, plus what the UI needs to ask for the next.
@immutable
class PagedList<T> {
  const PagedList({
    this.items = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;

  bool get isEmpty => items.isEmpty;

  PagedList<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PagedList<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Offset pagination over a Frappe list endpoint.
///
/// Deals, Leads and Customers differ only in what they fetch, so the paging
/// rules — when to stop, what happens to loaded pages when the next one fails,
/// how a filter change resets the list — live here once. Three copies of this
/// logic would drift, and the failure mode of the drift is a list that silently
/// stops loading.
abstract class PagedListController<T> extends AsyncNotifier<PagedList<T>> {
  @protected
  int get pageSize => 20;

  /// Fetch one page. Implementations `ref.watch` their own filter state here,
  /// which is what makes a filter change reset pagination for free.
  ///
  /// They must `ref.watch` their **repository** too, not `ref.read` it. The
  /// repository depends on the authenticated client, so watching is what makes
  /// a list drop its contents when the session changes. Reading it left every
  /// screen showing the previous user's rows after a sign-out and sign-in.
  /// `ref.read` remains correct inside actions — those are one-shot commands,
  /// not dependencies.
  @protected
  Future<List<T>> fetchPage({required int offset, required int pageSize});

  @override
  Future<PagedList<T>> build() async {
    final items = await fetchPage(offset: 0, pageSize: pageSize);

    // A short page means the end. Asking for one more to be certain would cost
    // a round trip on every list in the app to learn nothing.
    return PagedList<T>(items: items, hasMore: items.length == pageSize);
  }

  /// Appends the next page. Safe to call repeatedly from a scroll listener: a
  /// no-op while a fetch is in flight or the list is exhausted.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final next = await fetchPage(
        offset: current.items.length,
        pageSize: pageSize,
      );

      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next],
          hasMore: next.length == pageSize,
          isLoadingMore: false,
        ),
      );
    } on Exception {
      // Keep the pages already loaded. Replacing a screenful of readable data
      // with an error because page four failed is a bad trade; the user can
      // still work, and pulling to refresh retries.
      state = AsyncData(current.copyWith(isLoadingMore: false, hasMore: false));
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}
