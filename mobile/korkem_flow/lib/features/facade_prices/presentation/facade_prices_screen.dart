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
import 'package:korkem_flow/features/facade_prices/application/facade_price_controller.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_price_table.dart';
import 'package:korkem_flow/features/facade_prices/presentation/facade_rules_card.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The facade price matrix: milling × finish, ₸ per m².
///
/// Edited by the administrator and the managers who take orders; the server
/// enforces that, and this screen only hides the pencil from anybody else.
class FacadePricesScreen extends ConsumerWidget {
  const FacadePricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tableAsync = ref.watch(facadePriceControllerProvider);
    final table = tableAsync.value;

    return AppScreen(
      title: l10n.facadePricesTitle,
      subtitle: l10n.facadePricesSubtitle,
      actions: [
        if (table != null && table.canEdit)
          IconButton(
            key: const ValueKey('facadeQuoteOpen'),
            tooltip: l10n.facadeQuoteTitle,
            icon: const Icon(AppIcons.quote),
            onPressed: () => context.push(Routes.facadeQuote),
          ),
        if (table != null && table.canEdit)
          IconButton(
            key: const ValueKey('facadePriceAdd'),
            tooltip: l10n.facadePricesAddMilling,
            icon: const Icon(AppIcons.add),
            onPressed: () => _edit(context, ref, table),
          ),
      ],
      body: tableAsync.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(facadePriceControllerProvider),
        ),
        data: (table) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final milling in table.millings)
              ReadableWidth(
                child: _MillingCard(
                  milling: milling,
                  table: table,
                  onEdit: (finish) => _edit(
                    context,
                    ref,
                    table,
                    milling: milling,
                    finish: finish,
                  ),
                ),
              ),
            ReadableWidth(child: FacadeRulesCard(canEdit: table.canEdit)),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    FacadePriceTable table, {
    String? milling,
    String? finish,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<List<_Edit>>(
      context: context,
      builder: (_) => _EditDialog(
        finishes: table.finishes,
        milling: milling,
        finish: finish,
        current: milling != null && finish != null
            ? table.cell(milling, finish)
            : null,
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      // A new milling arrives with a price per finish; each is its own cell.
      for (final edit in result) {
        await ref
            .read(facadePriceControllerProvider.notifier)
            .save(
              milling: edit.milling,
              finish: edit.finish,
              pricePerM2: edit.price,
              enabled: edit.enabled,
            );
      }
      messenger.showDone(l10n.facadePricesSaved);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

class _MillingCard extends StatelessWidget {
  const _MillingCard({
    required this.milling,
    required this.table,
    required this.onEdit,
  });

  final String milling;
  final FacadePriceTable table;
  final void Function(String finish) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: '₸',
      decimalDigits: 0,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(milling),
            for (final finish in table.finishes)
              _priceRow(context, l10n, money, finish),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(
    BuildContext context,
    AppLocalizations l10n,
    NumberFormat money,
    String finish,
  ) {
    final cell = table.cell(milling, finish);
    final sold = cell != null && cell.enabled;
    return ListTile(
      key: ValueKey('facadePrice:$milling:$finish'),
      contentPadding: EdgeInsets.zero,
      title: Text(finish),
      subtitle: sold ? null : Text(l10n.facadePricesNotSold),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sold ? '${money.format(cell.pricePerM2)} / м²' : '—',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (table.canEdit) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(AppIcons.edit, size: AppIconSize.dense),
          ],
        ],
      ),
      onTap: table.canEdit ? () => onEdit(finish) : null,
    );
  }
}

class _Edit {
  const _Edit(this.milling, this.finish, this.price, {required this.enabled});

  final String milling;
  final String finish;
  final double price;
  final bool enabled;
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.finishes,
    this.milling,
    this.finish,
    this.current,
  });

  final List<String> finishes;
  final String? milling;
  final String? finish;
  final FacadePrice? current;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _milling = TextEditingController(
    text: widget.milling ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.current == null
        ? ''
        : widget.current!.pricePerM2.toStringAsFixed(0),
  );
  late final String? _finish =
      widget.finish ?? (widget.finishes.isEmpty ? null : widget.finishes.first);
  late bool _enabled = widget.current?.enabled ?? true;

  /// A new milling gets one price field per finish, all visible at once.
  /// It used to be one field and a finish picker, and switching the finish
  /// kept the typed price — so «ПВХ 19 500», then «Эмаль», saved 19 500 as
  /// the enamel price (owner, 01.11.2026). Empty means «не продаётся».
  late final Map<String, TextEditingController> _byFinish = {
    for (final f in widget.finishes) f: TextEditingController(),
  };
  bool _noPrice = false;

  bool get _isNew => widget.milling == null;

  @override
  void dispose() {
    _milling.dispose();
    _price.dispose();
    for (final c in _byFinish.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        _isNew
            ? l10n.facadePricesAddMilling
            : '${widget.milling} — ${widget.finish}',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isNew) ...[
              TextFormField(
                key: const ValueKey('facadePriceMilling'),
                controller: _milling,
                decoration: InputDecoration(
                  labelText: l10n.facadePricesMilling,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.facadePricesMilling
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final MapEntry(key: finish, value: controller)
                  in _byFinish.entries) ...[
                TextFormField(
                  key: ValueKey('facadePriceFor:$finish'),
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: finish,
                    hintText: l10n.facadePricesEmptyNotSold,
                    suffixText: '₸ / м²',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return null;
                    final n = double.tryParse(text);
                    return (n == null || n <= 0)
                        ? l10n.facadePricesPricePerM2
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_noPrice)
                Text(
                  l10n.facadePricesNeedOne,
                  key: const ValueKey('facadePriceNeedOne'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
            if (!_isNew)
              TextFormField(
                key: const ValueKey('facadePriceValue'),
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.facadePricesPricePerM2,
                  suffixText: '₸',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return (n == null || n <= 0)
                      ? l10n.facadePricesPricePerM2
                      : null;
                },
              ),
            if (!_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.facadePricesSold),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('facadePriceSave'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_isNew) {
              final edits = [
                for (final MapEntry(key: finish, value: c) in _byFinish.entries)
                  if (c.text.trim().isNotEmpty)
                    _Edit(
                      _milling.text.trim(),
                      finish,
                      double.parse(c.text.trim()),
                      enabled: true,
                    ),
              ];
              if (edits.isEmpty) {
                setState(() => _noPrice = true);
                return;
              }
              Navigator.of(context).pop(edits);
              return;
            }
            if (_finish == null) return;
            Navigator.of(context).pop([
              _Edit(
                _milling.text.trim(),
                _finish,
                double.parse(_price.text.trim()),
                enabled: _enabled,
              ),
            ]);
          },
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}
