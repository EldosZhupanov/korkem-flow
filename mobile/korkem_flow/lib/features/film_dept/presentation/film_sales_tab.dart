import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/charts/bar_rows.dart';
import 'package:korkem_flow/core/design/widgets/charts/flow_bars.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Which days the sales are shown for.
enum FilmSalesPeriod { today, week, month, custom }

/// The days of a period, ending [today]; and the same number of days
/// before it, to compare with.
({String since, String until, String prevSince, String prevUntil})
filmSalesRange(
  FilmSalesPeriod period,
  DateTime today, {
  DateTimeRange? picked,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final (from, to) = switch (period) {
    FilmSalesPeriod.today => (day, day),
    FilmSalesPeriod.week => (day.subtract(const Duration(days: 6)), day),
    FilmSalesPeriod.month => (DateTime(day.year, day.month), day),
    FilmSalesPeriod.custom => (picked?.start ?? day, picked?.end ?? day),
  };
  final days = to.difference(from).inDays + 1;
  final prevTo = from.subtract(const Duration(days: 1));
  final prevFrom = prevTo.subtract(Duration(days: days - 1));
  return (
    since: mdfIso(from),
    until: mdfIso(to),
    prevSince: mdfIso(prevFrom),
    prevUntil: mdfIso(prevTo),
  );
}

/// Which sales the list shows.
enum FilmSalesFilter { all, paid, debt, wholesale }

bool filmSaleShown(FilmSale s, FilmSalesFilter f, String query) {
  final ok = switch (f) {
    FilmSalesFilter.all => true,
    FilmSalesFilter.paid => (s.debt ?? 0) <= 0.5,
    FilmSalesFilter.debt => (s.debt ?? 0) > 0.5,
    FilmSalesFilter.wholesale => s.wholesale,
  };
  if (!ok) return false;
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [
    s.customerName ?? '',
    for (final l in s.lines) l.title,
  ].any((t) => t.toLowerCase().contains(q));
}

/// «Продажи» (owner, 13.11.2026): the period's figures against the one
/// before; the sales by day with each day's total; how each was paid at a
/// glance; who owes, a reminder a tap away.
class FilmSalesTab extends ConsumerStatefulWidget {
  const FilmSalesTab({this.today, super.key});

  /// «Today» — for tests; the clock's otherwise.
  final DateTime? today;

  @override
  ConsumerState<FilmSalesTab> createState() => _FilmSalesTabState();
}

class _FilmSalesTabState extends ConsumerState<FilmSalesTab> {
  FilmSalesPeriod _period = FilmSalesPeriod.today;
  DateTimeRange? _picked;
  FilmSalesFilter _filter = FilmSalesFilter.all;
  String _query = '';

  DateTime get _today => widget.today ?? DateTime.now();

  void _refresh() {
    ref
      ..invalidate(filmSalesPeriodProvider)
      ..invalidate(filmSalesProvider)
      ..invalidate(filmStockProvider)
      ..invalidate(filmCustomersProvider);
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: _today,
      initialDateRange: _picked,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _picked = picked;
      _period = FilmSalesPeriod.custom;
    });
  }

  Future<void> _sell() async {
    final stock = await ref.read(filmStockProvider.future);
    if (!mounted) return;
    final done = await showFilmSale(context, stock);
    if (done ?? false) _refresh();
  }

  Future<void> _open(FilmSale s) async {
    final done = await showFilmSaleCard(context, s);
    if (done ?? false) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final range = filmSalesRange(_period, _today, picked: _picked);
    final now = ref.watch(
      filmSalesPeriodProvider((since: range.since, until: range.until)),
    );
    final before = ref
        .watch(
          filmSalesPeriodProvider((
            since: range.prevSince,
            until: range.prevUntil,
          )),
        )
        .value;
    final stock = ref.watch(filmStockProvider).value;
    final customers =
        ref.watch(filmCustomersProvider).value ?? const <FilmCustomer>[];
    final canSell = stock?.canEdit ?? false;
    return now.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: _refresh),
      data: (sales) {
        final rows = [
          for (final s in sales)
            if (filmSaleShown(s, _filter, _query)) s,
        ];
        int count(FilmSalesFilter f) =>
            sales.where((s) => filmSaleShown(s, f, '')).length;
        final days = <String, List<FilmSale>>{};
        for (final s in rows) {
          (days[s.date] ??= []).add(s);
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (p, label) in [
                  (FilmSalesPeriod.today, l10n.filmSalesToday),
                  (FilmSalesPeriod.week, l10n.filmSalesWeek),
                  (FilmSalesPeriod.month, l10n.filmSalesMonth),
                ])
                  ChoiceChip(
                    key: ValueKey('filmSales:period:${p.name}'),
                    label: Text(label),
                    selected: _period == p,
                    onSelected: (_) => setState(() => _period = p),
                  ),
                ChoiceChip(
                  key: const ValueKey('filmSales:period:custom'),
                  avatar: const Icon(AppIcons.calendar),
                  label: Text(
                    _period == FilmSalesPeriod.custom
                        ? '${mdfDay(range.since, year: false)} — '
                              '${mdfDay(range.until, year: false)}'
                        : l10n.filmSalesPeriod,
                  ),
                  selected: _period == FilmSalesPeriod.custom,
                  onSelected: (_) => _pickPeriod(),
                ),
                if (canSell)
                  FilledButton.icon(
                    key: const ValueKey('filmSales:sell'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.statusColors.info,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                    ),
                    onPressed: _sell,
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.filmSell),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // A quiet today is not an empty page (owner, 14.11.2026):
            // what yesterday brought stands in its place.
            if (_period == FilmSalesPeriod.today &&
                sales.isEmpty &&
                (before?.isNotEmpty ?? false))
              _Yesterday(sales: before!),
            _Figures(
              sales: sales,
              before: before,
              customers: customers,
              onDebt: () => setState(() => _filter = FilmSalesFilter.debt),
            ),
            if (sales.isNotEmpty && range.since != range.until)
              _Insight(sales: sales, since: range.since, until: range.until),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final f in FilmSalesFilter.values)
                  ChoiceChip(
                    key: ValueKey('filmSales:filter:${f.name}'),
                    label: Text(switch (f) {
                      FilmSalesFilter.all => l10n.filmSalesAll(count(f)),
                      FilmSalesFilter.paid => l10n.filmSalesPaid(count(f)),
                      FilmSalesFilter.debt => l10n.filmSalesDebt(count(f)),
                      FilmSalesFilter.wholesale => l10n.filmSalesWholesale(
                        count(f),
                      ),
                    }),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                SizedBox(
                  width: AppSpacing.xxxl * 5,
                  child: TextField(
                    key: const ValueKey('filmSales:search'),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(AppIcons.search),
                      hintText: l10n.filmSalesSearch,
                    ),
                  ),
                ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l10n.filmSalesEmpty),
              ),
            for (final MapEntry(key: day, value: list) in days.entries) ...[
              _DayHead(day: day, sales: list, today: _today),
              for (final s in list)
                _SaleRow(
                  key: ValueKey('filmSaleRow:${rows.indexOf(s)}'),
                  sale: s,
                  stock: stock,
                  phone: customers
                      .where((c) => c.customer == s.customer)
                      .firstOrNull
                      ?.phone,
                  onTap: () => _open(s),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// The period's figures: sales, metres, the money against the period
/// before, what it earned, what is not paid — a tap shows who owes.
class _Figures extends StatelessWidget {
  const _Figures({
    required this.sales,
    required this.before,
    required this.customers,
    required this.onDebt,
  });

  final List<FilmSale> sales;
  final List<FilmSale>? before;
  final List<FilmCustomer> customers;
  final VoidCallback onDebt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final metres = sales.fold<double>(0, (s, x) => s + x.metres);
    final amount = sales.fold<double>(0, (s, x) => s + (x.amount ?? 0));
    final sees = sales.any((x) => x.amount != null);
    final profits = [
      for (final x in sales)
        if (x.profit != null) x.profit!,
    ];
    final owing = sales.where((x) => (x.debt ?? 0) > 0.5).toList();
    final debt = owing.fold<double>(0, (s, x) => s + x.debt!);
    final was = before?.fold<double>(0, (s, x) => s + (x.amount ?? 0));
    final change = was == null || was <= 0
        ? null
        : ((amount - was) / was * 100).round();
    Widget tile(
      String key,
      String label,
      String value, {
      Color? colour,
      String? under,
      Color? underColour,
      VoidCallback? onTap,
    }) => SizedBox(
      width: AppSpacing.xxxl * 3.5,
      child: Card(
        key: ValueKey('filmSales:kpi:$key'),
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colour,
                  ),
                ),
                if (under != null)
                  Text(
                    under,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: underColour,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        tile('count', l10n.filmSalesSold, l10n.filmSalesCount(sales.length)),
        tile('metres', l10n.filmSalesMetres, '${filmMetres(metres)} м'),
        if (sees)
          tile(
            'amount',
            l10n.filmSalesAmount,
            money.format(amount),
            under: change == null
                ? null
                : l10n.filmSalesChange(
                    '${change >= 0 ? '▲' : '▼'} ${change.abs()}',
                  ),
            underColour: change == null
                ? null
                : change >= 0
                ? status.success
                : status.danger,
          ),
        // What one sale brings, on average.
        if (sees && sales.length > 1)
          tile(
            'average',
            l10n.filmSalesAverage,
            money.format(amount / sales.length),
            under: '${filmMetres(metres / sales.length)} м',
          ),
        if (profits.isNotEmpty)
          tile(
            'profit',
            l10n.filmSalesProfit,
            '≈ ${money.format(profits.fold<double>(0, (s, p) => s + p))}',
            colour: status.success,
          ),
        if (sees)
          tile(
            'debt',
            l10n.filmSalesUnpaid,
            money.format(debt),
            colour: debt > 0 ? status.danger : status.success,
            under: debt > 0
                ? l10n.filmSalesDebtors(
                    owing.map((x) => x.customer).toSet().length,
                  )
                : null,
            onTap: debt > 0
                ? () => showFilmDebtors(context, customers, onShow: onDebt)
                : null,
          ),
      ],
    );
  }
}

/// «Сегодня продаж ещё нет» — and what yesterday brought.
class _Yesterday extends StatelessWidget {
  const _Yesterday({required this.sales});

  final List<FilmSale> sales;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metres = sales.fold<double>(0, (s, x) => s + x.metres);
    final amount = sales.fold<double>(0, (s, x) => s + (x.amount ?? 0));
    return Card(
      key: const ValueKey('filmSales:yesterday'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          [
            l10n.filmSalesQuietToday,
            l10n.filmSalesYesterdayWas(
              l10n.filmSalesCount(sales.length),
              filmMetres(metres),
            ),
            if (sales.any((x) => x.amount != null))
              mdfMoney(context).format(amount),
          ].join(' · '),
        ),
      ),
    );
  }
}

/// How many of the best are named.
const _top = 5;

/// From this width the chart and the two tops stand side by side.
const double _wide = 900;

/// A period of several days at a glance (owner, 14.11.2026): the metres
/// sold day by day, the films that sold most and who bought most.
class _Insight extends StatelessWidget {
  const _Insight({
    required this.sales,
    required this.since,
    required this.until,
  });

  final List<FilmSale> sales;
  final String since;
  final String until;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final byDay = <String, double>{};
    final byFilm = <String, double>{};
    final byCustomer = <String, double>{};
    for (final s in sales) {
      byDay[s.date] = (byDay[s.date] ?? 0) + s.metres;
      final who = s.customerName ?? s.customer ?? '—';
      byCustomer[who] = (byCustomer[who] ?? 0) + s.metres;
      for (final l in s.lines) {
        byFilm[l.title] = (byFilm[l.title] ?? 0) + l.metres;
      }
    }
    // Every day of the period, the quiet ones too.
    final from = DateTime.tryParse(since);
    final to = DateTime.tryParse(until);
    final days = [
      if (from != null && to != null)
        for (
          var d = from;
          !d.isAfter(to);
          d = DateTime(d.year, d.month, d.day + 1)
        )
          mdfIso(d),
    ];
    List<BarRow> top(Map<String, double> by, String prefix, Color? colour) {
      final rows = by.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return [
        for (final e in rows.take(_top))
          BarRow(
            id: '$prefix:${e.key}',
            label: e.key,
            value: e.value,
            note: '${filmMetres(e.value)} м',
            color: colour,
          ),
      ];
    }

    final total = sales.fold<double>(0, (s, x) => s + x.metres);
    Widget block(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
    final chart = block(
      l10n.filmSalesByDay,
      FlowBars(
        key: const ValueKey('filmSales:chart'),
        bars: [
          for (final d in days)
            FlowBar(
              label: days.length <= 7 ? mdfDay(d, year: false) : d.substring(8),
              up: byDay[d] ?? 0,
            ),
        ],
        semanticLabel: l10n.filmSalesChartA11y(filmMetres(total)),
      ),
    );
    final films = block(
      l10n.filmSalesTopFilms,
      BarRows(
        key: const ValueKey('filmSales:topFilms'),
        rows: top(byFilm, 'film', null),
      ),
    );
    final customers = block(
      l10n.filmSalesTopCustomers,
      BarRows(
        key: const ValueKey('filmSales:topCustomers'),
        rows: top(byCustomer, 'customer', status.info),
      ),
    );
    return Padding(
      key: const ValueKey('filmSales:insight'),
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: LayoutBuilder(
        // Side by side where there is room, so the list stays in sight.
        builder: (context, box) => box.maxWidth >= _wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: chart),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: films),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: customers),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  chart,
                  const SizedBox(height: AppSpacing.md),
                  films,
                  const SizedBox(height: AppSpacing.md),
                  customers,
                ],
              ),
      ),
    );
  }
}

/// A day's head: which day, and its sales, metres and money.
class _DayHead extends StatelessWidget {
  const _DayHead({required this.day, required this.sales, required this.today});

  final String day;
  final List<FilmSale> sales;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final date = DateTime.tryParse(day);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final yesterday = mdfIso(today.subtract(const Duration(days: 1)));
    final short = mdfDay(day, year: false);
    final name = date == null
        ? day
        : mdfIso(date) == mdfIso(today)
        ? l10n.filmSalesTodayOn(short)
        : mdfIso(date) == yesterday
        ? l10n.filmSalesYesterdayOn(short)
        : '${mdfDay(day)} · ${DateFormat.EEEE(locale).format(date)}';
    final amount = sales.fold<double>(0, (s, x) => s + (x.amount ?? 0));
    final metres = sales.fold<double>(0, (s, x) => s + x.metres);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              key: ValueKey('filmSales:day:$day'),
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text(
            [
              l10n.filmSalesCount(sales.length),
              '${filmMetres(metres)} м',
              if (sales.any((x) => x.amount != null)) money.format(amount),
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One sale: when, who, the films with their colour, the money, and how
/// it was paid — green paid, orange part, red owing with a reminder.
class _SaleRow extends StatelessWidget {
  const _SaleRow({
    required this.sale,
    required this.stock,
    required this.phone,
    required this.onTap,
    super.key,
  });

  final FilmSale sale;
  final FilmCatalog? stock;
  final String? phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final s = sale;
    final debt = s.debt ?? 0;
    final paid = s.paid ?? 0;
    final (label, colour) = s.amount == null
        ? (null, null)
        : debt <= 0.5
        ? (
            [
              l10n.filmSalesPaidMark,
              ?s.method,
            ].join(' · '),
            status.success,
          )
        : paid > 0
        ? (l10n.filmSalesPartly(money.format(debt)), status.warning)
        : (l10n.filmSaleDebt(money.format(debt)), status.danger);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppSpacing.xxxl,
              child: Text(s.time ?? '', style: theme.textTheme.bodySmall),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: s.customerName ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (s.wholesale)
                          TextSpan(
                            text: ' · ${l10n.filmSalesWholesaleMark}',
                            style: TextStyle(color: status.warning),
                          ),
                      ],
                    ),
                  ),
                  for (final line in s.lines)
                    Row(
                      children: [
                        if (stock?.film(line.item)?.argb case final argb?) ...[
                          SizedBox.square(
                            dimension: AppIconSize.dense,
                            child: FilmSample(argb: argb),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            '${line.title} — ${filmMetres(line.metres)} м',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (s.amount != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money.format(s.amount),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (s.lines.length == 1 && s.lines.single.priceM != null)
                    Text(
                      l10n.filmSalesPerM(
                        money.format(s.lines.single.priceM),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (label != null)
                    Container(
                      key: ValueKey('filmSales:state:${s.entry}'),
                      margin: const EdgeInsets.only(top: AppSpacing.xxs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colour!.withValues(alpha: AppTint.surface),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colour,
                        ),
                      ),
                    ),
                ],
              ),
            if (debt > 0.5 && phone != null)
              IconButton(
                key: ValueKey('filmSales:remind:${s.entry}'),
                tooltip: l10n.filmRemind,
                icon: Icon(AppIcons.whatsApp, color: status.success),
                onPressed: () => ContactActions.whatsAppMessage(
                  phone,
                  l10n.filmRemindText(
                    s.customerName ?? '',
                    money.format(debt),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «Должники»: who owes, how much, how long — the oldest first, a
/// WhatsApp reminder a tap away (owner, 13.11.2026).
Future<void> showFilmDebtors(
  BuildContext context,
  List<FilmCustomer> customers, {
  VoidCallback? onShow,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final owing = [
      for (final c in customers)
        if (c.debt > 0.5) c,
    ]..sort((a, b) => (b.debtDays ?? 0).compareTo(a.debtDays ?? 0));
    final total = owing.fold<double>(0, (s, c) => s + c.debt);
    return ListView(
      key: const ValueKey('filmDebtors'),
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          l10n.filmDebtorsTitle(money.format(total)),
          style: theme.textTheme.titleLarge,
        ),
        if (onShow != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onShow();
              },
              child: Text(l10n.filmDebtorsShowSales),
            ),
          ),
        for (final c in owing)
          ListTile(
            key: ValueKey('filmDebtor:${c.customer}'),
            contentPadding: EdgeInsets.zero,
            title: Text(c.name),
            subtitle: Text(
              l10n.filmDebtorLine(money.format(c.debt), c.debtDays ?? 0),
              style: TextStyle(
                color: (c.debtDays ?? 0) > 14 ? status.danger : null,
              ),
            ),
            trailing: c.phone == null
                ? null
                : OutlinedButton.icon(
                    key: ValueKey('filmDebtor:remind:${c.customer}'),
                    onPressed: () => ContactActions.whatsAppMessage(
                      c.phone,
                      l10n.filmRemindText(c.name, money.format(c.debt)),
                    ),
                    icon: const Icon(AppIcons.whatsApp),
                    label: Text(l10n.filmRemind),
                  ),
          ),
      ],
    );
  },
);
