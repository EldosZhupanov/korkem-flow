import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.filmDeptTitle),
          actions: [
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
            ],
          ),
        ),
        body: const TabBarView(
          children: [_StockTab(), _SalesTab(), _CustomersTab()],
        ),
      ),
    );
  }
}

void _refresh(WidgetRef ref, [String? item]) {
  ref
    ..invalidate(filmStockProvider)
    ..invalidate(filmSalesProvider)
    ..invalidate(filmCustomersProvider)
    ..invalidate(filmCatalogProvider);
  if (item != null) ref.invalidate(filmHistoryProvider(item));
}

class _StockTab extends ConsumerStatefulWidget {
  const _StockTab();

  @override
  ConsumerState<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<_StockTab> {
  bool _lowOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stock = ref.watch(filmStockProvider);
    return stock.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(filmStockProvider)),
      data: (c) {
        final low = [
          for (final f in c.films)
            if (f.low) f,
        ];
        final films = _lowOnly ? low : c.films;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (c.canEdit)
                  FilledButton.icon(
                    key: const ValueKey('filmDept:sell'),
                    onPressed: () async {
                      final done = await showFilmSale(context, c);
                      if (done ?? false) _refresh(ref);
                    },
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.filmSell),
                  ),
                FilterChip(
                  key: const ValueKey('filmDept:low'),
                  label: Text(l10n.filmLowCount(low.length)),
                  selected: _lowOnly,
                  onSelected: (on) => setState(() => _lowOnly = on),
                ),
              ],
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

class _StockTile extends StatelessWidget {
  const _StockTile({required this.film, required this.onTap});

  final Film film;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = film;
    final (text, color) = f.free <= 0
        ? (l10n.filmToOrder, theme.colorScheme.outline)
        : f.low
        ? (l10n.filmLow(filmMetres(f.free)), theme.colorScheme.error)
        : ('${filmMetres(f.free)} м', theme.colorScheme.primary);
    return ListTile(
      key: ValueKey('filmStock:${f.item}'),
      onTap: onTap,
      leading: FilmSample(argb: f.argb),
      title: Text(
        filmName(f),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text([?f.code, ?f.type].join(' · ')),
      trailing: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
    return Scaffold(
      appBar: AppBar(title: Text(filmName(film))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              FilmSample(argb: film.argb, size: AppSpacing.xxxl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(film.colour, style: theme.textTheme.titleLarge),
                    Text([film.maker, ?film.code].join(' · ')),
                  ],
                ),
              ),
              Text(
                film.free > 0 ? '${filmMetres(film.free)} м' : l10n.filmToOrder,
                key: const ValueKey('filmPage:free'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: film.free > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
            ],
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
                  onPressed: film.free <= 0
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
                    await showFilmCard(context, film, stock);
                    _refresh(ref, item);
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
              if (rows.isEmpty) Text(l10n.filmHistoryEmpty),
              for (final (i, m) in rows.indexed)
                ListTile(
                  key: ValueKey('filmMove:$i'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    [
                      mdfDay(m.date),
                      filmMoveLabel(m.kind, l10n),
                      ?m.party,
                      ?m.reason,
                      if (m.priceM != null) price(m.priceM),
                    ].join(' · '),
                  ),
                  trailing: Text(
                    '${m.metres > 0 ? '+' : '−'}${filmMetres(m.metres.abs())}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: m.metres > 0 ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String filmMoveLabel(FilmMoveKind kind, AppLocalizations l10n) =>
    switch (kind) {
      FilmMoveKind.receipt => l10n.filmMoveReceipt,
      FilmMoveKind.sale => l10n.filmMoveSale,
      FilmMoveKind.shop => l10n.filmMoveShop,
      FilmMoveKind.writeOff => l10n.filmMoveWriteOff,
      FilmMoveKind.other => l10n.filmMoveOther,
    };

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final sales = ref.watch(filmSalesProvider);
    return sales.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(filmSalesProvider)),
      data: (rows) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.filmSalesEmpty),
            ),
          for (final (i, s) in rows.indexed)
            ListTile(
              key: ValueKey('filmSaleRow:$i'),
              title: Text(
                '${mdfDay(s.date)} · ${s.customerName ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  for (final l in s.lines)
                    '${l.title} — ${filmMetres(l.metres)} м',
                ].join('; '),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (s.amount != null)
                    Text(
                      money.format(s.amount),
                      style: theme.textTheme.titleSmall,
                    ),
                  if ((s.debt ?? 0) > 0)
                    Text(
                      l10n.filmSaleDebt(money.format(s.debt)),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomersTab extends ConsumerWidget {
  const _CustomersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final customers = ref.watch(filmCustomersProvider);
    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(filmCustomersProvider),
      ),
      data: (rows) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.filmCustomersEmpty),
            ),
          for (final c in rows)
            ListTile(
              key: ValueKey('filmCustomer:${c.customer}'),
              onTap: () async {
                final done = await showFilmCustomerTerms(context, c);
                if (done ?? false) ref.invalidate(filmCustomersProvider);
              },
              title: Text(
                c.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (c.wholesale) l10n.filmWholesale else l10n.filmRetail,
                  if (c.discount > 0) '−${filmMetres(c.discount)}%',
                  if (c.last != null) mdfDay(c.last),
                  if (c.asleep) l10n.filmAsleep(c.idleDays ?? 0),
                ].join(' · '),
                style: c.asleep
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.filmMonthMetres(filmMetres(c.monthM)),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    c.debt > 0
                        ? l10n.filmSaleDebt(money.format(c.debt))
                        : money.format(c.total),
                    style: c.debt > 0
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
