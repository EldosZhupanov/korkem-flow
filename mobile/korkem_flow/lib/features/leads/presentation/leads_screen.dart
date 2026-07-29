import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/leads/application/leads_controller.dart';
import 'package:korkem_flow/features/leads/domain/lead.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  Future<void> _openFilter(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final catalog =
        ref.read(leadStatusCatalogProvider).value ?? StatusCatalog.empty;

    final choice = await showFilterSheet<String>(
      context: context,
      title: l10n.actionFilter,
      current: ref.read(leadFilterProvider).status,
      options: [
        for (final status in catalog.statuses)
          FilterOption(value: status.name, label: status.name),
      ],
    );

    if (choice == null) return;
    ref.read(leadFilterProvider.notifier).setStatus(choice.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(leadFilterProvider);
    final controller = ref.read(leadsControllerProvider.notifier);

    return CrmListSection(
      searchValue: filter.search,
      onSearch: (value) => ref
          .read(leadFilterProvider.notifier)
          .setSearch(value.isEmpty ? null : value),
      isFiltered: filter.status != null,
      onFilter: () => _openFilter(context, ref),
      child: PagedListView<Lead>(
        state: ref.watch(leadsControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, lead) => LeadCard(
          lead: lead,
          heroTag: Routes.heroTag(Routes.lead(lead.id)),
          onTap: () => context.push(Routes.lead(lead.id)),
        ),
        emptyView: (context) => ListEmptyView(
          icon: AppIcons.lead,
          title: l10n.leadsEmpty,
          // A status filter and a search fail differently, and saying "new
          // ones will appear here" to someone who just filtered to a status
          // with no records blames the data for the user's own choice.
          message: switch (filter) {
            _ when filter.search != null => l10n.searchNoResults(
              filter.search!,
            ),
            _ when filter.status != null => l10n.filterNoResults,
            _ => l10n.leadsEmptyBody,
          },
          onRefresh: controller.refresh,
          onClearFilter: filter.status == null && filter.search == null
              ? null
              : ref.read(leadFilterProvider.notifier).clear,
        ),
      ),
    );
  }
}

class LeadCard extends ConsumerWidget {
  const LeadCard({required this.lead, this.onTap, this.heroTag, super.key});

  final Lead lead;
  final VoidCallback? onTap;

  /// Opt-in. A hero tag has to be unique across everything mounted at once, so
  /// only the list that owns the record claims one.
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog =
        ref.watch(leadStatusCatalogProvider).value ?? StatusCatalog.empty;
    final status = catalog.resolve(lead.status);

    return EntityCard(
      heroTag: heroTag,
      title: lead.displayName,
      // Only when it adds something: for a lead captured with just a company
      // name, displayName already *is* the organisation.
      subtitle: lead.organization == lead.displayName
          ? null
          : lead.organization,
      statusLabel: lead.converted
          ? l10n.leadConverted
          : (status.name.isEmpty ? null : status.name),
      statusIntent: lead.converted ? StatusIntent.success : status.intent,
      onTap: onTap,
      metadata: [
        if (lead.mobileNo != null)
          EntityMeta(icon: AppIcons.call, label: lead.mobileNo!),
        if (lead.source != null)
          EntityMeta(icon: AppIcons.conversation, label: lead.source!),
      ],
    );
  }
}
