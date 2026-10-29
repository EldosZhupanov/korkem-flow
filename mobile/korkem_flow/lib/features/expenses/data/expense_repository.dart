import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/expenses/domain/urgent_expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(frappeClientProvider));
});

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final expensesProvider = FutureProvider.autoDispose<ExpenseList>(
  (ref) => ref.watch(expenseRepositoryProvider).listing(),
);

/// Urgent expenses. Who sees and decides what is the server's decision.
class ExpenseRepository {
  const ExpenseRepository(this._client);

  static const _base = 'korkem_manufacturing.api.urgent_expenses';

  final FrappeClient _client;

  Future<ExpenseList> listing() async =>
      ExpenseList.fromJson(_map(await _client.callMethod('$_base.listing')));

  Future<UrgentExpense> file({
    required double amount,
    required String purpose,
    required String category,
  }) async => UrgentExpense.fromJson(
    _map(
      await _client.callMethod(
        '$_base.file',
        post: true,
        params: {'amount': amount, 'purpose': purpose, 'category': category},
      ),
    ),
  );

  Future<void> attachReceipt(String expense, XFile photo) async {
    await _client.uploadFile(
      '$_base.attach_receipt',
      field: 'file',
      filename: photo.name.isNotEmpty ? photo.name : 'чек.jpg',
      bytes: await photo.readAsBytes(),
      fields: <String, dynamic>{'expense': expense},
    );
  }

  Future<UrgentExpense> decide(
    String expense, {
    required bool approve,
    String? note,
  }) async => UrgentExpense.fromJson(
    _map(
      await _client.callMethod(
        '$_base.decide',
        post: true,
        params: {
          'expense': expense,
          'approve': approve ? 1 : 0,
          'note': ?note,
        },
      ),
    ),
  );

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final raw = response['message'] ?? response['data'];
    if (raw is! Map) {
      throw const ServerFailure('Сервер не ответил по расходам.');
    }
    return Map<String, dynamic>.from(raw);
  }
}
