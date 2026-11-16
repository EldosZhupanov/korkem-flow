import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/cnc/data/cnc_repository.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String cncStatusLabel(CncStatus s, AppLocalizations l10n) => switch (s) {
  CncStatus.draft => l10n.cncStatusDraft,
  CncStatus.queued => l10n.cncStatusQueued,
  CncStatus.onMachine => l10n.cncStatusOnMachine,
  CncStatus.ready => l10n.cncStatusReady,
  CncStatus.handedOver => l10n.cncStatusHandedOver,
  CncStatus.cancelled => l10n.cncStatusCancelled,
};

StatusIntent cncStatusIntent(CncStatus s) => switch (s) {
  CncStatus.draft => StatusIntent.neutral,
  CncStatus.queued => StatusIntent.info,
  CncStatus.onMachine => StatusIntent.warning,
  CncStatus.ready => StatusIntent.success,
  CncStatus.handedOver => StatusIntent.neutral,
  CncStatus.cancelled => StatusIntent.danger,
};

String cncMinutes(double minutes, AppLocalizations l10n) =>
    cncDuration(minutes, l10n.cncHours, l10n.cncMinutesShort);

/// «Услуги ЧПУ» (owner, 15.11.2026): the machine's queue — how many hours
/// are booked, what is ready to hand over, what is owed — and the orders,
/// newest first, each with when it will be ready.
class CncOrdersScreen extends ConsumerStatefulWidget {
  const CncOrdersScreen({super.key});

  @override
  ConsumerState<CncOrdersScreen> createState() => _CncOrdersScreenState();
}

class _CncOrdersScreenState extends ConsumerState<CncOrdersScreen> {
  CncStatus? _status;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  CncQuery get _query => (status: _status, search: _search.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final listing = ref.watch(cncListingProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cncTitle),
        actions: [
          IconButton(
            key: const ValueKey('cncPrices'),
            tooltip: l10n.cncPricesTitle,
            icon: const Icon(AppIcons.payroll),
            onPressed: () => context.push(Routes.cncPrices),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('cncNew'),
        onPressed: () async {
          await context.push(Routes.cncOrderNew);
          ref.invalidate(cncListingProvider);
        },
        icon: const Icon(AppIcons.add),
        label: Text(l10n.cncNewOrder),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cncListingProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (listing.value case final l?)
              ReadableWidth(
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Figure(
                      key: const ValueKey('cncQueue'),
                      label: l10n.cncQueueLabel,
                      value: cncMinutes(l.queueMinutes, l10n),
                      hint: l10n.cncQueueOrders(l.queueOrders),
                    ),
                    _Figure(
                      label: l10n.cncReadyLabel,
                      value: '${l.ready}',
                    ),
                    _Figure(
                      label: l10n.cncDebtLabel,
                      value: money.format(l.debt),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            ReadableWidth(
              child: TextField(
                key: const ValueKey('cncSearch'),
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(AppIcons.search),
                  hintText: l10n.cncSearchHint,
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ReadableWidth(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    key: const ValueKey('cncStatus:all'),
                    label: Text(l10n.cncStatusAll),
                    selected: _status == null,
                    onSelected: (_) => setState(() => _status = null),
                  ),
                  for (final s in CncStatus.values)
                    ChoiceChip(
                      key: ValueKey('cncStatus:${s.wire}'),
                      label: Text(cncStatusLabel(s, l10n)),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...switch (listing) {
              AsyncData(:final value) when value.orders.isEmpty => [
                ReadableWidth(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      l10n.cncEmpty,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
              AsyncData(:final value) => [
                for (final o in value.orders)
                  ReadableWidth(
                    child: ListTile(
                      key: ValueKey('cncRow:${o.name}'),
                      title: Text('${o.name} · ${o.customerName}'),
                      subtitle: Text(
                        [
                          if (o.eta case final eta?)
                            l10n.cncEta(mdfDay(eta, year: false))
                          else
                            l10n.cncDue(mdfDay(o.due, year: false)),
                          if (o.minutes > 0) cncMinutes(o.minutes, l10n),
                          if (o.hold case final hold?) l10n.cncHolding(hold),
                          if (o.debt > 0) l10n.cncOwes(money.format(o.debt)),
                        ].join(' · '),
                      ),
                      leading: o.urgent
                          ? Icon(
                              AppIcons.warning,
                              color: context.statusColors.danger,
                            )
                          : null,
                      trailing: Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(money.format(o.total)),
                          StatusChip(
                            label: cncStatusLabel(o.status, l10n),
                            intent: cncStatusIntent(o.status),
                            compact: true,
                          ),
                        ],
                      ),
                      onTap: () async {
                        await context.push(Routes.cncOrder(o.name));
                        ref.invalidate(cncListingProvider);
                      },
                    ),
                  ),
              ],
              AsyncError(:final error) => [
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(cncListingProvider),
                ),
              ],
              _ => [const LinearProgressIndicator()],
            },
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.hint,
    super.key,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleLarge),
          if (hint case final h?) Text(h, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
