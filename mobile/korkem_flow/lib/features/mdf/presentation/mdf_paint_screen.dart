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
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_paint_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_paint.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_client_paint.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _m2(double v) => '${v.toStringAsFixed(2)} м²';

/// «Отдел краски» (owner, 14.11.2026): what to paint, colour by colour, the
/// biggest batch first; what is drying and when it will be dry; which orders
/// are on their way and where they are now; the colours painted most. Each
/// order says if the customer brings his paint or his facades, and if both
/// sides are painted.
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
            key: const ValueKey('paintSettings'),
            tooltip: l10n.mdfPaintSettings,
            icon: const Icon(AppIcons.settings),
            onPressed: board.value == null
                ? null
                : () => _settings(context, ref, board.value!),
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

  Future<void> _settings(
    BuildContext context,
    WidgetRef ref,
    MdfPaintBoard board,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(int, double)>(
      context: context,
      builder: (_) => _SettingsDialog(
        hours: board.dryHours,
        discount: board.clientPaintDiscount,
      ),
    );
    if (result == null) return;
    try {
      await ref
          .read(mdfPaintRepositoryProvider)
          .settings(dryHours: result.$1, clientPaintDiscount: result.$2);
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

  Future<void> _paintIn(String order) async {
    final note = await askClientPaint(context);
    if (note == null || !mounted) return;
    await _run(
      () =>
          ref.read(mdfPaintRepositoryProvider).clientPaintIn(order, note: note),
    );
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
    if (b.byColour.isEmpty &&
        b.drying.isEmpty &&
        b.coming.isEmpty &&
        b.popular.isEmpty) {
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
                child: _OrderTile(
                  tileKey: ValueKey('paintOrder:${o.name}'),
                  name: o.name,
                  customer: o.customer,
                  detail:
                      '${_m2(o.areaM2)} · '
                      '${mdfDay(o.deliveryDate, year: false)}',
                  detailColor: o.overdue ? status.danger : null,
                  marks: o.marks,
                  action: o.marks.waitingPaint
                      ? FilledButton(
                          key: ValueKey('paintIn:${o.name}'),
                          onPressed: _busy ? null : () => _paintIn(o.name),
                          child: Text(l10n.mdfClientPaintBrought),
                        )
                      : OutlinedButton.icon(
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
        if (b.drying.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.mdfPaintDrying(b.dryHours))),
          for (final d in b.drying)
            ReadableWidth(
              child: _OrderTile(
                tileKey: ValueKey('paintDrying:${d.name}'),
                name: d.name,
                customer: d.customer,
                detail: [
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
                detailColor: d.dry ? status.success : status.warning,
                marks: d.marks,
                action: d.dry
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
        if (b.coming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.mdfPaintComing)),
          for (final c in b.coming)
            ReadableWidth(
              child: _OrderTile(
                tileKey: ValueKey('paintComing:${c.name}'),
                name: c.name,
                customer: c.customer,
                detail: [
                  c.colours.join(', '),
                  _m2(c.areaM2),
                  mdfDay(c.deliveryDate, year: false),
                ].join(' · '),
                marks: c.marks,
                action: c.marks.waitingPaint
                    ? TextButton(
                        key: ValueKey('paintIn:${c.name}'),
                        onPressed: _busy ? null : () => _paintIn(c.name),
                        child: Text(l10n.mdfClientPaintBrought),
                      )
                    : null,
                stage: switch (MdfStage.parse(c.stage)) {
                  final stage? => l10n.mdfPaintNowAt(
                    mdfStageLabel(stage, l10n),
                  ),
                  null => null,
                },
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

/// One order on the board: who, how much, its marks, and what can be done.
class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.tileKey,
    required this.name,
    required this.customer,
    required this.detail,
    required this.marks,
    this.detailColor,
    this.action,
    this.stage,
  });

  final Key tileKey;
  final String name;
  final String customer;
  final String detail;
  final Color? detailColor;
  final MdfPaintMarks marks;
  final Widget? action;

  /// «сейчас: фреза» — for an order still on its way.
  final String? stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chips = [
      if (stage != null) StatusChip(label: stage!, intent: StatusIntent.info),
      if (marks.urgent)
        StatusChip(label: l10n.mdfTagUrgent, intent: StatusIntent.danger),
      if (marks.waitingPaint)
        StatusChip(
          label: l10n.mdfClientPaintWaiting,
          intent: StatusIntent.danger,
        )
      else if (marks.clientPaint)
        StatusChip(
          label: [
            l10n.mdfTagClientPaint,
            ?marks.clientPaintNote,
          ].join(' · '),
          intent: StatusIntent.success,
        ),
      if (marks.clientParts)
        StatusChip(
          label: l10n.mdfTagClientParts,
          intent: StatusIntent.warning,
        ),
      if (marks.twoSided)
        StatusChip(label: l10n.mdfPaintTwoSided, intent: StatusIntent.info),
    ];
    return ListTile(
      key: tileKey,
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push(Routes.mdfOrder(name)),
      title: Text('$name · $customer'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail,
            style: detailColor == null ? null : TextStyle(color: detailColor),
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: chips,
              ),
            ),
        ],
      ),
      trailing: action,
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.hours, required this.discount});

  final int hours;
  final double discount;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final _hours = TextEditingController(text: '${widget.hours}');
  late final _discount = TextEditingController(
    text: widget.discount > 0 ? widget.discount.toStringAsFixed(0) : '',
  );

  @override
  void dispose() {
    _hours.dispose();
    _discount.dispose();
    super.dispose();
  }

  int? get _hoursValue {
    final value = int.tryParse(_hours.text.trim());
    return value != null && value > 0 && value <= 168 ? value : null;
  }

  double get _discountValue => double.tryParse(_discount.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mdfPaintSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('paintDryHoursField'),
            controller: _hours,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.mdfPaintDryHours),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('paintDiscountField'),
            controller: _discount,
            decoration: InputDecoration(
              labelText: l10n.mdfPaintDiscount,
              helperText: l10n.mdfPaintDiscountHint,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('paintSettingsSave'),
          onPressed: _hoursValue == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((_hoursValue!, _discountValue)),
          child: Text(l10n.mdfPaintSave),
        ),
      ],
    );
  }
}
