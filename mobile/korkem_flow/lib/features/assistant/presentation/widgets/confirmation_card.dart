import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The assistant asking before it changes anything.
///
/// Shown in the conversation rather than as a modal, deliberately. A dialog
/// that appears over the transcript hides the very thing the decision depends
/// on — what was asked and what the assistant said back — and a dismissed
/// dialog leaves a proposal the server is still holding open with no way to
/// return to it.
///
/// The action described here is the action that will run. The server wrote it
/// down when the model proposed it and executes it from that record, so the
/// model cannot substitute a different one after a human has agreed.
class ConfirmationCard extends ConsumerWidget {
  const ConfirmationCard({required this.request, super.key});

  final AssistantNeedsConfirmation request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = context.statusColors.resolve(StatusIntent.warning);
    final busy = ref.watch(assistantBusyProvider);

    return Semantics(
      container: true,
      label: l10n.chatConfirmTitle,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.warning,
                    size: AppIconSize.small,
                    color: accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.chatConfirmTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.chatConfirmBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final call in request.calls)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _Call(call: call),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => rejectPendingAction(ref),
                    child: Text(l10n.chatConfirmReject),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: busy ? null : () => approvePendingAction(ref),
                    child: Text(l10n.chatConfirmApprove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One proposed call, named and with its arguments spelled out.
///
/// The arguments are shown because "approve" on an unnamed action is not
/// consent — the whole value of the pause is that a person can see what the
/// model decided to do with the words they typed.
class _Call extends StatelessWidget {
  const _Call({required this.call});

  final PendingToolCall call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          call.tool,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final entry in call.arguments.entries)
          Text(
            '${entry.key}: ${entry.value}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
