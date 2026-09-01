import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/orders/application/order_detail_controller.dart';
import 'package:korkem_flow/features/orders/domain/sales_order.dart';
import 'package:korkem_flow/features/orders/presentation/sales_order_status_label.dart';
import 'package:korkem_flow/features/orders/presentation/start_production_button.dart';
import 'package:korkem_flow/features/production/domain/work_order.dart';
import 'package:korkem_flow/features/production/presentation/work_order_status_label.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One order, and the production raised for it.
///
/// The order list could not answer "what is happening with this one" — it
/// showed a row and had nowhere to go. This is that somewhere.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(name));

    return AppScreen(
      title: name,
      subtitle: order.value?.customer,
      body: switch (order) {
        AsyncData(:final value) => _Body(order: value),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(orderDetailProvider(name)),
        ),
        // Riverpod 3 keeps a failed provider in `AsyncLoading(retrying)`, so a
        // spinner here can outlive the request. That is the router's problem
        // too — see `korkem-flutter` — and the reason tests disable retry.
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jobs = ref.watch(orderWorkOrdersProvider(order.name));

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(orderDetailProvider(order.name))
          ..invalidate(orderWorkOrdersProvider(order.name));
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Header(order: order),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.orderProductionSection),
          const SizedBox(height: AppSpacing.sm),
          switch (jobs) {
            AsyncData(:final value) => _Jobs(order: order, jobs: value),
            AsyncError(:final error) => ErrorView(
              error: error,
              onRetry: () =>
                  ref.invalidate(orderWorkOrdersProvider(order.name)),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final money = NumberFormat.currency(
      locale: locale,
      symbol: '₸',
      decimalDigits: 0,
    );
    final date = DateFormat.yMMMd(locale);
    final isLate = order.isLateAt(ref.watch(clockProvider)());
    final transaction = order.transactionDate;
    final delivery = order.deliveryDate;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              label: order.status.label(l10n),
              intent: order.status.intent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(icon: AppIcons.quote, label: money.format(order.grandTotal)),
          if (transaction != null)
            _Field(
              icon: AppIcons.schedule,
              label: l10n.ordersTransactionDate(date.format(transaction)),
            ),
          if (delivery != null)
            _Field(
              icon: AppIcons.schedule,
              label: l10n.ordersDeliveryDate(date.format(delivery)),
              intent: isLate ? StatusIntent.danger : null,
            ),
          // The server's own number. Nothing here recomputes it from the
          // lines: two answers to "how much shipped" is one answer too many.
          _Field(
            icon: AppIcons.warehouse,
            label: l10n.ordersDeliveredProgress(
              '${order.perDelivered.round()}',
            ),
          ),
        ],
      ),
    );
  }
}

class _Jobs extends ConsumerWidget {
  const _Jobs({required this.order, required this.jobs});

  final SalesOrder order;
  final List<WorkOrder> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (jobs.isEmpty) {
      // Not an empty list — a statement. Production has not been started, and
      // the one thing a person would want to do about that is right here.
      return Column(
        children: [
          EmptyView(
            icon: AppIcons.workOrder,
            title: l10n.orderNoProductionTitle,
            message: l10n.orderNoProductionBody,
          ),
          const SizedBox(height: AppSpacing.md),
          StartProductionButton(
            salesOrder: order.name,
            onStarted: () async {
              ref
                ..invalidate(orderWorkOrdersProvider(order.name))
                ..invalidate(orderDetailProvider(order.name));
            },
          ),
        ],
      );
    }

    return Column(
      children: [for (final job in jobs) _JobCard(job: job)],
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job});

  final WorkOrder job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quantity = NumberFormat.decimalPattern(locale);
    final date = DateFormat.yMMMd(locale);
    final plannedEnd = job.plannedEndDate;
    final isLate =
        plannedEnd != null &&
        !job.status.isFinished &&
        plannedEnd.isBefore(ref.watch(clockProvider)());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.itemName ?? job.productionItem ?? job.id,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusChip(
                  label: job.status.label(l10n),
                  intent: job.status.intent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Field(
              icon: AppIcons.workOrder,
              label:
                  '${quantity.format(job.producedQty)} / '
                  '${quantity.format(job.qty)}',
            ),
            if (plannedEnd != null)
              _Field(
                icon: AppIcons.schedule,
                label: date.format(plannedEnd),
                intent: isLate ? StatusIntent.danger : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, this.intent});

  final IconData icon;
  final String label;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = intent == StatusIntent.danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.dense, color: colour),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}
