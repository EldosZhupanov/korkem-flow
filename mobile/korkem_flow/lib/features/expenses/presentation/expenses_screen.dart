import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/enquiry_flow/application/image_picker_service.dart';
import 'package:korkem_flow/features/expenses/data/expense_repository.dart';
import 'package:korkem_flow/features/expenses/domain/urgent_expense.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Urgent expenses: anyone files their own; the administrator and accounting
/// approve or reject other people's.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final listAsync = ref.watch(expensesProvider);
    final money = NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: '₸',
      decimalDigits: 0,
    );

    return AppScreen(
      title: l10n.expensesTitle,
      actions: [
        IconButton(
          key: const ValueKey('expenseAdd'),
          tooltip: l10n.expensesAdd,
          icon: const Icon(AppIcons.add),
          onPressed: () => _file(context, ref),
        ),
      ],
      body: listAsync.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(expensesProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(expensesProvider);
            await ref.read(expensesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ReadableWidth(
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.expensesPendingTotal)),
                      Text(
                        money.format(list.pendingTotal),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (list.expenses.isEmpty)
                ReadableWidth(
                  child: EmptyView(
                    icon: AppIcons.quote,
                    title: l10n.expensesEmptyTitle,
                    message: l10n.expensesEmptyMessage,
                  ),
                ),
              for (final expense in list.expenses)
                ReadableWidth(
                  child: _ExpenseCard(
                    expense: expense,
                    money: money,
                    canDecide:
                        list.canDecide &&
                        expense.status == UrgentExpense.pending,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _file(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final draft = await showDialog<_Draft>(
      context: context,
      builder: (_) => const _FileDialog(),
    );
    if (draft == null) return;
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final filed = await repo.file(
        amount: draft.amount,
        purpose: draft.purpose,
        category: draft.category,
      );
      final photo = draft.photo;
      if (photo != null) {
        try {
          await repo.attachReceipt(filed.expense, photo);
        } on Object {
          messenger.showFailureMessage(l10n.expensesReceiptNotSent);
        }
      }
      messenger.showDone(l10n.expensesFiled);
      ref.invalidate(expensesProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

class _ExpenseCard extends ConsumerWidget {
  const _ExpenseCard({
    required this.expense,
    required this.money,
    required this.canDecide,
  });

  final UrgentExpense expense;
  final NumberFormat money;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final intent = switch (expense.status) {
      UrgentExpense.approved => StatusIntent.success,
      UrgentExpense.rejected => StatusIntent.neutral,
      _ => StatusIntent.warning,
    };
    final note = expense.decisionNote;
    return Card(
      key: ValueKey('expense:${expense.expense}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense.purpose,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(money.format(expense.amount)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                StatusChip(
                  label: expense.status,
                  intent: intent,
                  compact: true,
                ),
                Text('${expense.category} · ${expense.requestedByName}'),
              ],
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(note),
            ],
            if (canDecide)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: ValueKey('expenseReject:${expense.expense}'),
                    onPressed: () => _decide(context, ref, approve: false),
                    child: Text(l10n.pieceWorkReject),
                  ),
                  FilledButton(
                    key: ValueKey('expenseApprove:${expense.expense}'),
                    onPressed: () => _decide(context, ref, approve: true),
                    child: Text(l10n.pieceWorkApprove),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    String? note;
    if (!approve) {
      note = await showReasonDialog(
        context,
        title: l10n.pieceWorkReject,
        label: l10n.pieceWorkReason,
        confirm: l10n.pieceWorkReject,
        cancel: l10n.actionCancel,
        fieldKey: const ValueKey('expenseRejectReason'),
      );
      if (note == null) return;
    }
    try {
      await ref
          .read(expenseRepositoryProvider)
          .decide(expense.expense, approve: approve, note: note);
      ref.invalidate(expensesProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

class _Draft {
  const _Draft(this.amount, this.purpose, this.category, this.photo);

  final double amount;
  final String purpose;
  final String category;
  final XFile? photo;
}

class _FileDialog extends ConsumerStatefulWidget {
  const _FileDialog();

  @override
  ConsumerState<_FileDialog> createState() => _FileDialogState();
}

class _FileDialogState extends ConsumerState<_FileDialog> {
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  String _category = UrgentExpense.categories.last;
  XFile? _photo;

  @override
  void dispose() {
    _amount.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final photo = await ref
          .read(imagePickerServiceProvider)
          .pickImageFromCamera();
      if (photo != null && mounted) setState(() => _photo = photo);
    } on Object {
      messenger.showFailureMessage(l10n.defectPhotoCameraFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.expensesAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('expenseAmount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.expensesAmount,
                suffixText: '₸',
              ),
            ),
            TextField(
              key: const ValueKey('expensePurpose'),
              controller: _purpose,
              decoration: InputDecoration(labelText: l10n.expensesPurpose),
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final c in UrgentExpense.categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: InputDecoration(labelText: l10n.expensesCategory),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _takePhoto,
                icon: Icon(_photo == null ? AppIcons.camera : AppIcons.check),
                label: Text(
                  _photo == null
                      ? l10n.expensesReceipt
                      : l10n.defectPhotoChosen,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('expenseSave'),
          onPressed: () {
            final amount = double.tryParse(_amount.text);
            final purpose = _purpose.text.trim();
            if (amount == null || amount <= 0 || purpose.length < 3) return;
            Navigator.of(
              context,
            ).pop(_Draft(amount, purpose, _category, _photo));
          },
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}
