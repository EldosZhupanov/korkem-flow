import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/costs/data/costs_repository.dart';
import 'package:korkem_flow/features/costs/domain/costs.dart';
import 'package:korkem_flow/features/costs/presentation/costs_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Куда идут деньги»: what the month's work brought, where it went by
/// group, what one m² costs, the m² the shop breaks even at, what to look
/// at, and every line.
class MoneyTab extends ConsumerWidget {
  const MoneyTab({required this.month, required this.header, super.key});

  final String month;
  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(moneyFlowProvider(month));
    return Column(
      children: [
        header,
        Expanded(
          child: flow.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(moneyFlowProvider(month)),
            ),
            data: (f) => RefreshIndicator(
              onRefresh: () => ref.refresh(moneyFlowProvider(month).future),
              child: _Body(flow: f),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.flow});

  final MoneyFlow flow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = costMoney(context);
    final f = flow;
    if (f.revenue == 0 && f.costs == 0) {
      return ListView(
        children: [EmptyView(title: l10n.cstEmptyMonth)],
      );
    }
    final palette = groupColours(context);
    final breakEven = f.breakEvenM2;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: FigureRow(
            tiles: [
              FigureTile(
                id: 'cst:revenue',
                title: l10n.cstRevenue,
                value: money.format(f.revenue),
                note: l10n.cstMade(f.orders, costQty(f.m2)),
              ),
              FigureTile(
                id: 'cst:costs',
                title: l10n.cstCosts,
                value: money.format(f.costs),
              ),
              FigureTile(
                id: 'cst:profit',
                title: l10n.cstProfit,
                value: money.format(f.profit),
                note: f.profitShare == null ? null : '${f.profitShare}%',
                colour: f.profit < 0 ? status.danger : status.success,
              ),
              if (f.costPerM2 case final perM2?)
                FigureTile(
                  id: 'cst:perM2',
                  title: l10n.cstCostPerM2,
                  value: money.format(perM2),
                  note: switch (f.overheadPerM2) {
                    final o? => l10n.cstOverheadPerM2(money.format(o)),
                    _ => null,
                  },
                ),
              FigureTile(
                id: 'cst:breakEven',
                title: l10n.cstBreakEven,
                value: breakEven == null
                    ? '—'
                    : l10n.cstBreakEvenValue(costQty(breakEven)),
                note: breakEven == null
                    ? l10n.cstBreakEvenUnknown
                    : f.m2 >= breakEven
                    ? l10n.cstBreakEvenSpare(
                        costQty(f.m2),
                        ((f.m2 - breakEven) / f.m2 * 100).round(),
                      )
                    : l10n.cstBreakEvenShort(
                        costQty(f.m2),
                        ((breakEven - f.m2) / breakEven * 100).round(),
                      ),
                colour: breakEven == null
                    ? null
                    : f.m2 >= breakEven
                    ? status.success
                    : status.danger,
              ),
            ],
          ),
        ),
        if (f.alerts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.cstAlerts)),
          for (final (i, a) in f.alerts.indexed)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('cst:alert:$i'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  a.kind == MoneyAlertKind.limit
                      ? AppIcons.danger
                      : AppIcons.warning,
                  color: a.kind == MoneyAlertKind.limit
                      ? status.danger
                      : status.warning,
                ),
                title: Text(alertText(a, l10n, money.format)),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ReadableWidth(child: SectionLabel(l10n.cstWhere)),
        const SizedBox(height: AppSpacing.xs),
        // Each group's part of the month's costs, in one bar.
        ReadableWidth(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              height: AppSpacing.lg,
              child: Row(
                key: const ValueKey('cst:bar'),
                children: [
                  for (final (i, g) in f.groups.indexed)
                    if (g.amount > 0)
                      Expanded(
                        flex: (g.amount / f.costs * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: palette[i % palette.length]),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final (i, g) in f.groups.indexed)
          ReadableWidth(
            child: Padding(
              key: ValueKey('cst:group:${g.group}'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Icon(
                    AppIcons.colour,
                    size: AppSpacing.md,
                    color: palette[i % palette.length],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(g.group)),
                  Text(
                    [
                      money.format(g.amount),
                      if (g.share != null) l10n.cstOfRevenue('${g.share}'),
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        ReadableWidth(child: SectionLabel(l10n.cstItems)),
        for (final x in f.items)
          ReadableWidth(child: _ItemLine(item: x, total: f.costs)),
        if (f.areas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.cstAreas)),
          for (final a in f.areas)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('cst:area:${a.area}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(a.area),
                trailing: Text(money.format(a.amount)),
              ),
            ),
        ],
      ],
    );
  }
}

/// One line: its sum, its usual, its limit filled.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, required this.total});

  final MoneyItem item;
  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = costMoney(context);
    final x = item;
    final over = x.limit > 0 && x.amount > x.limit;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      key: ValueKey('cst:item:${x.key}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(x.title)),
              Text(
                money.format(x.amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: over ? status.danger : null,
                ),
              ),
            ],
          ),
          Text(
            [
              x.group,
              ?x.area,
              if (x.fixed) l10n.cstFixed else l10n.cstVariable,
              if (x.usual > 0) l10n.cstUsual(money.format(x.usual)),
              if (x.limit > 0) l10n.cstLimitOf(money.format(x.limit)),
            ].join(' · '),
            style: muted,
          ),
          if (x.limit > 0) ...[
            const SizedBox(height: AppSpacing.xxs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: (x.amount / x.limit).clamp(0.0, 1.0),
                minHeight: AppSpacing.xs,
                color: over ? status.danger : status.success,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The colours of the cost groups, from the theme.
List<Color> groupColours(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final status = context.statusColors;
  return [
    cs.primary,
    status.success,
    status.warning,
    status.danger,
    cs.tertiary,
    cs.secondary,
    cs.outline,
  ];
}

/// What plan-against-fact says, in words.
String alertText(
  MoneyAlert a,
  AppLocalizations l10n,
  String Function(num) money,
) => switch (a.kind) {
  MoneyAlertKind.limit => l10n.cstAlertLimit(
    a.title,
    money(a.amount),
    money(a.limit),
    a.over,
  ),
  MoneyAlertKind.jump => l10n.cstAlertJump(
    a.title,
    money(a.amount),
    costQty(a.times),
  ),
  MoneyAlertKind.unfilled => l10n.cstAlertUnfilled(a.title),
};
