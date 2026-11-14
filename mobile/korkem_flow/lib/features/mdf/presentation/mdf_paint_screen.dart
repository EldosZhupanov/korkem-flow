import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/charts/bar_rows.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_paint_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_paint.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _m2(double v) => '${v.toStringAsFixed(2)} м²';

/// «Отдел краски» (owner, 14.11.2026): what to paint, colour by colour, the
/// biggest batch first; what is drying and when it will be dry; what is on
/// its way; the colours painted most.
class MdfPaintScreen extends ConsumerWidget {
  const MdfPaintScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(mdfPaintBoardProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mdfPaintTitle),
        actions: [
          IconButton(
            key: const ValueKey('paintDryHours'),
            tooltip: l10n.mdfPaintDryHours,
            icon: const Icon(AppIcons.schedule),
            onPressed: board.value == null
                ? null
                : () => _setDryHours(context, ref, board.value!.dryHours),
          ),
        ],
      ),
      body: board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(mdfPaintBoardProvider),
        ),
        data: (b) => _Board(board: b),
      ),
    );
  }

  Future<void> _setDryHours(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hours = await showDialog<int>(
      context: context,
      builder: (_) => _DryHoursDialog(current: current),
    );
    if (hours == null) return;
    try {
      await ref.read(mdfPaintRepositoryProvider).setDryHours(hours);
      ref.invalidate(mdfPaintBoardProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

class _Board extends ConsumerStatefulWidget {
  const _Board({required this.board});

  final MdfPaintBoard board;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  String? _colour;
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(mdfPaintBoardProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final b = widget.board;
    final paint = ref.read(mdfPaintRepositoryProvider);
    final orders = ref.read(mdfOrderRepositoryProvider);
    final colours = {for (final g in b.byColour) g.colour: g};
    // The biggest batch is the one to mix next, unless another is picked.
    final picked =
        colours[_colour] ?? (b.byColour.isEmpty ? null : b.byColour.first);
    if (b.byColour.isEmpty && b.drying.isEmpty && b.popular.isEmpty) {
      return Center(child: Text(l10n.mdfPaintEmpty));
    }
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
            l10n.mdfPaintSummary(
              _m2(b.waitingM2),
              '${b.drying.length}',
              _m2(b.comingM2),
            ),
            key: const ValueKey('paintSummary'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (b.drying.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.mdfPaintDrying(b.dryHours))),
          for (final d in b.drying)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('paintDrying:${d.name}'),
                contentPadding: EdgeInsets.zero,
                onTap: () => context.push(Routes.mdfOrder(d.name)),
                title: Text('${d.name} · ${d.customer}'),
                subtitle: Text(
                  [
                    d.colours.join(', '),
                    _m2(d.areaM2),
                    if (d.dry)
                      l10n.mdfPaintDry
                    else
                      l10n.mdfPaintLeft(
                        '${d.minutesLeft ~/ 60}',
                        '${d.minutesLeft % 60}',
                        mdfDay(d.dryAt.split(' ').first, year: false),
                        d.dryAt.length >= 16 ? d.dryAt.substring(11, 16) : '',
                      ),
                  ].join(' · '),
                  style: TextStyle(
                    color: d.dry ? status.success : status.warning,
                  ),
                ),
                trailing: d.dry
                    ? FilledButton(
                        key: ValueKey('paintDone:${d.name}'),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => orders.setStage(
                                  d.name,
                                  MdfStage.paint,
                                  done: true,
                                ),
                              ),
                        child: Text(l10n.mdfPaintMarkPainted),
                      )
                    : TextButton(
                        key: ValueKey('paintUndo:${d.name}'),
                        onPressed: _busy
                            ? null
                            : () => _run(() => paint.stopDrying(d.name)),
                        child: Text(l10n.mdfPaintUndo),
                      ),
              ),
            ),
        ],
        if (b.byColour.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.mdfPaintByColour)),
          ReadableWidth(
            child: Text(
              l10n.mdfPaintByColourHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ReadableWidth(
            child: BarRows(
              key: const ValueKey('paintColours'),
              rows: [
                for (final g in b.byColour)
                  BarRow(
                    id: g.colour,
                    label: g.colour,
                    value: g.areaM2,
                    note: l10n.mdfPaintColourNote(
                      _m2(g.areaM2),
                      '${g.orders.length}',
                    ),
                  ),
              ],
              selected: picked?.colour,
              onSelect: (id) => setState(() => _colour = id),
            ),
          ),
          if (picked != null)
            for (final o in picked.orders)
              ReadableWidth(
                child: ListTile(
                  key: ValueKey('paintOrder:${o.name}'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.push(Routes.mdfOrder(o.name)),
                  title: Text('${o.name} · ${o.customer}'),
                  subtitle: Text(
                    '${_m2(o.areaM2)} · ${mdfDay(o.deliveryDate, year: false)}',
                    style: o.overdue || o.urgent
                        ? TextStyle(color: status.danger)
                        : null,
                  ),
                  trailing: OutlinedButton.icon(
                    key: ValueKey('paintDry:${o.name}'),
                    onPressed: _busy
                        ? null
                        : () => _run(() => paint.startDrying(o.name)),
                    icon: const Icon(AppIcons.schedule),
                    label: Text(l10n.mdfPaintStartDrying),
                  ),
                ),
              ),
        ],
        if (b.popular.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.mdfPaintPopular)),
          ReadableWidth(
            child: BarRows(
              key: const ValueKey('paintPopular'),
              rows: [
                for (final p in b.popular)
                  BarRow(
                    id: 'popular:${p.colour}',
                    label: p.colour,
                    value: p.areaM2,
                    note: l10n.mdfPaintColourNote(
                      _m2(p.areaM2),
                      '${p.orders}',
                    ),
                    color: status.info,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DryHoursDialog extends StatefulWidget {
  const _DryHoursDialog({required this.current});

  final int current;

  @override
  State<_DryHoursDialog> createState() => _DryHoursDialogState();
}

class _DryHoursDialogState extends State<_DryHoursDialog> {
  late final _field = TextEditingController(text: '${widget.current}');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  int? get _hours {
    final value = int.tryParse(_field.text.trim());
    return value != null && value > 0 && value <= 168 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mdfPaintDryHours),
      content: TextField(
        key: const ValueKey('paintDryHoursField'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('paintDryHoursSave'),
          onPressed: _hours == null
              ? null
              : () => Navigator.of(context).pop(_hours),
          child: Text(l10n.mdfPaintSave),
        ),
      ],
    );
  }
}
