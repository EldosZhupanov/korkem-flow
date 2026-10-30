import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/quotes/data/quote_repository.dart';
import 'package:korkem_flow/features/quotes/domain/quote.dart';
import 'package:meta/meta.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => QuoteRepository(ref.watch(frappeClientProvider)),
);

@immutable
class QuoteFilter {
  const QuoteFilter({this.status, this.search});

  final QuoteStatus? status;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is QuoteFilter && other.status == status && other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

final quoteFilterProvider = NotifierProvider<QuoteFilterNotifier, QuoteFilter>(
  QuoteFilterNotifier.new,
);

class QuoteFilterNotifier extends Notifier<QuoteFilter> {
  @override
  QuoteFilter build() => const QuoteFilter();

  void setStatus(QuoteStatus? status) =>
      state = QuoteFilter(status: status, search: state.search);

  void setSearch(String? search) =>
      state = QuoteFilter(status: state.status, search: search);

  void clear() => state = const QuoteFilter();
}

final quotesControllerProvider =
    AsyncNotifierProvider<QuotesController, PagedList<Quote>>(
      QuotesController.new,
    );

class QuotesController extends PagedListController<Quote> {
  @override
  Future<List<Quote>> fetchPage({
    required int offset,
    required int pageSize,
  }) {
    final filter = ref.watch(quoteFilterProvider);

    return ref
        .watch(quoteRepositoryProvider)
        .fetchPage(
          pageSize: pageSize,
          offset: offset,
          status: filter.status,
          search: filter.search,
        );
  }
}
