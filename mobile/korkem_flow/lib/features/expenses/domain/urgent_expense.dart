import 'package:meta/meta.dart';

/// An urgent expense, as the server keeps it.
@immutable
class UrgentExpense {
  const UrgentExpense({
    required this.expense,
    required this.requestedBy,
    required this.requestedByName,
    required this.amount,
    required this.purpose,
    required this.category,
    required this.status,
    this.decisionNote,
  });

  factory UrgentExpense.fromJson(Map<String, dynamic> json) => UrgentExpense(
    expense: '${json['expense'] ?? ''}',
    requestedBy: '${json['requested_by'] ?? ''}',
    requestedByName:
        '${json['requested_by_name'] ?? json['requested_by'] ?? ''}',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    purpose: '${json['purpose'] ?? ''}',
    category: '${json['category'] ?? ''}',
    status: '${json['status'] ?? ''}',
    decisionNote: json['decision_note'] as String?,
  );

  static const pending = 'Ждёт решения';
  static const approved = 'Одобрено';
  static const rejected = 'Отклонено';
  static const categories = [
    'Материалы',
    'Инструмент',
    'Транспорт',
    'Ремонт',
    'Другое',
  ];

  final String expense;
  final String requestedBy;
  final String requestedByName;
  final double amount;
  final String purpose;
  final String category;
  final String status;
  final String? decisionNote;
}

/// The list the screen shows and whether this person decides.
@immutable
class ExpenseList {
  const ExpenseList({
    required this.expenses,
    required this.pendingTotal,
    required this.canDecide,
  });

  factory ExpenseList.fromJson(Map<String, dynamic> json) => ExpenseList(
    expenses: [
      for (final row in json['expenses'] as List? ?? const [])
        if (row is Map) UrgentExpense.fromJson(Map<String, dynamic>.from(row)),
    ],
    pendingTotal: (json['pending_total'] as num?)?.toDouble() ?? 0,
    canDecide: json['can_decide'] == true,
  );

  final List<UrgentExpense> expenses;
  final double pendingTotal;
  final bool canDecide;
}
