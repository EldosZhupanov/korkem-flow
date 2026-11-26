import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';
import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/features/team/presentation/people_screen.dart';
import 'package:korkem_flow/features/team/presentation/person_card_screen.dart';

import '../../design/fake_people.dart';
import '../../support/widget_harness.dart';

class _FakePay implements PieceWorkRepository {
  final added = <(String, String, double, String)>[];
  final approved = <String>[];
  final paidOut = <(String, PayPeriod)>[];

  @override
  Future<PayAdjustment> addAdjustment({
    required String employee,
    required String kind,
    required double amount,
    required String reason,
  }) async {
    added.add((employee, kind, amount, reason));
    return PayAdjustment.fromJson({
      'adjustment': 'PAY-ADJ-00099',
      'employee': employee,
      'kind': kind,
      'amount': amount,
      'reason': reason,
      'status': 'Approved',
    });
  }

  @override
  Future<void> approveAdjustment(String adjustment) async =>
      approved.add(adjustment);

  @override
  Future<void> markPaid(String employee, PayPeriod period) async =>
      paidOut.add((employee, period));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePeople repo;
  late _FakePay pay;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    repo = FakePeople();
    pay = _FakePay();
    tester.view
      ..physicalSize = const Size(1400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          peopleReportRepositoryProvider.overrideWithValue(repo),
          teamPeopleProvider.overrideWith((ref) async => fakeTeam),
          pieceWorkRepositoryProvider.overrideWithValue(pay),
        ],
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
    await pump(
      tester,
      PeopleScreen(today: DateTime(2026, 11, 25), tab: PeopleTab.work),
    );
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
    // His posts and what happened to them; the team's editor may let him go.
    expect(find.byKey(const ValueKey('card:post:cut.cutter')), findsOne);
    expect(find.byKey(const ValueKey('card:event:2')), findsOne);
    expect(find.byKey(const ValueKey('card:dismiss')), findsOne);
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

  // --- «Деньги» (owner, 26.11.2026): one list instead of «Ведомость» ---

  testWidgets("everyone's month; «Да» to what waits", (tester) async {
    await pump(
      tester,
      PeopleScreen(today: DateTime(2026, 11, 25), tab: PeopleTab.money),
    );
    expect(repo.reports.single, (span: PeopleSpan.month, day: '2026-11-25'));
    expect(find.byKey(const ValueKey('ppl:money:HR-EMP-00001')), findsOne);
    expect(find.byKey(const ValueKey('figure:ppl:money:left')), findsOne);
    // A login-less worker is listed, and says why he has no money here.
    expect(find.byKey(const ValueKey('ppl:money:none:HR-EMP-00002')), findsOne);
    // November is not over: no «Отдать», and the screen says so.
    expect(find.byKey(const ValueKey('ppl:payLater')), findsOne);
    expect(find.byKey(const ValueKey('ppl:pay:HR-EMP-00001')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ppl:yes:PAY-ADJ-00007')));
    await tester.pumpAndSettle();
    expect(pay.approved, ['PAY-ADJ-00007']);
  });

  testWidgets('a month that is over is given, person by person', (
    tester,
  ) async {
    await pump(
      tester,
      PeopleScreen(today: DateTime(2026, 11, 25), tab: PeopleTab.money),
    );
    await tester.tap(find.byKey(const ValueKey('ppl:prev')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ppl:pay:HR-EMP-00001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ppl:giveConfirm')));
    await tester.pumpAndSettle();
    expect(pay.paidOut, [('erlan@korkem.kz', monthOf(DateTime(2026, 10)))]);
  });

  testWidgets('an advance needs who, how much and what for', (tester) async {
    await pump(
      tester,
      PeopleScreen(today: DateTime(2026, 11, 25), tab: PeopleTab.money),
    );
    await tester.tap(find.byKey(const ValueKey('ppl:addMoney')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ppl:entrySave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ppl:entryError')), findsOne);
    expect(pay.added, isEmpty);

    await tester.tap(find.byKey(const ValueKey('ppl:entryWho')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ерлан Сапаров').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ppl:entryKind')),
        matching: find.text('Fine'),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('ppl:entryAmount')),
      '3000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ppl:entryWhy')),
      'Скол на фасаде',
    );
    await tester.tap(find.byKey(const ValueKey('ppl:entrySave')));
    await tester.pumpAndSettle();
    expect(pay.added, [
      ('erlan@korkem.kz', 'Штраф', 3000.0, 'Скол на фасаде'),
    ]);
  });

  testWidgets('the work tab shows what is not a facade stage', (tester) async {
    await pump(
      tester,
      PeopleScreen(today: DateTime(2026, 11, 25), tab: PeopleTab.work),
    );
    expect(find.textContaining('Orders taken in: 23'), findsOne);
  });
}
