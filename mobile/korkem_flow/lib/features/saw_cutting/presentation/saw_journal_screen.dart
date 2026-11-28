import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/saw_cutting/data/saw_cutting_repository.dart';
import 'package:korkem_flow/features/saw_cutting/domain/saw_cutting.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Цех → Раскрой» (owner, 28.11.2026): what to saw first — by the order's
/// due date — and what was sawn, by whom. Two jobs on one board that cost a
/// sheet less together are offered to be merged.
class SawJournalScreen extends ConsumerStatefulWidget {
  const SawJournalScreen({super.key});

  @override
  ConsumerState<SawJournalScreen> createState() => _SawJournalScreenState();
}

class _SawJournalScreenState extends ConsumerState<SawJournalScreen> {
  JournalFilter _filter = JournalFilter.all;
  String _search = '';
  final _searchField = TextEditingController();
  bool _merging = false;

  JournalQuery get _query => (filter: _filter, search: _search);

  @override
  void dispose() {
    _searchField.dispose();
    super.dispose();
  }

  Future<void> _merge(SawTogether offer) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _merging = true);
    try {
      final job = await ref
          .read(sawCuttingRepositoryProvider)
          .merge(offer.jobs);
      ref.invalidate(sawJournalProvider);
      await router.push(Routes.sawJobOf(job.name));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final journal = ref.watch(sawJournalProvider(_query));
    final canMake = journal.value?.canMake ?? false;
    return AppScreen(
      title: l10n.sawTitle,
      actions: [
        IconButton(
          key: const ValueKey('sawSettingsOpen'),
          tooltip: l10n.sawSettingsTitle,
          icon: const Icon(AppIcons.settings),
          onPressed: () => context.push(Routes.sawSettings),
        ),
        if (canMake)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: FilledButton.icon(
              key: const ValueKey('sawNew'),
              onPressed: () async {
                await context.push(Routes.sawNew);
                ref.invalidate(sawJournalProvider);
              },
              icon: const Icon(AppIcons.add),
              label: Text(l10n.sawNew),
            ),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: ReadableWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('sawSearch'),
                    controller: _searchField,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(AppIcons.search),
                      hintText: l10n.sawSearchHint,
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.actionCancel,
                              icon: const Icon(AppIcons.close),
                              onPressed: () => setState(() {
                                _searchField.clear();
                                _search = '';
                              }),
                            ),
                    ),
                    onSubmitted: (v) => setState(() => _search = v.trim()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final f in JournalFilter.values)
                        ChoiceChip(
                          key: ValueKey('sawFilter:${f.name}'),
                          label: Text(_filterLabel(l10n, f)),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: journal.when(
              loading: () => const ListSkeleton(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(sawJournalProvider(_query)),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(sawJournalProvider(_query)),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final offer in data.together)
                      ReadableWidth(
                        child: _TogetherBanner(
                          offer: offer,
                          busy: _merging,
                          onMerge: data.canMake ? () => _merge(offer) : null,
                        ),
                      ),
                    if (data.jobs.isEmpty)
                      EmptyView(
                        title: l10n.sawEmpty,
                        message: l10n.sawEmptyHint,
                        icon: AppIcons.sawCutting,
                      ),
                    for (final row in data.jobs)
                      ReadableWidth(
                        child: _JobRow(
                          row: row,
                          onTap: () async {
                            await context.push(Routes.sawJobOf(row.name));
                            ref.invalidate(sawJournalProvider);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _filterLabel(AppLocalizations l10n, JournalFilter f) => switch (f) {
  JournalFilter.all => l10n.sawFilterAll,
  JournalFilter.check => l10n.sawFilterCheck,
  JournalFilter.cutting => l10n.sawFilterCutting,
  JournalFilter.done => l10n.sawFilterDone,
};

/// A job's state as a word and its colour.
(String, Color, Color) sawStatusLook(
  BuildContext context,
  JobStatus status,
) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final s = context.statusColors;
  final (word, colour) = switch (status) {
    JobStatus.draft => (l10n.sawStatusDraft, s.info),
    JobStatus.checked => (l10n.sawStatusChecked, s.neutral),
    JobStatus.cutting => (l10n.sawStatusCutting, s.warning),
    JobStatus.done => (l10n.sawStatusDone, s.success),
    JobStatus.cancelled => (l10n.sawStatusCancelled, scheme.outline),
  };
  return (word, colour, colour.withValues(alpha: AppTint.surface));
}

class SawStatusChip extends StatelessWidget {
  const SawStatusChip({required this.status, super.key});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final (word, ink, fill) = sawStatusLook(context, status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          word,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: ink),
        ),
      ),
    );
  }
}

/// «сегодня» red, «завтра» amber, a date otherwise — what to saw first.
(String, Color?) sawDueLook(BuildContext context, String? due) {
  final l10n = AppLocalizations.of(context);
  final s = context.statusColors;
  final date = due == null ? null : DateTime.tryParse(due);
  if (date == null) return ('—', null);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(date.year, date.month, date.day).difference(today);
  return switch (days.inDays) {
    < 0 => (l10n.sawOverdue, s.danger),
    0 => (l10n.sawToday, s.danger),
    1 => (l10n.sawTomorrow, s.warning),
    _ => (
      MaterialLocalizations.of(context).formatShortMonthDay(date),
      null,
    ),
  };
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.row, required this.onTap});

  final JournalRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (due, dueColour) = sawDueLook(context, row.dueDate);
    final s = context.statusColors;
    final waste = row.wastePct.round();
    final details = [
      row.name,
      row.material,
      l10n.sawSheetsOf(row.sheetsDone, row.sheetsTotal),
      if (row.sawnBy.isNotEmpty) row.sawnBy.join(', '),
    ].join(' · ');
    return Card(
      key: ValueKey('sawJob:${row.name}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: AppSpacing.xxxl + AppSpacing.lg,
                    child: Text(
                      due,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: dueColour ?? theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.title.isEmpty ? row.name : row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SawStatusChip(status: row.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const SizedBox(width: AppSpacing.xxxl + AppSpacing.lg),
                  Expanded(
                    child: Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    l10n.sawWaste(waste),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: waste >= 12 ? s.danger : null,
                    ),
                  ),
                ],
              ),
              if (row.sheetsTotal > 0 && row.status != JobStatus.cancelled)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.xxxl + AppSpacing.lg,
                    top: AppSpacing.xs,
                  ),
                  child: LinearProgressIndicator(
                    value: row.sheetsDone / row.sheetsTotal,
                    color: row.status == JobStatus.done ? s.success : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TogetherBanner extends StatelessWidget {
  const _TogetherBanner({
    required this.offer,
    required this.busy,
    required this.onMerge,
  });

  final SawTogether offer;
  final bool busy;
  final VoidCallback? onMerge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = context.statusColors.info;
    return Card(
      key: ValueKey('sawTogether:${offer.jobs.join(',')}'),
      color: info.withValues(alpha: AppTint.surface),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(AppIcons.merge, color: info),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.sawTogether(
                  offer.jobs.join(', '),
                  offer.material,
                  offer.together,
                  offer.apart,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: info),
              ),
            ),
            if (onMerge != null)
              TextButton(
                key: const ValueKey('sawMerge'),
                onPressed: busy ? null : onMerge,
                child: Text(l10n.sawTogetherAction),
              ),
          ],
        ),
      ),
    );
  }
}
