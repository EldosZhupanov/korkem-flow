import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/material_stock/data/material_stock_repository.dart';
import 'package:korkem_flow/features/material_stock/domain/material_stock.dart';
import 'package:korkem_flow/features/material_stock/presentation/stock_count_tab.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The materials store: what is on hand, a receipt, and the lists behind it.
///
/// Everybody on staff sees quantities. Receipts and the lists are for the
/// administrator and the managers; the server says who that is.
class MaterialStockScreen extends ConsumerWidget {
  const MaterialStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canEdit = ref.watch(materialListsProvider).value?.canEdit ?? false;
    return AppScreen.tabbed(
      // A new key when the role is known, so the tab set is rebuilt rather
      // than a live TabController being handed a different length.
      key: ValueKey('materialStock:$canEdit'),
      title: l10n.materialStockTitle,
      actions: [
        if (canEdit)
          IconButton(
            key: const ValueKey('openLogistics'),
            tooltip: l10n.logisticsTitle,
            icon: const Icon(AppIcons.delivery),
            onPressed: () => context.push(Routes.logistics),
          ),
      ],
      tabs: [
        AppTab(
          label: l10n.materialStockOnHand,
          view: const MaterialStockOnHand(),
        ),
        if (canEdit) ...[
          AppTab(label: l10n.materialStockReceive, view: const _Receive()),
          AppTab(label: l10n.stockCountTab, view: const StockCountTab()),
          AppTab(label: l10n.materialStockLists, view: const _Lists()),
        ],
      ],
    );
  }
}

/// A material's card for whoever keeps the warehouse: its minimum — below it
/// the owner is told to order more — and, for a film, whether it may be
/// turned on the press.
Future<void> _materialSheet(
  BuildContext context,
  WidgetRef ref,
  StockMaterial row,
) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MaterialSheet(row: row),
  );
  if (changed ?? false) ref.invalidate(stockMaterialsProvider);
}

class _MaterialSheet extends ConsumerStatefulWidget {
  const _MaterialSheet({required this.row});

  final StockMaterial row;

  @override
  ConsumerState<_MaterialSheet> createState() => _MaterialSheetState();
}

class _MaterialSheetState extends ConsumerState<_MaterialSheet> {
  late final TextEditingController _min = TextEditingController(
    text: widget.row.minStock > 0 ? _plain(widget.row.minStock) : '',
  );
  late bool _textured = widget.row.textured;
  bool _busy = false;

  @override
  void dispose() {
    _min.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    final text = _min.text.trim().replaceAll(',', '.');
    final minimum = text.isEmpty ? 0.0 : double.tryParse(text);
    if (minimum == null || minimum < 0) {
      messenger.showFailureMessage(l10n.materialStockFillAll);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(materialStockRepositoryProvider);
      if (minimum != widget.row.minStock) {
        await repo.setMinStock(widget.row.item, minimum);
      }
      if (_textured != widget.row.textured) {
        await repo.setFilmTextured(widget.row.item, textured: _textured);
      }
      navigator.pop(true);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.row.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('materialMin'),
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.materialMin,
                helperText: l10n.materialMinHint,
                helperMaxLines: 3,
                suffixText: widget.row.unit,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.row.kind == StockMaterial.film)
              SwitchListTile(
                key: const ValueKey('materialTextured'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(AppIcons.textured),
                title: Text(l10n.materialTextured),
                subtitle: Text(l10n.materialTexturedHint),
                value: _textured,
                onChanged: (on) => setState(() => _textured = on),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('materialSave'),
              onPressed: _busy ? null : _save,
              child: Text(l10n.facadePricesSave),
            ),
          ],
        ),
      ),
    );
  }
}

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// On hand and reserved when something is promised; the price when shown.
Widget? _subtitle(
  AppLocalizations l10n,
  NumberFormat money,
  StockMaterial row,
) {
  final lines = [
    if (row.low) l10n.materialLow('${_plain(row.minStock)} ${row.unit}'),
    if (row.textured) l10n.materialTextured,
    if (row.reserved > 0)
      l10n.materialStockHeld(
        '${_plain(row.onHand)} ${row.unit}',
        '${_plain(row.reserved)} ${row.unit}',
      ),
    if (row.averagePrice != null)
      l10n.materialStockAverage(money.format(row.averagePrice)),
  ];
  return lines.isEmpty ? null : Text(lines.join('\n'));
}

/// What is on hand, reserved and free — also a tab of the warehouse section.
class MaterialStockOnHand extends ConsumerWidget {
  const MaterialStockOnHand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: '₸',
      decimalDigits: 0,
    );
    final canEdit = ref.watch(materialListsProvider).value?.canEdit ?? false;
    return ref
        .watch(stockMaterialsProvider)
        .when(
          loading: () => const ListSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(stockMaterialsProvider),
          ),
          data: (rows) => rows.isEmpty
              ? EmptyView(
                  icon: AppIcons.material,
                  title: l10n.materialStockEmptyTitle,
                  message: l10n.materialStockEmptyMessage,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(stockMaterialsProvider);
                    await ref.read(stockMaterialsProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      for (final kind in StockMaterial.kinds)
                        if (rows.any((r) => r.kind == kind)) ...[
                          ReadableWidth(child: SectionLabel(kind)),
                          for (final row in rows.where((r) => r.kind == kind))
                            ReadableWidth(
                              child: Card(
                                key: ValueKey('material:${row.item}'),
                                child: ListTile(
                                  title: Text(row.title),
                                  subtitle: _subtitle(l10n, money, row),
                                  // Its minimum, and for a film whether it
                                  // may be turned on the press.
                                  onTap: canEdit
                                      ? () => _materialSheet(context, ref, row)
                                      : null,
                                  trailing: Text(
                                    row.reserved > 0
                                        ? l10n.materialStockFree(
                                            '${_plain(row.free)} ${row.unit}',
                                          )
                                        : '${_plain(row.onHand)} ${row.unit}',
                                    key: ValueKey('materialQty:${row.item}'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: row.low
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.error
                                              : null,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                    ],
                  ),
                ),
        );
  }
}

class _Receive extends ConsumerStatefulWidget {
  const _Receive();

  @override
  ConsumerState<_Receive> createState() => _ReceiveState();
}

class _ReceiveState extends ConsumerState<_Receive> {
  String _kind = StockMaterial.mdf;
  final _choice = <String, String?>{};
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _deliveryAmount = TextEditingController();
  final _deliveryFrom = TextEditingController();
  final _deliveryTransport = TextEditingController();
  String? _unit;
  String? _supplier;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _qty,
      _price,
      _deliveryAmount,
      _deliveryFrom,
      _deliveryTransport,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The delivery, when its cost was typed; the place and the way are then
  /// needed too. Nothing typed is no delivery — the reminder asks later.
  ({bool ok, ReceiptDelivery? delivery}) _delivery() {
    final amount = double.tryParse(_deliveryAmount.text.replaceAll(',', '.'));
    if (_deliveryAmount.text.trim().isEmpty) {
      return (ok: true, delivery: null);
    }
    final from = _deliveryFrom.text.trim();
    final transport = _deliveryTransport.text.trim();
    if (amount == null ||
        amount < 0 ||
        from.length < 2 ||
        transport.length < 2) {
      return (ok: false, delivery: null);
    }
    return (
      ok: true,
      delivery: (amount: amount, fromCity: from, transport: transport),
    );
  }

  List<String> _needed() => switch (_kind) {
    StockMaterial.mdf => const [
      MaterialLists.mdfThickness,
      MaterialLists.manufacturer,
    ],
    StockMaterial.film => const [
      MaterialLists.filmColor,
      MaterialLists.filmWidth,
      MaterialLists.filmThickness,
      MaterialLists.manufacturer,
    ],
    _ => const [],
  };

  Future<void> _submit(MaterialLists lists) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final qty = double.tryParse(_qty.text.replaceAll(',', '.'));
    final price = double.tryParse(_price.text);
    final unit = _unit ?? (lists.units.isEmpty ? null : lists.units.first);
    final supplier = _supplier;
    final delivery = _delivery();
    if (!delivery.ok ||
        qty == null ||
        qty <= 0 ||
        price == null ||
        price <= 0 ||
        unit == null ||
        supplier == null ||
        _needed().any((list) => _choice[list] == null) ||
        (_kind == StockMaterial.other && _name.text.trim().length < 2)) {
      messenger.showFailureMessage(l10n.materialStockFillAll);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(materialStockRepositoryProvider);
      final material = await repo.define(
        kind: _kind,
        unit: unit,
        thickness: _choice[MaterialLists.mdfThickness],
        manufacturer: _choice[MaterialLists.manufacturer],
        color: _choice[MaterialLists.filmColor],
        width: _choice[MaterialLists.filmWidth],
        filmThickness: _choice[MaterialLists.filmThickness],
        name: _kind == StockMaterial.other ? _name.text.trim() : null,
      );
      final after = await repo.receive(
        item: material.item,
        qty: qty,
        pricePerUnit: price,
        supplier: supplier,
        delivery: delivery.delivery,
      );
      messenger.showDone(
        l10n.materialStockReceived(
          material.title,
          '${_plain(after.onHand)} ${after.unit}',
        ),
      );
      for (final c in [
        _qty,
        _price,
        _deliveryAmount,
        _deliveryFrom,
        _deliveryTransport,
      ]) {
        c.clear();
      }
      ref.invalidate(stockMaterialsProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(materialListsProvider)
        .when(
          loading: () => const ListSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(materialListsProvider),
          ),
          data: (lists) {
            DropdownButtonFormField<String> pick(
              String label,
              List<String> values,
              String? value,
              ValueChanged<String?> onChanged, {
              Key? key,
            }) => DropdownButtonFormField<String>(
              key: key,
              initialValue: values.contains(value) ? value : null,
              isExpanded: true,
              items: [
                for (final v in values)
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            );
            Widget gap() => const SizedBox(height: AppSpacing.md);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ReadableWidth(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<String>(
                          segments: [
                            for (final k in StockMaterial.kinds)
                              ButtonSegment(value: k, label: Text(k)),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (s) =>
                              setState(() => _kind = s.first),
                        ),
                        gap(),
                        for (final list in _needed()) ...[
                          pick(
                            list,
                            lists.enabled(list),
                            _choice[list],
                            (v) => setState(() => _choice[list] = v),
                            key: ValueKey('pick:$list'),
                          ),
                          gap(),
                        ],
                        if (_kind == StockMaterial.other) ...[
                          TextField(
                            key: const ValueKey('materialName'),
                            controller: _name,
                            decoration: InputDecoration(
                              labelText: l10n.materialStockName,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          gap(),
                        ],
                        pick(
                          l10n.materialStockSupplier,
                          [
                            for (final s in lists.suppliers)
                              if (s.enabled) s.supplier,
                          ],
                          _supplier,
                          (v) => setState(() => _supplier = v),
                          key: const ValueKey('pickSupplier'),
                        ),
                        gap(),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('receiveQty'),
                                controller: _qty,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp('[0-9.,]'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: l10n.materialStockQty,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: pick(
                                l10n.materialStockUnit,
                                lists.units,
                                _unit ??
                                    (lists.units.isEmpty
                                        ? null
                                        : lists.units.first),
                                (v) => setState(() => _unit = v),
                              ),
                            ),
                          ],
                        ),
                        gap(),
                        TextField(
                          key: const ValueKey('receivePrice'),
                          controller: _price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.materialStockPrice,
                            suffixText: '₸',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        gap(),
                        SectionLabel(l10n.logisticsDeliveryOptional),
                        TextField(
                          key: const ValueKey('receiveDeliveryAmount'),
                          controller: _deliveryAmount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.logisticsAmount,
                            suffixText: '₸',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        gap(),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('receiveDeliveryFrom'),
                                controller: _deliveryFrom,
                                decoration: InputDecoration(
                                  labelText: l10n.logisticsFrom,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextField(
                                key: const ValueKey('receiveDeliveryTransport'),
                                controller: _deliveryTransport,
                                decoration: InputDecoration(
                                  labelText: l10n.logisticsTransport,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        gap(),
                        FilledButton(
                          key: const ValueKey('receiveSubmit'),
                          onPressed: _busy ? null : () => _submit(lists),
                          child: Text(l10n.materialStockReceive),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }
}

class _Lists extends ConsumerWidget {
  const _Lists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(materialListsProvider)
        .when(
          loading: () => const ListSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(materialListsProvider),
          ),
          data: (lists) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // The press the film is counted for (press_layout).
              ReadableWidth(
                child: Card(
                  child: ListTile(
                    key: const ValueKey('pressSettingsOpen'),
                    leading: const Icon(AppIcons.pressLayout),
                    title: Text(l10n.pressSettingsTitle),
                    trailing: const Icon(AppIcons.forward),
                    onTap: () => context.push(Routes.pressSettings),
                  ),
                ),
              ),
              for (final list in MaterialLists.all)
                ReadableWidth(
                  child: _ListCard(
                    title: list,
                    entries: [
                      for (final o
                          in lists.lists[list] ?? const <MaterialOption>[])
                        (id: o.option, label: o.value, enabled: o.enabled),
                    ],
                    onAdd: (value) => ref
                        .read(materialStockRepositoryProvider)
                        .addOption(list, value),
                    onRemove: (id) => ref
                        .read(materialStockRepositoryProvider)
                        .removeOption(id),
                  ),
                ),
              ReadableWidth(
                child: _ListCard(
                  title: l10n.materialStockSuppliers,
                  entries: [
                    for (final s in lists.suppliers)
                      (id: s.supplier, label: s.name, enabled: s.enabled),
                  ],
                  onAdd: (value) => ref
                      .read(materialStockRepositoryProvider)
                      .addSupplier(value),
                  onRemove: (id) => ref
                      .read(materialStockRepositoryProvider)
                      .disableSupplier(id),
                ),
              ),
            ],
          ),
        );
  }
}

typedef _Entry = ({String id, String label, bool enabled});

class _ListCard extends ConsumerWidget {
  const _ListCard({
    required this.title,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final List<_Entry> entries;
  final Future<Object?> Function(String value) onAdd;
  final Future<Object?> Function(String id) onRemove;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
      ref.invalidate(materialListsProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _AddValueDialog(title: title),
    );
    if (value == null || value.isEmpty || !context.mounted) return;
    await _run(context, ref, () => onAdd(value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showDone(l10n.materialStockAdded(value));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(title)),
                IconButton(
                  key: ValueKey('addTo:$title'),
                  tooltip: l10n.materialStockAdd,
                  icon: const Icon(AppIcons.add),
                  onPressed: () => _add(context, ref),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final e in entries)
                  e.enabled
                      ? InputChip(
                          key: ValueKey('chip:$title:${e.label}'),
                          label: Text(e.label),
                          onDeleted: () =>
                              _run(context, ref, () => onRemove(e.id)),
                        )
                      : Chip(
                          label: Text(
                            l10n.materialStockOff(e.label),
                          ),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddValueDialog extends StatefulWidget {
  const _AddValueDialog({required this.title});

  final String title;

  @override
  State<_AddValueDialog> createState() => _AddValueDialogState();
}

class _AddValueDialogState extends State<_AddValueDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('newValue'),
        controller: _controller,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('newValueSave'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.materialStockAdd),
        ),
      ],
    );
  }
}
