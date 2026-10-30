import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/operations/data/operations_repository.dart';
import 'package:korkem_flow/features/operations/domain/delivery.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Who was asked to do what, and what they said back.
///
/// A view over `Work Instruction` and nothing more — it reads through
/// `get_list`, so it shows exactly what ERPNext would let this person see
/// anywhere else. There is no action here on purpose: dispatching work is a
/// decision the assistant records after somebody confirms it, and a button that
/// re-sent an instruction would be a second way to create one.
class WorkInstructionsScreen extends ConsumerWidget {
  const WorkInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final instructions = ref.watch(workInstructionsProvider);

    return AppScreen(
      title: l10n.instructionsTitle,
      subtitle: l10n.instructionsSubtitle,
      body: instructions.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(workInstructionsProvider),
        ),
        data: (rows) => rows.isEmpty
            ? Center(child: Text(l10n.instructionsEmpty))
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: rows.length,
                itemBuilder: (context, index) =>
                    _InstructionTile(row: rows[index]),
              ),
      ),
    );
  }
}

class _InstructionTile extends StatelessWidget {
  const _InstructionTile({required this.row});

  final WorkInstructionRow row;

  String _elapsed(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    return '${seconds ~/ 3600}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colour = switch (row.status) {
      'Acknowledged' || 'Completed' => context.statusColors.success,
      'Rejected' => context.statusColors.danger,
      'Clarification Requested' => context.statusColors.warning,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.employee,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  row.status,
                  style: theme.textTheme.labelSmall?.copyWith(color: colour),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(row.instruction),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                row.sender,
                if (row.salesOrder != null) row.salesOrder!,
                if (row.channel != null) row.channel!,
                if (row.dueDate != null) row.dueDate!,
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (row.response != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '«${row.response!}»',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (row.responseSeconds != null)
              Text(
                '${l10n.instructionsAnsweredIn} '
                '${_elapsed(row.responseSeconds!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
