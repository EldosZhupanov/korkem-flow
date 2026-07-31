import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/dashboard/presentation/workload_bar.dart';

import '../../support/widget_harness.dart';

/// The dashboard's one chart, and the only place its data is really a ratio.
///
/// Overdue tasks are a subset of open tasks, so the proportion means
/// something: two of three is a bad week, two of forty is a Tuesday. The six
/// counts the endpoint returns have no such relationship to each other, which
/// is why there is no second chart.
void main() {
  Future<void> pump(WidgetTester tester, {int? total, int? overdue}) =>
      tester.pumpWidget(
        harness(WorkloadBar(total: total, overdue: overdue)),
      );

  testWidgets('reads "N of M", not "M of N"', (tester) async {
    await pump(tester, total: 7, overdue: 2);
    await tester.pumpAndSettle();

    // The bar drew the right fraction while the sentence said "7 of 2 are
    // overdue" — nonsense that renders cleanly and still parses as English,
    // so nothing but reading it catches it.
    expect(find.text('2 of 7 are overdue'), findsOneWidget);
  });

  testWidgets('fills to the overdue share', (tester) async {
    await pump(tester, total: 8, overdue: 2);
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.25, 0.001));
  });

  testWidgets('says nothing when there is nothing to say', (tester) async {
    // No tasks at all: an empty track under a zero is a chart of nothing.
    await pump(tester, total: 0, overdue: 0);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // A figure the signed-in role may not see is not a zero either.
    await pump(tester, overdue: 2);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
