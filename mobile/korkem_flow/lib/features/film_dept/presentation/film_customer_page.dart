import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

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
    final favourite = byFilm.entries.isEmpty
        ? null
        : byFilm.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

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
              if (favourite != null)
                fact(l10n.filmCustomerFavourite, favourite),
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
