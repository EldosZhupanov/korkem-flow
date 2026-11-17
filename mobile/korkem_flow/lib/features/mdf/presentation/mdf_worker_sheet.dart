import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_volume.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Кто сделал?» before a stage is ticked, or «Кому отдать?» when
/// [assigning]. Null — the sheet was closed and nothing changes; an empty
/// string — nobody named (the one the stage is [given] to, when it is), or,
/// assigning, the stage taken back.
///
/// With [order] and [stage] the stage's own post comes first (owner,
/// 17.11.2026: the vacuum operator for the vacuum), then everyone else.
Future<String?> pickMdfWorker(
  BuildContext context,
  String title, {
  String? order,
  MdfStage? stage,
  String? given,
  bool assigning = false,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _WorkerSheet(
    title: title,
    order: order,
    stage: stage,
    given: given,
    assigning: assigning,
  ),
);

class _WorkerSheet extends ConsumerWidget {
  const _WorkerSheet({
    required this.title,
    required this.order,
    required this.stage,
    required this.given,
    required this.assigning,
  });

  final String title;
  final String? order;
  final MdfStage? stage;
  final String? given;
  final bool assigning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workers = ref.watch(mdfWorkersProvider);
    final key = order != null && stage != null
        ? (order: order!, stage: stage!)
        : null;
    final post = key == null
        ? const <MdfWorker>[]
        : ref.watch(mdfStagePeopleProvider(key)).value ?? const <MdfWorker>[];
    final nobody = assigning
        ? (given == null ? null : l10n.mdfStageTakeBack)
        : (given == null ? l10n.mdfWorkerNobody : null);

    Widget tile(MdfWorker w) => ListTile(
      key: ValueKey('worker:${w.employee}'),
      title: Text(w.name),
      subtitle: w.role == null ? null : Text(w.role!),
      trailing: w.employee == given ? const Icon(AppIcons.check) : null,
      onTap: () => Navigator.of(context).pop(w.employee),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                assigning ? l10n.mdfGiveStageTo : l10n.mdfWhoDidIt,
              ),
            ),
            if (nobody != null)
              ListTile(
                key: const ValueKey('workerNobody'),
                title: Text(nobody),
                onTap: () => Navigator.of(context).pop(''),
              ),
            const Divider(height: 1),
            Flexible(
              child: workers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(mdfWorkersProvider),
                ),
                data: (list) {
                  final ids = {for (final w in post) w.employee};
                  final others = [
                    for (final w in list)
                      if (!ids.contains(w.employee)) w,
                  ];
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      if (post.isNotEmpty) ...[
                        ListTile(
                          dense: true,
                          title: SectionLabel(l10n.mdfStagePostPeople),
                        ),
                        for (final w in post) tile(w),
                        if (others.isNotEmpty)
                          ListTile(
                            dense: true,
                            title: SectionLabel(l10n.mdfAllWorkers),
                          ),
                      ],
                      for (final w in others) tile(w),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
