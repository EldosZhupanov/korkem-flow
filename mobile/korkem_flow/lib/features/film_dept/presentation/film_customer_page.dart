import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_print.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

/// One customer of the film department on a page (owner, 12.11.2026): what
/// he bought in all, what he owes, the film he takes most; his purchases;
/// his terms; sell to him, call him, write to him.
class FilmCustomerPage extends ConsumerWidget {
  const FilmCustomerPage({required this.customer, super.key});

  final FilmCustomer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final c =
        ref
            .watch(filmCustomersProvider)
            .value
            ?.where((x) => x.customer == customer.customer)
            .firstOrNull ??
        customer;
    final sales = ref.watch(filmCustomerSalesProvider(c.customer));
    final stock = ref.watch(filmStockProvider).value;

    // The film he takes most, by metres.
    final byFilm = <String, double>{};
    for (final s in sales.value ?? const <FilmSale>[]) {
      for (final l in s.lines) {
        byFilm[l.title] = (byFilm[l.title] ?? 0) + l.metres;
      }
    }
    // His three films, most first (owner, 13.11.2026).
    final favourites =
        (byFilm.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .toList();
    final favourite = favourites.firstOrNull?.key;
    final rows = sales.value ?? const <FilmSale>[];
    final profits = [
      for (final s in rows)
        if (s.profit != null) s.profit!,
    ];
    final average = c.sales > 0 ? c.total / c.sales : null;

    void refresh() => ref
      ..invalidate(filmCustomersProvider)
      ..invalidate(filmCustomerSalesProvider(c.customer))
      ..invalidate(filmSalesProvider)
      ..invalidate(filmStockProvider);

    Widget fact(String label, String value, {Color? color}) => SizedBox(
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
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            [
              if (c.wholesale) l10n.filmWholesale else l10n.filmRetail,
              if (c.discount > 0) '−${filmMetres(c.discount)}%',
              ?c.phone,
              if (c.last != null) l10n.filmCustomerLast(mdfDay(c.last)),
            ].join(' · '),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              fact(l10n.filmCustomerBought, '${filmMetres(c.totalM)} м'),
              fact(l10n.filmCustomerSum, money.format(c.total)),
              fact(
                l10n.filmCustomerDebt,
                money.format(c.debt),
                color: c.debt > 0.5 ? status.danger : status.success,
              ),
              fact(l10n.filmCustomerMonth, '${filmMetres(c.monthM)} м'),
              if (average != null)
                fact(l10n.filmCustomerAverage, money.format(average)),
              if (c.rhythmDays != null)
                fact(
                  l10n.filmCustomerRhythm,
                  l10n.filmSaleEvery(c.rhythmDays!),
                ),
              if (profits.isNotEmpty)
                fact(
                  l10n.filmSalesProfit,
                  '≈ ${money.format(profits.fold<double>(0, (a, p) => a + p))}',
                  color: status.success,
                ),
              if (c.debtLimit != null || c.debtLimitDays != null)
                fact(
                  l10n.filmCustomerLimit,
                  [
                    if (c.debtLimit case final l?) money.format(l),
                    if (c.debtLimitDays case final d?) l10n.filmLimitDays(d),
                  ].join(' ').trim(),
                  color: c.overLimit(0) != null ? status.danger : null,
                ),
              if (favourite != null)
                fact(
                  l10n.filmCustomerFavourite,
                  [
                    for (final f in favourites)
                      '${f.key} ${filmMetres(f.value)} м',
                  ].join('\n'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (stock != null && stock.canEdit)
                FilledButton.icon(
                  key: const ValueKey('filmCustomerPage:sell'),
                  onPressed: () async {
                    final done = await showFilmSale(
                      context,
                      stock,
                      customer: c.customer,
                    );
                    if (done ?? false) refresh();
                  },
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.filmSell),
                ),
              // «Акт сверки» (owner, 13.11.2026): every sale and payment,
              // the balance after each — to print or send.
              OutlinedButton.icon(
                key: const ValueKey('filmCustomerPage:statement'),
                onPressed: rows.isEmpty
                    ? null
                    : () async {
                        final locale = Localizations.localeOf(
                          context,
                        ).toString();
                        final bytes = await buildFilmStatementPdf(
                          c.name,
                          [...rows].reversed.toList(),
                          (
                            title: l10n.filmStatement,
                            customer: l10n.filmStatementCustomer,
                            onDay: l10n.filmStatementOn,
                            date: l10n.filmStatementDate,
                            what: l10n.filmStatementWhat,
                            sold: l10n.filmStatementSold,
                            paid: l10n.filmStatementPaid,
                            balance: l10n.filmStatementBalance,
                            sale: l10n.filmStatementSale,
                            payment: l10n.filmStatementPayment,
                            owes: l10n.filmStatementOwes,
                            settled: l10n.filmStatementSettled,
                            signs: l10n.filmStatementSigns,
                          ),
                          today: mdfIso(DateTime.now()),
                          locale: locale,
                        );
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: 'akt-${c.customer}.pdf',
                        );
                      },
                icon: const Icon(AppIcons.print),
                label: Text(l10n.filmStatement),
              ),
              OutlinedButton(
                key: const ValueKey('filmCustomerPage:terms'),
                onPressed: () async {
                  final done = await showFilmCustomerTerms(context, c);
                  if (done ?? false) refresh();
                },
                child: Text(l10n.filmCustomerTerms),
              ),
              if (c.phone != null) ...[
                OutlinedButton.icon(
                  onPressed: () => ContactActions.call(c.phone),
                  icon: const Icon(AppIcons.call),
                  label: Text(l10n.filmCall),
                ),
                OutlinedButton.icon(
                  onPressed: () => c.debt > 0.5
                      ? ContactActions.whatsAppMessage(
                          c.phone,
                          l10n.filmRemindText(c.name, money.format(c.debt)),
                        )
                      : ContactActions.whatsApp(c.phone),
                  icon: const Icon(AppIcons.whatsApp),
                  label: Text(c.debt > 0.5 ? l10n.filmRemind : l10n.filmWrite),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.filmCustomerHistory, style: theme.textTheme.titleMedium),
          ...sales.when(
            loading: () => const [LinearProgressIndicator()],
            error: (e, _) => [Text('$e')],
            data: (rows) => [
              if (rows.isEmpty) Text(l10n.filmHistoryEmpty),
              for (final s in rows)
                ListTile(
                  key: ValueKey('filmCustomerSale:${s.entry}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    [
                      mdfDay(s.date),
                      for (final l in s.lines)
                        '${l.title} ${filmMetres(l.metres)} м',
                    ].join(' · '),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money.format(s.amount ?? 0)),
                      if ((s.debt ?? 0) > 0.5)
                        Text(
                          l10n.filmSaleDebt(money.format(s.debt)),
                          style: TextStyle(color: status.danger),
                        ),
                    ],
                  ),
                  onTap: () async {
                    final done = await showFilmSaleCard(context, s);
                    if (done ?? false) refresh();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
