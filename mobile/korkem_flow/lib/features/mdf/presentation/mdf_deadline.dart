import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The shop's traffic light: red — today or late, yellow — tomorrow, green —
/// later (owner, 08.11.2026).
StatusIntent mdfDeadlineIntent(MdfDeadline d) => switch (d) {
  MdfDeadline.now => StatusIntent.danger,
  MdfDeadline.tomorrow => StatusIntent.warning,
  MdfDeadline.later => StatusIntent.success,
};

String mdfDeadlineLabel(PlanOrder o, AppLocalizations l10n) =>
    switch (o.deadline) {
      MdfDeadline.now when (o.daysLeft ?? 0) < 0 => l10n.mdfOverdue,
      MdfDeadline.now => l10n.mdfDeadlineToday,
      MdfDeadline.tomorrow => l10n.mdfDeadlineTomorrow,
      MdfDeadline.later => o.deliveryDate,
    };

/// The deadline chip, «Не успевает» beside it when the stages left will not
/// fit, and «Срочный».
class MdfDeadlineChips extends StatelessWidget {
  const MdfDeadlineChips({required this.order, super.key});

  final PlanOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        StatusChip(
          key: ValueKey('deadline:${order.name}:${order.deadline.name}'),
          label: mdfDeadlineLabel(order, l10n),
          intent: mdfDeadlineIntent(order.deadline),
          compact: true,
        ),
        if (order.atRisk)
          StatusChip(
            key: ValueKey('atRisk:${order.name}'),
            label: l10n.mdfAtRisk,
            intent: StatusIntent.danger,
          ),
        if (order.urgent)
          StatusChip(
            label: l10n.mdfTagUrgent,
            intent: StatusIntent.danger,
            compact: true,
          ),
      ],
    );
  }
}
