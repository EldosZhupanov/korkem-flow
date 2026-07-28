import 'package:flutter/material.dart';
import 'package:korkem_flow/features/customers/presentation/customers_screen.dart';
import 'package:korkem_flow/features/deals/presentation/deals_screen.dart';
import 'package:korkem_flow/features/leads/presentation/leads_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Deals, Leads and Customers under one tab.
///
/// Three bottom-bar destinations for three views of the same pipeline would
/// push the bar past the point where it stays scannable, and they are read
/// together anyway: a lead becomes a deal, a deal belongs to a customer.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navSales),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.navDeals),
              Tab(text: l10n.navLeads),
              Tab(text: l10n.navCustomers),
            ],
          ),
        ),
        body: const TabBarView(
          children: [DealsScreen(), LeadsScreen(), CustomersScreen()],
        ),
      ),
    );
  }
}
