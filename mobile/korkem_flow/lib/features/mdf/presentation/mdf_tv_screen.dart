import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_deadline.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// How often the wall screen asks again.
const mdfTvRefresh = Duration(minutes: 5);

/// The shop's wall screen (owner, 08.11.2026): every order still in the shop
/// in three big columns — «Сегодня» (today or late), «Завтра», «Дальше» —
/// urgent first, each with the stage it waits at and «не успевает». It asks
/// again every five minutes by itself; nobody has to touch it.
class MdfTvScreen extends ConsumerStatefulWidget {
  const MdfTvScreen({super.key});

  @override
  ConsumerState<MdfTvScreen> createState() => _MdfTvScreenState();
}

class _MdfTvScreenState extends ConsumerState<MdfTvScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      mdfTvRefresh,
      (_) => ref.invalidate(mdfPlanProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(mdfPlanProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfTvTitle)),
      body: plan.when(
        // The last picture stays up while the next one loads.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(mdfPlanProvider),
        ),
        data: (p) {
          final columns = mdfTvColumns(p);
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in MdfDeadline.values)
                  Expanded(
                    child: _Column(
                      key: ValueKey('tv:${d.name}'),
                      deadline: d,
                      orders: columns[d]!,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The plan's orders by their traffic light, urgent first, then by date.
Map<MdfDeadline, List<PlanOrder>> mdfTvColumns(MdfPlan plan) {
  final out = {for (final d in MdfDeadline.values) d: <PlanOrder>[]};
  for (final s in plan.stages) {
    for (final o in s.orders) {
      out[o.deadline]!.add(o);
    }
  }
  for (final list in out.values) {
    list.sort((a, b) {
      if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
      return a.deliveryDate.compareTo(b.deliveryDate);
    });
  }
  return out;
}

class _Column extends StatelessWidget {
  const _Column({required this.deadline, required this.orders, super.key});

  final MdfDeadline deadline;
  final List<PlanOrder> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = context.statusColors.resolve(mdfDeadlineIntent(deadline));
    final title = switch (deadline) {
      MdfDeadline.now => l10n.mdfDeadlineToday,
      MdfDeadline.tomorrow => l10n.mdfDeadlineTomorrow,
      MdfDeadline.later => l10n.mdfDeadlineLater,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '$title · ${orders.length}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.surface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              children: [
                for (final o in orders) _Card(order: o, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.order, required this.color});

  final PlanOrder order;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final o = order;
    return Card(
      key: ValueKey('tvOrder:${o.name}'),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: o.urgent ? theme.colorScheme.error : color,
          width: o.urgent ? AppSpacing.xs : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${o.name} · ${o.customerName}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: o.urgent ? theme.colorScheme.error : null,
              ),
            ),
            Text(
              [
                o.decorTop,
                o.milling,
                '${o.areaM2.toStringAsFixed(2)} м²',
              ].whereType<String>().join(' · '),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (o.stage != null)
                  StatusChip(
                    label: mdfStageLabel(o.stage!, l10n),
                    intent: StatusIntent.info,
                  ),
                MdfDeadlineChips(order: o),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
