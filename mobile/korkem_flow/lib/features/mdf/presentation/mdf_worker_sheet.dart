import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Кто сделал?» before a stage is ticked. Null — the sheet was closed and
/// nothing is ticked; an empty string — tick without naming anyone.
Future<String?> pickMdfWorker(BuildContext context, String title) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WorkerSheet(title: title),
    );

class _WorkerSheet extends ConsumerWidget {
  const _WorkerSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workers = ref.watch(mdfWorkersProvider);
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
              subtitle: Text(l10n.mdfWhoDidIt),
            ),
            ListTile(
              key: const ValueKey('workerNobody'),
              title: Text(l10n.mdfWorkerNobody),
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
                data: (list) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final w in list)
                      ListTile(
                        key: ValueKey('worker:${w.employee}'),
                        title: Text(w.name),
                        subtitle: w.role == null ? null : Text(w.role!),
                        onTap: () => Navigator.of(context).pop(w.employee),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
