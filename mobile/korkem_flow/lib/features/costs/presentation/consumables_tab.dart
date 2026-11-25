import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/costs/data/costs_repository.dart';
import 'package:korkem_flow/features/costs/domain/costs.dart';
import 'package:korkem_flow/features/costs/presentation/costs_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Расходники»: what is on the shelf, «Взял» in one tap; for the owner,
/// «Купили» and the minimum. One not in the list is added from the floor.
class ConsumablesTab extends ConsumerWidget {
  const ConsumablesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shelf = ref.watch(consumablesProvider);
    return shelf.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(consumablesProvider),
      ),
      data: (s) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ReadableWidth(
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('cst:quickAdd'),
                onPressed: () => _quickAdd(context, ref),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.cstQuickAdd),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in s.items)
            ReadableWidth(
              child: _Line(item: c, owner: s.canReceive),
            ),
        ],
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final got = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _QuickAddDialog(),
    );
    if (got == null) return;
    try {
      await ref.read(costsRepositoryProvider).quickAdd(got.$1, unit: got.$2);
      ref
        ..invalidate(consumablesProvider)
        ..invalidate(costCatalogProvider);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }
}

class _Line extends ConsumerWidget {
  const _Line({required this.item, required this.owner});

  final Consumable item;
  final bool owner;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<Consumables> Function(CostsRepository repo) action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(costsRepositoryProvider));
      ref.invalidate(consumablesProvider);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = costMoney(context);
    final c = item;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      key: ValueKey('cst:consumable:${c.item}'),
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(child: Text(c.title, overflow: TextOverflow.ellipsis)),
          if (c.low) ...[
            const SizedBox(width: AppSpacing.xs),
            StatusChip(
              key: ValueKey('cst:low:${c.item}'),
              label: l10n.cstLow,
              intent: StatusIntent.danger,
              compact: true,
            ),
          ],
          if (c.isNew) ...[
            const SizedBox(width: AppSpacing.xs),
            StatusChip(
              label: l10n.cstNew,
              intent: StatusIntent.info,
              compact: true,
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          l10n.cstOnHand(costQty(c.onHand), c.unit),
          if (c.minimum > 0) l10n.cstMinimum(costQty(c.minimum)),
          if (c.taken30d > 0) l10n.cstTaken30(costQty(c.taken30d)),
          if (c.price case final p? when p > 0) money.format(p),
        ].join(' · '),
        style: muted?.copyWith(color: c.low ? status.danger : null),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonal(
            key: ValueKey('cst:take:${c.item}'),
            onPressed: c.onHand <= 0
                ? null
                : () async {
                    final qty = await _askNumber(
                      context,
                      title: '${l10n.cstTake} · ${c.title}',
                      label: l10n.cstTakeHow,
                      initial: '1',
                      fieldKey: const ValueKey('cst:takeQty'),
                    );
                    if (qty == null || !context.mounted) return;
                    await _run(context, ref, (r) => r.take(c.item, qty));
                  },
            child: Text(l10n.cstTake),
          ),
          if (owner)
            PopupMenuButton<String>(
              key: ValueKey('cst:menu:${c.item}'),
              onSelected: (what) async {
                if (what == 'receive') {
                  final got = await showDialog<(double, double, String)>(
                    context: context,
                    builder: (_) => _ReceiveDialog(item: c),
                  );
                  if (got == null || !context.mounted) return;
                  await _run(
                    context,
                    ref,
                    (r) => r.receive(
                      c.item,
                      qty: got.$1,
                      price: got.$2,
                      supplier: got.$3.isEmpty ? null : got.$3,
                    ),
                  );
                } else {
                  final min = await _askNumber(
                    context,
                    title: '${l10n.cstSetMinimum} · ${c.title}',
                    label: l10n.cstSetMinimum,
                    initial: c.minimum > 0 ? costQty(c.minimum) : '',
                    fieldKey: const ValueKey('cst:minimum'),
                  );
                  if (min == null || !context.mounted) return;
                  await _run(context, ref, (r) => r.setMinimum(c.item, min));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const ValueKey('cst:receive'),
                  value: 'receive',
                  child: Text(l10n.cstReceive),
                ),
                PopupMenuItem(
                  key: const ValueKey('cst:setMinimum'),
                  value: 'minimum',
                  child: Text(l10n.cstSetMinimum),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

double? _number(String s) =>
    double.tryParse(s.replaceAll(' ', '').replaceAll(',', '.'));

/// One number asked for: how many, the minimum.
Future<double?> _askNumber(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
  required Key fieldKey,
}) => showDialog<double>(
  context: context,
  builder: (_) => _NumberDialog(
    title: title,
    label: label,
    initial: initial,
    fieldKey: fieldKey,
  ),
);

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.fieldKey,
  });

  final String title;
  final String label;
  final String initial;
  final Key fieldKey;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = _number(_field.text);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9,.]'))],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('cst:numberOk'),
          onPressed: value == null
              ? null
              : () => Navigator.of(context).pop(value),
          child: Text(l10n.cstSave),
        ),
      ],
    );
  }
}

/// «Купили»: how many, at what price, where.
class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({required this.item});

  final Consumable item;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  final _qty = TextEditingController();
  late final TextEditingController _price = TextEditingController(
    text: widget.item.price == null || widget.item.price == 0
        ? ''
        : costQty(widget.item.price!),
  );
  final _supplier = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _supplier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qty = _number(_qty.text);
    final price = _number(_price.text);
    final numbers = [FilteringTextInputFormatter.allow(RegExp('[0-9,.]'))];
    return AlertDialog(
      key: const ValueKey('cst:receiveDialog'),
      title: Text('${l10n.cstReceive} · ${widget.item.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('cst:receiveQty'),
            controller: _qty,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: numbers,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.cstTakeHow,
              suffixText: widget.item.unit,
            ),
          ),
          TextField(
            key: const ValueKey('cst:receivePrice'),
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: numbers,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.cstPrice),
          ),
          TextField(
            key: const ValueKey('cst:receiveSupplier'),
            controller: _supplier,
            decoration: InputDecoration(labelText: l10n.cstSupplier),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('cst:receiveSave'),
          onPressed: qty != null && qty > 0 && price != null && price > 0
              ? () => Navigator.of(
                  context,
                ).pop((qty, price, _supplier.text.trim()))
              : null,
          child: Text(l10n.cstSave),
        ),
      ],
    );
  }
}

/// «Нет в списке»: what was taken, and its unit.
class _QuickAddDialog extends StatefulWidget {
  const _QuickAddDialog();

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  final _title = TextEditingController();
  String _unit = 'шт';

  /// The stock's own units (`material_stock.UNITS`) — names, not words.
  static const List<String> _units = [
    'шт',
    'рулон',
    'пачка',
    'упак',
    'м',
    'л',
    'кг',
  ];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _title.text.trim();
    return AlertDialog(
      key: const ValueKey('cst:quickAddDialog'),
      title: Text(l10n.cstQuickAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('cst:quickAddTitle'),
            controller: _title,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.cstQuickAddTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.cstUnit),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final u in _units)
                ChoiceChip(
                  key: ValueKey('cst:unit:$u'),
                  label: Text(u),
                  selected: _unit == u,
                  onSelected: (_) => setState(() => _unit = u),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('cst:quickAddSave'),
          onPressed: title.length < 2
              ? null
              : () => Navigator.of(context).pop((title, _unit)),
          child: Text(l10n.cstSave),
        ),
      ],
    );
  }
}
