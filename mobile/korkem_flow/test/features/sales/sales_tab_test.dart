import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/sales/presentation/sales_screen.dart';

import '../../support/widget_harness.dart';

/// Opening Sales on a chosen tab, which is how the sidebar's Clients row works.
void main() {
  test('the Clients route points at Sales, on the Customers tab', () {
    final uri = Uri.parse(Routes.clients);

    expect(uri.path, Routes.sales);
    expect(
      SalesTab.fromName(uri.queryParameters[SalesTab.queryParameter]),
      SalesTab.customers,
    );
  });

  test('an unknown or missing tab opens the pipeline rather than failing', () {
    // A stale link, a typo, a hand-edited URL. None of these should be an
    // error screen.
    expect(SalesTab.fromName(null), SalesTab.deals);
    expect(SalesTab.fromName(''), SalesTab.deals);
    expect(SalesTab.fromName('nonsense'), SalesTab.deals);
  });

  test('tab names are stable identifiers, not positions', () {
    // The URL carries `customers`, so reordering the tabs moves the tab
    // without silently re-pointing the link at a different screen.
    expect(SalesTab.customers.name, 'customers');
    expect(SalesTab.fromName('customers'), SalesTab.customers);
  });

  testWidgets('AppScreen.tabbed opens on the tab it is given', (tester) async {
    await tester.pumpWidget(
      harness(
        const AppScreen.tabbed(
          title: 'Sales',
          initialTab: 2,
          tabs: [
            AppTab(label: 'Deals', view: Text('deals view')),
            AppTab(label: 'Leads', view: Text('leads view')),
            AppTab(label: 'Customers', view: Text('customers view')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('customers view'), findsOneWidget);
    expect(find.text('deals view'), findsNothing);
  });

  testWidgets('an out-of-range tab is clamped, not thrown', (tester) async {
    // Cheap insurance: the index arrives from a URL, and `DefaultTabController`
    // asserts on an initialIndex past the end.
    await tester.pumpWidget(
      harness(
        const AppScreen.tabbed(
          title: 'Sales',
          initialTab: 99,
          tabs: [
            AppTab(label: 'Deals', view: Text('deals view')),
            AppTab(label: 'Leads', view: Text('leads view')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('leads view'), findsOneWidget);
  });
}
