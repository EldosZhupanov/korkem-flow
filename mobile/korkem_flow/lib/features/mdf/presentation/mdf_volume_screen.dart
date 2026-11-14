import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/charts/bar_rows.dart';
import 'package:korkem_flow/core/design/widgets/charts/flow_bars.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_volume.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_report_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _m2(double v) => '${v.toStringAsFixed(2)} м²';

/// «Объём работ» — OnayBaza's «Жұмыс көлемі»: m² per worker and stage, from
/// the stages ticked with a name. The pay stays with piece work.
class MdfVolumeScreen extends ConsumerStatefulWidget {
  const MdfVolumeScreen({super.key, this.today});

  final DateTime? today;

  @override
  ConsumerState<MdfVolumeScreen> createState() => _MdfVolumeScreenState();
}

class _MdfVolumeScreenState extends ConsumerState<MdfVolumeScreen> {
  ReportRange _range = ReportRange.thisMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final period = reportPeriodOf(_range, widget.today ?? DateTime.now());
    final volume = ref.watch(mdfVolumeProvider(period));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfVolumeTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<ReportRange>(
              segments: [
                ButtonSegment(
                  value: ReportRange.thisMonth,
                  label: Text(l10n.mdfReportThisMonth),
                ),
                ButtonSegment(
                  value: ReportRange.lastMonth,
                  label: Text(l10n.mdfReportLastMonth),
                ),
                ButtonSegment(
                  value: ReportRange.year,
                  label: Text(l10n.mdfReportYear),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          Expanded(
            child: volume.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(mdfVolumeProvider(period)),
              ),
              data: (v) => _VolumeBody(volume: v),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shop's dashboard (owner, 14.11.2026): how much was done and how it
/// compares, a bar a day, what was done at each stage, what waits at each
/// stage now — and who did it.
class _VolumeBody extends StatefulWidget {
  const _VolumeBody({required this.volume});

  final MdfVolume volume;

  @override
  State<_VolumeBody> createState() => _VolumeBodyState();
}

class _VolumeBodyState extends State<_VolumeBody> {
  int? _day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = widget.volume;
    if (v.workers.isEmpty && v.queue.isEmpty) {
      return Center(child: Text(l10n.mdfVolumeEmpty));
    }
    final monthly = v.days.isNotEmpty && v.days.first.date.length == 7;
    final day = _day != null && _day! < v.days.length ? v.days[_day!] : null;
    final change = v.previousM2 > 0
        ? ((v.totalM2 - v.previousM2) / v.previousM2 * 100).round()
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        ReadableWidth(
          child: Text(
            _m2(v.totalM2),
            key: const ValueKey('volumeTotal'),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (change != null)
          ReadableWidth(
            child: Text(
              l10n.mdfVolumeVersus(change >= 0 ? '▲' : '▼', change.abs()),
              key: const ValueKey('volumeVersus'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: change >= 0
                    ? context.statusColors.success
                    : context.statusColors.danger,
              ),
            ),
          ),
        if (v.days.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(
            child: FlowBars(
              key: const ValueKey('volumeChart'),
              bars: [
                for (final d in v.days)
                  FlowBar(
                    label: monthly ? d.date.substring(5) : d.date.substring(8),
                    up: d.areaM2,
                  ),
              ],
              selected: day == null ? null : _day,
              onSelect: (i) => setState(() => _day = i),
              semanticLabel: l10n.mdfVolumeTitle,
            ),
          ),
          ReadableWidth(
            child: Text(
              day == null
                  ? l10n.mdfSumIntakeHint
                  : '${monthly ? day.date : mdfDay(day.date)}: '
                        '${_m2(day.areaM2)}',
              key: const ValueKey('volumeDay'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        if (v.byStage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          ReadableWidth(child: SectionLabel(l10n.mdfVolumeDone)),
          ReadableWidth(
            child: BarRows(
              key: const ValueKey('volumeStages'),
              rows: [
                for (final e in v.byStage.entries)
                  BarRow(
                    id: 'done:${e.key.name}',
                    label: mdfStageLabel(e.key, l10n),
                    value: e.value,
                    note: _m2(e.value),
                  ),
              ],
            ),
          ),
        ],
        if (v.queue.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          // The longest bar is where the shop jams; a tap opens «Жоспар».
          ReadableWidth(child: SectionLabel(l10n.mdfVolumeQueue)),
          ReadableWidth(
            child: BarRows(
              key: const ValueKey('volumeQueue'),
              rows: [
                for (final q in v.queue)
                  BarRow(
                    id: 'queue:${q.stage.name}',
                    label: mdfStageLabel(q.stage, l10n),
                    value: q.areaM2,
                    note: '${q.orders} · ${_m2(q.areaM2)}',
                    color: context.statusColors.warning,
                  ),
              ],
              onSelect: (_) => context.push(Routes.mdfPlan),
            ),
          ),
        ],
        if (v.unassignedM2 > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          ReadableWidth(
            child: Text(
              l10n.mdfVolumeUnassigned(_m2(v.unassignedM2)),
              key: const ValueKey('volumeUnassigned'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ReadableWidth(child: SectionLabel(l10n.mdfVolumeByWorker)),
        for (final w in v.workers)
          ReadableWidth(
            child: ListTile(
              key: ValueKey('volume:${w.employee ?? '-'}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(w.name ?? w.employee ?? l10n.mdfWorkerNobody),
              subtitle: Text(
                [
                  for (final e in w.byStage.entries)
                    '${mdfStageLabel(e.key, l10n)} ${_m2(e.value)}',
                ].join(' · '),
              ),
              trailing: Text(
                _m2(w.areaM2),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
      ],
    );
  }
}
