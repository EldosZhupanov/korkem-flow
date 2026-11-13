import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';

/// One row of [BarRows]: a name, how much, and what to write beside it.
@immutable
class BarRow {
  const BarRow({
    required this.id,
    required this.label,
    required this.value,
    required this.note,
  });

  /// What [BarRows.onSelect] is told when this row is tapped.
  final String id;
  final String label;

  /// The bar's length, against the longest row's.
  final double value;

  /// Beside the bar: «5 · 12,4 м²».
  final String note;
}

/// How much sits where, a row each — orders at each stage of the shop, a
/// film's metres by supplier (owner, 14.11.2026: the department
/// dashboards). Tap a row to pick it and the screen shows that row's own;
/// tap it again for all.
///
/// Built of widgets rather than painted: each row is a real tap target with
/// a label a screen reader can read.
class BarRows extends StatelessWidget {
  const BarRows({
    required this.rows,
    this.selected,
    this.onSelect,
    super.key,
  });

  final List<BarRow> rows;

  /// The picked row's [BarRow.id], or null for none.
  final String? selected;
  final ValueChanged<String?>? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme.primary;
    final longest = rows.map((r) => r.value).fold<double>(0, math.max);
    return Column(
      children: [
        for (final r in rows)
          InkWell(
            key: ValueKey('barRow:${r.id}'),
            borderRadius: BorderRadius.circular(AppRadius.xs),
            onTap: onSelect == null
                ? null
                : () => onSelect!(r.id == selected ? null : r.id),
            child: SizedBox(
              height: AppChart.row,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      r.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: r.id == selected
                          ? theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            )
                          : theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: longest == 0 ? 0 : r.value / longest,
                        heightFactor: AppChart.barShare,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected == null || selected == r.id
                                ? colour
                                : colour.withValues(alpha: AppTint.chartFaded),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(r.note, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
