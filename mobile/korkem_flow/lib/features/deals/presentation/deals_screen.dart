import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});

  Future<void> _openFilter(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final catalog =
        ref.read(dealStatusCatalogProvider).value ?? StatusCatalog.empty;

    final choice = await showFilterSheet<String>(
      context: context,
      title: l10n.actionFilter,
      current: ref.read(dealFilterProvider).status,
      options: [
        // Options come from the site's own configured stages, in the order the
        // administrator arranged them — not from a list baked into this build.
        for (final status in catalog.statuses)
          FilterOption(value: status.name, label: status.name),
      ],
    );

    if (choice == null) return;
    ref.read(dealFilterProvider.notifier).setStatus(choice.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(dealFilterProvider);
    final controller = ref.read(dealsControllerProvider.notifier);

    return CrmListSection(
      searchValue: filter.search,
      onSearch: (value) => ref
          .read(dealFilterProvider.notifier)
          .setSearch(value.isEmpty ? null : value),
      isFiltered: filter.status != null,
      onFilter: () => _openFilter(context, ref),
      child: PagedListView<Deal>(
        state: ref.watch(dealsControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, deal) => DealCard(
          deal: deal,
          onTap: () => context.push(Routes.deal(deal.id)),
        ),
        emptyView: (context) => EmptyView(
          icon: AppIcons.deal,
          // Distinguishes "no deals exist" from "none are yours". Frappe CRM
          // scopes CRM Deal to the owner and assignees, so a new user's list is
          // legitimately empty — and a generic "nothing here" reads as a bug.
          title: filter.status == null && filter.search == null
              ? l10n.dealsEmptyAssigned
              : null,
          message: filter.search != null
              ? l10n.searchNoResults(filter.search!)
              : (filter.status == null ? l10n.dealsEmptyAssignedBody : null),
          actionLabel: filter.status == null && filter.search == null
              ? null
              : l10n.actionClearFilter,
          onAction: filter.status == null && filter.search == null
              ? null
              : ref.read(dealFilterProvider.notifier).clear,
        ),
      ),
    );
  }
}

/// A deal rendered with the shared [EntityCard] shape.
class DealCard extends ConsumerWidget {
  const DealCard({required this.deal, this.onTap, super.key});

  final Deal deal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog =
        ref.watch(dealStatusCatalogProvider).value ?? StatusCatalog.empty;
    final status = catalog.resolve(deal.status);

    return EntityCard(
      title: deal.organization,
      subtitle: deal.nextStep,
      // The stage name is shown exactly as configured. Translating it would
      // detach the label from the value the backend stores and the Desk shows.
      statusLabel: status.name.isEmpty ? null : status.name,
      statusIntent: status.name.isEmpty ? null : status.intent,
      onTap: onTap,
      metadata: [
        if (deal.mobileNo != null)
          EntityMeta(icon: AppIcons.call, label: deal.mobileNo!),
      ],
    );
  }
}
