import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_report.dart';
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

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final MdfReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final r = report;
    String line(ReportGroup g) => l10n.mdfReportLine(
      '${g.orders}',
      g.areaM2.toStringAsFixed(2),
      money.format(g.total),
    );
    Widget figure(String key, String label, String value, {Color? color}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                value,
                key: ValueKey(key),
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        ReadableWidth(
          child: Row(
            children: [
              figure('reportOrders', l10n.mdfReportOrders, '${r.all.orders}'),
              figure(
                'reportArea',
                l10n.mdfReportArea,
                '${r.all.areaM2.toStringAsFixed(2)} м²',
              ),
              figure(
                'reportTotal',
                l10n.mdfReportTotal,
                money.format(r.all.total),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ReadableWidth(
          child: Row(
            children: [
              figure(
                'reportPaid',
                l10n.mdfReportPaid,
                money.format(r.all.paid),
              ),
              figure(
                'reportDebt',
                l10n.mdfReportDebt,
                money.format(r.all.debt),
                color: r.all.debt > 0 ? theme.colorScheme.error : null,
              ),
              figure(
                'reportCancelled',
                l10n.mdfReportCancelled,
                '${r.cancelled}',
              ),
            ],
          ),
        ),
        if (r.byStatus.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
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
        if (r.byDecor.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.mdfReportByDecor)),
          for (final g in r.byDecor)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('reportDecor:${g.key}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(g.key),
                subtitle: Text(line(g)),
              ),
            ),
        ],
        if (r.topCustomers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.mdfReportTopCustomers)),
          for (final g in r.topCustomers)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('reportCustomer:${g.key}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(g.label ?? g.key),
                subtitle: Text(line(g)),
                trailing: g.debt > 0
                    ? Text(
                        l10n.mdfReportOwes(money.format(g.debt)),
                        style: TextStyle(color: theme.colorScheme.error),
                      )
                    : null,
              ),
            ),
        ],
      ],
    );
  }
}
