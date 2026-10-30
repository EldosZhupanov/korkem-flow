import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/material_stock/data/material_stock_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}';

/// «Пересчёт»: type what is on the shelf; the month's usage follows from it —
/// at the start + bought − at the end, against what orders took.
class StockCountTab extends ConsumerStatefulWidget {
  const StockCountTab({super.key});

  @override
  ConsumerState<StockCountTab> createState() => _StockCountTabState();
}

class _StockCountTabState extends ConsumerState<StockCountTab> {
  final _counted = <String, TextEditingController>{};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _counted.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String item) =>
      _counted.putIfAbsent(item, TextEditingController.new);

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final counted = <String, double>{};
    for (final MapEntry(key: item, value: c) in _counted.entries) {
      final text = c.text.trim().replaceAll(',', '.');
      if (text.isEmpty) continue;
      final qty = double.tryParse(text);
      if (qty == null || qty < 0) {
        messenger.showFailureMessage(l10n.materialStockFillAll);
        return;
      }
      counted[item] = qty;
    }
    if (counted.isEmpty) {
      messenger.showFailureMessage(l10n.stockCountNothing);
      return;
    }
    setState(() => _busy = true);
    try {
      final differed = await ref
          .read(materialStockRepositoryProvider)
          .recordCount(counted);
      messenger.showDone(l10n.stockCountSaved(differed));
      for (final c in _counted.values) {
        c.clear();
      }
      ref
        ..invalidate(stockMaterialsProvider)
        ..invalidate(monthUsageProvider(_monthKey(_month)));
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
    final stock = ref.watch(stockMaterialsProvider);
    final usage = ref.watch(monthUsageProvider(_monthKey(_month)));
    final money = NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: '₸',
      decimalDigits: 0,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(child: SectionLabel(l10n.stockCountTitle)),
        ReadableWidth(
          child: Text(l10n.stockCountHint, style: theme.textTheme.bodySmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...stock.when(
          loading: () => const [LinearProgressIndicator()],
          error: (error, _) => [
            SizedBox(
              height: AppSpacing.xxxl * 5,
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(stockMaterialsProvider),
              ),
            ),
          ],
          data: (rows) => [
            for (final row in rows)
              ReadableWidth(
                child: ListTile(
                  key: ValueKey('count:${row.item}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.title),
                  subtitle: Text(
                    l10n.stockCountBooks('${_plain(row.onHand)} ${row.unit}'),
                  ),
                  trailing: SizedBox(
                    width: AppSpacing.xl * 4,
                    child: TextField(
                      key: ValueKey('countQty:${row.item}'),
                      controller: _field(row.item),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        hintText: l10n.stockCountOnShelf,
                        suffixText: row.unit,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ReadableWidth(
          child: FilledButton(
            key: const ValueKey('countSave'),
            onPressed: _busy ? null : _save,
            child: Text(l10n.stockCountSave),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ReadableWidth(child: SectionLabel(l10n.stockUsageTitle)),
        ReadableWidth(
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('usagePrev'),
                tooltip: l10n.payrollPrevMonth,
                icon: const Icon(AppIcons.back),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const ValueKey('usageNext'),
                tooltip: l10n.payrollNextMonth,
                icon: const Icon(AppIcons.forward),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
        ),
        ...usage.when(
          loading: () => const [LinearProgressIndicator()],
          error: (error, _) => [
            SizedBox(
              height: AppSpacing.xxxl * 5,
              child: ErrorView(
                error: error,
                onRetry: () =>
                    ref.invalidate(monthUsageProvider(_monthKey(_month))),
              ),
            ),
          ],
          data: (month) => [
            ReadableWidth(
              child: Text(
                month.countedOn == null
                    ? l10n.stockUsageNotCounted
                    : l10n.stockUsageCountedOn(month.countedOn!),
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final m in month.materials)
              ReadableWidth(
                child: AppCard(
                  key: ValueKey('usage:${m.item}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.stockUsageLine(
                          _plain(m.start),
                          _plain(m.bought),
                          _plain(m.end),
                          m.unit,
                        ),
                      ),
                      Text(
                        l10n.stockUsageUsed(
                          '${_plain(m.used)} ${m.unit}',
                          '${_plain(m.byOrders)} ${m.unit}',
                        ),
                      ),
                      if (m.unaccounted > 0)
                        Text(
                          l10n.stockUsageLoss(
                            '${_plain(m.unaccounted)} ${m.unit}',
                            m.unaccountedValue == null
                                ? ''
                                : ' · ${money.format(m.unaccountedValue)}',
                          ),
                          key: ValueKey('usageLoss:${m.item}'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
