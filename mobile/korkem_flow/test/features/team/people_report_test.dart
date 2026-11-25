import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/features/team/presentation/people_screen.dart';
import 'package:korkem_flow/features/team/presentation/person_card_screen.dart';

import '../../design/fake_people.dart';
import '../../support/widget_harness.dart';

void main() {
  late FakePeople repo;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    repo = FakePeople();
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [peopleReportRepositoryProvider.overrideWithValue(repo)],
        child: harness(screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('a week runs Monday to Sunday, a month to its last day', () {
    final wed = DateTime(2026, 11, 25);
    expect(peopleSpanOf(PeopleSpan.week, wed), (
      DateTime(2026, 11, 23),
      DateTime(2026, 11, 29),
    ));
    expect(peopleSpanOf(PeopleSpan.month, wed), (
      DateTime(2026, 11),
      DateTime(2026, 11, 30),
    ));
    expect(peopleShift(PeopleSpan.week, wed, -1), DateTime(2026, 11, 18));
  });

  testWidgets('everyone for the month; the period moves and changes', (
    tester,
  ) async {
    await pump(tester, PeopleScreen(today: DateTime(2026, 11, 25)));
    expect(repo.reports.single, (span: PeopleSpan.month, day: '2026-11-25'));
    expect(find.byKey(const ValueKey('figure:ppl:total:left')), findsOne);
    expect(find.byKey(const ValueKey('ppl:person:HR-EMP-00001')), findsOne);
    expect(find.byKey(const ValueKey('ppl:person:HR-EMP-00002')), findsOne);
    expect(find.text('Ерлан Сапаров'), findsOne);
    // This month is not over: nothing after it to look at.
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('ppl:next')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('ppl:prev')));
    await tester.pumpAndSettle();
    expect(repo.reports.last, (span: PeopleSpan.month, day: '2026-10-01'));
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(repo.reports.last, (span: PeopleSpan.week, day: '2026-10-01'));
  });

  testWidgets('a card: what he did, earned, took and was fined', (
    tester,
  ) async {
    await pump(
      tester,
      PersonCardScreen(
        employee: 'HR-EMP-00001',
        today: DateTime(2026, 11, 25),
      ),
    );
    expect(repo.cards.single.employee, 'HR-EMP-00001');
    expect(find.byKey(const ValueKey('figure:card:earned')), findsOne);
    expect(find.byKey(const ValueKey('figure:card:left')), findsOne);
    expect(find.byKey(const ValueKey('card:days')), findsOne);
    expect(find.byKey(const ValueKey('card:adj:1')), findsOne);
    expect(find.textContaining('брак: скол'), findsOne);
    expect(find.byKey(const ValueKey('card:work:0')), findsOne);
    expect(find.byKey(const ValueKey('card:noLogin')), findsNothing);
  });

  testWidgets('no login: the volume, and why there is no money', (
    tester,
  ) async {
    await pump(
      tester,
      PersonCardScreen(
        employee: 'HR-EMP-00002',
        today: DateTime(2026, 11, 25),
      ),
    );
    expect(find.byKey(const ValueKey('card:noLogin')), findsOne);
    expect(find.byKey(const ValueKey('figure:card:earned')), findsNothing);
    expect(find.byKey(const ValueKey('figure:card:m2')), findsOne);
  });
}
