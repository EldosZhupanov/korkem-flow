import 'package:flutter/material.dart';
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
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navSales),
          bottom: TabBar(
            // Scrollable: four Russian labels do not fit a phone width evenly,
            // and squeezing them truncates every one of them.
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.navDeals),
              Tab(text: l10n.navLeads),
              Tab(text: l10n.navCustomers),
              Tab(text: l10n.navQuotes),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DealsScreen(),
            LeadsScreen(),
            CustomersScreen(),
            QuotesScreen(),
          ],
        ),
      ),
    );
  }
}
