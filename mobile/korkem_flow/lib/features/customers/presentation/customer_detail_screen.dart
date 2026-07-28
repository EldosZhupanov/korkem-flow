import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/detail_view.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/features/customers/application/customers_controller.dart';
import 'package:korkem_flow/features/customers/domain/customer.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:korkem_flow/features/deals/presentation/deals_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// ignore: specify_nonobvious_property_types — the generics are right there.
final customerDetailProvider = FutureProvider.family<Customer, String>(
  (ref, id) => ref.watch(customerRepositoryProvider).fetchOne(id),
);

/// The deals belonging to one organisation.
///
/// A separate request rather than a field on the customer: `CRM Organization`
/// holds no back-reference, and this is the question a salesperson opening a
/// customer actually has.
// ignore: specify_nonobvious_property_types — the generics are right there.
final customerDealsProvider = FutureProvider.family<List<Deal>, String>(
  (
    ref,
    id,
  ) => ref.watch(dealRepositoryProvider).fetchForOrganization(id),
);

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    return DetailScaffold<Customer>(
      state: ref.watch(customerDetailProvider(id)),
      onRefresh: () async {
        ref
          ..invalidate(customerDetailProvider(id))
          ..invalidate(customerDealsProvider(id));
      },
      builder: (context, customer) {
        final money = NumberFormat.simpleCurrency(
          locale: locale,
          name: customer.currency,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailHeader(title: customer.name, subtitle: customer.industry),

            DetailActions(
              children: [
                ContactAction(
                  icon: AppIcons.info,
                  label: l10n.fieldWebsite,
                  onPressed: customer.website == null
                      ? null
                      : () => ContactActions.openWebsite(customer.website),
                ),
              ],
            ),

            DetailSection(
              label: l10n.detailCompany,
              fields: [
                DetailField(
                  icon: AppIcons.item,
                  label: l10n.fieldIndustry,
                  value: customer.industry,
                ),
                DetailField(
                  icon: AppIcons.warehouse,
                  label: l10n.fieldTerritory,
                  value: customer.territory,
                ),
                DetailField(
                  icon: AppIcons.profile,
                  label: l10n.fieldEmployees,
                  value: customer.employeeCount,
                ),
                DetailField(
                  icon: AppIcons.quote,
                  label: l10n.fieldRevenue,
                  // Frappe stores an unset Currency as 0, not null, so a zero
                  // here means "not recorded" and is not worth a row.
                  value:
                      customer.annualRevenue == null ||
                          customer.annualRevenue == 0
                      ? null
                      : money.format(customer.annualRevenue),
                ),
                DetailField(
                  icon: AppIcons.refresh,
                  label: l10n.fieldUpdated,
                  value: customer.modified == null
                      ? null
                      : DateFormat.yMMMd(
                          locale,
                        ).add_Hm().format(customer.modified!),
                ),
              ],
            ),

            SectionLabel(l10n.navDeals),
            switch (ref.watch(customerDealsProvider(id))) {
              AsyncData(:final value) when value.isEmpty => DetailEmpty(
                message: l10n.dealsEmptyAssignedBody,
              ),
              AsyncData(:final value) => Column(
                children: [
                  for (final deal in value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DealCard(deal: deal),
                    ),
                ],
              ),
              AsyncError() => DetailEmpty(message: l10n.errorGeneric),
              _ => const DetailEmpty(message: '…'),
            },
          ],
        );
      },
    );
  }
}
