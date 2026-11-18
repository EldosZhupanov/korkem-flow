import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/mdf/data/my_work_repository.dart';
import 'package:korkem_flow/features/mdf/domain/my_work.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/order_scan_sheet.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Мои заказы» — a worker's own stages, from his own phone (owner,
/// 17.11.2026): what he can do now, what is coming to him, and his m² this
/// month. «Сделал» ticks his stage with his name; whoever has no phone, the
/// manager ticks for.
class MyWorkScreen extends ConsumerStatefulWidget {
  const MyWorkScreen({super.key});

  @override
  ConsumerState<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends ConsumerState<MyWorkScreen> {
  String? _busy;

  Future<void> _done(MyWorkStage row, {bool undo = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(myWorkRepositoryProvider);
    final stage = mdfStageLabel(row.stage, l10n);
    setState(() => _busy = '${row.order}:${row.stage.name}');
    try {
      await repo.done(row.order, row.stage, undo: undo);
      ref.invalidate(myWorkProvider);
      if (undo) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.myWorkDone(row.order, stage)),
            action: SnackBarAction(
              label: l10n.myWorkUndo,
              onPressed: () => _done(row, undo: true),
            ),
          ),
        );
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final work = ref.watch(myWorkProvider);
    return AppScreen(
      title: l10n.myWorkTitle,
      subtitle: work.value?.name,
      actions: [
        // A sticker that will not read, or no scanner: its number.
        IconButton(
          key: const ValueKey('myWorkScanEntry'),
          tooltip: l10n.scanEntryTitle,
          icon: const Icon(AppIcons.qrScan),
          onPressed: () => showScanEntry(context),
        ),
        IconButton(
          tooltip: l10n.adminStatsRetry,
          icon: const Icon(AppIcons.refresh),
          onPressed: () => ref.invalidate(myWorkProvider),
        ),
      ],
      body: work.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(myWorkProvider),
        ),
        data: (w) => w.name == null
            ? EmptyView(
                icon: AppIcons.team,
                title: l10n.myWorkNotLinkedTitle,
                message: l10n.myWorkNotLinked,
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myWorkProvider);
                  await ref.read(myWorkProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    ReadableWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Month(work: w),
                          const SizedBox(height: AppSpacing.lg),
                          SectionLabel(l10n.myWorkReady),
                          if (w.ready.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Text(l10n.myWorkNothingReady),
                            ),
                          for (final row in w.ready)
                            _StageCard(
                              row: row,
                              busy: _busy == '${row.order}:${row.stage.name}',
                              onDone: _busy == null ? () => _done(row) : null,
                            ),
                          if (w.coming.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            SectionLabel(l10n.myWorkComing),
                            for (final row in w.coming) _StageCard(row: row),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Month extends StatelessWidget {
  const _Month({required this.work});

  final MyWork work;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AppCard(
      key: const ValueKey('myWorkMonth'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.myWorkMonth, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.myWorkMonthTotal(
              work.monthM2.toStringAsFixed(2),
              work.monthOrders,
            ),
            style: theme.textTheme.headlineSmall,
          ),
          if (work.monthByStage.isNotEmpty)
            Text(
              [
                for (final e in work.monthByStage.entries)
                  l10n.myWorkStageM2(
                    mdfStageLabel(e.key, l10n),
                    e.value.toStringAsFixed(2),
                  ),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.row, this.busy = false, this.onDone});

  final MyWorkStage row;
  final bool busy;

  /// Null on a stage still coming: nothing to tick yet.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final coming = row.waitingFor.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        key: ValueKey('myWork:${row.order}:${row.stage.name}'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${mdfStageLabel(row.stage, l10n)} · ${row.order}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [
                      ?row.customer,
                      '${row.areaM2.toStringAsFixed(2)} м²',
                      if (row.deliveryDate != null)
                        l10n.myWorkDue(mdfDay(row.deliveryDate, year: false)),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: row.overdue ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (coming)
                    Text(
                      l10n.myWorkWaiting(
                        row.waitingFor
                            .map((s) => mdfStageLabel(s, l10n))
                            .join(', '),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (!coming)
              FilledButton.icon(
                key: ValueKey('myWorkDone:${row.order}:${row.stage.name}'),
                onPressed: busy ? null : onDone,
                icon: const Icon(AppIcons.check),
                label: Text(l10n.myWorkDoneButton),
              ),
          ],
        ),
      ),
    );
  }
}
