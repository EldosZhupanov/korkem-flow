import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/logistics/data/logistics_repository.dart';
import 'package:korkem_flow/features/logistics/domain/logistics.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What the form starts from: a receipt the delivery came with.
typedef DeliveryDraft = ({
  String? receipt,
  String? category,
  String? what,
  double? qty,
  String? unit,
});

/// Write a delivery down. Returns true once it is saved.
Future<bool> showDeliveryForm(
  BuildContext context, {
  DeliveryDraft? draft,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DeliveryForm(draft: draft),
    ) ??
    false;

/// The form: what it cost, from where, by what — then, optionally, what it
/// brought, for which order, when it was ordered, and whether it was urgent.
class DeliveryForm extends ConsumerStatefulWidget {
  const DeliveryForm({this.draft, super.key});

  final DeliveryDraft? draft;

  @override
  ConsumerState<DeliveryForm> createState() => _DeliveryFormState();
}

class _DeliveryFormState extends ConsumerState<DeliveryForm> {
  final _amount = TextEditingController();
  final _city = TextEditingController();
  final _transport = TextEditingController();
  final _carrier = TextEditingController();
  late final TextEditingController _what = TextEditingController(
    text: widget.draft?.what ?? '',
  );
  late final TextEditingController _qty = TextEditingController(
    text: _plain(widget.draft?.qty),
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.draft?.unit ?? '',
  );
  final _order = TextEditingController();
  final _note = TextEditingController();
  late String? _category = widget.draft?.category;
  DateTime _deliveredOn = DateUtils.dateOnly(DateTime.now());
  DateTime? _orderedOn;
  bool _urgent = false;
  bool _busy = false;

  static String _plain(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
  }

  @override
  void dispose() {
    for (final c in [
      _amount,
      _city,
      _transport,
      _carrier,
      _what,
      _qty,
      _unit,
      _order,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick({required bool ordered}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: ordered ? (_orderedOn ?? _deliveredOn) : _deliveredOn,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => ordered ? _orderedOn = picked : _deliveredOn = picked);
  }

  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save(List<String> categories) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    final category =
        _category ?? (categories.isEmpty ? null : categories.first);
    if (amount == null ||
        amount < 0 ||
        _city.text.trim().length < 2 ||
        _transport.text.trim().length < 2 ||
        category == null) {
      messenger.showFailureMessage(l10n.materialStockFillAll);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(logisticsRepositoryProvider)
          .record(
            NewDelivery(
              amount: amount,
              fromCity: _city.text.trim(),
              transport: _transport.text.trim(),
              category: category,
              deliveredOn: _deliveredOn,
              orderedOn: _orderedOn,
              carrier: _optional(_carrier),
              urgent: _urgent,
              salesOrder: _optional(_order),
              receipt: widget.draft?.receipt,
              what: _optional(_what),
              qty: double.tryParse(_qty.text.replaceAll(',', '.')),
              unit: _optional(_unit),
              note: _optional(_note),
            ),
          );
      messenger.showDone(l10n.logisticsSaved);
      navigator.pop(true);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    bool number = false,
    String? suffix,
  }) => TextField(
    key: ValueKey(key),
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: number
        ? [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))]
        : null,
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      border: const OutlineInputBorder(),
    ),
  );

  /// The usual answers as chips under the field; typing anything else works.
  Widget _choices(
    String key,
    List<String> values,
    TextEditingController controller,
  ) => Wrap(
    spacing: AppSpacing.sm,
    children: [
      for (final v in values.take(8))
        ChoiceChip(
          key: ValueKey('$key:$v'),
          label: Text(v),
          selected: controller.text.trim() == v,
          onSelected: (_) => setState(() => controller.text = v),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offered = ref.watch(logisticsSuggestionsProvider).value;
    final categories = offered?.categories ?? const <String>[];
    final day = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    Widget gap() => const SizedBox(height: AppSpacing.md);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            l10n.logisticsAdd,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          gap(),
          if (categories.isNotEmpty) ...[
            SegmentedButton<String>(
              key: const ValueKey('deliveryCategory'),
              segments: [
                for (final c in categories)
                  ButtonSegment(value: c, label: Text(c)),
              ],
              selected: {_category ?? categories.first},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
            gap(),
          ],
          _field(
            'deliveryAmount',
            l10n.logisticsAmount,
            _amount,
            number: true,
            suffix: '₸',
          ),
          gap(),
          _field('deliveryCity', l10n.logisticsFrom, _city),
          _choices('deliveryCityChip', offered?.cities ?? const [], _city),
          gap(),
          _field('deliveryTransport', l10n.logisticsTransport, _transport),
          _choices(
            'deliveryTransportChip',
            offered?.transports ?? const [],
            _transport,
          ),
          gap(),
          _field('deliveryCarrier', l10n.logisticsCarrier, _carrier),
          _choices(
            'deliveryCarrierChip',
            offered?.carriers ?? const [],
            _carrier,
          ),
          gap(),
          _field('deliveryWhat', l10n.logisticsWhat, _what),
          gap(),
          Row(
            children: [
              Expanded(
                child: _field(
                  'deliveryQty',
                  l10n.logisticsQty,
                  _qty,
                  number: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: AppSpacing.xl * 4,
                child: _field('deliveryUnit', l10n.logisticsUnit, _unit),
              ),
            ],
          ),
          gap(),
          _field('deliveryOrder', l10n.logisticsOrder, _order),
          gap(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('deliveryOrderedOn'),
                  onPressed: () => _pick(ordered: true),
                  child: Text(
                    '${l10n.logisticsOrderedOn}: '
                    '${_orderedOn == null ? '—' : day.format(_orderedOn!)}',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('deliveryDeliveredOn'),
                  onPressed: () => _pick(ordered: false),
                  child: Text(
                    '${l10n.logisticsDeliveredOn}: '
                    '${day.format(_deliveredOn)}',
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile(
            key: const ValueKey('deliveryUrgent'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.logisticsUrgent),
            value: _urgent,
            onChanged: (on) => setState(() => _urgent = on),
          ),
          _field('deliveryNote', l10n.logisticsNote, _note),
          gap(),
          FilledButton(
            key: const ValueKey('deliverySave'),
            onPressed: _busy ? null : () => _save(categories),
            child: Text(l10n.facadePricesSave),
          ),
        ],
      ),
    );
  }
}
