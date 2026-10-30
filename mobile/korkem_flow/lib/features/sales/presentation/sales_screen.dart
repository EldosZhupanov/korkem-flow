import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/features/customers/presentation/customers_screen.dart';
import 'package:korkem_flow/features/deals/presentation/deals_screen.dart';
import 'package:korkem_flow/features/leads/presentation/leads_screen.dart';
import 'package:korkem_flow/features/quotes/presentation/quotes_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Deals, Leads, Customers and Quotes under one destination.
///
/// Four bottom-bar entries for four views of the same pipeline would push the
/// bar well past the point where it stays scannable, and they are read
/// together anyway: a lead becomes a deal, a deal gets a quote, and the quote
/// belongs to a customer.
class SalesScreen extends StatelessWidget {
  const SalesScreen({this.tab = SalesTab.deals, super.key});

  final SalesTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScreen.tabbed(
      title: l10n.navSales,
      initialTab: tab.index,
      tabs: [
        AppTab(label: l10n.navDeals, view: const DealsScreen()),
        AppTab(label: l10n.navLeads, view: const LeadsScreen()),
        AppTab(label: l10n.navCustomers, view: const CustomersScreen()),
        AppTab(label: l10n.navQuotes, view: const QuotesScreen()),
      ],
    );
  }
}

/// The views of the pipeline, in the order they are shown.
///
/// Named rather than numbered because the sidebar links to one of them by
/// name in a URL — `/sales?tab=customers` survives a reorder of the tabs,
/// where `?tab=2` would quietly start opening a different screen.
enum SalesTab {
  deals,
  leads,
  customers,
  quotes;

  static const queryParameter = 'tab';

  /// Resolves a URL's `tab` value. Anything unrecognised — a stale link, a
  /// typo, a hand-edited URL — opens the pipeline rather than failing.
  static SalesTab fromName(String? name) =>
      SalesTab.values.where((tab) => tab.name == name).firstOrNull ??
      SalesTab.deals;
}
