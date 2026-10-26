import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/facade_prices/application/facade_price_controller.dart';
import 'package:korkem_flow/features/facade_prices/data/facade_price_repository.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_price_table.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final facadeRulesProvider = FutureProvider.autoDispose<FacadeRules>(
  (ref) => ref.watch(facadePriceRepositoryProvider).fetchRules(),
);

/// A facade order priced on the server: pieces, m², sum, prepayment, balance.
///
/// The screen only collects sizes and choices. Every figure it shows came
/// back from `api.facade_prices.quote`; nothing is multiplied here.
class FacadeQuoteScreen extends ConsumerStatefulWidget {
  const FacadeQuoteScreen({super.key});

  @override
  ConsumerState<FacadeQuoteScreen> createState() => _FacadeQuoteScreenState();
}

class _LineDraft {
  _LineDraft({this.milling, this.finish});

  final width = TextEditingController();
  final height = TextEditingController();
  final qty = TextEditingController(text: '1');
  String? milling;
  String? finish;
  bool doubleSided = false;
  bool customerMaterial = false;

  void dispose() {
    width.dispose();
    height.dispose();
    qty.dispose();
  }
}

class _FacadeQuoteScreenState extends ConsumerState<FacadeQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lines = <_LineDraft>[];
  final _prepayment = TextEditingController();
  bool _demolition = false;
  bool _busy = false;
  FacadeQuote? _quote;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _prepayment.dispose();
    super.dispose();
  }

  void _addLine(FacadePriceTable table) {
    setState(() {
      _lines.add(
        _LineDraft(
          milling: table.millings.isEmpty ? null : table.millings.first,
          finish: table.finishes.isEmpty ? null : table.finishes.first,
        ),
      );
      _quote = null;
    });
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final quote = await ref
          .read(facadePriceRepositoryProvider)
          .quote(
            [
              for (final line in _lines)
                FacadeLineInput(
                  widthMm: double.parse(line.width.text),
                  heightMm: double.parse(line.height.text),
                  qty: int.parse(line.qty.text),
                  milling: line.milling!,
                  finish: line.finish!,
                  doubleSided: line.doubleSided,
                  customerMaterial: line.customerMaterial,
                ),
            ],
            demolition: _demolition,
            prepaymentAmount: double.tryParse(_prepayment.text.trim()),
          );
      if (mounted) setState(() => _quote = quote);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tableAsync = ref.watch(facadePriceControllerProvider);
    final rules = ref.watch(facadeRulesProvider).value ?? const FacadeRules();

    return AppScreen(
      title: l10n.facadeQuoteTitle,
      body: tableAsync.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(facadePriceControllerProvider),
        ),
        data: (table) {
          if (_lines.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _lines.isEmpty) _addLine(table);
            });
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final (index, line) in _lines.indexed)
                  ReadableWidth(
                    child: _LineCard(
                      key: ObjectKey(line),
                      index: index,
                      line: line,
                      table: table,
                      rules: rules,
                      amount:
                          _quote != null && index < _quote!.lineAmounts.length
                          ? _quote!.lineAmounts[index]
                          : null,
                      onChanged: () => setState(() => _quote = null),
                      onRemove: _lines.length > 1
                          ? () => setState(() {
                              _lines.remove(line);
                              line.dispose();
                              _quote = null;
                            })
                          : null,
                    ),
                  ),
                ReadableWidth(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('facadeQuoteAddLine'),
                      onPressed: () => _addLine(table),
                      icon: const Icon(AppIcons.add),
                      label: Text(l10n.facadeQuoteAddLine),
                    ),
                  ),
                ),
                ReadableWidth(
                  child: AppCard(
                    child: Column(
                      children: [
                        if (rules.demolitionOffered)
                          SwitchListTile(
                            key: const ValueKey('facadeQuoteDemolition'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.facadeQuoteDemolition),
                            value: _demolition,
                            onChanged: (v) => setState(() {
                              _demolition = v;
                              _quote = null;
                            }),
                          ),
                        TextFormField(
                          key: const ValueKey('facadeQuotePrepayment'),
                          controller: _prepayment,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.facadeQuotePrepaymentManual,
                            helperText: rules.prepaymentPercent == null
                                ? null
                                : l10n.facadeQuotePrepaymentDefault(
                                    rules.prepaymentPercent!.toStringAsFixed(0),
                                  ),
                            suffixText: '₸',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _quote = null),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ReadableWidth(
                  child: FilledButton.icon(
                    key: const ValueKey('facadeQuoteCalculate'),
                    onPressed: _busy || _lines.isEmpty ? null : _calculate,
                    icon: const Icon(AppIcons.quote),
                    label: Text(l10n.facadeQuoteCalculate),
                  ),
                ),
                if (_quote != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ReadableWidth(child: _Totals(quote: _quote!)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LineCard extends StatefulWidget {
  const _LineCard({
    required this.index,
    required this.line,
    required this.table,
    required this.rules,
    required this.onChanged,
    this.amount,
    this.onRemove,
    super.key,
  });

  final int index;
  final _LineDraft line;
  final FacadePriceTable table;
  final FacadeRules rules;
  final double? amount;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final line = widget.line;
    String? positiveInt(String? v) {
      final n = int.tryParse((v ?? '').trim());
      return (n == null || n <= 0) ? l10n.facadeQuoteNumberRequired : null;
    }

    Widget number(TextEditingController c, String label, String key) =>
        Expanded(
          child: TextFormField(
            key: ValueKey('$key:${widget.index}'),
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            validator: positiveInt,
            onChanged: (_) => widget.onChanged(),
          ),
        );

    void changed(VoidCallback update) {
      setState(update);
      widget.onChanged();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionLabel(l10n.facadeQuoteLine(widget.index + 1)),
                ),
                if (widget.amount != null)
                  Text(
                    _money(context).format(widget.amount),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: l10n.facadeQuoteRemoveLine,
                    icon: const Icon(AppIcons.close),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            Row(
              children: [
                number(line.width, l10n.facadeQuoteWidth, 'facadeQuoteWidth'),
                const SizedBox(width: AppSpacing.sm),
                number(
                  line.height,
                  l10n.facadeQuoteHeight,
                  'facadeQuoteHeight',
                ),
                const SizedBox(width: AppSpacing.sm),
                number(line.qty, l10n.facadeQuoteQty, 'facadeQuoteQty'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.milling,
                    isExpanded: true,
                    items: [
                      for (final m in widget.table.millings)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => changed(() => line.milling = v),
                    decoration: InputDecoration(
                      labelText: l10n.facadePricesMilling,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.finish,
                    isExpanded: true,
                    items: [
                      for (final f in widget.table.finishes)
                        DropdownMenuItem(value: f, child: Text(f)),
                    ],
                    onChanged: (v) => changed(() => line.finish = v),
                    decoration: InputDecoration(
                      labelText: l10n.facadePricesFinish,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.rules.doubleSidedOffered)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.facadeQuoteDoubleSided),
                value: line.doubleSided,
                onChanged: (v) => changed(() => line.doubleSided = v ?? false),
              ),
            if (widget.rules.customerMaterialOffered)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.facadeQuoteCustomerMaterial),
                value: line.customerMaterial,
                onChanged: (v) =>
                    changed(() => line.customerMaterial = v ?? false),
              ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.quote});

  final FacadeQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: strong
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
    return AppCard(
      key: const ValueKey('facadeQuoteTotals'),
      child: Column(
        children: [
          row(l10n.facadeQuotePieces, '${quote.pieces}'),
          row(l10n.facadeQuoteArea, '${quote.areaM2.toStringAsFixed(2)} м²'),
          if (quote.demolition > 0)
            row(l10n.facadeQuoteDemolition, money.format(quote.demolition)),
          row(l10n.facadeQuoteTotal, money.format(quote.total), strong: true),
          row(l10n.facadeQuotePrepayment, money.format(quote.prepayment)),
          row(
            l10n.facadeQuoteBalance,
            money.format(quote.balance),
            strong: true,
          ),
        ],
      ),
    );
  }
}

NumberFormat _money(BuildContext context) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol: '₸',
  decimalDigits: 0,
);
