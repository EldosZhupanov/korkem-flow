import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_cash_tab.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_customer_page.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_orders_page.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_pick.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_sales_tab.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_team_tab.dart';
import 'package:korkem_flow/features/film_sources/presentation/film_sources.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Отдел плёнки» (owner, 10.11.2026): a department of its own — it buys
/// film from wholesalers and sells it by the metre. Its stock, its sales,
/// its customers; the catalogue is a tap away. Apart from the facade shop
/// until the two are joined.
class FilmDeptScreen extends ConsumerWidget {
  const FilmDeptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.filmDeptTitle),
          actions: [
            IconButton(
              key: const ValueKey('filmDept:search'),
              tooltip: l10n.searchTitle,
              icon: const Icon(AppIcons.search),
              onPressed: () => context.push(Routes.search),
            ),
            TextButton.icon(
              key: const ValueKey('filmDept:catalog'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FilmCatalogScreen(),
                  ),
                );
                ref.invalidate(filmStockProvider);
              },
              icon: const Icon(AppIcons.dictionary),
              label: Text(l10n.filmCatalogShort),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                key: const ValueKey('filmTab:stock'),
                text: l10n.filmTabStock,
              ),
              Tab(
                key: const ValueKey('filmTab:sales'),
                text: l10n.filmTabSales,
              ),
              Tab(
                key: const ValueKey('filmTab:customers'),
                text: l10n.filmTabCustomers,
              ),
              Tab(
                key: const ValueKey('filmTab:sources'),
                text: l10n.filmTabSources,
              ),
              Tab(
                key: const ValueKey('filmTab:team'),
                text: l10n.filmTabTeam,
              ),
              Tab(
                key: const ValueKey('filmTab:cash'),
                text: l10n.filmTabCash,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StockTab(),
            FilmSalesTab(),
            _CustomersTab(),
            FilmSourcesTab(),
            FilmTeamTab(),
            FilmCashTab(),
          ],
        ),
      ),
    );
  }
}

/// «На складе 50 м» — a labelled figure beside the film's name.
class _StockBadge extends StatelessWidget {
  const _StockBadge({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.background,
    required this.foreground,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
            ),
            Text(
              value,
              key: valueKey,
              style: theme.textTheme.titleLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// «в пути 50 м · прибудет 13.11», or how late it is.
String filmComingLine(FilmComing c, AppLocalizations l10n) => c.lateDays > 0
    ? l10n.filmComingLate(filmMetres(c.metres), '${c.lateDays}')
    : l10n.filmComing(filmMetres(c.metres), mdfDay(c.due, year: false));

/// A roll on its way, with what can be done when it comes — or does not.
class _ComingRow extends ConsumerWidget {
  const _ComingRow({
    required this.coming,
    required this.canEdit,
    required this.onDone,
    super.key,
  });

  final FilmComing coming;
  final bool canEdit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final late = coming.lateDays > 0;
    final repo = ref.read(filmDeptRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        onDone();
      } on Object catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }

    Future<void> arrived() async {
      final metres = await showFilmArrived(context, coming);
      if (metres != null) {
        await run(() => repo.arrived(coming.entry, metres: metres));
      }
    }

    Future<void> move() async {
      final now = DateTime.now();
      final due = DateTime.tryParse(coming.due);
      final picked = await showDatePicker(
        context: context,
        initialDate: due != null && due.isAfter(now)
            ? due
            : now.add(const Duration(days: 1)),
        firstDate: now.add(const Duration(days: 1)),
        lastDate: now.add(const Duration(days: 180)),
      );
      if (picked != null) {
        await run(() => repo.reschedule(coming.entry, mdfIso(picked)));
      }
    }

    Future<void> drop() async {
      final reason = await showReasonDialog(
        context,
        title: l10n.filmComingDrop,
        label: l10n.filmComingDropReason,
        confirm: l10n.mdfConfirm,
        cancel: l10n.mdfCancel,
        fieldKey: const ValueKey('filmComing:reason'),
      );
      if (reason != null) {
        await run(() => repo.dropComing(coming.entry, reason));
      }
    }

    return Card(
      color: late ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  late ? AppIcons.warning : AppIcons.delivery,
                  color: late
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    [
                      filmComingLine(coming, l10n),
                      ?coming.supplier,
                    ].join(' · '),
                    style: TextStyle(
                      color: late ? theme.colorScheme.onErrorContainer : null,
                    ),
                  ),
                ),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton(
                    key: const ValueKey('filmComing:arrived'),
                    onPressed: arrived,
                    child: Text(l10n.filmComingArrived),
                  ),
                  OutlinedButton(
                    key: const ValueKey('filmComing:move'),
                    onPressed: move,
                    child: Text(l10n.filmComingMove),
                  ),
                  TextButton(
                    key: const ValueKey('filmComing:drop'),
                    onPressed: drop,
                    child: Text(l10n.filmComingDrop),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// How a receipt came and who took it in, or who sold: «Такси · Алматы ·
/// 5 000 ₸ (100 ₸/м) · срочно · принял Айбек»; null when nothing is known.
String? _about(FilmMove m, AppLocalizations l10n, NumberFormat money) {
  final d = m.delivery;
  final parts = [
    if (d != null) ...[
      ?d.transport,
      ?d.city,
      if ((d.cost ?? 0) > 0)
        d.perM == null
            ? money.format(d.cost)
            : '${money.format(d.cost)} (${money.format(d.perM)}/м)',
      if (d.urgent) l10n.filmUrgent.toLowerCase(),
      if (d.driver != null || d.phone != null) [?d.driver, ?d.phone].join(' '),
      ?switch (d.payer) {
        FilmPayer.cash => l10n.filmPaidCash,
        FilmPayer.employee =>
          d.settled
              ? l10n.filmPaidByBack(d.paidBy ?? '')
              : l10n.filmPaidByOwed(d.paidBy ?? ''),
        FilmPayer.unpaid =>
          d.settled ? l10n.filmCarrierPaid : l10n.filmCarrierOwed,
        FilmPayer.supplier => l10n.filmPaidSupplier,
        _ => null,
      },
      if (d.receivedBy case final who?) l10n.filmTakenBy(who),
    ],
    if (m.seller case final who?) l10n.filmSoldBy(who),
    if (m.supplierOwed) l10n.filmSupplierOwedNote,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

void _refresh(WidgetRef ref, [String? item]) {
  ref
    ..invalidate(filmStockProvider)
    ..invalidate(filmWantedProvider)
    ..invalidate(filmSalesProvider)
    ..invalidate(filmSalesPeriodProvider)
    ..invalidate(filmCustomersProvider)
    ..invalidate(filmCatalogProvider);
  if (item != null) ref.invalidate(filmHistoryProvider(item));
}

class _StockTab extends ConsumerStatefulWidget {
  const _StockTab();

  @override
  ConsumerState<_StockTab> createState() => _StockTabState();
}

/// Which films the stock shows (owner, 13.11.2026).
enum _StockFilter { all, have, low, onWay, none }

bool _shows(Film f, _StockFilter filter) => switch (filter) {
  _StockFilter.all => true,
  _StockFilter.have => f.free > 0,
  _StockFilter.low => f.low,
  _StockFilter.onWay => f.coming.isNotEmpty,
  _StockFilter.none => f.free <= 0,
};

bool _found(Film f, String query) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return [
    filmName(f),
    ?f.code,
    ?f.type,
    ?f.supplier,
    f.maker,
    f.colour,
  ].any((t) => t.toLowerCase().contains(q));
}

class _StockTabState extends ConsumerState<_StockTab> {
  _StockFilter _filter = _StockFilter.all;
  String _query = '';

  Future<void> _receive(FilmCatalog c, [Film? film]) async {
    final l10n = AppLocalizations.of(context);
    // With a search (owner, 12.11.2026).
    final picked =
        film ??
        await showFilmChoice(context, c.films, title: l10n.filmReceivePick);
    if (picked == null || !mounted) return;
    final done = await showFilmReceive(context, picked, c);
    if (done ?? false) _refresh(ref);
  }

  Future<void> _sell(FilmCatalog c, [Film? film]) async {
    final done = await showFilmSale(context, c, film: film);
    if (done ?? false) _refresh(ref);
  }

  Future<void> _want(Film film) async {
    final done = await showFilmWant(context, film);
    if (done ?? false) _refresh(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final stock = ref.watch(filmStockProvider);
    return stock.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(filmStockProvider)),
      data: (c) {
        int count(_StockFilter f) => c.films.where((x) => _shows(x, f)).length;
        final films = [
          for (final f in c.films)
            if (_shows(f, _filter) && _found(f, _query)) f,
        ];
        // The bar's full length: three minimums, or the fullest film.
        final fullest = c.films.fold<double>(
          1,
          (m, f) => f.free > m ? f.free : m,
        );
        // Two colours (owner, 13.11.2026): goods in — green, a sale —
        // blue; the receipt first.
        final light = theme.brightness == Brightness.light
            ? theme.colorScheme.surface
            : theme.colorScheme.onSurface;
        final dark = theme.brightness == Brightness.light
            ? theme.colorScheme.onSurface
            : theme.colorScheme.surface;
        Color on(Color fill) =>
            ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
            ? light
            : dark;
        final lowCount = count(_StockFilter.low);
        String label(_StockFilter f) => switch (f) {
          _StockFilter.all => l10n.filmFilterAll(count(f)),
          _StockFilter.have => l10n.filmFilterHave(count(f)),
          _StockFilter.low => l10n.filmLowCount(count(f)),
          _StockFilter.onWay => l10n.filmFilterOnWay(count(f)),
          _StockFilter.none => l10n.filmFilterNone(count(f)),
        };
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // A receipt straight from the stock list: pick the film,
                // then the usual window (owner, 12.11.2026).
                if (c.canEdit)
                  FilledButton.icon(
                    key: const ValueKey('filmDept:receive'),
                    style: FilledButton.styleFrom(
                      backgroundColor: status.success,
                      foregroundColor: on(status.success),
                    ),
                    onPressed: () => _receive(c),
                    icon: const Icon(AppIcons.moveIn),
                    label: Text(l10n.filmReceive),
                  ),
                if (c.canEdit)
                  FilledButton.icon(
                    key: const ValueKey('filmDept:sell'),
                    style: FilledButton.styleFrom(
                      backgroundColor: status.info,
                      foregroundColor: on(status.info),
                    ),
                    onPressed: () => _sell(c),
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.filmSell),
                  ),
                // «К заказу» (owner, 12.11.2026): the day's list.
                if (c.canEdit) FilmOrdersButton(stock: c),
                SizedBox(
                  width: AppSpacing.xxxl * 6,
                  child: TextField(
                    key: const ValueKey('filmDept:search'),
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(AppIcons.search),
                      hintText: l10n.filmStockSearch,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final f in _StockFilter.values)
                  ChoiceChip(
                    key: ValueKey(
                      f == _StockFilter.low
                          ? 'filmDept:low'
                          : 'filmDept:filter:${f.name}',
                    ),
                    label: Text(label(f)),
                    // «Мало» lights up while something runs low.
                    backgroundColor: f == _StockFilter.low && lowCount > 0
                        ? status.danger.withValues(alpha: AppTint.surface)
                        : null,
                    side: f == _StockFilter.low && lowCount > 0
                        ? BorderSide(color: status.danger)
                        : null,
                    labelStyle: f == _StockFilter.low && lowCount > 0
                        ? TextStyle(color: status.danger)
                        : null,
                    selected: _filter == f,
                    onSelected: (on) => setState(
                      () => _filter = on && _filter != f ? f : _StockFilter.all,
                    ),
                  ),
              ],
            ),
            // Time to order (owner, 11.11.2026): what ran low, as last time.
            if (c.canEdit && c.films.any((f) => f.reorder != null))
              Card(
                key: const ValueKey('filmReorder:banner'),
                color: theme.colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(AppIcons.delivery),
                  title: Text(
                    l10n.filmReorderBanner(
                      c.films.where((f) => f.reorder != null).length,
                    ),
                  ),
                  trailing: FilledButton(
                    key: const ValueKey('filmReorder:open'),
                    onPressed: () async {
                      final done = await showFilmReorder(context, c);
                      if (done ?? false) _refresh(ref);
                    },
                    child: Text(l10n.filmReorderOpen),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (films.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l10n.filmStockEmpty),
              ),
            for (final f in films)
              _StockTile(
                film: f,
                full: (f.minStock ?? 0) > 0 ? f.minStock! * 3 : fullest,
                canEdit: c.canEdit,
                onSell: () => _sell(c, f),
                onReceive: () => _receive(c, f),
                onWant: () => _want(f),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FilmPage(item: f.item),
                    ),
                  );
                  _refresh(ref);
                },
              ),
          ],
        );
      },
    );
  }
}

/// One film on the stock list: its colour, what is left with a bar, how
/// many days that lasts, what is put by and on its way — and the buttons
/// for it right in the row (owner, 13.11.2026).
class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.film,
    required this.full,
    required this.canEdit,
    required this.onTap,
    required this.onSell,
    required this.onReceive,
    required this.onWant,
  });

  final Film film;

  /// The metres that fill the bar.
  final double full;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onSell;
  final VoidCallback onReceive;
  final VoidCallback onWant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final f = film;
    // «заказать» only when nothing is free, nothing put by and nothing on
    // its way (owner, 12.11.2026: all four read «заказать»).
    final held = f.holds.fold<double>(0, (s, h) => s + h.metres);
    final onWay = f.coming.fold<double>(0, (s, c) => s + c.metres);
    final (text, color) = f.free <= 0 && held > 0
        ? (l10n.filmHeldShort(filmMetres(held)), theme.colorScheme.tertiary)
        : f.free <= 0 && onWay > 0
        ? (l10n.filmOnWayShort(filmMetres(onWay)), theme.colorScheme.primary)
        : f.free <= 0
        ? (l10n.filmToOrder, theme.colorScheme.error)
        : f.low
        ? (l10n.filmLow(filmMetres(f.free)), status.warning)
        : ('${filmMetres(f.free)} м', status.success);
    // Rolls on time are one line; a late one stands alone.
    final onTime = [
      for (final c in f.coming)
        if (c.lateDays <= 0) c,
    ];
    final late = [
      for (final c in f.coming)
        if (c.lateDays > 0) c,
    ];
    final days = f.daysLeft;
    final lines = <Widget>[
      if (f.code != null || f.type != null || days != null)
        Text(
          [
            ?f.code,
            ?f.type,
            if (days != null) l10n.filmDaysLeft(days),
          ].join(' · '),
          style: days != null && days < 7
              ? TextStyle(color: status.warning)
              : null,
        ),
      for (final h in f.holds)
        Text(
          l10n.filmHeldFor(
            filmMetres(h.metres),
            h.customerName,
            mdfDay(h.until, year: false),
          ),
          style: TextStyle(color: theme.colorScheme.tertiary),
        ),
      if (onTime.length > 1)
        Text(
          l10n.filmComingRolls(
            onTime.length,
            filmMetres(onTime.fold<double>(0, (s, c) => s + c.metres)),
            mdfDay(onTime.first.due, year: false),
          ),
          style: TextStyle(color: theme.colorScheme.primary),
        )
      else
        for (final c in onTime)
          Text(
            filmComingLine(c, l10n),
            style: TextStyle(color: theme.colorScheme.primary),
          ),
      for (final c in late)
        Text(
          filmComingLine(c, l10n),
          style: TextStyle(color: theme.colorScheme.error),
        ),
    ];
    // In the row too: goods in green and first, a sale blue, «заказать»
    // orange (owner, 13.11.2026).
    ButtonStyle tint(Color c) => OutlinedButton.styleFrom(
      foregroundColor: c,
      side: BorderSide(color: c),
    );
    final actions = canEdit
        ? Wrap(
            spacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                key: ValueKey('filmStock:receive:${f.item}'),
                style: tint(status.success),
                onPressed: onReceive,
                child: Text(l10n.filmReceive),
              ),
              if (f.free > 0)
                OutlinedButton(
                  key: ValueKey('filmStock:sell:${f.item}'),
                  style: tint(status.info),
                  onPressed: onSell,
                  child: Text(l10n.filmSell),
                )
              else if (onWay <= 0)
                OutlinedButton.icon(
                  key: ValueKey('filmStock:want:${f.item}'),
                  style: tint(status.warning),
                  onPressed: onWant,
                  icon: const Icon(AppIcons.delivery),
                  label: Text(l10n.filmWantShort),
                ),
            ],
          )
        : null;
    final metres = SizedBox(
      width: AppSpacing.xxxl * 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            text,
            textAlign: TextAlign.end,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (f.free > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: full > 0 ? (f.free / full).clamp(0.05, 1.0) : 0,
                minHeight: AppSpacing.xs,
                color: f.low ? status.warning : status.success,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
    return InkWell(
      key: ValueKey('filmStock:${f.item}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 720;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSpacing.xl,
                  child: f.argb == null ? null : FilmSample(argb: f.argb),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filmName(f),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      DefaultTextStyle.merge(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: lines,
                        ),
                      ),
                      if (!wide && actions != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        actions,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                metres,
                if (wide && actions != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  actions,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One film: its card, what can be done with it, and all that came and left.
class FilmPage extends ConsumerWidget {
  const FilmPage({required this.item, super.key});

  final String item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final stock = ref.watch(filmStockProvider).value;
    final film = stock?.films.where((f) => f.item == item).firstOrNull;
    final history = ref.watch(filmHistoryProvider(item));
    if (stock == null || film == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    Future<void> act(Future<bool?> Function() dialog) async {
      final done = await dialog();
      if (done ?? false) _refresh(ref, item);
    }

    String price(double? v) => v == null ? '—' : '${money.format(v)}/м';
    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
    final onWay = film.coming.fold<double>(0, (s, c) => s + c.metres);
    final held = film.holds.fold<double>(0, (s, h) => s + h.metres);
    return Scaffold(
      appBar: AppBar(title: Text(filmName(film))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              if (film.argb != null) ...[
                FilmSample(argb: film.argb, size: AppSpacing.xxxl),
                const SizedBox(width: AppSpacing.md),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(film.colour, style: theme.textTheme.titleLarge),
                    Text([film.maker, ?film.code].join(' · ')),
                  ],
                ),
              ),
              // Beside the name, where the eye is (owner, 11.11.2026):
              // what is on the shelf, and what is on its way.
              const SizedBox(width: AppSpacing.lg),
              // With metres put by, the first figure is what is still free
              // — «заказать» only when the shelf is truly empty (owner,
              // 12.11.2026: all 6,8 m put by read as «заказать»).
              _StockBadge(
                label: film.holds.isEmpty ? l10n.filmOnShelf : l10n.filmFree,
                value: film.free > 0 || film.holds.isNotEmpty
                    ? '${filmMetres(film.free < 0 ? 0 : film.free)} м'
                    : l10n.filmToOrder,
                valueKey: const ValueKey('filmPage:free'),
                background: film.free > 0
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                foreground: film.free > 0
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.outline,
              ),
              if (film.holds.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                _StockBadge(
                  label: l10n.filmHeld,
                  value: '${filmMetres(held)} м',
                  valueKey: const ValueKey('filmPage:held'),
                  background: theme.colorScheme.tertiaryContainer,
                  foreground: theme.colorScheme.onTertiaryContainer,
                ),
              ],
              if (film.coming.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                _StockBadge(
                  label: l10n.filmOnWay,
                  value: '${filmMetres(onWay)} м',
                  valueKey: const ValueKey('filmPage:coming'),
                  background: film.coming.any((c) => c.lateDays > 0)
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.secondaryContainer,
                  foreground: film.coming.any((c) => c.lateDays > 0)
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSecondaryContainer,
                ),
              ],
            ],
          ),
          // On its way (owner, 11.11.2026): came, late, or will not come.
          for (final (i, c) in film.coming.indexed)
            _ComingRow(
              key: ValueKey('filmComing:$i'),
              coming: c,
              canEdit: stock.canEdit,
              onDone: () => _refresh(ref, item),
            ),
          for (final h in film.holds)
            ListTile(
              key: ValueKey('filmHold:${h.hold}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                AppIcons.hold,
                color: h.late
                    ? theme.colorScheme.error
                    : theme.colorScheme.tertiary,
              ),
              title: Text(
                l10n.filmHeldFor(
                  filmMetres(h.metres),
                  h.customerName,
                  mdfDay(h.until, year: false),
                ),
                style: h.late
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
              trailing: stock.canEdit
                  ? Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        FilledButton(
                          key: ValueKey('filmHold:sell:${h.hold}'),
                          onPressed: () => act(
                            () => showFilmSale(
                              context,
                              stock,
                              film: film,
                              customer: h.customer,
                            ),
                          ),
                          child: Text(l10n.filmSell),
                        ),
                        TextButton(
                          key: ValueKey('filmHold:release:${h.hold}'),
                          onPressed: () async {
                            await ref
                                .read(filmDeptRepositoryProvider)
                                .releaseHold(h.hold);
                            _refresh(ref, item);
                          },
                          child: Text(l10n.filmHoldRelease),
                        ),
                      ],
                    )
                  : null,
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            children: [
              if (film.type != null) fact(l10n.filmType, film.type!),
              if (film.thicknessMm != null)
                fact(l10n.filmThickness, filmMetres(film.thicknessMm!)),
              if (film.widthMm != null)
                fact(l10n.filmWidth, film.widthMm!.toStringAsFixed(0)),
              if (film.ral != null) fact(l10n.filmRal, film.ral!),
              fact(l10n.filmPriceM, price(film.priceM)),
              fact(l10n.filmRetailM, price(film.retailM)),
              fact(l10n.filmWholesaleM, price(film.wholesaleM)),
            ],
          ),
          if (stock.canEdit)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  key: const ValueKey('filmPage:receive'),
                  onPressed: () =>
                      act(() => showFilmReceive(context, film, stock)),
                  child: Text(l10n.filmReceive),
                ),
                FilledButton(
                  key: const ValueKey('filmPage:sell'),
                  onPressed: film.free <= 0 && film.holds.isEmpty
                      ? null
                      : () => act(
                          () => showFilmSale(context, stock, film: film),
                        ),
                  child: Text(l10n.filmSell),
                ),
                OutlinedButton(
                  key: const ValueKey('filmPage:shop'),
                  onPressed: film.free <= 0
                      ? null
                      : () => act(
                          () => showFilmIssue(context, film, writeOff: false),
                        ),
                  child: Text(l10n.filmToShop),
                ),
                // Put by for a customer (owner, 11.11.2026).
                OutlinedButton(
                  key: const ValueKey('filmPage:hold'),
                  onPressed: film.free <= 0
                      ? null
                      : () => act(() => showFilmHold(context, film)),
                  child: Text(l10n.filmHold),
                ),
                OutlinedButton(
                  key: const ValueKey('filmPage:writeOff'),
                  onPressed: film.free <= 0
                      ? null
                      : () => act(
                          () => showFilmIssue(context, film, writeOff: true),
                        ),
                  child: Text(l10n.filmWriteOff),
                ),
                TextButton(
                  key: const ValueKey('filmPage:card'),
                  onPressed: () async {
                    final gone = await showFilmCard(context, film, stock);
                    _refresh(ref, item);
                    // A deleted film has no page to stay on.
                    if ((gone ?? false) && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(l10n.filmEditCard),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.filmHistory, style: theme.textTheme.labelLarge),
          ...history.when(
            loading: () => const [LinearProgressIndicator()],
            error: (e, _) => [Text('$e')],
            data: (rows) => [
              if (rows.isEmpty)
                Text(l10n.filmHistoryEmpty)
              else
                _History(
                  rows: rows,
                  onHand: film.onHand,
                  onTap: stock.canEdit
                      ? (m) => act(
                          () => showFilmCorrect(
                            context,
                            move: m,
                            film: film,
                            stock: stock,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A film's history (owner, 11.11.2026: «приход и продажа как-то
/// отличались, чтобы не терять»): each kind its colour and mark, by day,
/// what stayed on the shelf after each, a filter by kind and its totals.
class _History extends StatefulWidget {
  const _History({required this.rows, required this.onHand, this.onTap});

  final List<FilmMove> rows;
  final double onHand;
  final void Function(FilmMove)? onTap;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  FilmMoveKind? _only;

  static const List<FilmMoveKind> _kinds = [
    FilmMoveKind.receipt,
    FilmMoveKind.sale,
    FilmMoveKind.shop,
    FilmMoveKind.writeOff,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    // What stayed on the shelf after each: from what is there now, back.
    final after = <FilmMove, double>{};
    var running = widget.onHand;
    for (final m in widget.rows) {
      if (m.struck) continue;
      after[m] = running;
      running -= m.metres;
    }
    final counts = <FilmMoveKind, int>{};
    for (final m in widget.rows) {
      if (!m.struck) counts[m.kind] = (counts[m.kind] ?? 0) + 1;
    }
    final shown = [
      for (final m in widget.rows)
        if (_only == null || m.kind == _only) m,
    ];
    final totals = <FilmMoveKind, double>{};
    for (final m in shown) {
      if (!m.struck) totals[m.kind] = (totals[m.kind] ?? 0) + m.metres;
    }
    final now = DateTime.now();
    String dayLabel(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return iso;
      final days = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(d.year, d.month, d.day)).inDays;
      return switch (days) {
        0 => l10n.filmToday,
        1 => l10n.filmYesterday,
        _ => mdfDay(iso),
      };
    }

    final children = <Widget>[
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          ChoiceChip(
            key: const ValueKey('filmHistory:all'),
            label: Text(l10n.filmHistoryAll),
            selected: _only == null,
            onSelected: (_) => setState(() => _only = null),
          ),
          for (final k in _kinds)
            if ((counts[k] ?? 0) > 0)
              // The filter is the legend too: each kind in its colour.
              ChoiceChip(
                key: ValueKey('filmHistory:${k.name}'),
                avatar: Icon(
                  filmMoveIcon(k),
                  color: status.resolve(filmMoveIntent(k)),
                ),
                showCheckmark: false,
                label: Text('${filmMovePlural(k, l10n)} ${counts[k]}'),
                selected: _only == k,
                selectedColor: status
                    .resolve(filmMoveIntent(k))
                    .withValues(alpha: AppTint.surface),
                side: BorderSide(color: status.resolve(filmMoveIntent(k))),
                onSelected: (_) => setState(() => _only = k),
              ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
    String? lastDay;
    for (final m in shown) {
      if (m.date != lastDay) {
        lastDay = m.date;
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              dayLabel(m.date),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );
      }
      final i = widget.rows.indexOf(m);
      final about = _about(m, l10n, money);
      final color = m.struck
          ? theme.colorScheme.outline
          : status.resolve(filmMoveIntent(m.kind));
      final struck = m.struck
          ? TextStyle(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.outline,
            )
          : null;
      final sum = m.kind == FilmMoveKind.sale && m.priceM != null
          ? money.format(m.metres.abs() * m.priceM!)
          : null;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            child: InkWell(
              key: ValueKey('filmMove:$i'),
              // A movement entered wrong is put right from here (owner,
              // 11.11.2026); one already put right stays struck through.
              onTap:
                  widget.onTap != null &&
                      !m.struck &&
                      m.kind != FilmMoveKind.other
                  ? () => widget.onTap!(m)
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: color, width: AppSpacing.xs),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(filmMoveIcon(m.kind), color: color),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: filmMoveTitle(m.kind, l10n),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: [
                                      '',
                                      ?m.party,
                                      ?m.reason,
                                      if (m.priceM != null)
                                        '${money.format(m.priceM)}/м',
                                      ?sum,
                                    ].join(' · '),
                                  ),
                                ],
                              ),
                              style: struck,
                            ),
                            if (about != null)
                              Text(
                                about,
                                key: ValueKey('filmMoveAbout:$i'),
                                style: theme.textTheme.bodySmall,
                              ),
                            if (m.fixed)
                              Text(
                                l10n.filmCorrected(
                                  mdfDay(m.fixAt!.split(' ').first),
                                  m.fixBy ?? '',
                                  m.fixReason ?? '',
                                ),
                                key: ValueKey('filmMoveFixed:$i'),
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${m.metres > 0 ? '+' : '−'}'
                            '${filmMetres(m.metres.abs())} м',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              decoration: m.struck
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (after[m] case final left?)
                            Text(
                              l10n.filmAfter(filmMetres(left)),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          [
            for (final k in _kinds)
              if (totals[k] case final t?)
                '${filmMovePlural(k, l10n)} ${_signed(t)} м',
          ].join(' · '),
          key: const ValueKey('filmHistory:totals'),
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// «+50», «−12» — metres with their direction.
String _signed(double metres) =>
    '${metres > 0 ? '+' : '−'}${filmMetres(metres.abs())}';

/// Each kind its colour: in green, a sale blue, the press grey, a loss red.
StatusIntent filmMoveIntent(FilmMoveKind kind) => switch (kind) {
  FilmMoveKind.receipt => StatusIntent.success,
  FilmMoveKind.sale => StatusIntent.info,
  FilmMoveKind.writeOff => StatusIntent.danger,
  _ => StatusIntent.neutral,
};

IconData filmMoveIcon(FilmMoveKind kind) => switch (kind) {
  FilmMoveKind.receipt => AppIcons.moveIn,
  FilmMoveKind.sale => AppIcons.moveOut,
  FilmMoveKind.shop => AppIcons.mounting,
  FilmMoveKind.writeOff => AppIcons.delete,
  FilmMoveKind.other => AppIcons.moveOut,
};

/// «Приход», «Продажа» — at the head of a row.
String filmMoveTitle(FilmMoveKind kind, AppLocalizations l10n) {
  final w = filmMoveLabel(kind, l10n);
  return w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
}

/// «Приходы», «Продажи» — on the filter.
String filmMovePlural(FilmMoveKind kind, AppLocalizations l10n) =>
    switch (kind) {
      FilmMoveKind.receipt => l10n.filmHistoryReceipts,
      FilmMoveKind.sale => l10n.filmHistorySales,
      FilmMoveKind.shop => l10n.filmHistoryShop,
      FilmMoveKind.writeOff => l10n.filmHistoryWriteOffs,
      FilmMoveKind.other => l10n.filmMoveOther,
    };

String filmMoveLabel(FilmMoveKind kind, AppLocalizations l10n) =>
    switch (kind) {
      FilmMoveKind.receipt => l10n.filmMoveReceipt,
      FilmMoveKind.sale => l10n.filmMoveSale,
      FilmMoveKind.shop => l10n.filmMoveShop,
      FilmMoveKind.writeOff => l10n.filmMoveWriteOff,
      FilmMoveKind.other => l10n.filmMoveOther,
    };

class _CustomersTab extends ConsumerStatefulWidget {
  const _CustomersTab();

  @override
  ConsumerState<_CustomersTab> createState() => _CustomersTabState();
}

enum _CustomerFilter { all, regular, debtors, asleep }

/// Who buys film (owner, 12.11.2026): who buys most first, with a medal;
/// a stripe for each — paid up, owing, gone quiet; who is regular; a call
/// or a WhatsApp a tap away. A tap opens the customer's card.
class _CustomersTabState extends ConsumerState<_CustomersTab> {
  _CustomerFilter _filter = _CustomerFilter.all;

  /// Ranked by this month, or by all time.
  bool _allTime = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final customers = ref.watch(filmCustomersProvider);
    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(filmCustomersProvider),
      ),
      data: (all) {
        double rank(FilmCustomer c) => _allTime ? c.total : c.monthM;
        final ranked = [...all]..sort((a, b) => rank(b).compareTo(rank(a)));
        final counts = {
          for (final f in _CustomerFilter.values)
            f: ranked.where((c) => _matches(c, f)).length,
        };
        final rows = [
          for (final c in ranked)
            if (_matches(c, _filter)) c,
        ];
        final owed = all
            .where((c) => c.debt > 0.5)
            .fold<double>(0, (s, c) => s + c.debt);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final f in _CustomerFilter.values)
                  ChoiceChip(
                    key: ValueKey(
                      f == _CustomerFilter.debtors
                          ? 'filmCustomers:debtors'
                          : 'filmCustomers:${f.name}',
                    ),
                    label: Text(switch (f) {
                      _CustomerFilter.all => l10n.filmCustomersAll(counts[f]!),
                      _CustomerFilter.regular => l10n.filmCustomersRegular(
                        counts[f]!,
                      ),
                      _CustomerFilter.debtors => l10n.filmDebtors(
                        counts[f]!,
                        money.format(owed),
                      ),
                      _CustomerFilter.asleep => l10n.filmCustomersAsleep(
                        counts[f]!,
                      ),
                    }),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                const SizedBox(width: AppSpacing.sm),
                // Who buys most — this month or all time.
                SegmentedButton<bool>(
                  key: const ValueKey('filmCustomers:rank'),
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.filmCustomersByMonth),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.filmCustomersByAll),
                    ),
                  ],
                  selected: {_allTime},
                  onSelectionChanged: (v) => setState(() => _allTime = v.first),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // «Пора позвонить» (owner, 13.11.2026): silent past his own
            // rhythm, or owing too long — with the call or the reminder.
            if (all.any((c) => c.call != null))
              Card(
                key: const ValueKey('filmCustomers:call'),
                color: status.warning.withValues(alpha: AppTint.surface),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.filmCallTitle(
                          all.where((c) => c.call != null).length,
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                      for (final c in all)
                        if (c.call != null)
                          Row(
                            key: ValueKey('filmCall:${c.customer}'),
                            children: [
                              Expanded(
                                child: Text(
                                  c.call == 'debt'
                                      ? l10n.filmCallDebt(
                                          c.name,
                                          money.format(c.debt),
                                          c.debtDays ?? 0,
                                        )
                                      : l10n.filmCallRhythm(
                                          c.name,
                                          c.rhythmDays ?? 0,
                                          c.idleDays ?? 0,
                                        ),
                                ),
                              ),
                              if (c.phone != null) ...[
                                IconButton(
                                  tooltip: l10n.filmCall,
                                  icon: const Icon(AppIcons.call),
                                  onPressed: () => ContactActions.call(c.phone),
                                ),
                                IconButton(
                                  key: ValueKey('filmCall:wa:${c.customer}'),
                                  tooltip: l10n.filmRemind,
                                  icon: Icon(
                                    AppIcons.whatsApp,
                                    color: status.success,
                                  ),
                                  onPressed: () => c.call == 'debt'
                                      ? ContactActions.whatsAppMessage(
                                          c.phone,
                                          l10n.filmRemindText(
                                            c.name,
                                            money.format(c.debt),
                                          ),
                                        )
                                      : ContactActions.whatsApp(c.phone),
                                ),
                              ],
                            ],
                          ),
                    ],
                  ),
                ),
              ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l10n.filmCustomersEmpty),
              ),
            for (final c in rows)
              _CustomerTile(
                customer: c,
                place: rank(c) > 0 ? ranked.indexOf(c) : null,
                allTime: _allTime,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FilmCustomerPage(customer: c),
                    ),
                  );
                  _refresh(ref);
                },
              ),
            if (rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.filmCustomersLegend,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.neutral,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static bool _matches(FilmCustomer c, _CustomerFilter f) => switch (f) {
    _CustomerFilter.all => true,
    _CustomerFilter.regular => filmRegular(c),
    _CustomerFilter.debtors => c.debt > 0.5,
    _CustomerFilter.asleep => c.asleep,
  };
}

/// Bought this month and before it, and not gone quiet: a regular.
bool filmRegular(FilmCustomer c) =>
    !c.asleep && c.monthM > 0 && c.totalM > c.monthM;

const _medals = ['🥇', '🥈', '🥉'];

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.place,
    required this.allTime,
    required this.onTap,
  });

  final FilmCustomer customer;
  final int? place;
  final bool allTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final c = customer;
    final owing = c.debt > 0.5;
    // Owing red, gone quiet grey, paid up green.
    final stripe = owing
        ? status.danger
        : c.asleep
        ? status.neutral
        : status.success;
    final initials = [
      for (final w in c.name.split(' '))
        if (w.isNotEmpty) w.characters.first.toUpperCase(),
    ].take(2).join();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: InkWell(
          key: ValueKey('filmCustomer:${c.customer}'),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: stripe, width: AppSpacing.xs),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: AppSpacing.xl,
                    child: Text(
                      place == null
                          ? ''
                          : place! < _medals.length
                          ? _medals[place!]
                          : '${place! + 1}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: stripe.withValues(alpha: AppTint.surface),
                    foregroundColor: stripe,
                    child: Text(initials),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (filmRegular(c))
                              Text(
                                l10n.filmRegularBadge,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: status.warning,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          [
                            if (c.wholesale)
                              l10n.filmWholesale
                            else
                              l10n.filmRetail,
                            if (c.discount > 0) '−${filmMetres(c.discount)}%',
                            if (c.last != null) mdfDay(c.last),
                            if (c.asleep) l10n.filmAsleep(c.idleDays ?? 0),
                            ?c.phone,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.asleep ? status.neutral : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        allTime
                            ? '${filmMetres(c.totalM)} м'
                            : l10n.filmMonthMetres(filmMetres(c.monthM)),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        money.format(c.total),
                        style: theme.textTheme.labelSmall,
                      ),
                      Text(
                        owing
                            ? [
                                l10n.filmSaleDebt(money.format(c.debt)),
                                if (c.debtDays != null)
                                  l10n.filmDebtDays(c.debtDays!),
                              ].join(' · ')
                            : l10n.filmNoDebt,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: owing ? status.danger : status.success,
                        ),
                      ),
                    ],
                  ),
                  if (c.phone != null) ...[
                    IconButton(
                      key: ValueKey('filmCustomer:call:${c.customer}'),
                      tooltip: l10n.filmCall,
                      icon: const Icon(AppIcons.call),
                      onPressed: () => ContactActions.call(c.phone),
                    ),
                    IconButton(
                      key: ValueKey('filmCustomer:remind:${c.customer}'),
                      tooltip: owing ? l10n.filmRemind : l10n.filmWrite,
                      icon: const Icon(AppIcons.whatsApp),
                      onPressed: () => owing
                          ? ContactActions.whatsAppMessage(
                              c.phone,
                              l10n.filmRemindText(c.name, money.format(c.debt)),
                            )
                          : ContactActions.whatsApp(c.phone),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
