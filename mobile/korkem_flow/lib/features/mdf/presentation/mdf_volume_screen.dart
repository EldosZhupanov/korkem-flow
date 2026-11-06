import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_volume.dart';
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

class _VolumeBody extends StatelessWidget {
  const _VolumeBody({required this.volume});

  final MdfVolume volume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = volume;
    if (v.workers.isEmpty) {
      return Center(child: Text(l10n.mdfVolumeEmpty));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final e in v.byStage.entries)
              StatusChip(
                label: '${mdfStageLabel(e.key, l10n)}: ${_m2(e.value)}',
                intent: StatusIntent.info,
              ),
          ],
        ),
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
