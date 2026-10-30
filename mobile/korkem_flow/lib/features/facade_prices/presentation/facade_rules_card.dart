import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/features/facade_prices/data/facade_price_repository.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/facade_prices/presentation/facade_quote_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The rules a facade order is priced by: double-sided, customer's material,
/// demolition, prepayment. Each may be left empty, which means "not offered".
class FacadeRulesCard extends ConsumerWidget {
  const FacadeRulesCard({required this.canEdit, super.key});

  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rules = ref.watch(facadeRulesProvider).value;
    if (rules == null) return const SizedBox.shrink();
    final off = l10n.facadeRulesNotOffered;
    String n(double? v) => v == null ? off : _plain(v);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(l10n.facadeRulesTitle)),
              if (canEdit)
                IconButton(
                  key: const ValueKey('facadeRulesEdit'),
                  tooltip: l10n.facadeRulesTitle,
                  icon: const Icon(AppIcons.edit),
                  onPressed: () => _edit(context, ref, rules),
                ),
            ],
          ),
          _row(
            l10n.facadeQuoteDoubleSided,
            rules.doubleSidedOffered ? '×${n(rules.doubleSidedFactor)}' : off,
          ),
          _row(
            l10n.facadeQuoteCustomerMaterial,
            rules.customerMaterialOffered
                ? '−${_plain(rules.customerMaterialDiscountPercent)}%'
                : off,
          ),
          _row(
            l10n.facadeQuoteDemolition,
            rules.demolitionOffered
                ? '${n(rules.demolitionRate)} ₸ '
                      '${rules.demolitionUnit!.toLowerCase()}'
                : off,
          ),
          _row(
            l10n.facadeQuotePrepayment,
            rules.prepaymentPercent == null
                ? off
                : '${_plain(rules.prepaymentPercent!)}%',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    FacadeRules rules,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final updated = await showDialog<FacadeRules>(
      context: context,
      builder: (_) => _RulesDialog(rules: rules),
    );
    if (updated == null) return;
    try {
      await ref.read(facadePriceRepositoryProvider).saveRules(updated);
      ref.invalidate(facadeRulesProvider);
      messenger.showDone(l10n.facadePricesSaved);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }
}

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _RulesDialog extends StatefulWidget {
  const _RulesDialog({required this.rules});

  final FacadeRules rules;

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  late final _factor = TextEditingController(
    text: _text(widget.rules.doubleSidedFactor),
  );
  late final _discount = TextEditingController(
    text: _plain(widget.rules.customerMaterialDiscountPercent),
  );
  late final _demolitionRate = TextEditingController(
    text: _text(widget.rules.demolitionRate),
  );
  late final _prepayment = TextEditingController(
    text: _text(widget.rules.prepaymentPercent),
  );
  late bool _material = widget.rules.customerMaterialOffered;
  late String? _unit = widget.rules.demolitionUnit;

  static String _text(double? v) => v == null ? '' : _plain(v);

  @override
  void dispose() {
    _factor.dispose();
    _discount.dispose();
    _demolitionRate.dispose();
    _prepayment.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? suffix,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.facadeRulesTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(
              _factor,
              l10n.facadeRulesDoubleSidedFactor,
              helper: l10n.facadeRulesEmptyMeansOff,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.facadeQuoteCustomerMaterial),
              value: _material,
              onChanged: (v) => setState(() => _material = v),
            ),
            if (_material)
              _field(_discount, l10n.facadeRulesDiscount, suffix: '%'),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DropdownButtonFormField<String?>(
                initialValue: _unit,
                items: [
                  DropdownMenuItem(child: Text(l10n.facadeRulesNotOffered)),
                  for (final u in FacadeRules.demolitionUnits)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) => setState(() => _unit = v),
                decoration: InputDecoration(
                  labelText: l10n.facadeQuoteDemolition,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_unit != null)
              _field(
                _demolitionRate,
                l10n.facadeRulesDemolitionRate,
                suffix: '₸',
              ),
            _field(_prepayment, l10n.facadeRulesPrepayment, suffix: '%'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('facadeRulesSave'),
          onPressed: () => Navigator.of(context).pop(
            FacadeRules(
              doubleSidedFactor: double.tryParse(_factor.text),
              customerMaterialOffered: _material,
              customerMaterialDiscountPercent:
                  double.tryParse(_discount.text) ?? 0,
              demolitionUnit: _unit,
              demolitionRate: _unit == null
                  ? null
                  : double.tryParse(_demolitionRate.text),
              prepaymentPercent: double.tryParse(_prepayment.text),
            ),
          ),
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}
