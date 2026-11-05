import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/features/facade_prices/application/facade_price_controller.dart';
import 'package:korkem_flow/features/material_stock/data/material_stock_repository.dart';
import 'package:korkem_flow/features/material_stock/domain/material_stock.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_batch.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Детали по плёнке» — OnayBaza's «Тапсырыс Кестесі»: choose the face film
/// and the milling, and every part of the open orders waiting for it comes
/// out as one list, largest first, identical sizes summed.
class MdfBatchScreen extends ConsumerStatefulWidget {
  const MdfBatchScreen({super.key});

  @override
  ConsumerState<MdfBatchScreen> createState() => _MdfBatchScreenState();
}

class _MdfBatchScreenState extends ConsumerState<MdfBatchScreen> {
  String? _decor;
  String? _milling;
  MdfBatch? _batch;
  bool _busy = false;

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final batch = await ref
          .read(mdfOrderRepositoryProvider)
          .batch(decor: _decor, milling: _milling);
      if (mounted) setState(() => _batch = batch);
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
    final lists = ref.watch(materialListsProvider).value;
    final films = [
      for (final o in lists?.lists['Цвет плёнки'] ?? const <MaterialOption>[])
        if (o.enabled) o.value,
    ];
    final millings =
        ref.watch(facadePriceControllerProvider).value?.millings ??
        const <String>[];
    Widget pick(
      String key,
      String label,
      List<String> values,
      String? current,
      ValueChanged<String?> set,
    ) => SizedBox(
      width: AppSpacing.xxxl * 6,
      child: DropdownButtonFormField<String?>(
        key: ValueKey(key),
        initialValue: values.contains(current) ? current : null,
        isExpanded: true,
        items: [
          DropdownMenuItem(child: Text(l10n.mdfFilterAll)),
          for (final v in values) DropdownMenuItem(value: v, child: Text(v)),
        ],
        onChanged: (v) {
          setState(() => set(v));
          unawaited(_load());
        },
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
    final batch = _batch;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfBatchTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              pick(
                'batchDecor',
                l10n.mdfDecorTop,
                films,
                _decor,
                (v) => _decor = v,
              ),
              pick(
                'batchMilling',
                l10n.mdfMilling,
                millings,
                _milling,
                (v) => _milling = v,
              ),
              FilledButton(
                key: const ValueKey('batchShow'),
                onPressed: _busy ? null : _load,
                child: Text(l10n.mdfBatchShow),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (batch != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ReadableWidth(
              child: Text(
                l10n.mdfBatchTotals(
                  '${batch.orders.length}',
                  '${batch.pieces}',
                  batch.areaM2.toStringAsFixed(2),
                ),
                key: const ValueKey('batchTotals'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (batch.orders.isNotEmpty)
              Text(batch.orders.join(' · '), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            ReadableWidth(child: SectionLabel(l10n.mdfBatchParts)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const ValueKey('batchTable'),
                columns: [
                  DataColumn(label: Text(l10n.mdfBatchLong), numeric: true),
                  DataColumn(label: Text(l10n.mdfBatchShort), numeric: true),
                  DataColumn(label: Text(l10n.mdfQty), numeric: true),
                  DataColumn(label: Text(l10n.mdfArea), numeric: true),
                  DataColumn(label: Text(l10n.mdfMilling)),
                  DataColumn(label: Text(l10n.mdfBatchOrders)),
                ],
                rows: [
                  for (final p in batch.parts)
                    DataRow(
                      cells: [
                        DataCell(Text('${p.longMm}')),
                        DataCell(Text('${p.shortMm}')),
                        DataCell(Text('${p.qty}')),
                        DataCell(Text(p.areaM2.toStringAsFixed(2))),
                        DataCell(Text(p.milling ?? '')),
                        DataCell(Text(p.orders.join(', '))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
