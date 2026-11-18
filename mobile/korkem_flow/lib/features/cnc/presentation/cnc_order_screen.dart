import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/cnc/data/cnc_repository.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';
import 'package:korkem_flow/features/cnc/presentation/cnc_orders_screen.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_receipt_terms.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_customers_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A CNC order (owner, 15.11.2026): a new one or a draft as a form; an
/// accepted one as its card, with what to do next.
class CncOrderScreen extends ConsumerStatefulWidget {
  const CncOrderScreen({this.name, super.key});

  /// Null for a new order.
  final String? name;

  @override
  ConsumerState<CncOrderScreen> createState() => _CncOrderScreenState();
}

class _CncOrderScreenState extends ConsumerState<CncOrderScreen> {
  CncCard? _card;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.name != null) unawaited(_load(widget.name!));
  }

  Future<void> _load(String name) async {
    setState(() => _loading = true);
    try {
      final card = await ref.read(cncRepositoryProvider).card(name);
      if (mounted) {
        setState(() {
          _card = card;
          _loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final card = _card;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          card == null
              ? l10n.cncNewOrder
              : '${card.name} · ${card.customerName}',
        ),
      ),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: () => _load(widget.name!))
          : _loading
          ? const LinearProgressIndicator()
          : card == null || card.status == CncStatus.draft
          ? _CncForm(
              card: card,
              onSaved: (c) => setState(() => _card = c),
            )
          : _CncCardView(
              card: card,
              onChanged: (c) => setState(() => _card = c),
            ),
    );
  }
}

// ---------------------------------------------------------------- the form --

class _Line {
  _Line({
    this.service,
    this.material,
    String? title,
    String? qty,
    String? rate,
    String? note,
  }) : title = TextEditingController(text: title),
       qty = TextEditingController(text: qty ?? '1'),
       rate = TextEditingController(text: rate),
       note = TextEditingController(text: note);

  final CncService? service;
  final CncMaterial? material;
  final TextEditingController title;
  final TextEditingController qty;
  final TextEditingController rate;
  final TextEditingController note;

  CncLineInput? input() {
    final q = filmNumber(qty.text);
    if (q == null || q <= 0) return null;
    final custom = service == null && material == null;
    if (custom && title.text.trim().isEmpty) return null;
    return CncLineInput(
      service: service?.id,
      material: material?.item,
      title: custom ? title.text.trim() : null,
      qty: q,
      rate: filmNumber(rate.text),
      note: note.text.trim().isEmpty ? null : note.text.trim(),
    );
  }

  void dispose() {
    for (final c in [title, qty, rate, note]) {
      c.dispose();
    }
  }
}

class _Intake {
  _Intake({String? what, String? qty, String? defects})
    : what = TextEditingController(text: what),
      qty = TextEditingController(text: qty ?? '1'),
      defects = TextEditingController(text: defects);

  final TextEditingController what;
  final TextEditingController qty;
  final TextEditingController defects;

  CncIntake? input() {
    if (what.text.trim().isEmpty) return null;
    return (
      what: what.text.trim(),
      qty: filmNumber(qty.text) ?? 1,
      unit: 'шт',
      defects: defects.text.trim().isEmpty ? null : defects.text.trim(),
    );
  }

  void dispose() {
    for (final c in [what, qty, defects]) {
      c.dispose();
    }
  }
}

class _CncForm extends ConsumerStatefulWidget {
  const _CncForm({required this.card, required this.onSaved});

  final CncCard? card;
  final ValueChanged<CncCard> onSaved;

  @override
  ConsumerState<_CncForm> createState() => _CncFormState();
}

class _CncFormState extends ConsumerState<_CncForm> {
  String? _customer;
  String? _customerName;
  DateTime _due = DateTime.now().add(const Duration(days: 1));
  bool _urgent = false;
  bool _terms = false;
  final _lines = <_Line>[];
  final _intake = <_Intake>[];
  final _notes = TextEditingController();
  CncQuote? _quote;
  Timer? _debounce;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    if (c != null) {
      _customer = c.customer;
      _customerName = c.customerName;
      _due = DateTime.tryParse(c.deliveryDate) ?? _due;
      _urgent = c.urgent;
      _terms = c.terms;
      _notes.text = c.notes ?? '';
      for (final i in c.intake) {
        _intake.add(
          _Intake(what: i.what, qty: filmMetres(i.qty), defects: i.defects),
        );
      }
      unawaited(_restoreLines(c));
    }
  }

  /// A draft's lines back into the form: each to its service or material.
  Future<void> _restoreLines(CncCard c) async {
    final repo = ref.read(cncRepositoryProvider);
    final services = await repo.services(includeDisabled: true);
    final materials = c.lines.any((l) => l.material != null)
        ? await repo.materials()
        : const <CncMaterial>[];
    if (!mounted) return;
    setState(() {
      for (final l in c.lines) {
        final service = services.where((s) => s.id == l.service).firstOrNull;
        final material = materials
            .where((m) => m.item == l.material)
            .firstOrNull;
        _lines.add(
          _Line(
            service: service,
            material: material,
            title: service == null && material == null ? l.title : null,
            qty: filmMetres(l.qty),
            rate:
                l.manualRate ||
                    material != null ||
                    service == null ||
                    service.byAgreement
                ? filmMetres(l.rate)
                : null,
            note: l.note,
          ),
        );
      }
    });
    _reprice();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final l in _lines) {
      l.dispose();
    }
    for (final i in _intake) {
      i.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  List<CncLineInput> get _inputs => [
    for (final l in _lines) ?l.input(),
  ];

  List<String> get _tags => [if (_urgent) 'urgent'];

  void _reprice() {
    _debounce?.cancel();
    _debounce = Timer(AppDebounce.search, () async {
      final inputs = _inputs;
      if (inputs.isEmpty) {
        if (mounted) setState(() => _quote = null);
        return;
      }
      try {
        final quote = await ref
            .read(cncRepositoryProvider)
            .price(inputs, customer: _customer, tags: _tags);
        if (mounted) setState(() => _quote = quote);
      } on Object {
        // A line half typed: the total waits for it.
      }
    });
  }

  Future<void> _pickCustomer() async {
    final picked = await showMdfCustomers(context, current: _customer);
    if (picked == null || !mounted) return;
    setState(() {
      _customer = picked.name;
      _customerName = picked.title;
    });
    _reprice();
  }

  Future<void> _addService() async {
    final services = await ref.read(cncRepositoryProvider).services();
    if (!mounted) return;
    final picked = await showDialog<CncService>(
      context: context,
      builder: (_) => _ServicePicker(services: services),
    );
    if (picked == null || !mounted) return;
    setState(() => _lines.add(_Line(service: picked)));
    _reprice();
  }

  Future<void> _addMaterial() async {
    final materials = await ref.read(cncRepositoryProvider).materials();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final picked = await showDialog<CncMaterial>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.cncAddMaterial),
        children: [
          if (materials.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.cncNoMaterials),
            ),
          for (final m in materials)
            SimpleDialogOption(
              key: ValueKey('cncMaterial:${m.item}'),
              onPressed: () => Navigator.of(context).pop(m),
              child: Text(
                [
                  m.title,
                  '${filmMetres(m.onHand)} ${m.unit}',
                  if (m.cost > 0) l10n.cncCost(money.format(m.cost)),
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _lines.add(_Line(material: picked)));
  }

  Future<CncCard?> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_customer == null) {
      messenger.showFailureMessage(l10n.cncPickCustomer);
      return null;
    }
    setState(() => _busy = true);
    try {
      final card = await ref
          .read(cncRepositoryProvider)
          .saveDraft(
            customer: _customer!,
            lines: _inputs,
            deliveryDate: mdfIso(_due),
            intake: [for (final i in _intake) ?i.input()],
            terms: _terms,
            tags: _tags,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            order: widget.card?.name,
          );
      return card;
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await _save();
    if (saved == null) return;
    try {
      final card = await ref.read(cncRepositoryProvider).accept(saved.name);
      ref.invalidate(cncListingProvider);
      if (mounted) {
        widget.onSaved(card);
        if (widget.card == null) {
          context.replace(Routes.cncOrder(card.name));
        }
      }
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final quote = _quote;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('cncCustomer'),
                onPressed: _pickCustomer,
                icon: const Icon(AppIcons.customer),
                label: Text(_customerName ?? l10n.cncPickCustomer),
              ),
              OutlinedButton.icon(
                key: const ValueKey('cncDue'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _due,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (d != null) setState(() => _due = d);
                },
                icon: const Icon(AppIcons.calendar),
                label: Text(l10n.cncDue(mdfDayOf(_due))),
              ),
              FilterChip(
                key: const ValueKey('cncUrgent'),
                label: Text(l10n.cncUrgent),
                selected: _urgent,
                onSelected: (v) {
                  setState(() => _urgent = v);
                  _reprice();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // What the customer brought, and his word on hidden defects.
        ReadableWidth(child: SectionLabel(l10n.cncIntake)),
        for (final (i, row) in _intake.indexed)
          ReadableWidth(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    key: ValueKey('cncIntakeWhat:$i'),
                    controller: row.what,
                    decoration: InputDecoration(
                      labelText: l10n.cncIntakeWhat,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: AppSpacing.xxxl * 1.5,
                  child: TextField(
                    key: ValueKey('cncIntakeQty:$i'),
                    controller: row.qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.cncQty,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: ValueKey('cncIntakeDefects:$i'),
                    controller: row.defects,
                    decoration: InputDecoration(
                      labelText: l10n.cncIntakeDefects,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.cncRemove,
                  icon: const Icon(AppIcons.delete),
                  onPressed: () =>
                      setState(() => _intake.removeAt(i).dispose()),
                ),
              ],
            ),
          ),
        ReadableWidth(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('cncIntakeAdd'),
              onPressed: () => setState(() => _intake.add(_Intake())),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.cncIntakeAdd),
            ),
          ),
        ),
        if (_intake.isNotEmpty)
          ReadableWidth(
            child: CheckboxListTile(
              key: const ValueKey('cncTerms'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _terms,
              onChanged: (v) => setState(() => _terms = v ?? false),
              title: Text(l10n.cncTerms),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        ReadableWidth(child: SectionLabel(l10n.cncWork)),
        for (final (i, line) in _lines.indexed)
          ReadableWidth(
            child: _LineEditor(
              index: i,
              line: line,
              priced: line.input() == null
                  ? null
                  : quote?.lines.elementAtOrNull(
                      _lines.take(i).where((l) => l.input() != null).length,
                    ),
              onChanged: _reprice,
              onRemove: () {
                setState(() => _lines.removeAt(i).dispose());
                _reprice();
              },
            ),
          ),
        ReadableWidth(
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                key: const ValueKey('cncAddService'),
                onPressed: _addService,
                icon: const Icon(AppIcons.add),
                label: Text(l10n.cncAddService),
              ),
              TextButton.icon(
                key: const ValueKey('cncAddMaterial'),
                onPressed: _addMaterial,
                icon: const Icon(AppIcons.material),
                label: Text(l10n.cncAddMaterial),
              ),
              TextButton.icon(
                key: const ValueKey('cncAddCustom'),
                onPressed: () => setState(() => _lines.add(_Line())),
                icon: const Icon(AppIcons.edit),
                label: Text(l10n.cncAddCustom),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ReadableWidth(
          child: TextField(
            key: const ValueKey('cncNotes'),
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.cncNotes),
          ),
        ),
        if (quote != null) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(
            child: Container(
              key: const ValueKey('cncTotals'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in quote.extras)
                    Row(
                      children: [
                        Expanded(child: Text(e.title)),
                        Text(money.format(e.amount)),
                      ],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.cncTotal,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        money.format(quote.total),
                        key: const ValueKey('cncTotal'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  if (quote.minutes > 0)
                    Text(
                      l10n.cncMachineTime(cncMinutes(quote.minutes, l10n)),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (quote.makerPrices)
                    Text(
                      l10n.cncMakerPrices,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        ReadableWidth(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const ValueKey('cncSave'),
                onPressed: _busy || _inputs.isEmpty
                    ? null
                    : () async {
                        final card = await _save();
                        if (card != null && context.mounted) {
                          ref.invalidate(cncListingProvider);
                          if (widget.card == null) {
                            context.replace(Routes.cncOrder(card.name));
                          } else {
                            widget.onSaved(card);
                          }
                        }
                      },
                child: Text(l10n.cncSaveDraft),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                key: const ValueKey('cncAccept'),
                onPressed: _busy || _inputs.isEmpty ? null : _accept,
                child: Text(l10n.cncAccept),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.index,
    required this.line,
    required this.priced,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _Line line;
  final CncLine? priced;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final service = line.service;
    final material = line.material;
    final unit = service?.unit ?? material?.unit ?? 'шт';
    final listed = service == null || service.byAgreement
        ? null
        : money.format(service.price);
    Widget number(
      TextEditingController c,
      String label,
      String key, {
      double width = 1.5,
      String? hint,
    }) => SizedBox(
      width: AppSpacing.xxxl * width,
      child: TextField(
        key: ValueKey(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
        ],
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
    return Padding(
      key: ValueKey('cncLine:$index'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: AppSpacing.xxxl * 6,
            child: service != null || material != null
                ? Text(
                    service?.title ?? material!.title,
                    style: theme.textTheme.titleSmall,
                  )
                : TextField(
                    key: ValueKey('cncLineTitle:$index'),
                    controller: line.title,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      labelText: l10n.cncCustomWork,
                      isDense: true,
                    ),
                  ),
          ),
          number(line.qty, '${l10n.cncQty}, $unit', 'cncLineQty:$index'),
          number(
            line.rate,
            l10n.cncRate,
            'cncLineRate:$index',
            width: 2,
            hint: listed,
          ),
          SizedBox(
            width: AppSpacing.xxxl * 3,
            child: TextField(
              key: ValueKey('cncLineNote:$index'),
              controller: line.note,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: l10n.cncLineNote,
                isDense: true,
              ),
            ),
          ),
          if (priced case final p?)
            Text(
              p.noPrice ? l10n.cncNoPrice : money.format(p.amount),
              key: ValueKey('cncLineAmount:$index'),
              style: TextStyle(
                color: p.noPrice ? context.statusColors.danger : null,
              ),
            ),
          IconButton(
            key: ValueKey('cncLineRemove:$index'),
            tooltip: l10n.cncRemove,
            icon: const Icon(AppIcons.delete),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The price list by group, to pick a service from.
class _ServicePicker extends StatelessWidget {
  const _ServicePicker({required this.services});

  final List<CncService> services;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final groups = <String, List<CncService>>{};
    for (final s in services) {
      groups.putIfAbsent(s.group ?? '', () => []).add(s);
    }
    return AlertDialog(
      title: Text(l10n.cncAddService),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  g.key.isEmpty ? l10n.cncNoGroup : g.key,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              for (final s in g.value)
                ListTile(
                  key: ValueKey('cncService:${s.title}'),
                  dense: true,
                  title: Text(s.title),
                  subtitle: Text(
                    [
                      if (s.byAgreement)
                        l10n.cncByAgreement
                      else
                        '${money.format(s.price)} / ${s.unit}',
                      if (s.minutes > 0)
                        l10n.cncPerUnitMinutes(filmMetres(s.minutes)),
                    ].join(' · '),
                  ),
                  onTap: () => Navigator.of(context).pop(s),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- the card --

class _CncCardView extends ConsumerStatefulWidget {
  const _CncCardView({required this.card, required this.onChanged});

  final CncCard card;
  final ValueChanged<CncCard> onChanged;

  @override
  ConsumerState<_CncCardView> createState() => _CncCardViewState();
}

class _CncCardViewState extends ConsumerState<_CncCardView> {
  bool _busy = false;

  Future<void> _do(Future<CncCard?> Function(CncRepository repo) action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final card = await action(ref.read(cncRepositoryProvider));
      ref.invalidate(cncListingProvider);
      if (card != null && mounted) widget.onChanged(card);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askText(String title, String key, {String? label}) =>
      showDialog<String>(
        context: context,
        builder: (_) => _TextAsk(title: title, fieldKey: key, label: label),
      );

  Future<void> _pay() async {
    final card = widget.card;
    final got = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _PayDialog(debt: card.debt),
    );
    if (got == null) return;
    await _do((r) => r.addPayment(card.name, got.$1, got.$2));
  }

  Future<void> _handOver() async {
    final card = widget.card;
    final got =
        await showDialog<({String? by, String? phone, String? comment})>(
          context: context,
          builder: (_) => _HandOverDialog(debt: card.debt),
        );
    if (got == null) return;
    await _do(
      (r) => r.handOver(
        card.name,
        takenBy: got.by,
        takenPhone: got.phone,
        comment: got.comment,
      ),
    );
  }

  /// «Готово — напишите клиенту»: WhatsApp with the words already typed.
  Future<void> _tell() async {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final card = widget.card;
    final text = card.debt > 0
        ? l10n.cncReadyMessageDebt(card.name, money.format(card.debt))
        : l10n.cncReadyMessage(card.name);
    final ok = await ContactActions.whatsAppMessage(card.phone, text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showFailureMessage(l10n.cncNoPhone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final c = widget.card;
    final open =
        c.status != CncStatus.cancelled && c.status != CncStatus.handedOver;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadableWidth(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                key: const ValueKey('cncCardStatus'),
                label: cncStatusLabel(c.status, l10n),
                intent: cncStatusIntent(c.status),
              ),
              if (c.urgent)
                StatusChip(label: l10n.cncUrgent, intent: StatusIntent.danger),
              if (c.place case final p?)
                Text(
                  [
                    l10n.cncEta(mdfDay(p.eta, year: false)),
                    if (!p.onMachine && p.minutesAhead > 0)
                      l10n.cncAhead(cncMinutes(p.minutesAhead, l10n)),
                  ].join(' · '),
                  key: const ValueKey('cncCardEta'),
                ),
              Text(l10n.cncDue(mdfDay(c.deliveryDate, year: false))),
              if (c.holdReason case final h?)
                Text(
                  l10n.cncHolding(h),
                  style: TextStyle(color: context.statusColors.warning),
                ),
            ],
          ),
        ),
        if (c.intake.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.cncIntake)),
          for (final i in c.intake)
            ReadableWidth(
              child: Text(
                [
                  '${i.what} — ${filmMetres(i.qty)} ${i.unit}',
                  if (i.defects case final d?) l10n.cncDefects(d),
                ].join(' · '),
              ),
            ),
          if (c.terms)
            ReadableWidth(
              child: Text(
                l10n.cncTermsAgreed,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        ReadableWidth(child: SectionLabel(l10n.cncWork)),
        for (final l in c.lines)
          ReadableWidth(
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.title),
              subtitle: Text(
                [
                  [
                    filmMetres(l.qty),
                    l.unit ?? '',
                    '×',
                    money.format(l.rate),
                  ].join(' '),
                  if (l.minutes > 0) cncMinutes(l.minutes, l10n),
                  ?l.note,
                ].join(' · '),
              ),
              trailing: Text(money.format(l.amount)),
            ),
          ),
        for (final e in c.extras)
          ReadableWidth(
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.title),
              trailing: Text(money.format(e.amount)),
            ),
          ),
        ReadableWidth(
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.cncTotal, style: theme.textTheme.titleMedium),
              ),
              Text(money.format(c.total), style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        ReadableWidth(
          child: Text(
            [
              l10n.cncPaid(money.format(c.paid)),
              if (c.debt > 0) l10n.cncOwes(money.format(c.debt)),
            ].join(' · '),
            key: const ValueKey('cncCardMoney'),
            style: TextStyle(
              color: c.debt > 0 ? context.statusColors.danger : null,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (open)
          ReadableWidth(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (c.status == CncStatus.queued)
                  FilledButton.icon(
                    key: const ValueKey('cncStart'),
                    onPressed: _busy ? null : () => _do((r) => r.start(c.name)),
                    icon: const Icon(AppIcons.moveIn),
                    label: Text(l10n.cncStart),
                  ),
                if (c.status == CncStatus.queued ||
                    c.status == CncStatus.onMachine)
                  FilledButton.icon(
                    key: const ValueKey('cncReady'),
                    onPressed: _busy ? null : () => _do((r) => r.ready(c.name)),
                    icon: const Icon(AppIcons.check),
                    label: Text(l10n.cncReadyAction),
                  ),
                if (c.status == CncStatus.ready) ...[
                  FilledButton.icon(
                    key: const ValueKey('cncTell'),
                    onPressed: _tell,
                    icon: const Icon(AppIcons.whatsApp),
                    label: Text(l10n.cncTell),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('cncHandOver'),
                    onPressed: _busy ? null : _handOver,
                    icon: const Icon(AppIcons.moveOut),
                    label: Text(l10n.cncHandOver),
                  ),
                  TextButton(
                    key: const ValueKey('cncNotReady'),
                    onPressed: _busy
                        ? null
                        : () => _do((r) => r.ready(c.name, done: false)),
                    child: Text(l10n.cncNotReady),
                  ),
                ],
                OutlinedButton.icon(
                  key: const ValueKey('cncPay'),
                  onPressed: _busy ? null : _pay,
                  icon: const Icon(AppIcons.payroll),
                  label: Text(l10n.cncPay),
                ),
                if (c.status != CncStatus.ready)
                  TextButton(
                    key: const ValueKey('cncHold'),
                    onPressed: _busy
                        ? null
                        : () async {
                            if (c.holdReason != null) {
                              await _do((r) => r.hold(c.name, null));
                              return;
                            }
                            final why = await _askText(
                              l10n.cncHoldTitle,
                              'cncHoldReason',
                            );
                            if (why != null && why.trim().isNotEmpty) {
                              await _do((r) => r.hold(c.name, why.trim()));
                            }
                          },
                    child: Text(
                      c.holdReason != null ? l10n.cncUnhold : l10n.cncHold,
                    ),
                  ),
                TextButton(
                  key: const ValueKey('cncCancel'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final why = await _askText(
                            l10n.cncCancelTitle,
                            'cncCancelReason',
                          );
                          if (why != null && why.trim().isNotEmpty) {
                            await _do((r) => r.cancel(c.name, why.trim()));
                          }
                        },
                  child: Text(
                    l10n.cncCancel,
                    style: TextStyle(color: context.statusColors.danger),
                  ),
                ),
              ],
            ),
          ),
        if (c.status == CncStatus.handedOver)
          ReadableWidth(
            child: Text(
              l10n.cncHandedOverOn(
                mdfDay(c.handedOverOn),
                c.takenBy ?? c.customerName,
              ),
            ),
          ),
        if (c.payments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.cncPayments)),
          for (final p in c.payments)
            ReadableWidth(
              child: Text(
                [mdfDay(p.date), money.format(p.amount), ?p.method].join(' · '),
                style: TextStyle(
                  decoration: p.cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
        ],
        if (c.history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReadableWidth(child: SectionLabel(l10n.cncHistory)),
          for (final h in c.history)
            ReadableWidth(
              child: Text(
                '${h.at} · ${h.text}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _TextAsk extends StatefulWidget {
  const _TextAsk({required this.title, required this.fieldKey, this.label});

  final String title;
  final String fieldKey;
  final String? label;

  @override
  State<_TextAsk> createState() => _TextAskState();
}

class _TextAskState extends State<_TextAsk> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: ValueKey(widget.fieldKey),
        controller: _c,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: ValueKey('${widget.fieldKey}:ok'),
          onPressed: () => Navigator.of(context).pop(_c.text),
          child: Text(l10n.cncOk),
        ),
      ],
    );
  }
}

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.debt});

  final double debt;

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  late final _amount = TextEditingController(
    text: widget.debt > 0 ? widget.debt.toStringAsFixed(0) : '',
  );
  String _method = filmCash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final amount = filmNumber(_amount.text) ?? 0;
    return AlertDialog(
      title: Text(l10n.cncPay),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('cncPayAmount'),
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.cncAmount),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final m in [filmCash, filmTransfer, filmCard])
                ChoiceChip(
                  key: ValueKey('cncPayHow:$m'),
                  label: Text(filmMethodLabel(l10n, m)),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('cncPaySave'),
          onPressed: amount > 0
              ? () => Navigator.of(context).pop((amount, _method))
              : null,
          child: Text(l10n.cncOk),
        ),
      ],
    );
  }
}

class _HandOverDialog extends StatefulWidget {
  const _HandOverDialog({required this.debt});

  final double debt;

  @override
  State<_HandOverDialog> createState() => _HandOverDialogState();
}

class _HandOverDialogState extends State<_HandOverDialog> {
  final _by = TextEditingController();
  final _phone = TextEditingController();
  final _comment = TextEditingController();

  @override
  void dispose() {
    for (final c in [_by, _phone, _comment]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    return AlertDialog(
      title: Text(l10n.cncHandOver),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('cncTakenBy'),
            controller: _by,
            decoration: InputDecoration(labelText: l10n.cncTakenBy),
          ),
          TextField(
            key: const ValueKey('cncTakenPhone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: const [PhoneMaskFormatter()],
            decoration: InputDecoration(labelText: l10n.cncTakenPhone),
          ),
          if (widget.debt > 0)
            TextField(
              key: const ValueKey('cncHandOverComment'),
              controller: _comment,
              decoration: InputDecoration(
                labelText: l10n.cncDebtComment(money.format(widget.debt)),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('cncHandOverSave'),
          onPressed: () => Navigator.of(context).pop((
            by: _v(_by),
            phone: _v(_phone),
            comment: _v(_comment),
          )),
          child: Text(l10n.cncOk),
        ),
      ],
    );
  }
}
