import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';
import 'package:korkem_flow/features/piece_work/presentation/piece_work_screen.dart';

import '../../support/widget_harness.dart';

class _FakeRepository implements PieceWorkRepository {
  _FakeRepository({required this.canEdit});

  final bool canEdit;
  final approved = <String>[];
  final rejected = <(String, String)>[];

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
}
