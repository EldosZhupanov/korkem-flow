import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/charts/day_waterfall.dart';
import 'package:korkem_flow/core/design/widgets/charts/flow_bars.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Касса» of the film department (owner, 11.11.2026): its own money — what
/// customers paid for film, what bringing film cost — apart from the MDF
/// cash book. Below, what is still owed back to employees and to carriers.
class FilmCashTab extends ConsumerStatefulWidget {
  const FilmCashTab({super.key});

  @override
  ConsumerState<FilmCashTab> createState() => _FilmCashTabState();
}

class _FilmCashTabState extends ConsumerState<FilmCashTab> {
  /// 0 today, 1 yesterday, 7 the week, 30 the month; a picked day wins
  /// (owner, 12.11.2026).
  int _span = 0;
  DateTime? _day;

  /// The day tapped on the chart: the moves below are that day's alone.
  String? _picked;

  ({String? since, String? until}) get _period {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_day != null) return (since: mdfIso(_day!), until: mdfIso(_day!));
    return switch (_span) {
      1 => (
        since: mdfIso(today.subtract(const Duration(days: 1))),
        until: mdfIso(today.subtract(const Duration(days: 1))),
      ),
      7 => (
        since: mdfIso(today.subtract(const Duration(days: 6))),
        until: mdfIso(today),
      ),
      30 => (
        since: mdfIso(DateTime(now.year, now.month)),
        until: mdfIso(today),
      ),
      _ => (since: mdfIso(today), until: mdfIso(today)),
    };
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _settle(FilmOwed o, String method, String key) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(filmDeptRepositoryProvider);
    try {
      // Film taken on credit is paid to the supplier; a delivery is
      // settled with the employee or the carrier.
      await (key == 'supplier'
          ? repo.paySupplier(o.receipt, method)
          : repo.settleDelivery(o.receipt, method));
      ref.invalidate(filmCashProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final period = _period;
    final status = context.statusColors;
    return ref
        .watch(filmCashProvider(period))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(filmCashProvider(period)),
          ),
          data: (b) {
            // A day picked under another period is not this one's.
            final picked = b.days.any((d) => d.date == _picked)
                ? _picked
                : null;
            final moves = [
              for (final m in b.moves)
                if (picked == null || m.date == picked) m,
            ];
            Widget owedList(String title, List<FilmOwed> rows, String key) =>
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: theme.textTheme.titleMedium),
                    for (final o in rows)
                      ListTile(
                        key: ValueKey('filmCash:$key:${o.receipt}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          [o.who ?? '', money.format(o.amount)].join(' · '),
                        ),
                        subtitle: Text(
                          [mdfDay(o.date), ?o.supplier].join(' · '),
                        ),
                        // The carrier owed, a tap away (owner, 12.11.2026).
                        leading: o.phone == null || key != 'carrier'
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: ValueKey('filmCash:call:${o.receipt}'),
                                    icon: const Icon(AppIcons.call),
                                    onPressed: () =>
                                        ContactActions.call(o.phone),
                                  ),
                                  IconButton(
                                    key: ValueKey('filmCash:wa:${o.receipt}'),
                                    icon: const Icon(AppIcons.whatsApp),
                                    onPressed: () =>
                                        ContactActions.whatsApp(o.phone),
                                  ),
                                ],
                              ),
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('filmCash:settle:${o.receipt}'),
                          onSelected: (m) => _settle(o, m, key),
                          itemBuilder: (_) => [
                            for (final (m, label) in [
                              (filmCash, l10n.mdfPayCash),
                              (filmTransfer, l10n.mdfPayTransfer),
                              (filmCard, l10n.mdfPayCard),
                            ])
                              PopupMenuItem(
                                key: ValueKey('filmCash:settle:$m'),
                                value: m,
                                child: Text(l10n.filmSettleBy(label)),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              switch (key) {
                                'employee' => l10n.filmGaveBack,
                                'supplier' => l10n.filmPaidToSupplier,
                                _ => l10n.filmPaidCarrier,
                              },
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final (d, label) in [
                      (0, l10n.filmCashToday),
                      (1, l10n.filmYesterday),
                      (7, l10n.filmCashWeek),
                      (30, l10n.filmCashMonth),
                    ])
                      ChoiceChip(
                        key: ValueKey('filmCash:span:$d'),
                        label: Text(label),
                        selected: _day == null && _span == d,
                        onSelected: (_) => setState(() {
                          _day = null;
                          _span = d;
                        }),
                      ),
                    ActionChip(
                      key: const ValueKey('filmCash:day'),
                      avatar: const Icon(AppIcons.calendar),
                      label: Text(
                        _day == null ? l10n.filmArrivalPick : mdfDayOf(_day!),
                      ),
                      onPressed: _pickDay,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // In green, out in red, what is left (owner, 12.11.2026).
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CashCard(
                      key: const ValueKey('filmCash:in'),
                      label: l10n.filmCashIn,
                      value: '+${money.format(b.inTotal)}',
                      note: l10n.filmCashSales(b.sales),
                      color: status.success,
                      delta: _versus(l10n, b.inTotal, b.previous?.inTotal),
                    ),
                    _CashCard(
                      key: const ValueKey('filmCash:out'),
                      label: l10n.filmCashOut,
                      value: '−${money.format(b.outTotal)}',
                      note: l10n.filmCashSpent(b.spent),
                      color: status.danger,
                      delta: _versus(l10n, b.outTotal, b.previous?.outTotal),
                    ),
                    _CashCard(
                      key: const ValueKey('filmCash:balance'),
                      label: l10n.filmCashBalance,
                      value: money.format(b.balance),
                    ),
                  ],
                ),
                // The period as a chart (owner, 14.11.2026): one day as a
                // waterfall down to what is left; longer, a bar a day —
                // tap one and the moves below are that day's.
                const SizedBox(height: AppSpacing.md),
                if (period.since == period.until)
                  DayWaterfall(
                    key: const ValueKey('filmCash:waterfall'),
                    incoming: b.inTotal,
                    outgoing: b.outTotal,
                    labels: (
                      l10n.filmCashIn,
                      l10n.filmCashOut,
                      l10n.filmCashBalance,
                    ),
                    semanticLabel: l10n.filmCashChartA11y(
                      money.format(b.inTotal),
                      money.format(b.outTotal),
                    ),
                  )
                else if (b.days.isNotEmpty)
                  FlowBars(
                    key: const ValueKey('filmCash:chart'),
                    bars: [
                      for (final d in b.days)
                        FlowBar(
                          label: b.days.length <= 7
                              ? mdfDay(d.date, year: false)
                              : d.date.substring(8),
                          up: d.incoming,
                          down: d.outgoing,
                        ),
                    ],
                    selected: picked == null
                        ? null
                        : b.days.indexWhere((d) => d.date == picked),
                    onSelect: (i) => setState(
                      () => _picked = i == null ? null : b.days[i].date,
                    ),
                    semanticLabel: l10n.filmCashChartA11y(
                      money.format(b.inTotal),
                      money.format(b.outTotal),
                    ),
                  ),
                // «Закрыть день» — one day at a time (owner, 12.11.2026).
                if (period.since == period.until)
                  _CloseDay(
                    day: period.since!,
                    cash: b.where
                        .where((w) => w.way == filmCash)
                        .fold<double>(0, (s, w) => s + w.amount),
                    closed: b.closed,
                    onClosed: () => ref.invalidate(filmCashProvider),
                  ),
                if (b.where.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.filmCashWhere, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final w in b.where)
                        _CashCard(
                          key: ValueKey('filmCash:where:${w.way}'),
                          label: w.way,
                          value: money.format(w.amount),
                          icon: w.way == filmCash
                              ? AppIcons.payroll
                              : AppIcons.bank,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.filmCashMoves,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (picked != null)
                      InputChip(
                        key: const ValueKey('filmCash:picked'),
                        label: Text(mdfDay(picked, year: false)),
                        onDeleted: () => setState(() => _picked = null),
                      ),
                  ],
                ),
                if (moves.isEmpty) Text(l10n.filmCashNothing),
                for (final m in moves)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      border: Border(
                        left: BorderSide(
                          color: m.incoming ? status.success : status.danger,
                          width: AppSpacing.xs,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              mdfDay(m.date, year: false),
                              ?m.at,
                              m.what,
                              ?m.way,
                            ].join(' · '),
                          ),
                        ),
                        Text(
                          '${m.incoming ? '+' : '−'}${money.format(m.amount)}',
                          style: TextStyle(
                            color: m.incoming ? status.success : status.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                // For the owner's eye: what logistics costs — not in the
                // bonus (owner, 11.11.2026).
                Text(
                  b.logisticsPerM == null
                      ? l10n.filmCashLogistics(money.format(b.logistics))
                      : l10n.filmCashLogisticsPerM(
                          money.format(b.logistics),
                          money.format(b.logisticsPerM),
                        ),
                  key: const ValueKey('filmCash:logistics'),
                  style: theme.textTheme.bodySmall,
                ),
                if (b.employees.isNotEmpty)
                  owedList(l10n.filmOwedEmployees, b.employees, 'employee'),
                if (b.carriers.isNotEmpty)
                  owedList(l10n.filmOwedCarriers, b.carriers, 'carrier'),
                if (b.suppliers.isNotEmpty)
                  owedList(l10n.filmOwedSuppliers, b.suppliers, 'supplier'),
              ],
            );
          },
        );
  }
}

/// One figure of the cash on a card of its own — tinted when it is money
/// in or out.
/// «▲ 18% к прошлому периоду»: this period against the one before it;
/// nothing when there is nothing to compare with.
String? _versus(AppLocalizations l10n, double now, double? before) {
  if (before == null || before <= 0) return null;
  final change = (now - before) / before * 100;
  return l10n.filmCashVersus(
    change >= 0 ? '▲' : '▼',
    change.abs().round().toString(),
  );
}

class _CashCard extends StatelessWidget {
  const _CashCard({
    required this.label,
    required this.value,
    this.note,
    this.color,
    this.icon,
    this.delta,
    super.key,
  });

  final String label;
  final String value;
  final String? note;
  final Color? color;
  final IconData? icon;

  /// Against the period before: «▲ 18% к прошлому периоду».
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: AppSpacing.xxxl * 4,
      child: Card(
        color: color?.withValues(alpha: AppTint.surface),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppIconSize.dense),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              if (delta != null)
                Text(
                  delta!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseDay extends ConsumerWidget {
  const _CloseDay({
    required this.day,
    required this.cash,
    required this.closed,
    required this.onClosed,
  });

  final String day;
  final double cash;
  final ({
    double expected,
    double counted,
    double gap,
    String? reason,
    String? by,
  })?
  closed;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final c = closed;
    return Card(
      key: const ValueKey('filmCash:close'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: c == null
                  ? Text(l10n.filmCashShould(money.format(cash)))
                  : Text(
                      [
                        l10n.filmCashClosed(
                          money.format(c.counted),
                          c.by ?? '',
                        ),
                        if (c.gap.abs() >= 1)
                          l10n.filmCashGap(
                            '${c.gap > 0 ? '+' : '−'}'
                            '${money.format(c.gap.abs())}',
                            c.reason ?? '',
                          ),
                      ].join(' · '),
                      style: TextStyle(
                        color: c.gap.abs() >= 1
                            ? status.danger
                            : status.success,
                      ),
                    ),
            ),
            FilledButton.tonal(
              key: const ValueKey('filmCash:closeDay'),
              onPressed: () async {
                final done = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CloseDayDialog(day: day, expected: cash),
                );
                if (done ?? false) onClosed();
              },
              child: Text(
                c == null ? l10n.filmCashCloseDay : l10n.filmCashRecount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseDayDialog extends ConsumerStatefulWidget {
  const _CloseDayDialog({required this.day, required this.expected});

  final String day;
  final double expected;

  @override
  ConsumerState<_CloseDayDialog> createState() => _CloseDayDialogState();
}

class _CloseDayDialogState extends ConsumerState<_CloseDayDialog> {
  final _counted = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final counted = double.tryParse(_counted.text.trim().replaceAll(' ', ''));
    final gap = counted == null ? null : counted - widget.expected;
    final off = gap != null && gap.abs() >= 1;
    return AlertDialog(
      title: Text('${l10n.filmCashCloseDay} · ${mdfDay(widget.day)}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.filmCashShould(money.format(widget.expected))),
            TextField(
              key: const ValueKey('filmCash:counted'),
              controller: _counted,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.filmCashCounted),
            ),
            if (gap != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  off
                      ? (gap < 0
                            ? l10n.filmCashShort(money.format(-gap))
                            : l10n.filmCashOver(money.format(gap)))
                      : l10n.filmCashMatches,
                  style: TextStyle(
                    color: off ? status.danger : status.success,
                  ),
                ),
              ),
            if (off)
              TextField(
                key: const ValueKey('filmCash:reason'),
                controller: _reason,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.filmCashWhy),
              ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: status.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmCash:closeSave'),
          onPressed:
              _busy || counted == null || (off && _reason.text.trim().isEmpty)
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await ref
                        .read(filmDeptRepositoryProvider)
                        .closeDay(
                          widget.day,
                          counted,
                          reason: off ? _reason.text.trim() : null,
                        );
                    if (context.mounted) Navigator.of(context).pop(true);
                  } on Object catch (e) {
                    setState(() {
                      _busy = false;
                      _error = '$e';
                    });
                  }
                },
          child: Text(l10n.filmCashCloseDay),
        ),
      ],
    );
  }
}
