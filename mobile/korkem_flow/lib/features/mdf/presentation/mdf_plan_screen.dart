import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _m2(double v) => v.toStringAsFixed(2);

/// «Жоспар» — the shop's plan: each stage with the orders waiting for it and
/// their m², earliest due first; a tick moves an order to its next stage.
/// The manager does the ticking (owner, 01.11.2026).
class MdfPlanScreen extends ConsumerStatefulWidget {
  const MdfPlanScreen({super.key});

  @override
  ConsumerState<MdfPlanScreen> createState() => _MdfPlanScreenState();
}

class _MdfPlanScreenState extends ConsumerState<MdfPlanScreen> {
  String? _busy;

  Future<void> _tick(PlanStage stage, PlanOrder order) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = order.name);
    try {
      await ref
          .read(mdfOrderRepositoryProvider)
          .setStage(order.name, stage.stage, done: true);
      messenger.showDone(
        l10n.mdfPlanTicked(order.name, mdfStageLabel(stage.stage, l10n)),
      );
      ref.invalidate(mdfPlanProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = ref.watch(mdfPlanProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfPlanTitle)),
      body: plan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(mdfPlanProvider),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(mdfPlanProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ReadableWidth(
                child: Text(
                  l10n.mdfPlanInWork(_m2(p.inWorkM2)),
                  key: const ValueKey('planInWork'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in p.stages)
                    if (s.orders.isNotEmpty)
                      StatusChip(
                        label:
                            '${mdfStageLabel(s.stage, l10n)}: '
                            '${s.orders.length} · ${_m2(s.areaM2)} м²',
                        intent: StatusIntent.info,
                      ),
                ],
              ),
              for (final s in p.stages)
                if (s.orders.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ReadableWidth(
                    child: SectionLabel(
                      '${mdfStageLabel(s.stage, l10n)} · '
                      '${_m2(s.areaM2)} м²',
                    ),
                  ),
                  for (final o in s.orders)
                    ReadableWidth(
                      child: ListTile(
                        key: ValueKey('plan:${s.stage.name}:${o.name}'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('${o.name} · ${o.customerName}'),
                        subtitle: Text(
                          [
                            o.decorTop,
                            o.milling,
                            '${_m2(o.areaM2)} м²',
                            o.deliveryDate,
                          ].whereType<String>().join(' · '),
                          style: o.overdue
                              ? theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                )
                              : null,
                        ),
                        onTap: () => context.push(Routes.mdfOrder(o.name)),
                        trailing: IconButton(
                          key: ValueKey('planTick:${o.name}'),
                          tooltip: l10n.mdfPlanTick,
                          onPressed: _busy == null ? () => _tick(s, o) : null,
                          icon: const Icon(AppIcons.check),
                        ),
                      ),
                    ),
                ],
              if (p.intake.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                ReadableWidth(child: SectionLabel(l10n.mdfPlanIntake)),
                for (final d in p.intake)
                  ReadableWidth(
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(d.date),
                      trailing: Text(
                        l10n.mdfPlanIntakeDay('${d.orders}', _m2(d.areaM2)),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
