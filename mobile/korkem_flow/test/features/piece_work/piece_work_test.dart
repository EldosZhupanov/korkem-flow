import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';
import 'package:korkem_flow/features/piece_work/presentation/payroll_screen.dart';
import 'package:korkem_flow/features/piece_work/presentation/piece_work_screen.dart';

import '../../support/widget_harness.dart';

class _FakeRepository implements PieceWorkRepository {
  _FakeRepository({required this.canEdit, this.bonus = const BonusProgress()});

  final bool canEdit;
  final BonusProgress bonus;
  final approved = <String>[];
  final rejected = <(String, String)>[];
  final added = <(String, String, double, String)>[];
  final approvedAdjustments = <String>[];

  @override
  Future<BonusProgress> progress() async => bonus;

  @override
  Future<PieceRates> saveBonusRules({
    double? dailyThreshold,
    double? dailyBonus,
    double? monthlyThreshold,
    double? monthlyBonus,
  }) => rates();

  @override
  Future<PayrollStatement> statement(PayPeriod period) async =>
      PayrollStatement.fromJson(const {
        'from_date': '2026-10-01',
        'to_date': '2026-10-31',
        'rows': [
          {
            'employee': 'aidos@example.com',
            'employee_name': 'Айдос',
            'piece': 120000,
            'pending': 8000,
            'daily_bonus': 5000,
            'monthly_bonus': 0,
            'bonus': 0,
            'fine': 2000,
            'advance': 30000,
            'to_pay': 93000,
          },
        ],
        'total_to_pay': 93000,
      });

  @override
  Future<String> statementCsv(PayPeriod period) async => 'Сотрудник;К выплате';

  @override
  Future<List<PayAdjustment>> adjustments(PayPeriod period) async => [
    PayAdjustment.fromJson(const {
      'adjustment': 'PAY-ADJ-00001',
      'employee': 'aidos@example.com',
      'employee_name': 'Айдос',
      'kind': 'Аванс',
      'amount': 30000,
      'on_date': '2026-10-15',
      'reason': 'Аванс за полмесяца',
      'status': 'Pending Approval',
    }),
  ];

  @override
  Future<PayAdjustment> addAdjustment({
    required String employee,
    required String kind,
    required double amount,
    required String reason,
  }) async {
    added.add((employee, kind, amount, reason));
    return (await adjustments(monthOf(DateTime(2026, 10)))).first;
  }

  @override
  Future<void> approveAdjustment(String adjustment) async =>
      approvedAdjustments.add(adjustment);

  @override
  Future<void> reverseAdjustment(String adjustment, String reason) async {}

  @override
  Future<List<Worker>> workers() async => const [
    Worker(user: 'aidos@example.com', name: 'Айдос'),
  ];

  @override
  Future<MyPieceWork> myWork() async => MyPieceWork.fromJson(const {
    'entries': [
      {
        'entry': 'PWE-1',
        'operation': 'Раскрой',
        'quantity': 4,
        'unit': 'pcs',
        'rate': 150,
        'factor': 1.5,
        'shift': 'Сверхурочно',
        'amount': 900,
        'status': 'Pending Approval',
      },
    ],
    'totals': {'pending': 900, 'approved': 0, 'paid': 0},
  });

  @override
  Future<PieceRates> rates() async => PieceRates(
    rates: const [
      PieceRate(operation: 'Раскрой', rateType: PieceRate.perPart, rate: 150),
    ],
    canEdit: canEdit,
  );

  @override
  Future<List<PieceWorkEntry>> pending() async => [
    PieceWorkEntry.fromJson(const {
      'entry': 'PWE-2',
      'employee_name': 'Айдос',
      'operation': 'Фасад',
      'quantity': 0.4,
      'unit': 'm2',
      'rate': 2000,
      'amount': 800,
      'status': 'Pending Approval',
    }),
  ];

  @override
  Future<void> approve(String entry) async => approved.add(entry);

  @override
  Future<void> reject(String entry, String reason) async =>
      rejected.add((entry, reason));

  @override
  Future<PieceRates> setRate({
    required String operation,
    required String rateType,
    required double rate,
    bool enabled = true,
  }) => rates();

  @override
  Future<PieceRates> saveRules({
    required bool saturdayIsWeekend,
    required bool sundayIsWeekend,
    String? shiftEnd,
    double? overtimeFactor,
    double? weekendFactor,
  }) => rates();
}

void main() {
  Future<_FakeRepository> pump(
    WidgetTester tester, {
    required bool canEdit,
  }) async {
    final repo = _FakeRepository(canEdit: canEdit);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pieceWorkRepositoryProvider.overrideWithValue(repo)],
        child: harness(const PieceWorkScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test('a rate pays automatically only per piece and only when enabled', () {
    const rates = PieceRates(
      rates: [
        PieceRate(operation: 'Раскрой', rateType: PieceRate.perPart, rate: 150),
        PieceRate(operation: 'Фасад', rateType: PieceRate.perM2, rate: 2000),
        PieceRate(
          operation: 'Кромка',
          rateType: PieceRate.perPart,
          rate: 80,
          enabled: false,
        ),
      ],
      canEdit: false,
    );
    expect(rates.perPieceFor('Раскрой'), 150);
    expect(rates.perPieceFor('Фасад'), isNull);
    expect(rates.perPieceFor('Кромка'), isNull);
    expect(rates.perPieceFor('Покраска'), isNull);
  });

  testWidgets('a worker sees their own pay and no approval tools', (
    tester,
  ) async {
    await pump(tester, canEdit: false);
    expect(find.byKey(const ValueKey('pieceWorkTotals')), findsOneWidget);
    expect(find.textContaining('Раскрой'), findsWidgets);
    expect(find.byKey(const ValueKey('approve:PWE-2')), findsNothing);
    expect(find.byKey(const ValueKey('pieceRateAdd')), findsNothing);
  });

  testWidgets('the production manager approves and rejects with a reason', (
    tester,
  ) async {
    final repo = await pump(tester, canEdit: true);

    await tester.tap(find.byKey(const ValueKey('approve:PWE-2')));
    await tester.pumpAndSettle();
    expect(repo.approved, ['PWE-2']);

    await tester.tap(find.byKey(const ValueKey('reject:PWE-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rejectReason')), 'Брак');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject').last);
    await tester.pumpAndSettle();
    expect(repo.rejected, [('PWE-2', 'Брак')]);
  });

  testWidgets("a worker sees how far today's bonus is", (tester) async {
    final repo = _FakeRepository(
      canEdit: false,
      bonus: BonusProgress.fromJson(const {
        'today': {
          'earned': 6000,
          'threshold': 10000,
          'bonus': 2500,
          'left': 4000,
          'reached': false,
        },
        'month': null,
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pieceWorkRepositoryProvider.overrideWithValue(repo)],
        child: harness(const PieceWorkScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bonusToday')), findsOneWidget);
    expect(find.byKey(const ValueKey('bonusMonth')), findsNothing);
    expect(find.textContaining('to go'), findsOneWidget);
  });

  testWidgets('the pay sheet shows what each worker is owed', (tester) async {
    final repo = _FakeRepository(canEdit: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pieceWorkRepositoryProvider.overrideWithValue(repo)],
        child: harness(const PayrollScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('payrollRow:aidos@example.com')),
      findsOneWidget,
    );
    expect(find.textContaining('Not yet approved'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('adjustment:PAY-ADJ-00001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adjustmentApprove')));
    await tester.pumpAndSettle();
    expect(repo.approvedAdjustments, ['PAY-ADJ-00001']);
  });

  testWidgets('a fine needs a person, an amount and a reason', (tester) async {
    final repo = _FakeRepository(canEdit: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pieceWorkRepositoryProvider.overrideWithValue(repo)],
        child: harness(const PayrollScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payrollAddAdjustment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adjustmentSave')));
    await tester.pumpAndSettle();
    expect(repo.added, isEmpty);

    await tester.tap(find.byKey(const ValueKey('adjustmentEmployee')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Айдос').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Штраф'));
    await tester.enterText(
      find.byKey(const ValueKey('adjustmentAmount')),
      '3000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('adjustmentReason')),
      'Скол на фасаде',
    );
    await tester.tap(find.byKey(const ValueKey('adjustmentSave')));
    await tester.pumpAndSettle();
    expect(repo.added, [
      ('aidos@example.com', 'Штраф', 3000.0, 'Скол на фасаде'),
    ]);
  });
}
