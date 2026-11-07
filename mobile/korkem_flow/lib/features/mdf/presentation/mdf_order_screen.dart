import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/facade_prices/data/facade_price_repository.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/size_paste.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_print.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One MDF order, as one window — OnayBaza's card, compact.
///
/// A draft is a form: head, lines, Save, Accept. An accepted order is read,
/// with the stages ticked by the manager, the payments, and on hold /
/// cancel / hand over.
class MdfOrderScreen extends ConsumerWidget {
  const MdfOrderScreen({this.name, this.template, super.key});

  /// Null for a new order.
  final String? name;

  /// «Повторить заказ»: a new draft that starts as a copy of this one.
  final MdfOrder? template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (name == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mdfOrderNew)),
        body: _DraftForm(template: template),
      );
    }
    final order = ref.watch(mdfOrderProvider(name!));
    return Scaffold(
      appBar: AppBar(title: Text(name!)),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(mdfOrderProvider(name!)),
        ),
        data: (o) => o.isDraft
            ? _DraftForm(key: ValueKey('draft:${o.name}'), order: o)
            : _AcceptedView(order: o),
      ),
    );
  }
}

// --- the draft -------------------------------------------------------------

class _LineFields {
  _LineFields({
    String? h,
    String? w,
    String? q,
    this.milling,
    String? note,
    String? rate,
  }) : height = TextEditingController(text: h),
       width = TextEditingController(text: w),
       qty = TextEditingController(text: q ?? '1'),
       note = TextEditingController(text: note),
       rate = TextEditingController(text: rate);

  final TextEditingController height;
  final TextEditingController width;
  final TextEditingController qty;
  final TextEditingController note;
  final TextEditingController rate;
  String? milling;
  final heightFocus = FocusNode();

  MdfLineInput? input() {
    final h = int.tryParse(height.text.trim());
    final w = int.tryParse(width.text.trim());
    final q = int.tryParse(qty.text.trim());
    if (h == null || w == null || q == null || q < 1) return null;
    final r = double.tryParse(rate.text.trim().replaceAll(',', '.'));
    return MdfLineInput(
      heightMm: h,
      widthMm: w,
      qty: q,
      milling: milling,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      rate: r,
    );
  }

  _LineFields copy() => _LineFields(
    h: height.text,
    w: width.text,
    q: qty.text,
    milling: milling,
    note: note.text,
    rate: rate.text,
  );

  void dispose() {
    for (final c in [height, width, qty, note, rate]) {
      c.dispose();
    }
    heightFocus.dispose();
  }
}

class _DraftForm extends ConsumerStatefulWidget {
  const _DraftForm({
    this.order,
    this.template,
    this.onChanged,
    super.key,
  });

  /// The draft being changed; null for a new one.
  final MdfOrder? order;

  /// For a new draft: the order it repeats (customer, head and lines).
  final MdfOrder? template;

  /// Set when [order] is accepted and being changed: Save asks for the
  /// reason and changes the order in place; called with the changed card.
  final ValueChanged<MdfOrder>? onChanged;

  bool get changing => onChanged != null;

  @override
  ConsumerState<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends ConsumerState<_DraftForm> {
  FacadeCustomer? _customer;
  DateTime? _due;
  late MdfHead _head =
      widget.order?.head ?? widget.template?.head ?? const MdfHead();
  final _extra = TextEditingController();
  final _defaultRate = TextEditingController();
  final List<_LineFields> _lines = [];
  MdfPricing _pricing = MdfPricing.empty;
  Timer? _debounce;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order ?? widget.template;
    if (o != null) {
      _customer = FacadeCustomer(
        name: o.customer,
        title: o.customerName,
        phone: o.phone,
      );
      if (widget.order != null) _due = DateTime.tryParse(o.deliveryDate);
      _extra.text = o.head.extraName ?? '';
      _defaultRate.text = o.head.defaultRate?.toStringAsFixed(0) ?? '';
      for (final l in o.lines) {
        _lines.add(
          _LineFields(
            h: '${l.heightMm}',
            w: '${l.widthMm}',
            q: '${l.qty}',
            milling: l.milling,
            note: l.note,
            rate: l.manualRate ? l.rateM2.toStringAsFixed(0) : null,
          ),
        );
      }
    }
    if (_lines.isEmpty) _lines.add(_LineFields(milling: _head.milling));
    if (o == null) unawaited(_startFromLastHead());
    _reprice();
  }

  /// A new order starts with the head of the last one this manager wrote:
  /// the same finish, thickness and edge more often than not.
  Future<void> _startFromLastHead() async {
    try {
      final head = await ref.read(mdfOrderRepositoryProvider).lastHead();
      if (!mounted || head == null) return;
      setState(() {
        _head = head;
        if (_defaultRate.text.isEmpty) {
          _defaultRate.text = head.defaultRate?.toStringAsFixed(0) ?? '';
        }
        for (final l in _lines) {
          l.milling ??= head.milling;
        }
      });
      _reprice();
    } on Object {
      // A blank head is a fine start too.
    }
  }

  Future<void> _paste() async {
    final l10n = AppLocalizations.of(context);
    final pasted = await showDialog<SizePaste>(
      context: context,
      builder: (_) => _PasteDialog(milling: _head.milling),
    );
    if (pasted == null || pasted.lines.isEmpty) return;
    setState(() {
      if (_lines.length == 1 && _lines.first.input() == null) {
        _lines.removeAt(0).dispose();
      }
      for (final l in pasted.lines) {
        _lines.add(
          _LineFields(
            h: '${l.heightMm}',
            w: '${l.widthMm}',
            q: '${l.qty}',
            milling: l.milling,
            note: l.note,
          ),
        );
      }
    });
    _reprice();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showDone(l10n.mdfPasted(pasted.lines.length));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_extra, _defaultRate]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  MdfHead _readHead() => MdfHead(
    thicknessMm: _head.thicknessMm,
    finish: _head.finish,
    decorTop: _head.decorTop,
    decorBottom: _head.decorBottom,
    patina: _head.patina,
    milling: _head.milling,
    edgeProfile: _head.edgeProfile,
    extraName: _extra.text.trim().isEmpty ? null : _extra.text.trim(),
    defaultRate: double.tryParse(_defaultRate.text.trim()),
  );

  List<MdfLineInput> get _inputs => [
    for (final l in _lines) ?l.input(),
  ];

  /// Instant arithmetic: the server prices, the screen shows.
  void _reprice() {
    _debounce?.cancel();
    _debounce = Timer(AppDebounce.search, () async {
      final inputs = _inputs;
      if (inputs.isEmpty) {
        if (mounted) setState(() => _pricing = MdfPricing.empty);
        return;
      }
      try {
        final head = _readHead();
        final pricing = await ref
            .read(mdfOrderRepositoryProvider)
            .price(
              lines: inputs,
              finish: head.finish,
              defaultRate: head.defaultRate,
            );
        if (mounted) setState(() => _pricing = pricing);
      } on Object {
        // The figures stay as they were; Save reports the real error.
      }
    });
  }

  void _addLine({_LineFields? from}) {
    final line = from?.copy() ?? _LineFields(milling: _head.milling);
    setState(() => _lines.add(line));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => line.heightFocus.requestFocus(),
    );
  }

  void _removeLine(int i) {
    setState(() {
      _lines.removeAt(i).dispose();
      if (_lines.isEmpty) _lines.add(_LineFields(milling: _head.milling));
    });
    _reprice();
  }

  void _move(int i, int by) {
    final j = i + by;
    if (j < 0 || j >= _lines.length) return;
    setState(() {
      final line = _lines.removeAt(i);
      _lines.insert(j, line);
    });
  }

  Future<MdfOrder?> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_customer == null || _due == null) {
      messenger.showFailureMessage(l10n.mdfNeedCustomer);
      return null;
    }
    if (_inputs.isEmpty) {
      messenger.showFailureMessage(l10n.mdfNeedLine);
      return null;
    }
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(mdfOrderRepositoryProvider)
          .saveDraft(
            customer: _customer!.name,
            deliveryDate: _due!.toIso8601String().substring(0, 10),
            head: _readHead(),
            lines: _inputs,
            order: widget.order?.name,
          );
      messenger.showDone(l10n.mdfSaved);
      return saved;
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// «Сохранить изменения» on an accepted order: the reason first, then
  /// the change; the payments stay as they are.
  Future<void> _saveChange() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_inputs.isEmpty) {
      messenger.showFailureMessage(l10n.mdfNeedLine);
      return;
    }
    final reason = await showReasonDialog(
      context,
      title: l10n.mdfChangeOrder,
      label: l10n.mdfChangeReason,
      confirm: l10n.mdfConfirm,
      cancel: l10n.mdfCancel,
      fieldKey: const ValueKey('mdfChangeReasonField'),
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      final changed = await ref
          .read(mdfOrderRepositoryProvider)
          .changeOrder(
            widget.order!.name,
            lines: _inputs,
            reason: reason,
            head: _readHead(),
            deliveryDate: _due?.toIso8601String().substring(0, 10),
          );
      messenger.showDone(l10n.mdfChanged);
      widget.onChanged!(changed);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndShow({bool accept = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final saved = await _save();
    if (saved == null) return;
    var shown = saved;
    if (accept) {
      try {
        shown = await ref.read(mdfOrderRepositoryProvider).accept(saved.name);
        messenger.showDone(l10n.mdfAccepted);
      } on Object catch (error) {
        messenger.showFailure(error, l10n);
      }
    }
    ref.invalidate(mdfOrderProvider(shown.name));
    if (widget.order == null) {
      unawaited(router.replace<void>(Routes.mdfOrder(shown.name)));
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(mdfOrderRepositoryProvider)
          .deleteDraft(widget.order!.name);
      router.pop();
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final dicts =
        ref.watch(mdfDictionariesProvider).value ?? MdfDictionaries.empty;
    final millings = dicts.values(MdfDictKind.milling);
    // The thickness is a number on the order; the list says «16 мм».
    final thicknesses = dicts.values(MdfDictKind.thickness);
    final thickness = _head.thicknessMm == null
        ? null
        : thicknesses.firstWhere(
            (v) => thicknessOf(v) == _head.thicknessMm,
            orElse: () => '${_head.thicknessMm}',
          );

    void choose(ValueChanged<String?> set, String? v) {
      setState(() => set(v));
      _reprice();
    }

    Widget pick(
      String key,
      String label,
      MdfDictKind kind,
      String? current,
      ValueChanged<String?> set, {
      double width = AppSpacing.xxxl * 5,
    }) {
      final choices = mdfChoices(dicts.values(kind), current);
      return SizedBox(
        width: width,
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey('$key:${choices.length}'),
                initialValue: current,
                isExpanded: true,
                items: [
                  DropdownMenuItem(child: Text(l10n.mdfNone)),
                  for (final v in choices)
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) => choose(set, v),
                decoration: InputDecoration(labelText: label, isDense: true),
              ),
            ),
            IconButton(
              key: ValueKey('dict:${kind.name}'),
              tooltip: l10n.mdfDictOpen,
              icon: const Icon(AppIcons.dictionary),
              onPressed: () async {
                final picked = await showMdfDictionary(
                  context,
                  kind,
                  title: label,
                  current: current,
                );
                if (picked != null && mounted) choose(set, picked);
              },
            ),
          ],
        ),
      );
    }

    Widget text(
      String key,
      String label,
      TextEditingController c, {
      bool digits = false,
      double width = 160,
    }) => SizedBox(
      width: width,
      child: TextField(
        key: ValueKey(key),
        controller: c,
        keyboardType: digits ? TextInputType.number : TextInputType.text,
        inputFormatters: digits
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (_) => _reprice(),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: AppSpacing.xxxl * 6,
                    child: _CustomerField(
                      initial: _customer,
                      onPicked: (c) => setState(() => _customer = c),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('mdfDue'),
                    onPressed: _pickDue,
                    icon: const Icon(AppIcons.schedule),
                    label: Text(
                      _due == null
                          ? l10n.mdfDue
                          : '${l10n.mdfDue}: '
                                '${_due!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionLabel(l10n.mdfHeadSection),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  pick(
                    'mdfThickness',
                    l10n.mdfThickness,
                    MdfDictKind.thickness,
                    thickness,
                    (v) => _head = _copyHead(thicknessMm: thicknessOf(v)),
                  ),
                  pick(
                    'mdfFinish',
                    l10n.mdfFinish,
                    MdfDictKind.finish,
                    _head.finish,
                    (v) => _head = _copyHead(finish: v),
                  ),
                  pick(
                    'mdfDecorTop',
                    l10n.mdfDecorTop,
                    MdfDictKind.decor,
                    _head.decorTop,
                    (v) => _head = _copyHead(decorTop: v),
                  ),
                  pick(
                    'mdfDecorBottom',
                    l10n.mdfDecorBottom,
                    MdfDictKind.decor,
                    _head.decorBottom,
                    (v) => _head = _copyHead(decorBottom: v),
                  ),
                  pick(
                    'mdfMilling',
                    l10n.mdfMilling,
                    MdfDictKind.milling,
                    _head.milling,
                    (v) => _head = _copyHead(milling: v),
                  ),
                  pick(
                    'mdfEdge',
                    l10n.mdfEdge,
                    MdfDictKind.edge,
                    _head.edgeProfile,
                    (v) => _head = _copyHead(edgeProfile: v),
                  ),
                  pick(
                    'mdfPatina',
                    l10n.mdfPatina,
                    MdfDictKind.patina,
                    _head.patina,
                    (v) => _head = _copyHead(patina: v),
                  ),
                  text('mdfExtra', l10n.mdfExtraName, _extra),
                  text(
                    'mdfDefaultRate',
                    l10n.mdfDefaultRate,
                    _defaultRate,
                    digits: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: SectionLabel(l10n.mdfLinesSection)),
                  TextButton.icon(
                    key: const ValueKey('mdfPaste'),
                    onPressed: _paste,
                    icon: const Icon(AppIcons.paste),
                    label: Text(l10n.mdfPasteSizes),
                  ),
                ],
              ),
              for (var i = 0; i < _lines.length; i++)
                _LineRow(
                  key: ObjectKey(_lines[i]),
                  index: i,
                  line: _lines[i],
                  priced: i < _pricing.lines.length ? _pricing.lines[i] : null,
                  millings: millings,
                  isLast: i == _lines.length - 1,
                  onChanged: _reprice,
                  onNext: _addLine,
                  onDuplicate: () => _addLine(from: _lines[i]),
                  onDelete: () => _removeLine(i),
                  onUp: () => _move(i, -1),
                  onDown: () => _move(i, 1),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('mdfAddLine'),
                  onPressed: _addLine,
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.mdfAddLine),
                ),
              ),
            ],
          ),
        ),
        Material(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.mdfTotals(
                    '${_pricing.pieces}',
                    _pricing.areaM2.toStringAsFixed(2),
                    money.format(_pricing.total),
                  ),
                  key: const ValueKey('mdfTotals'),
                  style: theme.textTheme.titleMedium,
                ),
                if (widget.changing)
                  FilledButton(
                    key: const ValueKey('mdfSaveChange'),
                    onPressed: _busy ? null : _saveChange,
                    child: Text(l10n.mdfSaveChange),
                  )
                else ...[
                  if (widget.order != null)
                    TextButton(
                      key: const ValueKey('mdfDelete'),
                      onPressed: _busy ? null : _delete,
                      child: Text(l10n.mdfDeleteDraft),
                    ),
                  OutlinedButton(
                    key: const ValueKey('mdfSave'),
                    onPressed: _busy ? null : _saveAndShow,
                    child: Text(l10n.mdfSaveDraft),
                  ),
                  FilledButton(
                    key: const ValueKey('mdfAccept'),
                    onPressed: _busy ? null : () => _saveAndShow(accept: true),
                    child: Text(l10n.mdfAccept),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  MdfHead _copyHead({
    Object? thicknessMm = _keep,
    Object? patina = _keep,
    Object? finish = _keep,
    Object? decorTop = _keep,
    Object? decorBottom = _keep,
    Object? milling = _keep,
    Object? edgeProfile = _keep,
  }) => MdfHead(
    thicknessMm: thicknessMm == _keep ? _head.thicknessMm : thicknessMm as int?,
    finish: finish == _keep ? _head.finish : finish as String?,
    decorTop: decorTop == _keep ? _head.decorTop : decorTop as String?,
    decorBottom: decorBottom == _keep
        ? _head.decorBottom
        : decorBottom as String?,
    patina: patina == _keep ? _head.patina : patina as String?,
    milling: milling == _keep ? _head.milling : milling as String?,
    edgeProfile: edgeProfile == _keep
        ? _head.edgeProfile
        : edgeProfile as String?,
    extraName: _head.extraName,
    defaultRate: _head.defaultRate,
  );
}

const _keep = Object();

/// One line, typed like a spreadsheet row: Enter moves on, Enter on the last
/// field of the last row starts a new one.
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.index,
    required this.line,
    required this.priced,
    required this.millings,
    required this.isLast,
    required this.onChanged,
    required this.onNext,
    required this.onDuplicate,
    required this.onDelete,
    required this.onUp,
    required this.onDown,
    super.key,
  });

  final int index;
  final _LineFields line;
  final MdfLine? priced;
  final List<String> millings;
  final bool isLast;
  final VoidCallback onChanged;
  final VoidCallback onNext;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);

    Widget cell(
      String key,
      String label,
      TextEditingController c,
      double width, {
      bool digits = true,
      FocusNode? focus,
      bool last = false,
    }) => SizedBox(
      width: width,
      child: TextField(
        key: ValueKey('$key:$index'),
        controller: c,
        focusNode: focus,
        keyboardType: digits ? TextInputType.number : TextInputType.text,
        inputFormatters: digits
            ? [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))]
            : null,
        textInputAction: last && isLast
            ? TextInputAction.done
            : TextInputAction.next,
        onSubmitted: last && isLast ? (_) => onNext() : null,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );

    final p = priced;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: AppSpacing.xl, child: Text('${index + 1}')),
          cell(
            'mdfH',
            l10n.mdfHeight,
            line.height,
            80,
            focus: line.heightFocus,
          ),
          cell('mdfW', l10n.mdfWidth, line.width, 80),
          cell('mdfQ', l10n.mdfQty, line.qty, 56),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('mdfLineMilling:$index'),
              initialValue: line.milling,
              isExpanded: true,
              items: [
                DropdownMenuItem(child: Text(l10n.mdfNone)),
                for (final m in mdfChoices(millings, line.milling))
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) {
                line.milling = v;
                onChanged();
              },
              decoration: InputDecoration(
                labelText: l10n.mdfMilling,
                isDense: true,
              ),
            ),
          ),
          cell('mdfNote', l10n.mdfNote, line.note, 140, digits: false),
          cell('mdfRate', l10n.mdfRate, line.rate, 90, last: true),
          SizedBox(
            width: 150,
            child: p == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.areaM2.toStringAsFixed(2)} ${l10n.mdfArea}'
                        ' · ${money.format(p.amount)}',
                        key: ValueKey('mdfLineAmount:$index'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (p.noPrice)
                        StatusChip(
                          key: ValueKey('mdfNoPrice:$index'),
                          label: l10n.mdfNoPrice,
                          intent: StatusIntent.warning,
                          compact: true,
                        )
                      else if (p.manualRate)
                        Text(
                          l10n.mdfManualRate,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
          ),
          IconButton(
            tooltip: l10n.mdfLineDuplicate,
            onPressed: onDuplicate,
            icon: const Icon(AppIcons.share),
          ),
          IconButton(onPressed: onUp, icon: const Icon(AppIcons.back)),
          IconButton(onPressed: onDown, icon: const Icon(AppIcons.down)),
          IconButton(
            key: ValueKey('mdfLineDelete:$index'),
            tooltip: l10n.mdfLineDelete,
            onPressed: onDelete,
            icon: const Icon(AppIcons.delete),
          ),
        ],
      ),
    );
  }
}

class _CustomerField extends ConsumerWidget {
  const _CustomerField({required this.initial, required this.onPicked});

  final FacadeCustomer? initial;
  final ValueChanged<FacadeCustomer> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Autocomplete<FacadeCustomer>(
      key: const ValueKey('mdfCustomer'),
      initialValue: TextEditingValue(text: initial?.title ?? ''),
      displayStringForOption: (c) => c.name.isEmpty
          ? l10n.mdfNewCustomerOption(c.title)
          : c.phone == null
          ? c.title
          : '${c.title} · ${c.phone}',
      optionsBuilder: (value) async {
        final text = value.text.trim();
        if (text.length < 2) return const [];
        var found = <FacadeCustomer>[];
        try {
          found = await ref
              .read(facadePriceRepositoryProvider)
              .customers(search: text);
        } on Object {
          // Offer to write a new one all the same.
        }
        // The last option writes the typed name down as a new customer.
        return [...found, FacadeCustomer(name: '', title: text)];
      },
      onSelected: (c) async {
        if (c.name.isNotEmpty) {
          onPicked(c);
          return;
        }
        final made = await showDialog<FacadeCustomer>(
          context: context,
          builder: (_) => _NewCustomerDialog(typed: c.title),
        );
        if (made != null) onPicked(made);
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        key: const ValueKey('mdfCustomerField'),
        controller: controller,
        focusNode: focus,
        decoration: InputDecoration(labelText: l10n.mdfCustomer, isDense: true),
      ),
    );
  }
}

// --- the accepted order ----------------------------------------------------

class _AcceptedView extends ConsumerStatefulWidget {
  const _AcceptedView({required this.order});

  final MdfOrder order;

  @override
  ConsumerState<_AcceptedView> createState() => _AcceptedViewState();
}

class _AcceptedViewState extends ConsumerState<_AcceptedView> {
  bool _busy = false;
  bool _editing = false;

  MdfOrder get o => widget.order;

  Future<void> _run(Future<MdfOrder> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(mdfOrderProvider(o.name));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, String label, AppLocalizations l10n) =>
      showReasonDialog(
        context,
        title: title,
        label: label,
        confirm: l10n.mdfConfirm,
        cancel: l10n.mdfCancel,
        fieldKey: const ValueKey('mdfReason'),
      );

  Future<void> _payment() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (_) => const _PaymentDialog(),
    );
    if (result == null) return;
    await _run(() async {
      await ref
          .read(mdfOrderRepositoryProvider)
          .addPayment(o.name, amount: result.$1, method: result.$2);
      return o;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showDone(l10n.mdfSaved);
  }

  Future<void> _print({required bool withPrices}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final words = mdfPrintWords(l10n);
    try {
      await printMdfOrder(
        name: o.name,
        build: () => buildMdfOrderPdf(
          o,
          words,
          withPrices: withPrices,
          locale: locale,
        ),
      );
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return _DraftForm(
        key: ValueKey('change:${o.name}'),
        order: o,
        onChanged: (_) {
          setState(() => _editing = false);
          ref.invalidate(mdfOrderProvider(o.name));
        },
      );
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final repo = ref.read(mdfOrderRepositoryProvider);
    final (status, intent) = mdfStatusChip(o.status, l10n);
    final open =
        o.status != MdfStatus.cancelled && o.status != MdfStatus.handedOver;
    final h = o.head;
    final headLine = [
      if (h.thicknessMm != null) '${h.thicknessMm} мм',
      h.finish,
      h.decorTop,
      if (h.decorBottom != null) '/ ${h.decorBottom}',
      h.milling,
      h.edgeProfile,
      h.patina,
      h.extraName,
    ].whereType<String>().join(' · ');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(o.customerName, style: theme.textTheme.titleLarge),
            StatusChip(label: status, intent: intent),
            if (o.overdue)
              StatusChip(label: l10n.mdfOverdue, intent: StatusIntent.danger),
          ],
        ),
        Text(
          [
            o.phone,
            '${o.createdOn} → ${o.deliveryDate}',
          ].whereType<String>().join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (o.holdReason != null)
          Text(
            '${l10n.mdfStatusOnHold}: ${o.holdReason}',
            style: theme.textTheme.bodyMedium,
          ),
        if (headLine.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(headLine),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.mdfTotals(
            '${o.pieces}',
            o.areaM2.toStringAsFixed(2),
            money.format(o.total),
          ),
          style: theme.textTheme.titleMedium,
        ),
        Text(
          l10n.mdfPaidDebt(money.format(o.paid), money.format(o.debt)),
          key: const ValueKey('mdfPaidDebt'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: o.debt > 0 ? theme.colorScheme.error : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('mdfPrintClient'),
              onPressed: () => _print(withPrices: true),
              icon: const Icon(AppIcons.print),
              label: Text(l10n.mdfPrintClient),
            ),
            OutlinedButton.icon(
              key: const ValueKey('mdfRepeat'),
              onPressed: () => context.push(Routes.mdfOrderNew, extra: o),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.mdfRepeat),
            ),
            OutlinedButton.icon(
              key: const ValueKey('mdfPrintShop'),
              onPressed: () => _print(withPrices: false),
              icon: const Icon(AppIcons.print),
              label: Text(l10n.mdfPrintShop),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.mdfStagesSection),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final MapEntry(key: stage, value: doneOn) in o.stages.entries)
              FilterChip(
                key: ValueKey('mdfStage:${stage.name}'),
                label: Text(
                  [
                    mdfStageLabel(stage, l10n),
                    ?doneOn,
                    ?o.stageWorkers[stage],
                  ].join(' · '),
                ),
                selected: doneOn != null,
                onSelected: !open || _busy || o.status == MdfStatus.onHold
                    ? null
                    : (v) => _run(() => repo.setStage(o.name, stage, done: v)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.mdfLinesSection),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('№')),
              DataColumn(label: Text(l10n.mdfMilling)),
              DataColumn(label: Text(l10n.mdfHeight), numeric: true),
              DataColumn(label: Text(l10n.mdfWidth), numeric: true),
              DataColumn(label: Text(l10n.mdfQty), numeric: true),
              DataColumn(label: Text(l10n.mdfArea), numeric: true),
              DataColumn(label: Text(l10n.mdfRate), numeric: true),
              DataColumn(label: Text(l10n.mdfAmount), numeric: true),
            ],
            rows: [
              for (var i = 0; i < o.lines.length; i++)
                DataRow(
                  cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(
                      Text(
                        [
                          o.lines[i].milling,
                          o.lines[i].note,
                        ].whereType<String>().join(' · '),
                      ),
                    ),
                    DataCell(Text('${o.lines[i].heightMm}')),
                    DataCell(Text('${o.lines[i].widthMm}')),
                    DataCell(Text('${o.lines[i].qty}')),
                    DataCell(Text(o.lines[i].areaM2.toStringAsFixed(2))),
                    DataCell(
                      Text(
                        o.lines[i].noPrice
                            ? l10n.mdfNoPrice
                            : money.format(o.lines[i].rateM2),
                      ),
                    ),
                    DataCell(Text(money.format(o.lines[i].amount))),
                  ],
                ),
            ],
          ),
        ),
        if (open)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('mdfChangeOrder'),
              onPressed: _busy ? null : () => setState(() => _editing = true),
              icon: const Icon(AppIcons.edit),
              label: Text(l10n.mdfChangeOrder),
            ),
          ),
        if (o.history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.mdfHistorySection),
          for (final h in o.history)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(h.text),
              subtitle: Text('${h.at} · ${h.by}'),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.mdfPaymentsSection),
        if (o.payments.isEmpty)
          Text(l10n.mdfNoPayments, style: theme.textTheme.bodySmall),
        for (final p in o.payments)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(money.format(p.amount)),
            subtitle: Text([p.date, p.method].whereType<String>().join(' · ')),
          ),
        if (open)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('mdfAddPayment'),
              onPressed: _busy ? null : _payment,
              icon: const Icon(AppIcons.add),
              label: Text(l10n.mdfAddPayment),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        if (open)
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              if (o.status == MdfStatus.ready)
                FilledButton(
                  key: const ValueKey('mdfHandOver'),
                  onPressed: _busy
                      ? null
                      : () async {
                          String? comment;
                          if (o.debt > 0) {
                            comment = await _ask(
                              l10n.mdfHandOver,
                              l10n.mdfHandOverComment,
                              l10n,
                            );
                            if (comment == null) return;
                          }
                          await _run(
                            () => repo.handOver(o.name, comment: comment),
                          );
                        },
                  child: Text(l10n.mdfHandOver),
                ),
              OutlinedButton(
                key: const ValueKey('mdfHold'),
                onPressed: _busy
                    ? null
                    : () async {
                        if (o.status == MdfStatus.onHold) {
                          await _run(() => repo.hold(o.name, null));
                          return;
                        }
                        final reason = await _ask(
                          l10n.mdfHold,
                          l10n.mdfHoldReason,
                          l10n,
                        );
                        if (reason != null) {
                          await _run(() => repo.hold(o.name, reason));
                        }
                      },
                child: Text(
                  o.status == MdfStatus.onHold ? l10n.mdfResume : l10n.mdfHold,
                ),
              ),
              TextButton(
                key: const ValueKey('mdfCancelOrder'),
                onPressed: _busy
                    ? null
                    : () async {
                        final reason = await _ask(
                          l10n.mdfCancelOrder,
                          l10n.mdfCancelReason,
                          l10n,
                        );
                        if (reason != null) {
                          await _run(() => repo.cancel(o.name, reason));
                        }
                      },
                child: Text(l10n.mdfCancelOrder),
              ),
            ],
          ),
      ],
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog();

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  static const _methods = ['Kaspi', 'Наличные', 'Перевод', 'Карта'];
  final _amount = TextEditingController();
  String _method = _methods.first;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mdfAddPayment),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('mdfPaymentAmount'),
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.mdfPaymentAmount),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const ValueKey('mdfPaymentMethod'),
            initialValue: _method,
            items: [
              for (final m in _methods)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() => _method = v ?? _method),
            decoration: InputDecoration(labelText: l10n.mdfPaymentMethod),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfPaymentSave'),
          onPressed: () {
            final amount = double.tryParse(_amount.text.trim());
            if (amount == null || amount <= 0) return;
            Navigator.of(context).pop((amount, _method));
          },
          child: Text(l10n.mdfConfirm),
        ),
      ],
    );
  }
}

/// The printed order's words, from the reader's language.
MdfPrintWords mdfPrintWords(AppLocalizations l10n) => (
  title: l10n.mdfPrintTitle,
  accepted: l10n.mdfPrintAccepted,
  due: l10n.mdfDue,
  customer: l10n.mdfCustomer,
  phone: l10n.mdfPrintPhone,
  thickness: l10n.mdfThickness,
  finish: l10n.mdfFinish,
  decorTop: l10n.mdfDecorTop,
  decorBottom: l10n.mdfDecorBottom,
  patina: l10n.mdfPatina,
  milling: l10n.mdfMilling,
  edge: l10n.mdfEdge,
  extraName: l10n.mdfExtraName,
  paid: l10n.mdfPrintPaid,
  debt: l10n.mdfPrintDebt,
  note: l10n.mdfNote,
  height: l10n.mdfHeight,
  width: l10n.mdfWidth,
  qty: l10n.mdfQty,
  area: l10n.mdfArea,
  rate: l10n.mdfRate,
  amount: l10n.mdfAmount,
  total: l10n.mdfPrintTotal,
);

class _PasteDialog extends StatefulWidget {
  const _PasteDialog({this.milling});

  final String? milling;

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _text = TextEditingController();
  SizePaste _parsed = (lines: const [], skipped: const []);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.mdfPasteSizes),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.mdfPasteHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('mdfPasteText'),
              controller: _text,
              autofocus: true,
              minLines: 6,
              maxLines: 14,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (v) => setState(
                () => _parsed = parseSizes(v, milling: widget.milling),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.mdfPasteFound(_parsed.lines.length),
              key: const ValueKey('mdfPasteFound'),
              style: theme.textTheme.titleSmall,
            ),
            if (_parsed.skipped.isNotEmpty)
              Text(
                l10n.mdfPasteSkipped(_parsed.skipped.take(3).join(' · ')),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfPasteAdd'),
          onPressed: _parsed.lines.isEmpty
              ? null
              : () => Navigator.of(context).pop(_parsed),
          child: Text(l10n.mdfPasteAdd),
        ),
      ],
    );
  }
}

class _NewCustomerDialog extends ConsumerStatefulWidget {
  const _NewCustomerDialog({required this.typed});

  final String typed;

  @override
  ConsumerState<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends ConsumerState<_NewCustomerDialog> {
  late final bool _typedPhone = RegExp(
    r'^[+\d\s()-]{6,}$',
  ).hasMatch(widget.typed);
  late final _name = TextEditingController(
    text: _typedPhone ? '' : widget.typed,
  );
  late final _phone = TextEditingController(
    text: _typedPhone ? widget.typed : '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final made = await ref
          .read(mdfOrderRepositoryProvider)
          .newCustomer(
            _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      navigator.pop(made);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mdfNewCustomer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('mdfNewCustomerName'),
            controller: _name,
            autofocus: !_typedPhone,
            decoration: InputDecoration(labelText: l10n.mdfCustomer),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('mdfNewCustomerPhone'),
            controller: _phone,
            autofocus: _typedPhone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.mdfPrintPhone),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfNewCustomerSave'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.mdfConfirm),
        ),
      ],
    );
  }
}
