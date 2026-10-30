import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/motion/animated_counter.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The one thing the home screen should say before anything else: how much is
/// waiting on *you*, right now.
///
/// The dashboard used to open with six equal tiles. Six things given equal
/// weight is six things given no weight — the design system's own first
/// principle — and the two that actually stop work, an overdue task and a
/// decision an agent is blocked on, were the same size as a lead count nobody
/// acts on before lunch.
///
/// So they are pulled out and added together. The sum is the honest headline:
/// one number a manager can read at arm's length across a workshop, with the
/// split underneath for anyone who wants it.
///
/// The brand ornament sits behind it, clipped to the card. It is the only
/// decorative element on the screen and it earns its place by making the one
/// card that matters look unlike the ones that matter less.
class AttentionHero extends StatelessWidget {
  const AttentionHero({
    required this.overdue,
    required this.pending,
    required this.onOpen,
    super.key,
  });

  /// Null where the signed-in role may not see the figure — which is not the
  /// same as zero, and must not be added as one.
  final int? overdue;
  final int? pending;

  final VoidCallback onOpen;

  /// What the headline counts. Null only when *both* halves are withheld; a
  /// role that can see one of them still gets a real total.
  int? get _total => switch ((overdue, pending)) {
    (null, null) => null,
    (final int a, final int b) => a + b,
    (final int a, _) => a,
    (_, final int b) => b,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = context.statusColors.resolve(StatusIntent.warning);

    return AppCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Bled off the trailing edge rather than centred: centred it would
          // sit behind the number and fight it for the eye.
          PositionedDirectional(
            end: -AppIllustration.plateDense,
            top: -AppIllustration.plateDense / 2,
            child: Image.asset(
              'assets/brand/korkem_ring.png',
              width: AppIllustration.halo,
              height: AppIllustration.halo,
              color: accent.withValues(alpha: AppTint.ornament),
              excludeFromSemantics: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dashboardAttention.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: accent),
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedCounter(
                  value: _total,
                  placeholder: '—',
                  style: theme.textTheme.displaySmall?.copyWith(color: accent),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Split(label: l10n.metricOverdueTasks, value: overdue),
                    _Split(label: l10n.metricPendingActions, value: pending),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the headline, named. A bare "5" tells a user how much is wrong
/// but not what kind of wrong, and those two have different answers.
class _Split extends StatelessWidget {
  const _Split({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${value ?? '—'}', style: theme.textTheme.labelLarge),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
