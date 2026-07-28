import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/crm_list_section.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
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
        itemBuilder: (context, customer) => CustomerCard(customer: customer),
        emptyView: (context) => EmptyView(
          icon: AppIcons.customer,
          title: l10n.customersEmpty,
          message: search != null
              ? l10n.searchNoResults(search)
              : l10n.customersEmptyBody,
        ),
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({required this.customer, this.onTap, super.key});

  final Customer customer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return EntityCard(
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
