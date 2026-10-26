import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/features/expenses/data/expense_repository.dart';
import 'package:korkem_flow/features/expenses/domain/urgent_expense.dart';
import 'package:korkem_flow/features/expenses/presentation/expenses_screen.dart';

import '../../support/widget_harness.dart';

class _FakeRepository implements ExpenseRepository {
  _FakeRepository({required this.canDecide});

  final bool canDecide;
  final filed = <(double, String, String)>[];
  final decisions = <(String, bool, String?)>[];

  static const _pending = UrgentExpense(
    expense: 'EXP-00001',
    requestedBy: 'driver@example.com',
    requestedByName: 'Ерлан',
    amount: 8500,
    purpose: 'Бензин на доставку',
    category: 'Транспорт',
    status: UrgentExpense.pending,
  );

  @override
  Future<ExpenseList> listing() async => ExpenseList(
    expenses: const [_pending],
    pendingTotal: 8500,
    canDecide: canDecide,
  );

  @override
  Future<UrgentExpense> file({
    required double amount,
    required String purpose,
    required String category,
  }) async {
    filed.add((amount, purpose, category));
    return _pending;
  }

  @override
  Future<void> attachReceipt(String expense, XFile photo) async {}

  @override
  Future<UrgentExpense> decide(
    String expense, {
    required bool approve,
    String? note,
  }) async {
    decisions.add((expense, approve, note));
    return _pending;
  }
}

void main() {
  Future<_FakeRepository> pump(
    WidgetTester tester, {
    required bool canDecide,
  }) async {
    final repo = _FakeRepository(canDecide: canDecide);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: harness(const ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('anyone can file an expense', (tester) async {
    final repo = await pump(tester, canDecide: false);
    await tester.tap(find.byKey(const ValueKey('expenseAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expenseAmount')), '3200');
    await tester.enterText(
      find.byKey(const ValueKey('expensePurpose')),
      'Пильный диск',
    );
    await tester.tap(find.byKey(const ValueKey('expenseSave')));
    await tester.pumpAndSettle();
    expect(repo.filed.single.$1, 3200);
    expect(repo.filed.single.$2, 'Пильный диск');
  });

  testWidgets('somebody who does not decide sees no decision buttons', (
    tester,
  ) async {
    await pump(tester, canDecide: false);
    expect(
      find.byKey(const ValueKey('expenseApprove:EXP-00001')),
      findsNothing,
    );
  });

  testWidgets('accounting approves', (tester) async {
    final repo = await pump(tester, canDecide: true);
    await tester.tap(find.byKey(const ValueKey('expenseApprove:EXP-00001')));
    await tester.pumpAndSettle();
    expect(repo.decisions.single, ('EXP-00001', true, null));
  });
}
