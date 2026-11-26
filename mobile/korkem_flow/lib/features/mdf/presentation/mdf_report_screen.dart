import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_report.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Which orders the report covers, by the order's date.
enum ReportRange { thisMonth, lastMonth, year }

MdfPeriod reportPeriodOf(ReportRange range, DateTime today) {
  final f = DateFormat('yyyy-MM-dd');
  final (since, until) = switch (range) {
    ReportRange.thisMonth => (DateTime(today.year, today.month), today),
    ReportRange.lastMonth => (
      DateTime(today.year, today.month - 1),
      DateTime(today.year, today.month, 0),
    ),
    ReportRange.year => (DateTime(today.year), today),
  };
  return (since: f.format(since), until: f.format(until));
}

/// «Отчёт по заказам» — OnayBaza's «Тапсырыс есебі»: what was taken in the
/// period, by status, by film, and who brought the most.
class MdfReportScreen extends ConsumerStatefulWidget {
  const MdfReportScreen({super.key, this.today});

  final DateTime? today;

  @override
  ConsumerState<MdfReportScreen> createState() => _MdfReportScreenState();
}

class _MdfReportScreenState extends ConsumerState<MdfReportScreen> {
  ReportRange _range = ReportRange.thisMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final period = reportPeriodOf(_range, widget.today ?? DateTime.now());
    final report = ref.watch(mdfReportProvider(period));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfReportTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<ReportRange>(
              segments: [
                ButtonSegment(
                  value: ReportRange.thisMonth,
                  label: Text(l10n.mdfReportThisMonth),
                ),
                ButtonSegment(
                  value: ReportRange.lastMonth,
                  label: Text(l10n.mdfReportLastMonth),
                ),
                ButtonSegment(
                  value: ReportRange.year,
                  label: Text(l10n.mdfReportYear),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(mdfReportProvider(period)),
              ),
              data: (r) => _ReportBody(report: r),
            ),
          ),
        ],
      ),
    );
  }
}

/// The report's cuts, one at a time (owner, 26.11.2026).
enum _Cut { decor, customers, milling, coating, managers }

class _ReportBody extends StatefulWidget {
  const _ReportBody({required this.report});

  final MdfReport report;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  _Cut _cut = _Cut.decor;

  /// «+12%» against the period before; null — nothing to compare with.
  static double? _change(double now, double? before) =>
      before == null || before <= 0 ? null : (now - before) / before * 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final m2 = NumberFormat('#,##0.00', locale);
    final r = widget.report;
    final all = r.all;
    final prev = r.previous;
    double avg(ReportGroup? g) =>
        g == null || g.orders == 0 ? 0 : g.total / g.orders;
    double perM2(ReportGroup? g) =>
        g == null || g.areaM2 <= 0 ? 0 : g.total / g.areaM2;
    Widget figure(
      String key,
      String label,
      String value, {
      double? change,
      String? note,
      Color? color,
      bool lessIsBetter = false,
    }) {
      final up = change != null && change >= 0.5;
      final down = change != null && change <= -0.5;
      final good = lessIsBetter ? down : up;
      final bad = lessIsBetter ? up : down;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.xxs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                value,
                key: ValueKey(key),
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
              if (change != null)
                Text(
                  l10n.mdfReportChange(
                    '${change >= 0 ? '+' : '−'}${change.abs().round()}%',
                  ),
                  key: ValueKey('$key:change'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: good
                        ? status.success
                        : bad
                        ? status.danger
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (note != null)
                Text(
                  note,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color ?? theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final debtShare = all.total > 0 ? all.debt / all.total * 100 : 0.0;
    final (rows, rowKey) = switch (_cut) {
      _Cut.decor => (r.byDecor, 'reportDecor'),
      _Cut.customers => (r.topCustomers, 'reportCustomer'),
      _Cut.milling => (r.byMilling, 'reportMilling'),
      _Cut.coating => (r.byCoating, 'reportCoating'),
      _Cut.managers => (r.byManager, 'reportManager'),
    };
    String name(ReportGroup g) {
      final label = g.label?.trim() ?? '';
      if (label.isNotEmpty && label != '—') return label;
      if (g.key.isNotEmpty && g.key != '—') return g.key;
      return switch (_cut) {
        _Cut.decor => l10n.mdfReportNoFilm,
        _Cut.milling => l10n.mdfReportNoMilling,
        _ => l10n.mdfReportUnknown,
      };
    }

    // A film or a customer: its orders a tap away.
    String? search(ReportGroup g) => switch (_cut) {
      _Cut.decor when g.key.isNotEmpty && g.key != '—' => g.key,
      _Cut.customers => g.label ?? g.key,
      _ => null,
    };
    final widest = rows.fold<double>(0, (m, g) => g.total > m ? g.total : m);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  figure(
                    'reportOrders',
                    l10n.mdfReportOrders,
                    '${all.orders}',
                    change: _change(
                      all.orders.toDouble(),
                      prev?.orders.toDouble(),
                    ),
                  ),
                  figure(
                    'reportArea',
                    l10n.mdfReportArea,
                    '${m2.format(all.areaM2)} м²',
                    change: _change(all.areaM2, prev?.areaM2),
                  ),
                  figure(
                    'reportTotal',
                    l10n.mdfReportTotal,
                    money.format(all.total),
                    change: _change(all.total, prev?.total),
                  ),
                  figure(
                    'reportAverage',
                    l10n.mdfReportAverage,
                    money.format(avg(all)),
                    change: _change(avg(all), prev == null ? null : avg(prev)),
                  ),
                ],
              ),
              Row(
                children: [
                  figure(
                    'reportPaid',
                    l10n.mdfReportPaid,
                    money.format(all.paid),
                  ),
                  figure(
                    'reportDebt',
                    l10n.mdfReportDebt,
                    money.format(all.debt),
                    color: all.debt > 0 ? theme.colorScheme.error : null,
                    note: all.total > 0
                        ? l10n.mdfReportDebtShare(debtShare.round())
                        : null,
                  ),
                  figure(
                    'reportPerM2',
                    l10n.mdfReportPerM2,
                    money.format(perM2(all)),
                    change: _change(
                      perM2(all),
                      prev == null ? null : perM2(prev),
                    ),
                  ),
                  figure(
                    'reportCancelled',
                    l10n.mdfReportCancelled,
                    '${r.cancelled}',
                  ),
                ],
              ),
              if (prev != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.mdfReportComparedWith(
                      mdfDay(r.previousSince),
                      mdfDay(r.previousUntil),
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (r.byStatus.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final g in r.byStatus)
                      () {
                        final (label, intent) = mdfStatusChip(
                          MdfStatus.parse(g.key),
                          l10n,
                        );
                        return StatusChip(
                          key: ValueKey('reportStatus:${g.key}'),
                          label: '$label: ${g.orders}',
                          intent: intent,
                        );
                      }(),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_Cut>(
                  showSelectedIcon: false,
                  segments: [
                    for (final (c, label) in [
                      (_Cut.decor, l10n.mdfReportByDecor),
                      (_Cut.customers, l10n.mdfReportTopCustomers),
                      (_Cut.milling, l10n.mdfReportByMilling),
                      (_Cut.coating, l10n.mdfReportByCoating),
                      (_Cut.managers, l10n.mdfReportByManager),
                    ])
                      ButtonSegment(
                        value: c,
                        label: Text(
                          label,
                          key: ValueKey('reportTab:${c.name}'),
                        ),
                      ),
                  ],
                  selected: {_cut},
                  onSelectionChanged: (s) => setState(() => _cut = s.first),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final g in rows)
                InkWell(
                  key: ValueKey('$rowKey:${g.key}'),
                  onTap: switch (search(g)) {
                    final text? => () => unawaited(
                      context.push(Routes.mdfOrdersOf(text)),
                    ),
                    null => null,
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            name(g),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  widthFactor: widest <= 0
                                      ? 0
                                      : (g.total / widest).clamp(0.02, 1.0),
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Container(
                                    height: AppSpacing.sm,
                                    decoration: BoxDecoration(
                                      color: status.success,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xs,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                all.total <= 0
                                    ? ''
                                    : '${(g.total / all.total * 100).round()}%',
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l10n.mdfReportLine(
                                  '${g.orders}',
                                  m2.format(g.areaM2),
                                  money.format(g.total),
                                ),
                                textAlign: TextAlign.end,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (_cut == _Cut.customers && g.debt > 0)
                                Text(
                                  l10n.mdfReportOwes(money.format(g.debt)),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l10n.mdfReportNothing,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
