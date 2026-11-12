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
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_cash_tab.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
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
            _SalesTab(),
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
  ];
  return parts.isEmpty ? null : parts.join(' · ');
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
                // A receipt straight from the stock list: pick the film,
                // then the usual window (owner, 12.11.2026).
                if (c.canEdit)
                  OutlinedButton.icon(
                    key: const ValueKey('filmDept:receive'),
                    onPressed: () async {
                      final film = await showDialog<Film>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text(l10n.filmReceivePick),
                          children: [
                            for (final f in c.films)
                              if (f.enabled)
                                SimpleDialogOption(
                                  key: ValueKey('filmReceivePick:${f.item}'),
                                  onPressed: () => Navigator.of(context).pop(f),
                                  child: Text(filmName(f)),
                                ),
                          ],
                        ),
                      );
                      if (film == null || !context.mounted) return;
                      final done = await showFilmReceive(context, film, c);
                      if (done ?? false) _refresh(ref);
                    },
                    icon: const Icon(AppIcons.moveIn),
                    label: Text(l10n.filmReceive),
                  ),
                FilterChip(
                  key: const ValueKey('filmDept:low'),
                  label: Text(l10n.filmLowCount(low.length)),
                  selected: _lowOnly,
                  onSelected: (on) => setState(() => _lowOnly = on),
                ),
              ],
            ),
            // Time to order (owner, 11.11.2026): what ran low, as last time.
            if (c.canEdit && c.films.any((f) => f.reorder != null))
              Card(
                key: const ValueKey('filmReorder:banner'),
                color: Theme.of(context).colorScheme.tertiaryContainer,
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
    // «заказать» only when nothing is free, nothing put by and nothing on
    // its way (owner, 12.11.2026: all four read «заказать»).
    final held = f.holds.fold<double>(0, (s, h) => s + h.metres);
    final onWay = f.coming.fold<double>(0, (s, c) => s + c.metres);
    final (text, color) = f.free <= 0 && held > 0
        ? (l10n.filmHeldShort(filmMetres(held)), theme.colorScheme.tertiary)
        : f.free <= 0 && onWay > 0
        ? (l10n.filmOnWayShort(filmMetres(onWay)), theme.colorScheme.primary)
        : f.free <= 0
        ? (l10n.filmToOrder, theme.colorScheme.outline)
        : f.low
        ? (l10n.filmLow(filmMetres(f.free)), theme.colorScheme.error)
        : ('${filmMetres(f.free)} м', theme.colorScheme.primary);
    return ListTile(
      key: ValueKey('filmStock:${f.item}'),
      onTap: onTap,
      leading: f.argb == null ? null : FilmSample(argb: f.argb),
      title: Text(
        filmName(f),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: f.coming.isEmpty && f.holds.isEmpty
          ? Text([?f.code, ?f.type].join(' · '))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (f.code != null || f.type != null)
                  Text([?f.code, ?f.type].join(' · ')),
                for (final h in f.holds)
                  Text(
                    l10n.filmHeldFor(
                      filmMetres(h.metres),
                      h.customerName,
                      mdfDay(h.until, year: false),
                    ),
                    style: TextStyle(color: theme.colorScheme.tertiary),
                  ),
                for (final c in f.coming)
                  Text(
                    filmComingLine(c, l10n),
                    style: TextStyle(
                      color: c.lateDays > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
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
              // The sale's own card: a debt paid off, a mistake cancelled.
              onTap: () async {
                final done = await showFilmSaleCard(context, s);
                if (done ?? false) _refresh(ref);
              },
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

class _CustomersTab extends ConsumerStatefulWidget {
  const _CustomersTab();

  @override
  ConsumerState<_CustomersTab> createState() => _CustomersTabState();
}

/// Who buys film — and, a tap away, who owes: how much, how long, and a
/// reminder in WhatsApp already written (owner, 11.11.2026).
class _CustomersTabState extends ConsumerState<_CustomersTab> {
  bool _debtors = false;

  @override
  Widget build(BuildContext context) {
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
      data: (all) {
        final owing = [
          for (final c in all)
            if (c.debt > 0.5) c,
        ]..sort((a, b) => (b.debtDays ?? 0).compareTo(a.debtDays ?? 0));
        final rows = _debtors ? owing : all;
        final owed = owing.fold<double>(0, (s, c) => s + c.debt);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (owing.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  key: const ValueKey('filmCustomers:debtors'),
                  label: Text(
                    l10n.filmDebtors(owing.length, money.format(owed)),
                  ),
                  selected: _debtors,
                  onSelected: (on) => setState(() => _debtors = on),
                ),
              ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l10n.filmCustomersEmpty),
              ),
            for (final c in rows)
              ListTile(
                leading: c.debt > 0.5 && c.phone != null
                    ? IconButton(
                        key: ValueKey('filmCustomer:remind:${c.customer}'),
                        tooltip: l10n.filmRemind,
                        icon: const Icon(AppIcons.whatsApp),
                        onPressed: () => ContactActions.whatsAppMessage(
                          c.phone,
                          l10n.filmRemindText(c.name, money.format(c.debt)),
                        ),
                      )
                    : null,
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
                    if (c.debt > 0.5 && c.debtDays != null)
                      l10n.filmDebtDays(c.debtDays!),
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
        );
      },
    );
  }
}
