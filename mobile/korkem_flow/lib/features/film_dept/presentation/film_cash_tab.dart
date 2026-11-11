import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
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
  bool _month = false;

  ({String? since, String? until}) get _period {
    final now = DateTime.now();
    final today = mdfIso(now);
    return _month
        ? (since: mdfIso(DateTime(now.year, now.month)), until: today)
        : (since: today, until: today);
  }

  Future<void> _settle(FilmOwed o, String method) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(filmDeptRepositoryProvider)
          .settleDelivery(o.receipt, method);
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
    return ref
        .watch(filmCashProvider(period))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(filmCashProvider(period)),
          ),
          data: (b) {
            Widget line(String label, double v, {TextStyle? style}) => Row(
              children: [
                Expanded(child: Text(label, style: style)),
                Text(money.format(v), style: style),
              ],
            );
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
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('filmCash:settle:${o.receipt}'),
                          onSelected: (m) => _settle(o, m),
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
                              key == 'employee'
                                  ? l10n.filmGaveBack
                                  : l10n.filmPaidCarrier,
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
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.filmCashToday),
                    ),
                    ButtonSegment(value: true, label: Text(l10n.filmCashMonth)),
                  ],
                  selected: {_month},
                  onSelectionChanged: (v) => setState(() => _month = v.first),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.filmCashIn, style: theme.textTheme.titleMedium),
                if (b.ins.isEmpty) Text(l10n.filmCashNothing),
                for (final r in b.ins) line(r.way, r.amount),
                line(
                  l10n.filmCashTotal,
                  b.inTotal,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.filmCashOut, style: theme.textTheme.titleMedium),
                if (b.outs.isEmpty) Text(l10n.filmCashNothing),
                for (final o in b.outs)
                  line(
                    [
                      mdfDay(o.date, year: false),
                      o.what,
                      ?o.way,
                    ].join(' · '),
                    o.amount,
                  ),
                line(
                  l10n.filmCashTotal,
                  b.outTotal,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Divider(),
                line(
                  l10n.filmCashBalance,
                  b.balance,
                  style: theme.textTheme.titleLarge,
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
              ],
            );
          },
        );
  }
}
