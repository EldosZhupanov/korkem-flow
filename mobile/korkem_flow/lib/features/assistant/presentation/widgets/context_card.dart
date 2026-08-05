import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/motion/animated_counter.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/navigation/app_destinations.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/dashboard/application/dashboard_controller.dart';
import 'package:korkem_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// KORKEM data, attached to a reply.
///
/// This is what makes the assistant a way *into* the app rather than a second
/// copy of it: every figure comes from the provider that already feeds the
/// dashboard, and the button opens the screen that already exists. Nothing here
/// is authored, cached or approximated — reopen a week-old conversation and the
/// card shows this week's numbers, because it never stored last week's.
class ContextCard extends ConsumerWidget {
  const ContextCard({required this.kind, super.key});

  final ContextCardKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(dashboardControllerProvider).value;

    final (label, value, intent) = switch (kind) {
      ContextCardKind.attention => (
        l10n.chatCardAttention,
        _sum(summary, const [
          DashboardSummary.overdueTasks,
          DashboardSummary.pendingActions,
        ]),
        StatusIntent.warning,
      ),
      ContextCardKind.tasks => (
        l10n.chatCardTasks,
        summary?[DashboardSummary.myOpenTasks],
        StatusIntent.neutral,
      ),
      ContextCardKind.deals => (
        l10n.chatCardOpenDeals,
        summary?[DashboardSummary.openDeals],
        StatusIntent.neutral,
      ),
      ContextCardKind.production => (
        l10n.chatCardProduction,
        summary?[DashboardSummary.workOrdersInProgress],
        StatusIntent.neutral,
      ),
    };

    final accent = intent == StatusIntent.neutral
        ? theme.colorScheme.primary
        : context.statusColors.resolve(intent);

    return AppCard(
      onTap: () => _open(context),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedCounter(
              value: value,
              // A dash, never a zero: the backend returns null where the
              // signed-in role may not see a figure, and stating "0" would
              // assert something the user has no standing to know.
              placeholder: '—',
              style: theme.textTheme.displaySmall?.copyWith(color: accent),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  l10n.chatOpen,
                  style: theme.textTheme.labelLarge?.copyWith(color: accent),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(AppIcons.forward, size: AppIconSize.inline, color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Null only when *every* part is withheld. A role that can see one half of
  /// a total still gets a real number rather than a dash.
  int? _sum(DashboardSummary? summary, List<String> keys) {
    var total = 0;
    var sawOne = false;
    for (final key in keys) {
      final value = summary?[key];
      if (value != null) {
        total += value;
        sawOne = true;
      }
    }
    return sawOne ? total : null;
  }

  void _open(BuildContext context) {
    switch (kind) {
      case ContextCardKind.attention:
        unawaited(context.push<void>(Routes.approvals));
      case ContextCardKind.production:
        unawaited(context.push<void>(Routes.production));
      case ContextCardKind.deals:
        _toBranch(context, Routes.sales);
      case ContextCardKind.tasks:
        _toBranch(context, Routes.tasks);
    }
  }

  /// A branch switch rather than a push: Sales and Tasks are sections with
  /// their own stacks, and pushing a second copy inside the chat branch would
  /// strand the user in a duplicate of a place they already have.
  void _toBranch(BuildContext context, String path) =>
      StatefulNavigationShell.of(context).goBranch(branchIndexOf(path));
}
