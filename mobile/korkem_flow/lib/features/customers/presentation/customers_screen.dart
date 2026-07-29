import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/customers/application/customers_controller.dart';
import 'package:korkem_flow/features/customers/domain/customer.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final search = ref.watch(customerSearchProvider);
    final controller = ref.read(customersControllerProvider.notifier);

    return CrmListSection(
      searchValue: search,
      onSearch: ref.read(customerSearchProvider.notifier).set,
      child: PagedListView<Customer>(
        state: ref.watch(customersControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, customer) => CustomerCard(
          customer: customer,
          // Tagged from the same route the tap opens. `customer.name` is the
          // display name and `customer.id` is the docname; tagging one end
          // with each does not fail, it just silently never flies.
          heroTag: Routes.heroTag(Routes.customer(customer.id)),
          onTap: () => context.push(Routes.customer(customer.id)),
        ),
        emptyView: (context) => ListEmptyView(
          icon: AppIcons.customer,
          title: l10n.customersEmpty,
          message: search != null
              ? l10n.searchNoResults(search)
              : l10n.customersEmptyBody,
          onRefresh: controller.refresh,
          onClearFilter: search == null
              ? null
              : () => ref.read(customerSearchProvider.notifier).set(null),
        ),
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({
    required this.customer,
    this.onTap,
    this.heroTag,
    super.key,
  });

  final Customer customer;
  final VoidCallback? onTap;

  /// Opt-in. A hero tag has to be unique across everything mounted at once, so
  /// only the list that owns the record claims one.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return EntityCard(
      heroTag: heroTag,
      title: customer.name,
      subtitle: customer.industry,
      onTap: onTap,
      metadata: [
        if (customer.territory != null)
          EntityMeta(icon: AppIcons.warehouse, label: customer.territory!),
        if (customer.employeeCount != null)
          EntityMeta(icon: AppIcons.profile, label: customer.employeeCount!),
      ],
    );
  }
}
