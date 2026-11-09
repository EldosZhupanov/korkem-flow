import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Долги» — OnayBaza's «Қарыз»: the total, who owes the most, then every
/// order that is not paid up. An order handed over with a debt is marked:
/// that is the money hardest to collect.
class MdfDebtsScreen extends ConsumerWidget {
  const MdfDebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final debts = ref.watch(mdfDebtsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfDebtsTitle)),
      body: debts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(mdfDebtsProvider),
        ),
        data: (d) => d.orders.isEmpty
            ? EmptyView(
                title: l10n.mdfDebtsEmpty,
                message: l10n.mdfDebtsEmptyHint,
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(mdfDebtsProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    ReadableWidth(
                      child: Text(
                        l10n.mdfDebtsTotal(money.format(d.total)),
                        key: const ValueKey('debtsTotal'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReadableWidth(child: SectionLabel(l10n.mdfDebtsByCustomer)),
                    for (final c in d.customers)
                      ReadableWidth(
                        child: ListTile(
                          key: ValueKey('debtCustomer:${c.customer}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(c.customerName),
                          subtitle: Text(l10n.mdfDebtsOrders(c.orders)),
                          trailing: Text(
                            money.format(c.debt),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    ReadableWidth(child: SectionLabel(l10n.mdfDebtsByOrder)),
                    for (final o in d.orders)
                      ReadableWidth(
                        child: ListTile(
                          key: ValueKey('debtOrder:${o.name}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('${o.name} · ${o.customerName}'),
                          subtitle: Text(
                            l10n.mdfPaidDebt(
                              money.format(o.paid),
                              money.format(o.debt),
                            ),
                          ),
                          trailing: o.handedOver
                              ? StatusChip(
                                  label: l10n.mdfDebtsHandedOver,
                                  intent: StatusIntent.danger,
                                  compact: true,
                                )
                              : Text(mdfDay(o.createdOn)),
                          onTap: () => context.push(Routes.mdfOrder(o.name)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
