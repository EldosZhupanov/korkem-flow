import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// How the list is ordered.
enum _Sort { money, debt, slow }

/// «Рейтинг клиентов» (owner, 25.11.2026): who brings the most money, who
/// pays fast, who drags it out — for three months, a year or all the time.
class CustomerRatingScreen extends ConsumerStatefulWidget {
  const CustomerRatingScreen({super.key});

  @override
  ConsumerState<CustomerRatingScreen> createState() =>
      _CustomerRatingScreenState();
}

class _CustomerRatingScreenState extends ConsumerState<CustomerRatingScreen> {
  RatingPeriod _period = RatingPeriod.months12;
  _Sort _sort = _Sort.money;

  List<RatedCustomer> _sorted(List<RatedCustomer> all) => switch (_sort) {
    _Sort.money => all,
    _Sort.debt => [
      for (final c in all)
        if (c.debt > 0.5) c,
    ]..sort((a, b) => b.debt.compareTo(a.debt)),
    // Who drags it out: the marked first, then by how long he owes.
    _Sort.slow =>
      [
        for (final c in all)
          if (c.mark == PayMark.slow || (c.oldestDebtDays ?? 0) > 0) c,
      ]..sort((a, b) {
        final marked = (b.mark == PayMark.slow ? 1 : 0).compareTo(
          a.mark == PayMark.slow ? 1 : 0,
        );
        return marked != 0
            ? marked
            : (b.oldestDebtDays ?? 0).compareTo(a.oldestDebtDays ?? 0);
      }),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final rating = ref.watch(customerRatingProvider(_period));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rateTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: ReadableWidth(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (p, label) in [
                    (RatingPeriod.months3, l10n.rateP3),
                    (RatingPeriod.months12, l10n.rateP12),
                    (RatingPeriod.all, l10n.actAllTime),
                  ])
                    ChoiceChip(
                      key: ValueKey('rate:period:${p.wire}'),
                      label: Text(label),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  for (final (s, label) in [
                    (_Sort.money, l10n.rateByMoney),
                    (_Sort.debt, l10n.rateByDebt),
                    (_Sort.slow, l10n.rateBySlow),
                  ])
                    FilterChip(
                      key: ValueKey('rate:sort:${s.name}'),
                      label: Text(label),
                      selected: _sort == s,
                      onSelected: (_) => setState(() => _sort = s),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: rating.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(customerRatingProvider(_period)),
              ),
              data: (r) {
                final rows = _sorted(r.customers);
                if (rows.isEmpty) {
                  return EmptyView(title: l10n.rateEmpty);
                }
                final place = {
                  for (final (i, c) in r.customers.indexed) c.customer: i + 1,
                };
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    ReadableWidth(
                      child: Text(
                        l10n.rateTotal(money.format(r.total)),
                        key: const ValueKey('rate:total'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    ReadableWidth(
                      child: Text(
                        l10n.rateClassHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final c in rows)
                      ReadableWidth(
                        child: _Row(c: c, place: place[c.customer] ?? 0),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.c, required this.place});

  final RatedCustomer c;
  final int place;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final days = c.payDays;
    final mark = c.mark;
    return ListTile(
      key: ValueKey('rate:${c.customer}'),
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push(Routes.clientCard(c.customer)),
      leading: CircleAvatar(
        backgroundColor: c.grade == 'A'
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Text('$place'),
      ),
      title: Row(
        children: [
          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            c.grade,
            key: ValueKey('rate:class:${c.customer}'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (mark != null) ...[
            const SizedBox(width: AppSpacing.xs),
            StatusChip(
              key: ValueKey('rate:mark:${c.customer}'),
              compact: true,
              label: switch (mark) {
                PayMark.fast => l10n.rateFast,
                PayMark.usual => l10n.rateUsual,
                PayMark.slow => l10n.rateSlow,
              },
              intent: switch (mark) {
                PayMark.fast => StatusIntent.success,
                PayMark.usual => StatusIntent.neutral,
                PayMark.slow => StatusIntent.danger,
              },
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          l10n.rateOrders(c.orders, c.share.toStringAsFixed(1)),
          if (days != null)
            l10n.ratePayDays(days.toStringAsFixed(days % 1 == 0 ? 0 : 1))
          else
            l10n.rateNoPaid,
        ].join(' · '),
        style: muted,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money.format(c.total), style: theme.textTheme.titleSmall),
          if (c.debt > 0.5)
            Text(
              l10n.rateOwes(money.format(c.debt), c.oldestDebtDays ?? 0),
              key: ValueKey('rate:debt:${c.customer}'),
              style: muted?.copyWith(color: status.danger),
            ),
        ],
      ),
    );
  }
}
