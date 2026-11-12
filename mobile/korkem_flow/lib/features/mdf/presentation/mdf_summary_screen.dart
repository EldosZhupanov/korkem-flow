import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_summary_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_summary.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_report_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Which days «Итоги» covers.
enum SummaryRange { week, month, lastMonth, year }

MdfPeriod summaryPeriodOf(SummaryRange range, DateTime today) {
  final f = DateFormat('yyyy-MM-dd');
  return switch (range) {
    SummaryRange.week => (
      since: f.format(today.subtract(const Duration(days: 6))),
      until: f.format(today),
    ),
    SummaryRange.month => reportPeriodOf(ReportRange.thisMonth, today),
    SummaryRange.lastMonth => reportPeriodOf(ReportRange.lastMonth, today),
    SummaryRange.year => reportPeriodOf(ReportRange.year, today),
  };
}

/// «Итоги МДФ» (owner, 12.11.2026: «итоговый отчёт по продажам, объёма, кто
/// сколько заказывает, какой клиент уснул… на шаг впереди»).
class MdfSummaryScreen extends ConsumerStatefulWidget {
  const MdfSummaryScreen({super.key, this.today});

  final DateTime? today;

  @override
  ConsumerState<MdfSummaryScreen> createState() => _MdfSummaryScreenState();
}

class _MdfSummaryScreenState extends ConsumerState<MdfSummaryScreen> {
  SummaryRange _range = SummaryRange.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final period = summaryPeriodOf(_range, widget.today ?? DateTime.now());
    final summary = ref.watch(mdfSummaryProvider(period));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mdfSumTitle),
        actions: [
          if (summary.value case final s?)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: OutlinedButton.icon(
                key: const ValueKey('mdfSum:share'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final text = mdfSummaryText(l10n, mdfMoney(context), s);
                  await Clipboard.setData(ClipboardData(text: text));
                  messenger?.showSnackBar(
                    SnackBar(content: Text(l10n.mdfSumCopied)),
                  );
                },
                icon: const Icon(AppIcons.share),
                label: Text(l10n.mdfSumShare),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SegmentedButton<SummaryRange>(
              segments: [
                ButtonSegment(
                  value: SummaryRange.week,
                  label: Text(l10n.mdfSumWeek),
                ),
                ButtonSegment(
                  value: SummaryRange.month,
                  label: Text(l10n.mdfReportThisMonth),
                ),
                ButtonSegment(
                  value: SummaryRange.lastMonth,
                  label: Text(l10n.mdfReportLastMonth),
                ),
                ButtonSegment(
                  value: SummaryRange.year,
                  label: Text(l10n.mdfReportYear),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          Expanded(
            child: summary.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(mdfSummaryProvider(period)),
              ),
              data: (s) => _Body(summary: s, period: period),
            ),
          ),
        ],
      ),
    );
  }
}

/// The period's summary in a few lines, to paste into WhatsApp.
String mdfSummaryText(AppLocalizations l10n, NumberFormat money, MdfSummary s) {
  final n = s.now;
  return [
    l10n.mdfSumTextHead(mdfDay(s.since), mdfDay(s.until)),
    l10n.mdfSumTextOrders(
      n.orders,
      n.areaM2.toStringAsFixed(1),
      money.format(n.total),
    ),
    l10n.mdfSumTextMoney(money.format(n.paid), money.format(n.debt)),
    if (mdfChange(n.areaM2, s.before.areaM2) case final c?)
      l10n.mdfSumTextChange(c > 0 ? '+$c' : '$c'),
    if (s.plan.forecastM2 case final f?)
      l10n.mdfSumTextForecast(f.toStringAsFixed(0)),
    if (s.asleep.isNotEmpty) l10n.mdfSumTextAsleep(s.asleep.length),
  ].join('\n');
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary, required this.period});

  final MdfSummary summary;
  final MdfPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final s = summary;
    final n = s.now;
    final b = s.before;
    return LayoutBuilder(
      builder: (context, box) {
        // Two columns of cards on a wide screen, one on a phone.
        final half = box.maxWidth >= 900
            ? (box.maxWidth - AppSpacing.md * 3) / 2
            : box.maxWidth - AppSpacing.md * 2;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Figure(
                  k: 'orders',
                  label: l10n.mdfReportOrders,
                  value: '${n.orders}',
                  change: mdfChange(n.orders.toDouble(), b.orders.toDouble()),
                ),
                _Figure(
                  k: 'area',
                  label: l10n.mdfReportArea,
                  value: '${n.areaM2.toStringAsFixed(1)} м²',
                  change: mdfChange(n.areaM2, b.areaM2),
                ),
                _Figure(
                  k: 'total',
                  label: l10n.mdfReportTotal,
                  value: money.format(n.total),
                  change: mdfChange(n.total, b.total),
                ),
                _Figure(
                  k: 'avg',
                  label: l10n.mdfSumAvg,
                  value: money.format(n.avgTotal),
                  note: l10n.mdfSumAvgNote(
                    n.avgArea.toStringAsFixed(1),
                    money.format(n.rateM2),
                  ),
                ),
                _Figure(
                  k: 'paid',
                  label: l10n.mdfReportPaid,
                  value: money.format(n.paid),
                  note: n.debt > 0
                      ? l10n.mdfReportOwes(money.format(n.debt))
                      : null,
                ),
                _Figure(
                  k: 'customers',
                  label: l10n.mdfSumCustomers,
                  value: '${s.customers}',
                  note: l10n.mdfSumNewCustomers(s.newCustomers),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final card in [
                  _PlanCard(plan: s.plan, period: period),
                  _ShopCard(shop: s.shop),
                  _TopCard(top: s.top),
                  _AsleepCard(asleep: s.asleep),
                  _FilmsCard(summary: s),
                  _DeadlinesCard(summary: s),
                  _DebtsCard(debts: s.debts),
                  _ManagersCard(summary: s),
                ])
                  SizedBox(width: half, child: card),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A figure with how it moved against the period before.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.k,
    required this.label,
    required this.value,
    this.change,
    this.note,
  });

  final String k;
  final String label;
  final String value;
  final int? change;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final c = change;
    return SizedBox(
      width: AppSpacing.xxxl * 4,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                key: ValueKey('mdfSum:$k'),
                style: theme.textTheme.titleLarge,
              ),
              if (c != null)
                Text(
                  c >= 0 ? l10n.mdfSumUp(c) : l10n.mdfSumDown(-c),
                  key: ValueKey('mdfSum:$k:change'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: c >= 0 ? status.success : status.danger,
                  ),
                )
              else if (note != null)
                Text(note!, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card of the summary.
class _Section extends StatelessWidget {
  const _Section({
    required this.k,
    required this.icon,
    required this.title,
    required this.children,
  });

  final String k;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('mdfSum:card:$k'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: AppSpacing.lg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// «label ……… value» — one line of a card.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.color, this.trailing, super.key});

  final String label;
  final String value;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan, required this.period});

  final MdfPlan plan;
  final MdfPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final p = plan;
    final goal = p.targetM2;
    final ahead = goal != null && (p.forecastM2 ?? 0) >= goal;

    Future<void> setGoal() async {
      final value = await showDialog<double?>(
        context: context,
        builder: (_) => _GoalDialog(current: goal),
      );
      if (value == null) return;
      await ref
          .read(mdfSummaryRepositoryProvider)
          .setTarget(value <= 0 ? null : value);
      ref.invalidate(mdfSummaryProvider(period));
    }

    return _Section(
      k: 'plan',
      icon: AppIcons.calendar,
      title: l10n.mdfSumPlan,
      children: [
        _Line(
          l10n.mdfSumPlanDone,
          '${p.doneM2.toStringAsFixed(1)} м²',
          trailing: IconButton(
            key: const ValueKey('mdfSum:goal'),
            tooltip: l10n.mdfSumGoalSet,
            icon: const Icon(AppIcons.edit),
            onPressed: setGoal,
          ),
        ),
        if (goal != null) ...[
          LinearProgressIndicator(
            value: (p.progress ?? 0.0) > 1 ? 1.0 : p.progress ?? 0.0,
            minHeight: AppSpacing.sm,
            color: ahead ? status.success : status.warning,
          ),
          _Line(
            l10n.mdfSumGoal,
            l10n.mdfSumGoalOf(
              goal.toStringAsFixed(0),
              ((p.progress ?? 0) * 100).round(),
            ),
          ),
        ] else
          Text(l10n.mdfSumGoalNone),
        if (p.forecastM2 != null)
          _Line(
            l10n.mdfSumForecast(p.daysLeft),
            '${p.forecastM2!.toStringAsFixed(0)} м² · '
            '${money.format(p.forecastTotal ?? 0)}',
            key: const ValueKey('mdfSum:forecast'),
            color: goal == null
                ? null
                : ahead
                ? status.success
                : status.danger,
          ),
      ],
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.current});

  final double? current;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _c = TextEditingController(
    text: widget.current?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mdfSumGoalSet),
      content: TextField(
        key: const ValueKey('mdfSum:goalField'),
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: l10n.mdfSumGoalM2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfSum:goalSave'),
          onPressed: () =>
              Navigator.of(context).pop(double.tryParse(_c.text.trim()) ?? 0),
          child: Text(l10n.mdfSaveDraft),
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});

  final MdfShop shop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final s = shop;
    return _Section(
      k: 'shop',
      icon: AppIcons.workOrder,
      title: l10n.mdfSumShop,
      children: [
        _Line(
          l10n.mdfSumInWork,
          l10n.mdfSumInWorkValue(s.inWorkM2.toStringAsFixed(1), s.inWorkOrders),
        ),
        _Line(l10n.mdfSumPace, l10n.mdfSumPaceValue(s.paceM2Day.toString())),
        if (s.readyOn != null)
          _Line(
            l10n.mdfSumNewReady,
            l10n.mdfSumNewReadyValue(
              s.queueDays ?? 0,
              mdfDay(s.readyOn, year: false),
            ),
            key: const ValueKey('mdfSum:readyOn'),
            color: status.warning,
          )
        else
          Text(l10n.mdfSumPaceUnknown),
        if (s.overdue > 0)
          _Line(
            l10n.mdfSumOverdueNow,
            '${s.overdue}',
            color: status.danger,
          ),
      ],
    );
  }
}

const _medals = ['🥇', '🥈', '🥉'];

class _TopCard extends StatelessWidget {
  const _TopCard({required this.top});

  final List<MdfTopCustomer> top;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _Section(
      k: 'top',
      icon: AppIcons.team,
      title: l10n.mdfSumTop,
      children: [
        if (top.isEmpty) Text(l10n.mdfSumNothing),
        for (final (i, c) in top.indexed)
          Padding(
            key: ValueKey('mdfSum:top:${c.customer}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.xl,
                  child: Text(i < _medals.length ? _medals[i] : '${i + 1}'),
                ),
                Expanded(
                  child: Text(
                    [
                      c.name,
                      if (c.tags.contains('furniture_maker')) l10n.mdfSumMaker,
                      if (c.tags.contains('vip')) 'VIP',
                      if (c.isNew) l10n.mdfSumNew,
                    ].join(' · '),
                  ),
                ),
                Text(
                  l10n.mdfSumTopValue(c.orders, c.areaM2.toStringAsFixed(1)),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AsleepCard extends StatelessWidget {
  const _AsleepCard({required this.asleep});

  final List<MdfAsleep> asleep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    return _Section(
      k: 'asleep',
      icon: AppIcons.call,
      title: l10n.mdfSumAsleep,
      children: [
        if (asleep.isEmpty) Text(l10n.mdfSumAsleepNone),
        for (final c in asleep.take(10))
          Padding(
            key: ValueKey('mdfSum:asleep:${c.customer}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: theme.textTheme.bodyMedium),
                      Text(
                        c.rhythmDays == null
                            ? l10n.mdfSumAsleepOnce(c.idleDays)
                            : l10n.mdfSumAsleepRhythm(
                                c.rhythmDays!,
                                c.idleDays,
                              ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  c.gone ? l10n.mdfSumGone : l10n.mdfSumDozing,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: c.gone ? status.danger : status.warning,
                  ),
                ),
                if (c.phone != null)
                  IconButton(
                    key: ValueKey('mdfSum:wake:${c.customer}'),
                    tooltip: l10n.filmWrite,
                    icon: const Icon(AppIcons.whatsApp),
                    onPressed: () => ContactActions.whatsAppMessage(
                      c.phone,
                      l10n.mdfSumWakeText(c.name),
                    ),
                  ),
              ],
            ),
          ),
        if (asleep.length > 10)
          Text(
            l10n.mdfSumMore(asleep.length - 10),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _FilmsCard extends ConsumerWidget {
  const _FilmsCard({required this.summary});

  final MdfSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final s = summary;

    Future<void> order(MdfFilmDemand f) async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        await ref
            .read(filmOrdersRepositoryProvider)
            .add(item: f.item!, metres: f.toBuyM);
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.mdfSumOrdered(f.decor))),
        );
      } on Object catch (e) {
        messenger?.showSnackBar(SnackBar(content: Text('$e')));
      }
    }

    return _Section(
      k: 'films',
      icon: AppIcons.delivery,
      title: l10n.mdfSumFilms,
      children: [
        if (s.films.isEmpty) Text(l10n.mdfSumNothing),
        for (final f in s.films)
          Padding(
            key: ValueKey('mdfSum:film:${f.decor}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(child: Text(f.decor)),
                if (f.areaM2 > 0)
                  Text(
                    '${f.areaM2.toStringAsFixed(1)} м²',
                    style: theme.textTheme.titleSmall,
                  ),
                const SizedBox(width: AppSpacing.sm),
                if (f.toBuyM > 0) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: status.danger.withValues(alpha: AppTint.surface),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      child: Text(
                        l10n.mdfSumFilmShort(f.toBuyM.toStringAsFixed(0)),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: status.danger,
                        ),
                      ),
                    ),
                  ),
                  if (f.item != null)
                    TextButton(
                      key: ValueKey('mdfSum:order:${f.decor}'),
                      onPressed: () => order(f),
                      child: Text(l10n.mdfSumToOrder),
                    ),
                ] else if (f.freeM != null)
                  Text(
                    l10n.mdfSumFilmEnough,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: status.success,
                    ),
                  ),
              ],
            ),
          ),
        if (s.millings.isNotEmpty) ...[
          const Divider(),
          Text(
            [
              for (final m in s.millings)
                '${m.milling} ${(m.share * 100).round()}%',
            ].join(' · '),
            key: const ValueKey('mdfSum:millings'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _DeadlinesCard extends StatelessWidget {
  const _DeadlinesCard({required this.summary});

  final MdfSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final d = summary.deadlines;
    final q = summary.quality;
    final share = d.onTimeShare;
    return _Section(
      k: 'deadlines',
      icon: AppIcons.calendar,
      title: l10n.mdfSumDeadlines,
      children: [
        if (share != null)
          _Line(
            l10n.mdfSumOnTime(d.handedOver),
            '${(share * 100).round()}%',
            key: const ValueKey('mdfSum:onTime'),
            color: share >= 0.9 ? status.success : status.warning,
          )
        else
          Text(l10n.mdfSumNoHandedOver),
        if (d.lateDaysAvg != null)
          _Line(l10n.mdfSumLateAvg, l10n.mdfSumDays(d.lateDaysAvg.toString())),
        _Line(
          l10n.mdfSumRework,
          l10n.mdfSumReworkValue(
            q.orders,
            q.areaM2.toStringAsFixed(1),
            (q.share * 100).round(),
          ),
          color: q.orders > 0 ? status.warning : null,
        ),
        if (q.reasons.isNotEmpty)
          Text(
            l10n.mdfSumReasons(
              [
                for (final r in q.reasons) '${r.reason} (${r.count})',
              ].join(', '),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _DebtsCard extends StatelessWidget {
  const _DebtsCard({required this.debts});

  final MdfDebts debts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final d = debts;
    return _Section(
      k: 'debts',
      icon: AppIcons.bank,
      title: l10n.mdfSumDebts,
      children: [
        _Line(l10n.mdfSumDebtWeek, money.format(d.week)),
        _Line(
          l10n.mdfSumDebtMonth,
          money.format(d.month),
          color: d.month > 0 ? status.warning : null,
        ),
        _Line(
          l10n.mdfSumDebtOlder,
          money.format(d.older),
          key: const ValueKey('mdfSum:debtOlder'),
          color: d.older > 0 ? status.danger : null,
        ),
        for (final o in d.oldest)
          _Line(
            l10n.mdfSumDebtor(o.name, o.days),
            money.format(o.debt),
            trailing: o.phone == null
                ? null
                : IconButton(
                    tooltip: l10n.filmWrite,
                    icon: const Icon(AppIcons.whatsApp),
                    onPressed: () => ContactActions.whatsAppMessage(
                      o.phone,
                      l10n.filmRemindText(o.name, money.format(o.debt)),
                    ),
                  ),
          ),
      ],
    );
  }
}

class _ManagersCard extends StatelessWidget {
  const _ManagersCard({required this.summary});

  final MdfSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    return _Section(
      k: 'managers',
      icon: AppIcons.team,
      title: l10n.mdfSumManagers,
      children: [
        if (summary.managers.isEmpty) Text(l10n.mdfSumNothing),
        for (final m in summary.managers)
          _Line(
            m.name,
            l10n.mdfSumManagerValue(
              m.orders,
              m.areaM2.toStringAsFixed(1),
              money.format(m.total),
            ),
          ),
      ],
    );
  }
}
