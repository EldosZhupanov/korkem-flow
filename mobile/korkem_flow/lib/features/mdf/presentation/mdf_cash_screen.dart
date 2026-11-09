import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_cash.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// How far back the cash book looks: today, the last 7 or 30 days.
enum CashRange { today, week, month }

/// The days [range] covers, ending on [today].
MdfPeriod cashPeriodOf(CashRange range, DateTime today) {
  final f = DateFormat('yyyy-MM-dd');
  final back = switch (range) {
    CashRange.today => 0,
    CashRange.week => 6,
    CashRange.month => 29,
  };
  return (
    since: f.format(today.subtract(Duration(days: back))),
    until: f.format(today),
  );
}

/// «Касса» — OnayBaza's «Төлем есебі»: what came in, by method, what went
/// out, and the balance, then day by day.
class MdfCashScreen extends ConsumerStatefulWidget {
  const MdfCashScreen({super.key, this.today});

  /// Fixed in tests; the device's date otherwise.
  final DateTime? today;

  @override
  ConsumerState<MdfCashScreen> createState() => _MdfCashScreenState();
}

class _MdfCashScreenState extends ConsumerState<MdfCashScreen> {
  CashRange _range = CashRange.today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final period = cashPeriodOf(_range, widget.today ?? DateTime.now());
    final cash = ref.watch(mdfCashProvider(period));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfCashTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<CashRange>(
              key: const ValueKey('cashRange'),
              segments: [
                ButtonSegment(
                  value: CashRange.today,
                  label: Text(l10n.mdfCashToday),
                ),
                ButtonSegment(
                  value: CashRange.week,
                  label: Text(l10n.mdfCashWeek),
                ),
                ButtonSegment(
                  value: CashRange.month,
                  label: Text(l10n.mdfCashMonth),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          Expanded(
            child: cash.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(mdfCashProvider(period)),
              ),
              data: (c) => RefreshIndicator(
                onRefresh: () => ref.refresh(mdfCashProvider(period).future),
                child: _CashBody(cash: c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashBody extends StatelessWidget {
  const _CashBody({required this.cash});

  final MdfCash cash;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final c = cash;
    Widget total(String key, String label, double value, {Color? color}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                money.format(value),
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
              total('cashIn', l10n.mdfCashIn, c.totalIn),
              total('cashOut', l10n.mdfCashOut, c.totalOut),
              total(
                'cashNet',
                l10n.mdfCashNet,
                c.net,
                color: c.net < 0 ? theme.colorScheme.error : null,
              ),
            ],
          ),
        ),
        if (c.byMethod.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final e in c.byMethod.entries)
                StatusChip(
                  key: ValueKey('cashMethod:${e.key}'),
                  label: [
                    '${e.key}: ${money.format(e.value)}',
                    if (c.byBank[e.key]?.isNotEmpty ?? false)
                      '(${_banks(c.byBank[e.key]!, money)})',
                  ].join(' '),
                  intent: StatusIntent.success,
                ),
            ],
          ),
        ],
        if (c.days.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.mdfCashByDay)),
          for (final d in c.days)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('cashDay:${d.date}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(mdfDay(d.date)),
                subtitle: d.byMethod.isEmpty
                    ? null
                    : Text(
                        [
                          for (final e in d.byMethod.entries)
                            '${e.key} ${money.format(e.value)}',
                        ].join(' · '),
                      ),
                trailing: Text(
                  '+${money.format(d.moneyIn)}  −${money.format(d.moneyOut)}',
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ReadableWidth(child: SectionLabel(l10n.mdfCashPayments)),
        if (c.payments.isEmpty)
          ReadableWidth(child: Text(l10n.mdfCashNoPayments)),
        for (final p in c.payments)
          ReadableWidth(
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${p.order} · ${p.customerName}'),
              subtitle: Text(
                [mdfDay(p.date), p.method, ?p.bank].join(' · '),
              ),
              trailing: Text(money.format(p.amount)),
              onTap: () => context.push(Routes.mdfOrder(p.order)),
            ),
          ),
        if (c.expenses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.mdfCashExpenses)),
          for (final e in c.expenses)
            ReadableWidth(
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.purpose),
                subtitle: Text('${mdfDay(e.date)} · ${e.category}'),
                trailing: Text('−${money.format(e.amount)}'),
              ),
            ),
        ],
      ],
    );
  }
}

/// «Kaspi 300 000 ₸, Halyk 100 000 ₸» — a method's money by bank.
String _banks(Map<String, double> banks, NumberFormat money) => [
  for (final b in banks.entries) '${b.key} ${money.format(b.value)}',
].join(', ');
