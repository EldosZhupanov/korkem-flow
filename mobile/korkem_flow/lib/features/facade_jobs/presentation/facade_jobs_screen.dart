import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/facade_jobs/data/facade_job_repository.dart';
import 'package:korkem_flow/features/facade_jobs/domain/facade_job.dart';
import 'package:korkem_flow/features/facade_jobs/presentation/crew_dialog.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final facadeJobsProvider = FutureProvider.autoDispose<List<FacadeJob>>(
  (ref) => ref.watch(facadeJobRepositoryProvider).fetch(),
);

/// What the shop floor has to make: facades from submitted orders, by order,
/// soonest due first. Sizes and options only — no prices reach this screen.
class FacadeJobsScreen extends ConsumerWidget {
  const FacadeJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jobsAsync = ref.watch(facadeJobsProvider);
    return AppScreen(
      title: l10n.facadeJobsTitle,
      actions: [
        IconButton(
          tooltip: l10n.actionRefresh,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(facadeJobsProvider),
        ),
      ],
      body: jobsAsync.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(facadeJobsProvider),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return EmptyView(
              icon: AppIcons.task,
              title: l10n.facadeJobsEmptyTitle,
              message: l10n.facadeJobsEmptyMessage,
            );
          }
          final byOrder = <String, List<FacadeJob>>{};
          for (final job in jobs) {
            byOrder.putIfAbsent(job.salesOrder, () => []).add(job);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(facadeJobsProvider);
              await ref.read(facadeJobsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final entry in byOrder.entries)
                  ReadableWidth(child: _OrderCard(jobs: entry.value)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.jobs});

  final List<FacadeJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final first = jobs.first;
    final due = first.dueOn;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              [
                first.salesOrder,
                if (first.customer != null) first.customer!,
                if (due != null)
                  l10n.facadeJobsDue(
                    '${due.day.toString().padLeft(2, '0')}.'
                    '${due.month.toString().padLeft(2, '0')}',
                  ),
              ].join(' · '),
            ),
            if (first.urgent)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: StatusChip(
                  key: ValueKey('facadeUrgent:${first.salesOrder}'),
                  label: l10n.orderUrgent,
                  intent: StatusIntent.danger,
                  compact: true,
                ),
              ),
            for (final job in jobs) _JobTile(job: job),
          ],
        ),
      ),
    );
  }
}

class _JobTile extends ConsumerWidget {
  const _JobTile({required this.job});

  final FacadeJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final decor = [?job.decorTop, ?job.decorBottom].join(' / ');
    final options = [
      job.finish,
      if (job.thicknessMm case final mm?) '$mm мм',
      if (decor.isNotEmpty) decor,
      ?job.edgeProfile,
      if (job.doubleSided) l10n.facadeQuoteDoubleSided,
      if (job.customerMaterial) l10n.facadeQuoteCustomerMaterial,
      if (job.colorGroup case final group?) l10n.facadeSpecGroup(group),
    ].join(' · ');
    return ListTile(
      key: ValueKey('facadeJob:${job.line}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${job.widthMm}×${job.heightMm} мм · ${job.qty} ${l10n.facadeQuoteQty}'
        ' · ${job.milling}',
      ),
      subtitle: Text(options),
      trailing: StatusChip(
        label: job.status.wire,
        intent: switch (job.status) {
          FacadeJobStatus.queued => StatusIntent.neutral,
          FacadeJobStatus.inWork => StatusIntent.info,
          FacadeJobStatus.done => StatusIntent.success,
        },
        compact: true,
      ),
      onTap: () => _choose(context, ref),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    // `null` status with crew = «Готово», made together.
    var together = false;
    final next = await showModalBottomSheet<FacadeJobStatus>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in FacadeJobStatus.values)
              ListTile(
                key: ValueKey('facadeJobStatus:${status.name}'),
                title: Text(status.wire),
                trailing: status == job.status
                    ? const Icon(AppIcons.check)
                    : null,
                onTap: () => Navigator.of(sheet).pop(status),
              ),
            if (job.status != FacadeJobStatus.done)
              ListTile(
                key: const ValueKey('facadeJobDoneTogether'),
                leading: const Icon(AppIcons.team),
                title: Text(l10n.crewDoneTogether),
                onTap: () {
                  together = true;
                  Navigator.of(sheet).pop(FacadeJobStatus.done);
                },
              ),
          ],
        ),
      ),
    );
    if (next == null || next == job.status) return;
    List<CrewShare>? crew;
    if (together) {
      if (!context.mounted) return;
      crew = await pickCrew(context);
      if (crew == null) return;
    }
    try {
      await ref
          .read(facadeJobRepositoryProvider)
          .setStatus(job.line, next, crew: crew);
      ref.invalidate(facadeJobsProvider);
    } on MutationQueued {
      messenger.showFailureMessage(l10n.outboxQueued);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}
