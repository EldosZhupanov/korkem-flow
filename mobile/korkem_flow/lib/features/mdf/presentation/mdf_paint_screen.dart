import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/charts/bar_rows.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_paint_repository.dart';
import 'package:korkem_flow/features/mdf/data/paint_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_paint.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_client_paint.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/paint_stock_view.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_catalogue_screen.dart';
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
          // «Каталог красок» (owner, 19.11.2026).
          TextButton.icon(
            key: const ValueKey('paintCatalogue'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PaintCatalogueScreen(),
              ),
            ),
            icon: const Icon(AppIcons.colour),
            label: Text(l10n.pcTitle),
          ),
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

  /// «Покрасили партию»: every order of the colour that is not waiting for
  /// the customer's paint goes to dry at once (owner, 26.11.2026).
  Future<void> _dryBatch(List<MdfPaintOrder> batch) => _run(() async {
    final paint = ref.read(mdfPaintRepositoryProvider);
    for (final o in batch) {
      await paint.startDrying(o.name);
    }
    return null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final b = widget.board;
    final paint = ref.read(mdfPaintRepositoryProvider);
    final orders = ref.read(mdfOrderRepositoryProvider);
    final stock = ref.watch(paintStockProvider).value;
    final colours = {for (final g in b.byColour) g.colour: g};
    // The biggest batch is the one to mix next, unless another is picked.
    final picked =
        colours[_colour] ?? (b.byColour.isEmpty ? null : b.byColour.first);
    if (b.byColour.isEmpty &&
        b.drying.isEmpty &&
        b.coming.isEmpty &&
        b.popular.isEmpty) {
      // Nothing to paint — the store is still kept (owner, 15.11.2026).
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ReadableWidth(child: Text(l10n.mdfPaintEmpty)),
          const PaintStockSection(),
        ],
      );
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final toPaint = b.byColour.fold<int>(0, (n, g) => n + g.orders.length);
    final dry = b.drying.where((d) => d.dry).length;
    final short = [
      ...?stock?.queue.where((n) => n.shortKg > 0).map((n) => n.shortKg),
      ...?stock?.materials.where((m) => m.shortKg > 0).map((m) => m.shortKg),
    ];

    // «Красить»: the batches by colour, the picked one's orders, its norm.
    final painting = <Widget>[
      if (b.byColour.isNotEmpty) ...[
        SectionLabel(l10n.mdfPaintByColour),
        Text(l10n.mdfPaintByColourHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        BarRows(
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
        // The norm for the colour, and a batch bigger than it.
        if (picked?.norm case final norm? when norm.use.isNotEmpty)
          Padding(
            key: const ValueKey('paintNorm'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mdfPaintNorm(
                    [
                      for (final u in norm.use)
                        '${u.name} ${l10n.paintKgShort(filmMetres(u.kg))}',
                    ].join(' · '),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                if (norm.leftKg > 0)
                  Text(
                    l10n.mdfPaintBatch(
                      filmMetres(norm.onHandKg),
                      filmMetres(norm.batchKg ?? norm.onHandKg),
                      filmMetres(norm.enamelKg),
                      filmMetres(norm.leftKg),
                    ),
                    key: const ValueKey('paintNormLeft'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status.warning,
                    ),
                  ),
              ],
            ),
          ),
        // The whole colour painted: its orders go to dry together.
        if (picked != null)
          if ([
                for (final o in picked.orders)
                  if (!o.marks.waitingPaint) o,
              ]
              case final batch when batch.length > 1)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                key: ValueKey('paintBatchDry:${picked.colour}'),
                onPressed: _busy ? null : () => _dryBatch(batch),
                icon: const Icon(AppIcons.schedule),
                label: Text(l10n.mdfPaintBatchDry(batch.length)),
              ),
            ),
        if (picked != null)
          for (final o in picked.orders)
            _OrderTile(
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
      ],
    ];

    // «Сохнет»: how long, a bar of it, and «краска» once dry.
    final drying = <Widget>[
      if (b.drying.isNotEmpty) ...[
        SectionLabel(l10n.mdfPaintDrying(b.dryHours)),
        for (final d in b.drying)
          _OrderTile(
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
            // How far along the drying is (owner, 26.11.2026).
            progress: d.dry || b.dryHours <= 0
                ? 1.0
                : (1 - d.minutesLeft / (b.dryHours * 60))
                      .clamp(0, 1)
                      .toDouble(),
            progressColor: d.dry ? status.success : status.warning,
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
      ],
    ];

    // «Едет»: still in the shop before the paint — late in red, an order
    // with no colour or size in yellow.
    final coming = <Widget>[
      if (b.coming.isNotEmpty) ...[
        SectionLabel(l10n.mdfPaintComing),
        for (final c in b.coming)
          _OrderTile(
            tileKey: ValueKey('paintComing:${c.name}'),
            name: c.name,
            customer: c.customer,
            detail: [
              if (c.colours.isNotEmpty) c.colours.join(', '),
              _m2(c.areaM2),
              mdfDay(c.deliveryDate, year: false),
              if (_lateDays(c.deliveryDate, today) case final late?
                  when late > 0)
                l10n.mdfPaintLate(late),
            ].join(' · '),
            detailColor: (_lateDays(c.deliveryDate, today) ?? 0) > 0
                ? status.danger
                : null,
            marks: c.marks,
            check: c.colours.isEmpty || c.areaM2 <= 0
                ? l10n.mdfPaintCheckOrder
                : null,
            action: c.marks.waitingPaint
                ? TextButton(
                    key: ValueKey('paintIn:${c.name}'),
                    onPressed: _busy ? null : () => _paintIn(c.name),
                    child: Text(l10n.mdfClientPaintBrought),
                  )
                : null,
            stage: switch (MdfStage.parse(c.stage)) {
              final stage? => l10n.mdfPaintNowAt(mdfStageLabel(stage, l10n)),
              null => null,
            },
          ),
      ],
    ];

    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        // The paint shop at a glance (owner, 26.11.2026: figures, as on
        // «Отдел плёнки», not one small line).
        FigureRow(
          key: const ValueKey('paintFigures'),
          tiles: [
            FigureTile(
              id: 'paint:coming',
              title: l10n.mdfPaintFigComing,
              value: _m2(b.comingM2),
              note: l10n.mdfPaintFigOrders(b.coming.length),
            ),
            FigureTile(
              id: 'paint:toPaint',
              title: l10n.mdfPaintFigToPaint,
              value: _m2(b.waitingM2),
              note: l10n.mdfPaintFigOrders(toPaint),
            ),
            FigureTile(
              id: 'paint:drying',
              title: l10n.mdfPaintFigDrying,
              value: '${b.drying.length}',
              note: dry > 0 ? l10n.mdfPaintFigDry(dry) : null,
              colour: dry > 0 ? status.success : null,
            ),
            if (stock != null)
              FigureTile(
                id: 'paint:short',
                title: l10n.mdfPaintFigShort,
                value: '${short.length}',
                note: short.isEmpty
                    ? null
                    : l10n.paintKgShort(
                        filmMetres(short.fold<double>(0, (a, k) => a + k)),
                      ),
                colour: short.isEmpty ? status.success : status.danger,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // On a wide screen the road of a facade in three columns (owner,
        // 26.11.2026): on its way → to paint → drying; else one under
        // another, the paint first.
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= _boardWidth
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: column(coming)),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: column(painting)),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: column(drying)),
                  ],
                )
              : ReadableWidth(
                  child: column([
                    ...painting,
                    if (drying.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    ...drying,
                    if (coming.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    ...coming,
                  ]),
                ),
        ),
        // The store: what is short for the queue, what is here, «Приход».
        const PaintStockSection(),
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
                    note: [
                      l10n.mdfPaintColourNote(_m2(p.areaM2), '${p.orders}'),
                      // A month of it, in kilos by the recipe: what to keep.
                      if (stock != null && stock.kgPerM2 > 0)
                        l10n.mdfPaintMonthKg(
                          filmMetres(p.areaM2 / 3 * stock.kgPerM2),
                        ),
                    ].join(' · '),
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

/// Days past [due] (an ISO day) as of [today]; null when unknown.
int? _lateDays(String due, DateTime today) {
  final d = DateTime.tryParse(due);
  return d == null ? null : today.difference(DateUtils.dateOnly(d)).inDays;
}

/// From this width the board stands in three columns.
const double _boardWidth = 1100;

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
    this.progress,
    this.progressColor,
    this.check,
  });

  /// Drying: how far along, 0–1, as a bar under the line.
  final double? progress;
  final Color? progressColor;

  /// Something wrong with the order itself — «нет цвета или размеров».
  final String? check;

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
      if (check != null)
        StatusChip(label: check!, intent: StatusIntent.warning),
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
          if (progress case final p?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(
                  key: ValueKey('paintProgress:$name'),
                  value: p,
                  minHeight: AppSpacing.xs,
                  color: progressColor,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
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
