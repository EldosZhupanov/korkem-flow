import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/quotes/application/quotes_controller.dart';
import 'package:korkem_flow/features/quotes/domain/quote.dart';
import 'package:korkem_flow/features/quotes/presentation/quote_status_label.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  Future<void> _openFilter(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final choice = await showFilterSheet<QuoteStatus>(
      context: context,
      title: l10n.actionFilter,
      current: ref.read(quoteFilterProvider).status,
      options: [
        for (final status in QuoteStatus.values)
          FilterOption(value: status, label: status.label(l10n)),
      ],
    );

    if (choice == null) return;
    ref.read(quoteFilterProvider.notifier).setStatus(choice.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(quoteFilterProvider);
    final controller = ref.read(quotesControllerProvider.notifier);

    return CrmListSection(
      searchValue: filter.search,
      onSearch: (value) => ref
          .read(quoteFilterProvider.notifier)
          .setSearch(value.isEmpty ? null : value),
      isFiltered: filter.status != null,
      onFilter: () => _openFilter(context, ref),
      child: PagedListView<Quote>(
        state: ref.watch(quotesControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, quote) => QuoteCard(quote: quote),
        emptyView: (context) => ListEmptyView(
          icon: AppIcons.quote,
          title: l10n.quotesEmpty,
          // A status filter and a search fail differently, and saying "new
          // ones will appear here" to someone who just filtered to a status
          // with no records blames the data for the user's own choice.
          message: switch (filter) {
            _ when filter.search != null => l10n.searchNoResults(
              filter.search!,
            ),
            _ when filter.status != null => l10n.filterNoResults,
            _ => l10n.quotesEmptyBody,
          },
          onRefresh: controller.refresh,
          onClearFilter: filter.status == null && filter.search == null
              ? null
              : ref.read(quoteFilterProvider.notifier).clear,
        ),
      ),
    );
  }
}

class QuoteCard extends ConsumerWidget {
  const QuoteCard({required this.quote, this.onTap, super.key});

  final Quote quote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.watch(clockProvider)();
    final expiring = quote.expiresSoon(now);
    final money = NumberFormat.simpleCurrency(
      locale: locale,
      name: quote.currency,
    );

    return EntityCard(
      title: quote.displayName,
      subtitle: quote.id,
      // A lapsed validity outranks the stored status: ERPNext only rewrites
      // `status` to Expired on a scheduled job, so a quote can read "Open"
      // for hours after it stopped being one.
      statusLabel: quote.isExpiredAt(now)
          ? l10n.qExpired
          : quote.status.label(l10n),
      statusIntent: quote.isExpiredAt(now)
          ? StatusIntent.neutral
          : quote.status.intent,
      onTap: onTap,
      metadata: [
        if (quote.grandTotal != null)
          EntityMeta(
            icon: AppIcons.quote,
            label: money.format(quote.grandTotal),
          ),
        if (quote.validTill != null)
          EntityMeta(
            icon: AppIcons.schedule,
            label:
                '${expiring ? l10n.quoteExpiredSoon : l10n.fieldValidTill}: '
                '${DateFormat.yMMMd(locale).format(quote.validTill!)}',
          ),
      ],
    );
  }
}
