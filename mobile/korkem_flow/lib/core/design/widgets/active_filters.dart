import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';

/// One narrowing the user has applied, and the way back out of it.
@immutable
class ActiveFilter {
  const ActiveFilter({required this.label, required this.onRemove});

  /// Shown verbatim. Stage names come from the site's own records and are
  /// never translated — the label has to match what the Desk shows.
  final String label;

  final VoidCallback onRemove;
}

/// The filters currently narrowing a list, shown rather than implied.
///
/// A status filter used to be signalled by a single dot on the filter icon.
/// That says *something* is on; it never says what, so the only way to find out
/// was to reopen the sheet — and a filter you cannot see is a filter you
/// forget. A narrowed list then reads as "there is no data" instead of "you
/// asked for less of it", which is exactly the confusion the empty state had
/// already been taught to apologise for.
///
/// Search is deliberately not shown here. The query is sitting in the field
/// directly above, and repeating it would be chrome describing chrome.
///
/// Collapses to nothing when no filter is on, so an unfiltered list loses no
/// vertical space to a row that has nothing to say.
class ActiveFilters extends StatelessWidget {
  const ActiveFilters({required this.filters, super.key});

  final List<ActiveFilter> filters;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: motionOf(context, AppDuration.quick),
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: filters.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final filter in filters)
                    _FilterChip(key: ValueKey(filter.label), filter: filter),
                ],
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.filter, super.key});

  final ActiveFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: AppTint.surface),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: filter.onRemove,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          // Tall enough to take a thumb. The whole chip removes the filter —
          // aiming at a 16dp cross is a target for a mouse, not for someone
          // holding a phone in a workshop.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filter.label,
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(AppIcons.close, size: AppIconSize.dense, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
