import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/shop_board.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// «Цех» (owner, 26.11.2026): the month's plan against what is made, each
// stage in the order an order goes with its m² and its people, the late
// orders, and the departments off the road. Read only: every figure comes
// from the server (`shop_board`), which counts nothing «Жоспар», «Объём
// работ» and «Итоги» do not count already.

String _m2(BuildContext context, double v) => NumberFormat(
  '0.#',
  Localizations.localeOf(context).toLanguageTag(),
).format(v);

/// The month in one strip: plan, made, where today should be, the forecast.
class ShopMonthStrip extends ConsumerWidget {
  const ShopMonthStrip({required this.month, required this.day, super.key});

  final ShopMonth month;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final m = month;
    final name = DateFormat.LLLL(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(day);
    final gap = m.gapM2;
    final share = m.planM2 > 0 ? (m.doneM2 / m.planM2).clamp(0.0, 1.0) : 0.0;
    final mark = m.planM2 > 0 ? (m.expectedM2 / m.planM2).clamp(0.0, 1.0) : 0.0;
    final short = m.planM2 - m.forecastM2;
    return Column(
      key: const ValueKey('shop:month'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.shopMonthLine(
                  name.isEmpty ? name : name[0].toUpperCase() + name.substring(1),
                  _m2(context, m.planM2),
                  _m2(context, m.doneM2),
                ),
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('shop:target'),
              tooltip: l10n.shopSetPlan,
              icon: const Icon(AppIcons.edit),
              onPressed: () => unawaited(_setPlan(context, ref, m)),
            ),
          ],
        ),
        Text(
          m.planFromTarget ? l10n.shopPlanTarget : l10n.shopPlanDue,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Made, filled; where today should be, a mark.
        LayoutBuilder(
          builder: (context, box) => SizedBox(
            height: AppSpacing.md,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: box.maxWidth * share,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: gap < 0 ? status.warning : status.success,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                Positioned(
                  left: box.maxWidth * mark - AppSpacing.xxs / 2,
                  top: -AppSpacing.xs,
                  bottom: -AppSpacing.xs,
                  width: AppSpacing.xxs,
                  child: ColoredBox(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            l10n.shopExpected(_m2(context, m.expectedM2)),
            if (gap < 0) l10n.shopBehind(_m2(context, -gap)),
            if (gap > 0) l10n.shopAhead(_m2(context, gap)),
          ].join(' · '),
          key: const ValueKey('shop:gap'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: gap < 0 ? status.warning : status.success,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FigureRow(
          tiles: [
            FigureTile(
              id: 'shop:forecast',
              title: l10n.shopForecast,
              value: '${_m2(context, m.forecastM2)} м²',
              note: short > 0
                  ? l10n.shopShort(_m2(context, short))
                  : l10n.shopEnough,
              colour: short > 0 ? status.danger : status.success,
            ),
            FigureTile(
              id: 'shop:inShop',
              title: l10n.shopInShop,
              value: '${_m2(context, m.inShopM2)} м²',
              note: l10n.shopOrders(m.inShopOrders),
            ),
            FigureTile(
              id: 'shop:taken',
              title: l10n.shopTaken,
              value: '${_m2(context, m.takenM2)} м²',
              note: m.salesTargetM2 == null
                  ? l10n.shopOrders(m.takenOrders)
                  : l10n.shopOfSales(_m2(context, m.salesTargetM2!)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setPlan(
    BuildContext context,
    WidgetRef ref,
    ShopMonth m,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(mdfOrderRepositoryProvider);
    final c = ProviderScope.containerOf(context, listen: false);
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _PlanDialog(current: m.planFromTarget ? m.planM2 : null),
    );
    if (value == null) return;
    try {
      await repo.setShopTarget(value <= 0 ? null : value);
      c.invalidate(shopBoardProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({this.current});

  final double? current;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final _value = TextEditingController(
    text: widget.current == null ? '' : widget.current!.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.shopPlanDialog),
      content: TextField(
        key: const ValueKey('shop:targetField'),
        controller: _value,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(helperText: l10n.shopPlanHint),
      ),
      actions: [
        TextButton(
          key: const ValueKey('shop:targetClear'),
          onPressed: () => Navigator.of(context).pop(0.0),
          child: Text(l10n.shopClear),
        ),
        FilledButton(
          key: const ValueKey('shop:targetSave'),
          onPressed: () => Navigator.of(context).pop(
            double.tryParse(_value.text.replaceAll(' ', '').replaceAll(',', '.')) ??
                0.0,
          ),
          child: Text(l10n.shopSave),
        ),
      ],
    );
  }
}

/// The road an order takes: Раскрой → ЧПУ → Шлифовка → Вакуум или Покраска
/// → Готово. A row on a wide screen, a column on a phone. Tap a stage for
/// its orders.
class ShopFlow extends StatelessWidget {
  const ShopFlow({
    required this.stages,
    required this.onSelect,
    this.selected,
    super.key,
  });

  final List<ShopStage> stages;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    ShopStage? of(MdfStage s) =>
        stages.where((x) => x.stage == s).firstOrNull;
    Widget box(MdfStage s) => switch (of(s)) {
      final x? => _StageBox(
        stage: x,
        selected: selected == s.name,
        onTap: () => onSelect(selected == s.name ? null : s.name),
      ),
      _ => const SizedBox.shrink(),
    };
    final theme = Theme.of(context);
    final arrow = Icon(
      AppIcons.forward,
      size: AppIconSize.inline,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      key: const ValueKey('shop:flow'),
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.sidebar) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, s) in [
                MdfStage.cut,
                MdfStage.mill,
                MdfStage.sand,
                MdfStage.vacuum,
                MdfStage.paint,
                MdfStage.ready,
              ].indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                box(s),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: box(MdfStage.cut)),
              arrow,
              Expanded(child: box(MdfStage.mill)),
              arrow,
              Expanded(child: box(MdfStage.sand)),
              arrow,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: box(MdfStage.vacuum)),
                    const SizedBox(height: AppSpacing.xs),
                    Expanded(child: box(MdfStage.paint)),
                  ],
                ),
              ),
              arrow,
              Expanded(child: box(MdfStage.ready)),
            ],
          ),
        );
      },
    );
  }
}

class _StageBox extends StatelessWidget {
  const _StageBox({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final ShopStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final s = stage;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ready = s.stage == MdfStage.ready;
    Widget line(String label, String value) => Row(
      children: [
        Expanded(child: Text(label, style: muted)),
        Text(value, style: theme.textTheme.labelLarge),
      ],
    );
    final border = selected
        ? theme.colorScheme.primary
        : s.jam
        ? status.warning
        : theme.colorScheme.outlineVariant;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: border,
          width: selected || s.jam ? AppSpacing.xxs : AppSpacing.xxs / 2,
        ),
      ),
      child: InkWell(
        key: ValueKey('stage:${s.stage.name}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mdfStageLabel(s.stage, l10n),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              line(
                ready ? l10n.shopToGive : l10n.shopWaiting,
                '${_m2(context, s.waitingM2)} м²',
              ),
              line(l10n.shopToday, '${_m2(context, s.todayM2)} м²'),
              line(l10n.shopMonthM2, '${_m2(context, s.monthM2)} м²'),
              if (s.days case final d? when !ready)
                Text(
                  [
                    l10n.shopDays(_m2(context, d)),
                    if (s.jam) l10n.shopJam,
                  ].join(' · '),
                  key: ValueKey('stage:${s.stage.name}:days'),
                  style: muted?.copyWith(
                    color: s.jam ? status.warning : status.success,
                  ),
                ),
              for (final post in s.posts) ...[
                const SizedBox(height: AppSpacing.xs),
                if (s.posts.length > 1)
                  Text(post.department ?? post.title, style: muted),
                if (post.people.isEmpty)
                  Text(
                    l10n.shopNobody,
                    key: ValueKey('stage:${s.stage.name}:nobody:${post.post}'),
                    style: muted?.copyWith(color: status.danger),
                  )
                else
                  for (final p in post.people)
                    Text(
                      [
                        p.name,
                        if (p.todayM2 > 0) '${_m2(context, p.todayM2)} м²',
                        if (p.inWork > 0) l10n.shopInWork(p.inWork),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Overdue, then those that will not make their date.
class ShopLateList extends StatelessWidget {
  const ShopLateList({required this.late, super.key});

  final List<ShopLate> late;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    return Column(
      key: const ValueKey('shop:late'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.shopLate),
        if (late.isEmpty)
          Text(
            l10n.shopNoLate,
            style: theme.textTheme.bodySmall?.copyWith(color: status.success),
          ),
        for (final o in late)
          ListTile(
            key: ValueKey('shop:late:${o.order}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              [if (o.number != null) '№${o.number}', ?o.customer].join(' · '),
            ),
            subtitle: Text(
              l10n.shopLateLine(
                _m2(context, o.areaM2),
                mdfStageLabel(o.stage, l10n),
              ),
            ),
            trailing: Text(
              o.overdue
                  ? l10n.shopOverdue
                  : l10n.shopDue(mdfDay(o.deliveryDate, year: false)),
              style: theme.textTheme.labelLarge?.copyWith(
                color: o.overdue ? status.danger : status.warning,
              ),
            ),
            onTap: () => context.push(Routes.mdfOrder(o.order)),
          ),
      ],
    );
  }
}

/// Film sales and the warehouse: their people and today's figures.
class ShopSideBlocks extends StatelessWidget {
  const ShopSideBlocks({required this.side, super.key});

  final List<ShopSide> side;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      key: const ValueKey('shop:side'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.shopSide),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final d in side)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppBreakpoints.minTileWidth,
                  maxWidth: AppBreakpoints.listPaneWidth,
                ),
                child: DecoratedBox(
                  key: ValueKey('shop:side:${d.department}'),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title, style: theme.textTheme.titleSmall),
                        if (d.department == 'film_sales') ...[
                          Text(
                            l10n.shopSales(
                              d.salesToday,
                              _m2(context, d.metresToday),
                            ),
                            style: muted,
                          ),
                          Text(
                            l10n.shopSalesMonth(_m2(context, d.metresMonth)),
                            style: muted,
                          ),
                        ] else
                          Text(l10n.shopReceived(d.receivedToday), style: muted),
                        for (final post in d.posts)
                          Text(
                            _who(post, l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: post.people.isEmpty ? status.danger : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// «Продажник: Ерлан, Асет» — or «никого».
String _who(ShopPost post, AppLocalizations l10n) {
  final names = post.people.isEmpty
      ? l10n.shopNobody
      : post.people.map((p) => p.name).join(', ');
  return '${post.title}: $names';
}
