import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/cnc_patterns/data/cnc_patterns_repository.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';
import 'package:korkem_flow/features/cnc_patterns/presentation/cnc_pattern_editor.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// An order's positions for the router.
// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final cncOrderPlanProvider = FutureProvider.autoDispose
    .family<CncOrderPlan, String>(
      (ref, order) => ref.watch(cncPatternsRepositoryProvider).forOrder(order),
    );

/// «G-код ЧПУ (β)» on an order: each position's pattern, whether it fits, the
/// router's minutes, and the programs saved into one folder. Reads the order;
/// changes nothing in it.
Future<void> showCncOrderSheet(BuildContext context, String order) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CncOrderSheet(order: order),
    );

class _CncOrderSheet extends ConsumerStatefulWidget {
  const _CncOrderSheet({required this.order});

  final String order;

  @override
  ConsumerState<_CncOrderSheet> createState() => _CncOrderSheetState();
}

class _CncOrderSheetState extends ConsumerState<_CncOrderSheet> {
  bool _busy = false;

  Future<void> _save({String? line}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saver = ref.read(cncFileSaverProvider);
    setState(() => _busy = true);
    try {
      final files = await ref
          .read(cncPatternsRepositoryProvider)
          .orderFiles(widget.order, line: line);
      final dir = await saver.save(widget.order, {
        for (final f in files) f.name ?? 'program': f.text,
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.cncpSavedFiles('${files.length}', dir)),
          action: SnackBarAction(
            label: l10n.cncpOpenFolder,
            onPressed: () => unawaited(saver.open(dir)),
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final plan = ref.watch(cncOrderPlanProvider(widget.order));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: plan.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(cncOrderPlanProvider(widget.order)),
          ),
          data: (p) {
            final ready = p.lines.where((l) => l.ready).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.cncpOrderTitle, style: theme.textTheme.titleLarge),
                Text(
                  l10n.cncpOrderMinutes(cncFmt(p.minutes)),
                  key: const ValueKey('cncOrderMinutes'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final l in p.lines)
                        ListTile(
                          key: ValueKey('cncLine:${l.no}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l10n.cncpOrderLine(
                              '${l.no}',
                              cncFmt(l.height),
                              cncFmt(l.width),
                              cncFmt(l.qty),
                              l.milling ?? '—',
                            ),
                          ),
                          subtitle: Text(
                            l.error ??
                                (l.pattern == null
                                    ? l10n.cncpOrderNoPattern
                                    : [
                                        l10n.cncpOrderPattern(
                                          l.pattern!,
                                          cncFmt(l.minutes ?? 0),
                                        ),
                                        ...l.warnings,
                                      ].join(' · ')),
                            style: l.error != null
                                ? TextStyle(color: status.danger)
                                : l.pattern == null
                                ? muted
                                : null,
                          ),
                          trailing: l.ready
                              ? IconButton(
                                  key: ValueKey('cncLineSave:${l.no}'),
                                  tooltip: l10n.cncpDownload,
                                  icon: const Icon(AppIcons.moveOut),
                                  onPressed: _busy
                                      ? null
                                      : () => unawaited(_save(line: l.line)),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  key: const ValueKey('cncOrderSaveAll'),
                  onPressed: ready.isEmpty || _busy
                      ? null
                      : () => unawaited(_save()),
                  icon: const Icon(AppIcons.moveOut),
                  label: Text(l10n.cncpOrderSaveAll('${ready.length}')),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.cncpCheckOnOffcut, style: muted),
              ],
            );
          },
        ),
      ),
    );
  }
}
