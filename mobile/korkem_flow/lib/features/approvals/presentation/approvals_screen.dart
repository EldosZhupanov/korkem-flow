import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/error_feedback.dart';
import 'package:korkem_flow/core/design/widgets/paged_list_view.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/approvals/application/approvals_controller.dart';
import 'package:korkem_flow/features/approvals/domain/pending_action.dart';
import 'package:korkem_flow/features/approvals/presentation/status_labels.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The queue of decisions an agent is waiting on.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(approvalsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navApprovals)),
      body: PagedListView<PendingAction>(
        state: ref.watch(approvalsControllerProvider),
        onRefresh: controller.refresh,
        onLoadMore: controller.loadMore,
        itemBuilder: (context, action) => ApprovalCard(action: action),
        emptyView: (context) => ListEmptyView(
          icon: AppIcons.success,
          tone: StateTone.success,
          title: l10n.approvalsEmpty,
          message: l10n.approvalsEmptyBody,
          onRefresh: controller.refresh,
        ),
      ),
    );
  }
}

class ApprovalCard extends ConsumerStatefulWidget {
  const ApprovalCard({required this.action, super.key});

  final PendingAction action;

  @override
  ConsumerState<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<ApprovalCard> {
  bool _busy = false;

  Future<void> _resolve({required bool approved}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await ref
          .read(approvalsControllerProvider.notifier)
          .resolve(widget.action, approved: approved);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approved ? l10n.approvalApproved : l10n.approvalRejected,
          ),
        ),
      );
    } on Exception catch (error) {
      // The backend re-validates status, expiry and the target's existence, so
      // a refusal here is a real answer and must be shown, not swallowed — in
      // the backend's own words when it gave any.
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageOf(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final action = widget.action;
    final now = ref.watch(clockProvider)();
    final expired = action.isExpiredAt(now);
    final expiry = action.expiresAt;
    final when = DateFormat.MMMd(
      Localizations.localeOf(context).languageCode,
    ).add_Hm();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  action.agentSkill,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChipFor(action: action, expired: expired),
            ],
          ),

          if (action.entityName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${action.entityType ?? ''} ${action.entityName}'.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          if (expiry != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  AppIcons.schedule,
                  size: AppIconSize.inline - 2,
                  color: expired
                      ? context.statusColors.danger
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${expired ? l10n.approvalExpired : l10n.approvalExpires}: '
                  '${when.format(expiry)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: expired ? context.statusColors.danger : null,
                  ),
                ),
              ],
            ),
          ],

          // Resolved and expired proposals are history: showing buttons that
          // the backend is certain to refuse would be inviting a failure.
          if (action.isPending && !expired) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _resolve(approved: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text(l10n.approvalReject),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _resolve(approved: true),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: AppIconSize.normal,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.approvalApprove),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The proposal's own status, unless it has quietly expired while on screen.
class StatusChipFor extends StatelessWidget {
  const StatusChipFor({
    required this.action,
    required this.expired,
    super.key,
  });

  final PendingAction action;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showExpired = expired && action.isPending;

    return StatusChip(
      label: showExpired ? l10n.approvalExpired : action.status.label(l10n),
      intent: showExpired ? StatusIntent.neutral : action.status.intent,
      compact: true,
    );
  }
}
