import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
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
import 'package:korkem_flow/features/mdf/presentation/mdf_customers_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_print.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tags_view.dart';
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

/// What «+ доп.» adds under a row; each shows as a chip with ✕.
enum _Extra { back, patina, note }

class _LineFields {
  _LineFields({
    String? h,
    String? w,
    String? q,
    this.milling,
    String? note,
    String? rate,
    this.film,
    this.filmBack,
    this.material,
    this.edge = mdfDefaultEdge,
    this.patina,
    Set<_Extra>? extras,
  }) : height = TextEditingController(text: h),
       width = TextEditingController(text: w),
       qty = TextEditingController(text: q ?? '1'),
       note = TextEditingController(text: note),
       rate = TextEditingController(text: rate),
       extras =
           extras ??
           {
             if (filmBack != null) _Extra.back,
             if (patina != null) _Extra.patina,
             if (note != null && note.trim().isNotEmpty) _Extra.note,
           };

  final TextEditingController height;
  final TextEditingController width;
  final TextEditingController qty;
  final TextEditingController note;
  final TextEditingController rate;
  String? milling;

  /// The film group it is in.
  String? film;

  /// Its back film; null — one-sided.
  String? filmBack;

  /// Its own board; null — the order's.
  String? material;

  /// The radius of its edges; R3 unless the manager says, R0 a sharp corner.
  String? edge;
  String? patina;

  /// The extras shown under the row.
  final Set<_Extra> extras;
  final heightFocus = FocusNode();

  /// «✕» on an extra's chip: it goes, and so does its value.
  void drop(_Extra extra) {
    extras.remove(extra);
    switch (extra) {
      case _Extra.back:
        filmBack = null;
      case _Extra.patina:
        patina = null;
      case _Extra.note:
        note.clear();
    }
  }

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
      film: film,
      filmBack: filmBack,
      material: material,
      edge: edge,
      patina: patina,
    );
  }

  _LineFields copy() => _LineFields(
    h: height.text,
    w: width.text,
    q: qty.text,
    milling: milling,
    note: note.text,
    rate: rate.text,
    film: film,
    filmBack: filmBack,
    material: material,
    edge: edge,
    patina: patina,
    extras: {...extras},
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
      widget.order?.head ??
      _withoutTags(widget.template?.head) ??
      const MdfHead();
  final _extra = TextEditingController();
  final _defaultRate = TextEditingController();
  final List<_LineFields> _lines = [];

  /// The film groups, in the order they were added; null — no film chosen.
  final List<String?> _films = [];

  /// Each film group's price per m².
  final Map<String?, TextEditingController> _filmRates = {};
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
        tags: [for (final t in o.customerTags) t.wire],
      );
      if (widget.order != null) _due = DateTime.tryParse(o.deliveryDate);
      _extra.text = o.head.extraName ?? '';
      _defaultRate.text = o.head.defaultRate?.toStringAsFixed(0) ?? '';
      for (final e in o.head.filmRates.entries) {
        _rateOf(e.key).text = e.value.toStringAsFixed(0);
      }
      for (final l in o.lines) {
        if (!_films.contains(l.film)) _films.add(l.film);
        final groupRate = o.head.filmRates[l.film];
        _lines.add(
          _LineFields(
            h: '${l.heightMm}',
            w: '${l.widthMm}',
            q: '${l.qty}',
            milling: l.milling,
            note: l.note,
            rate: l.manualRate && l.rateM2 != groupRate
                ? l.rateM2.toStringAsFixed(0)
                : null,
            film: l.film,
            filmBack: l.filmBack,
            material: l.material == o.head.material ? null : l.material,
            edge: l.edge ?? o.head.edgeProfile ?? mdfDefaultEdge,
            patina: l.patina,
          ),
        );
      }
    }
    if (_films.isEmpty) _films.add(null);
    if (_lines.isEmpty) _lines.add(_blank(_films.first));
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
          if (l.input() == null) l.edge = _defaultEdge;
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
            film: _films.last,
            edge: _defaultEdge,
          ),
        );
      }
    });
    _reprice();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showDone(l10n.mdfPasted(pasted.lines.length));
  }

  /// The order's default radius: the head's, else R3.
  String get _defaultEdge => _head.edgeProfile ?? mdfDefaultEdge;

  _LineFields _blank(String? film) =>
      _LineFields(milling: _head.milling, film: film, edge: _defaultEdge);

  TextEditingController _rateOf(String? film) =>
      _filmRates[film] ??= TextEditingController();

  /// The lines as they are shown and sent: film group by film group.
  List<_LineFields> get _ordered => [
    for (final f in _films)
      for (final l in _lines)
        if (l.film == f) l,
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_extra, _defaultRate, ..._filmRates.values]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  MdfHead _readHead() => MdfHead(
    thicknessMm: thicknessOf(_head.material) ?? _head.thicknessMm,
    finish: _head.finish,
    // The first film stands for the order where one film is asked for.
    decorTop: _films.whereType<String>().firstOrNull ?? _head.decorTop,
    decorBottom: _head.decorBottom,
    // Patina is a position's now; an old order's head keeps its own.
    patina: _head.patina,
    milling: _head.milling,
    edgeProfile: _head.edgeProfile,
    extraName: _extra.text.trim().isEmpty ? null : _extra.text.trim(),
    defaultRate: double.tryParse(_defaultRate.text.trim()),
    material: _head.material,
    filmRates: {
      for (final e in _filmRates.entries)
        if (e.key != null &&
            _films.contains(e.key) &&
            double.tryParse(e.value.text.trim()) != null)
          e.key!: double.parse(e.value.text.trim()),
    },
    tags: _head.tags,
  );

  List<MdfLineInput> get _inputs => [
    for (final l in _ordered) ?l.input(),
  ];

  /// Where each shown line's figures are in the priced answer.
  Map<_LineFields, int> get _pricedIndex {
    final out = <_LineFields, int>{};
    var i = 0;
    for (final l in _ordered) {
      if (l.input() != null) out[l] = i++;
    }
    return out;
  }

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
              filmRates: head.filmRates,
            );
        if (mounted) setState(() => _pricing = pricing);
      } on Object {
        // The figures stay as they were; Save reports the real error.
      }
    });
  }

  void _addLine({_LineFields? from, String? film}) {
    final line = from?.copy() ?? _blank(film ?? _films.last);
    setState(() => _lines.add(line));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => line.heightFocus.requestFocus(),
    );
  }

  void _removeLine(_LineFields line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
      if (_lines.isEmpty) _lines.add(_blank(_films.first));
    });
    _reprice();
  }

  /// Up or down within its film group.
  void _move(_LineFields line, int by) {
    final mates = [
      for (final l in _lines)
        if (l.film == line.film) l,
    ];
    final j = mates.indexOf(line) + by;
    if (j < 0 || j >= mates.length) return;
    final other = mates[j];
    setState(() {
      final a = _lines.indexOf(line);
      final b = _lines.indexOf(other);
      _lines[a] = other;
      _lines[b] = line;
    });
    _reprice();
  }

  /// «+ Добавить покрытие»: a film from the list, and its first line.
  Future<void> _addFilm() async {
    final l10n = AppLocalizations.of(context);
    final film = await showMdfDictionary(
      context,
      MdfDictKind.decor,
      title: l10n.mdfFilmPick,
    );
    if (film == null || !mounted) return;
    if (_films.contains(film)) {
      _addLine(film: film);
      return;
    }
    setState(() {
      // A first group still without a film and without sizes takes it.
      final blank =
          _films.length == 1 &&
          _films.first == null &&
          _lines.every((l) => l.input() == null);
      if (blank) {
        _films[0] = film;
        for (final l in _lines) {
          l.film = film;
        }
      } else {
        _films.add(film);
        _lines.add(_blank(film));
      }
    });
    _reprice();
  }

  /// The group's film changed: its lines and its price go with it.
  void _renameFilm(String? from, String? to) {
    if (from == to) return;
    setState(() {
      if (_films.contains(to)) {
        _films.remove(from);
      } else {
        _films[_films.indexOf(from)] = to;
      }
      for (final l in _lines) {
        if (l.film == from) l.film = to;
      }
      final rate = _filmRates.remove(from);
      if (rate != null && !_filmRates.containsKey(to)) _filmRates[to] = rate;
    });
    _reprice();
  }

  Future<void> _removeFilm(String? film) async {
    final l10n = AppLocalizations.of(context);
    final mates = [
      for (final l in _lines)
        if (l.film == film) l,
    ];
    if (mates.any((l) => l.input() != null)) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.mdfFilmRemoveAsk(film ?? l10n.mdfNone)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('mdfFilmRemoveYes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.mdfDictDelete),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    setState(() {
      for (final l in mates) {
        _lines.remove(l);
        l.dispose();
      }
      _films.remove(film);
      _filmRates.remove(film)?.dispose();
      if (_films.isEmpty) _films.add(null);
      if (_lines.isEmpty) _lines.add(_blank(_films.first));
    });
    _reprice();
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

  /// «Только предоплата»: accepting without a payment asks first.
  Future<bool> _prepaidOrAsked() async {
    final customer = _customer;
    final paid = widget.order?.paid ?? 0;
    if (customer == null ||
        paid > 0 ||
        !customer.tags.contains(MdfCustomerTag.prepayOnly.wire)) {
      return true;
    }
    final l10n = AppLocalizations.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.mdfPrepayOnlyAsk(customer.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.mdfCancel),
          ),
          FilledButton(
            key: const ValueKey('mdfPrepayOnlyYes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mdfAccept),
          ),
        ],
      ),
    );
    return sure ?? false;
  }

  Future<void> _saveAndShow({bool accept = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (accept && !await _prepaidOrAsked()) return;
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
    final materials = dicts.values(MdfDictKind.material);
    final films = dicts.values(MdfDictKind.decor);
    final edges = mdfEdges(dicts.values(MdfDictKind.edge));
    final patinas = dicts.values(MdfDictKind.patina);
    final pricedIndex = _pricedIndex;
    MdfLine? pricedOf(_LineFields l) {
      final i = pricedIndex[l];
      return i != null && i < _pricing.lines.length ? _pricing.lines[i] : null;
    }

    var number = 0;

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
                      // A customer chosen from the list refills the field.
                      key: ValueKey('mdfCustomerOf:${_customer?.name}'),
                      initial: _customer,
                      onPicked: (c) => setState(() => _customer = c),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('dict:customer'),
                    tooltip: l10n.mdfCustomers,
                    icon: const Icon(AppIcons.dictionary),
                    onPressed: () async {
                      final picked = await showMdfCustomers(
                        context,
                        current: _customer?.name,
                      );
                      if (picked != null && mounted) {
                        setState(() => _customer = picked);
                      }
                    },
                  ),
                  if (_customer?.tags.isNotEmpty ?? false)
                    MdfTagBadges(
                      customerTags: MdfCustomerTag.parse(_customer!.tags),
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
                    'mdfMaterial',
                    l10n.mdfMaterial,
                    MdfDictKind.material,
                    _head.material,
                    (v) => _head = _copyHead(
                      material: v,
                      thicknessMm: thicknessOf(v) ?? _head.thicknessMm,
                    ),
                  ),
                  pick(
                    'mdfFinish',
                    l10n.mdfFinish,
                    MdfDictKind.finish,
                    _head.finish,
                    (v) => _head = _copyHead(finish: v),
                  ),
                  pick(
                    'mdfMilling',
                    l10n.mdfMilling,
                    MdfDictKind.milling,
                    _head.milling,
                    (v) => _head = _copyHead(milling: v),
                  ),
                  SizedBox(
                    width: AppSpacing.xxxl * 3,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('mdfEdge:${edges.length}'),
                      initialValue: _defaultEdge,
                      isExpanded: true,
                      items: [
                        for (final e in mdfChoices(edges, _defaultEdge))
                          DropdownMenuItem(value: e, child: Text(e)),
                      ],
                      onChanged: (v) => choose((next) {
                        final was = _defaultEdge;
                        _head = _copyHead(edgeProfile: next);
                        // Rows on the old default follow; changed ones stay.
                        for (final l in _lines) {
                          if (l.edge == was) l.edge = _defaultEdge;
                        }
                      }, v),
                      decoration: InputDecoration(
                        labelText: l10n.mdfEdgeDefault,
                        isDense: true,
                      ),
                    ),
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
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final t in MdfOrderTag.values)
                    FilterChip(
                      key: ValueKey('mdfOrderTag:${t.wire}'),
                      label: Text(mdfOrderTagLabel(t, l10n)),
                      selected: _head.tags.contains(t),
                      onSelected: (on) => setState(
                        () => _head = _copyHead(
                          tags: [
                            for (final x in MdfOrderTag.values)
                              if (x == t ? on : _head.tags.contains(x)) x,
                          ],
                        ),
                      ),
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
              for (var g = 0; g < _films.length; g++)
                () {
                  final film = _films[g];
                  final mates = [
                    for (final l in _lines)
                      if (l.film == film) l,
                  ];
                  final priced = [for (final l in mates) ?pricedOf(l)];
                  final first = number;
                  number += mates.length;
                  return _FilmGroup(
                    key: ValueKey('mdfFilmGroup:$g'),
                    index: g,
                    film: film,
                    films: films,
                    rate: _rateOf(film),
                    pieces: priced.fold(0, (sum, p) => sum + p.qty),
                    areaM2: priced.fold<double>(0, (sum, p) => sum + p.areaM2),
                    amount: priced.fold<double>(0, (sum, p) => sum + p.amount),
                    onFilm: (to) => _renameFilm(film, to),
                    onRateChanged: _reprice,
                    onRemove: () => _removeFilm(film),
                    onAddLine: () => _addLine(film: film),
                    children: [
                      for (var i = 0; i < mates.length; i++)
                        _LineRow(
                          key: ObjectKey(mates[i]),
                          index: first + i,
                          line: mates[i],
                          priced: pricedOf(mates[i]),
                          millings: millings,
                          materials: materials,
                          films: films,
                          edges: edges,
                          patinas: patinas,
                          defaultEdge: _defaultEdge,
                          headMaterial: _head.material,
                          groupRate: _rateOf(film).text.trim(),
                          isLast:
                              g == _films.length - 1 && i == mates.length - 1,
                          onChanged: () {
                            setState(() {});
                            _reprice();
                          },
                          onNext: () => _addLine(film: film),
                          onDuplicate: () => _addLine(from: mates[i]),
                          onDelete: () => _removeLine(mates[i]),
                          onUp: () => _move(mates[i], -1),
                          onDown: () => _move(mates[i], 1),
                        ),
                    ],
                  );
                }(),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('mdfAddFilm'),
                  onPressed: _addFilm,
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.mdfAddFilm),
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
    Object? material = _keep,
    Object? thicknessMm = _keep,
    Object? patina = _keep,
    Object? finish = _keep,
    Object? decorTop = _keep,
    Object? decorBottom = _keep,
    Object? milling = _keep,
    Object? edgeProfile = _keep,
    List<MdfOrderTag>? tags,
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
    material: material == _keep ? _head.material : material as String?,
    filmRates: _head.filmRates,
    tags: tags ?? _head.tags,
  );
}

const _keep = Object();

/// A repeated order starts as the old one, but not urgent and not a rework.
MdfHead? _withoutTags(MdfHead? h) => h == null
    ? null
    : MdfHead(
        thicknessMm: h.thicknessMm,
        finish: h.finish,
        decorTop: h.decorTop,
        decorBottom: h.decorBottom,
        patina: h.patina,
        milling: h.milling,
        edgeProfile: h.edgeProfile,
        extraName: h.extraName,
        defaultRate: h.defaultRate,
        material: h.material,
        filmRates: h.filmRates,
      );

/// One film's positions: a coloured header with the film, its price per m²
/// and its totals; the rows; «+ строка»; «Итого группы».
class _FilmGroup extends StatelessWidget {
  const _FilmGroup({
    required this.index,
    required this.film,
    required this.films,
    required this.rate,
    required this.pieces,
    required this.areaM2,
    required this.amount,
    required this.onFilm,
    required this.onRateChanged,
    required this.onRemove,
    required this.onAddLine,
    required this.children,
    super.key,
  });

  final int index;
  final String? film;
  final List<String> films;
  final TextEditingController rate;
  final int pieces;
  final double areaM2;
  final double amount;
  final ValueChanged<String?> onFilm;
  final VoidCallback onRateChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddLine;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final color = AppColors.filmGroup(index);
    final totals = l10n.mdfTotals(
      '$pieces',
      areaM2.toStringAsFixed(2),
      money.format(amount),
    );
    return Container(
      key: ValueKey('mdfFilm:${film ?? ''}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: AppSpacing.xs),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColoredBox(
            color: color.withValues(alpha: AppTint.surface),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: AppSpacing.md,
                    height: AppSpacing.md,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(
                    width: AppSpacing.xxxl * 5,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('mdfFilmPick:$index:${films.length}'),
                      initialValue: film,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(child: Text(l10n.mdfFilmNone)),
                        for (final f in mdfChoices(films, film))
                          DropdownMenuItem(value: f, child: Text(f)),
                      ],
                      onChanged: onFilm,
                      style: theme.textTheme.titleSmall?.copyWith(color: color),
                      decoration: InputDecoration(
                        labelText: l10n.mdfFilm,
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      key: ValueKey('mdfFilmRate:$index'),
                      controller: rate,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => onRateChanged(),
                      decoration: InputDecoration(
                        labelText: l10n.mdfFilmRate,
                        isDense: true,
                      ),
                    ),
                  ),
                  Text(
                    totals,
                    key: ValueKey('mdfFilmTotals:$index'),
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                  IconButton(
                    key: ValueKey('mdfFilmRemove:$index'),
                    tooltip: l10n.mdfFilmRemove,
                    onPressed: onRemove,
                    icon: const Icon(AppIcons.delete),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              0,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...children,
                Row(
                  children: [
                    TextButton.icon(
                      key: ValueKey('mdfAddLine:$index'),
                      onPressed: onAddLine,
                      icon: const Icon(AppIcons.add),
                      label: Text(l10n.mdfAddLine),
                    ),
                    const Spacer(),
                    Text(
                      '${l10n.mdfFilmSubtotal}: $totals',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line, typed like a spreadsheet row, in the owner's order (08.11.2026):
/// height, width, pieces, milling, R, film, thickness and material, m²,
/// price, sum. Enter moves on; Enter on the price of the last row starts a
/// new one. «+ доп.» adds the back side, a patina or a note under the row.
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.index,
    required this.line,
    required this.priced,
    required this.millings,
    required this.materials,
    required this.films,
    required this.edges,
    required this.patinas,
    required this.defaultEdge,
    required this.headMaterial,
    required this.groupRate,
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
  final List<String> materials;
  final List<String> films;
  final List<String> edges;
  final List<String> patinas;

  /// The order's radius; a row with another one is highlighted.
  final String defaultEdge;
  final String? headMaterial;

  /// The group's price, shown under an empty price field.
  final String groupRate;
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
    final warn = context.statusColors.warning;
    final own = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: warn.withValues(alpha: AppTint.surface),
    );

    Widget cell(
      String key,
      String label,
      TextEditingController c,
      double width, {
      bool digits = true,
      FocusNode? focus,
      bool last = false,
      String? hint,
      bool highlight = false,
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
        decoration: (highlight ? own : const InputDecoration(isDense: true))
            .copyWith(labelText: label, hintText: hint),
      ),
    );

    Widget drop(
      String key,
      String label,
      String? value,
      List<String> choices,
      double width,
      ValueChanged<String?> set, {
      String? none,
      bool highlight = false,
      bool required = false,
    }) => SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$key:$index:${choices.length}'),
        initialValue: value,
        isExpanded: true,
        items: [
          if (!required) DropdownMenuItem(child: Text(none ?? l10n.mdfNone)),
          for (final m in mdfChoices(choices, value))
            DropdownMenuItem(value: m, child: Text(m)),
        ],
        onChanged: (v) {
          set(v);
          onChanged();
        },
        decoration: (highlight ? own : const InputDecoration(isDense: true))
            .copyWith(labelText: label),
      ),
    );

    Widget figure(String key, String label, String value, double width) =>
        SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                key: ValueKey('$key:$index'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );

    final p = priced;
    final edge = line.edge ?? defaultEdge;
    final extras = <Widget>[
      if (line.extras.contains(_Extra.back))
        _ExtraChip(
          key: ValueKey('mdfExtra:back:$index'),
          label: '+ ${l10n.mdfBackSideShort}',
          onRemove: () {
            line.drop(_Extra.back);
            onChanged();
          },
          child: drop(
            'mdfBackFilm',
            l10n.mdfBackSide,
            line.filmBack,
            films,
            200,
            (v) => line.filmBack = v,
            required: true,
          ),
        ),
      if (line.extras.contains(_Extra.patina))
        _ExtraChip(
          key: ValueKey('mdfExtra:patina:$index'),
          label: '+ ${l10n.mdfPatina}',
          onRemove: () {
            line.drop(_Extra.patina);
            onChanged();
          },
          child: drop(
            'mdfLinePatina',
            l10n.mdfPatina,
            line.patina,
            patinas,
            180,
            (v) => line.patina = v,
          ),
        ),
      if (line.extras.contains(_Extra.note))
        _ExtraChip(
          key: ValueKey('mdfExtra:note:$index'),
          label: '+ ${l10n.mdfNote}',
          onRemove: () {
            line.drop(_Extra.note);
            onChanged();
          },
          child: cell('mdfNote', l10n.mdfNote, line.note, 200, digits: false),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
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
              drop(
                'mdfLineMilling',
                l10n.mdfMilling,
                line.milling,
                millings,
                160,
                (v) => line.milling = v,
              ),
              drop(
                'mdfLineEdge',
                l10n.mdfColEdge,
                edge,
                edges,
                76,
                (v) => line.edge = v,
                required: true,
                highlight: edge != defaultEdge,
              ),
              SizedBox(
                width: 140,
                child: Text(
                  line.film ?? l10n.mdfFilmNone,
                  key: ValueKey('mdfLineFilm:$index'),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              drop(
                'mdfLineMaterial',
                l10n.mdfColMaterial,
                line.material,
                materials,
                150,
                (v) => line.material = v == headMaterial ? null : v,
                none: headMaterial ?? l10n.mdfNone,
                highlight: line.material != null,
              ),
              figure(
                'mdfLineArea',
                l10n.mdfArea,
                p == null ? '—' : p.areaM2.toStringAsFixed(2),
                64,
              ),
              cell(
                'mdfRate',
                l10n.mdfRate,
                line.rate,
                90,
                last: true,
                hint: groupRate.isEmpty ? null : groupRate,
                highlight: line.rate.text.trim().isNotEmpty,
              ),
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l10n.mdfAmount, style: theme.textTheme.labelSmall),
                    Text(
                      p == null ? '—' : money.format(p.amount),
                      key: ValueKey('mdfLineAmount:$index'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (p?.noPrice ?? false)
                      StatusChip(
                        key: ValueKey('mdfNoPrice:$index'),
                        label: l10n.mdfNoPrice,
                        intent: StatusIntent.warning,
                        compact: true,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_Extra>(
                key: ValueKey('mdfMore:$index'),
                tooltip: l10n.mdfExtraAdd,
                onSelected: (e) {
                  line.extras.add(e);
                  if (e == _Extra.back) {
                    line.filmBack ??= line.film ?? films.firstOrNull;
                  }
                  onChanged();
                },
                itemBuilder: (_) => [
                  for (final e in _Extra.values)
                    if (!line.extras.contains(e))
                      PopupMenuItem(
                        key: ValueKey('mdfMore:${e.name}'),
                        value: e,
                        child: Text(switch (e) {
                          _Extra.back => l10n.mdfBackSide,
                          _Extra.patina => l10n.mdfPatina,
                          _Extra.note => l10n.mdfNote,
                        }),
                      ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    l10n.mdfExtraAdd,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
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
          if (extras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xl + AppSpacing.sm,
                top: AppSpacing.xs,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: extras,
              ),
            ),
        ],
      ),
    );
  }
}

/// An extra under a row: its name, its field, ✕.
class _ExtraChip extends StatelessWidget {
  const _ExtraChip({
    required this.label,
    required this.child,
    required this.onRemove,
    super.key,
  });

  final String label;
  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(width: AppSpacing.sm),
            child,
            IconButton(
              key: const ValueKey('mdfExtraRemove'),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onRemove,
              icon: const Icon(AppIcons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerField extends ConsumerWidget {
  const _CustomerField({
    required this.initial,
    required this.onPicked,
    super.key,
  });

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
      if (h.edgeProfile != null) '${l10n.mdfColEdge} ${h.edgeProfile}',
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
            MdfTagBadges(orderTags: o.tags, customerTags: o.customerTags),
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
            key: const ValueKey('mdfLinesTable'),
            columns: [
              const DataColumn(label: Text('№')),
              DataColumn(label: Text(l10n.mdfHeight), numeric: true),
              DataColumn(label: Text(l10n.mdfWidth), numeric: true),
              DataColumn(label: Text(l10n.mdfQty), numeric: true),
              DataColumn(label: Text(l10n.mdfMilling)),
              DataColumn(label: Text(l10n.mdfColEdge)),
              DataColumn(label: Text(l10n.mdfFilm)),
              DataColumn(label: Text(l10n.mdfColMaterial)),
              DataColumn(label: Text(l10n.mdfArea), numeric: true),
              DataColumn(label: Text(l10n.mdfRate), numeric: true),
              DataColumn(label: Text(l10n.mdfAmount), numeric: true),
            ],
            rows: [
              for (final (g, group) in mdfFilmGroups(o.lines).indexed) ...[
                for (final (n, line) in group.lines)
                  DataRow(
                    color: WidgetStatePropertyAll(
                      AppColors.filmGroup(g).withValues(alpha: AppTint.surface),
                    ),
                    cells: [
                      DataCell(Text('$n')),
                      DataCell(Text('${line.heightMm}')),
                      DataCell(Text('${line.widthMm}')),
                      DataCell(Text('${line.qty}')),
                      DataCell(
                        Text(
                          [
                            line.milling,
                            line.note,
                          ].whereType<String>().join(' · '),
                        ),
                      ),
                      DataCell(
                        Text(
                          line.edge ?? '',
                          key: ValueKey('mdfLineEdgeShown:$n'),
                          style: line.edge == 'R0'
                              ? const TextStyle(fontWeight: FontWeight.w700)
                              : null,
                        ),
                      ),
                      DataCell(
                        Text(
                          [
                            line.film ?? '',
                            if (line.filmBack != null)
                              '+ ${l10n.mdfBackSideShort}: ${line.filmBack}',
                            if (line.patina != null)
                              '+ ${l10n.mdfPatina}: ${line.patina}',
                          ].join('\n'),
                          style: TextStyle(color: AppColors.filmGroup(g)),
                        ),
                      ),
                      DataCell(
                        Text(
                          line.material ??
                              (line.thicknessMm == null
                                  ? ''
                                  : '${line.thicknessMm} мм'),
                        ),
                      ),
                      DataCell(Text(line.areaM2.toStringAsFixed(2))),
                      DataCell(
                        Text(
                          line.noPrice
                              ? l10n.mdfNoPrice
                              : money.format(line.rateM2),
                        ),
                      ),
                      DataCell(Text(money.format(line.amount))),
                    ],
                  ),
                DataRow(
                  key: ValueKey('mdfFilmSubtotal:$g'),
                  cells: [
                    const DataCell(Text('')),
                    DataCell(Text(l10n.mdfFilmSubtotal)),
                    const DataCell(Text('')),
                    DataCell(Text('${group.pieces}')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(
                      Text(
                        group.film ?? '',
                        style: TextStyle(color: AppColors.filmGroup(g)),
                      ),
                    ),
                    const DataCell(Text('')),
                    DataCell(Text(group.areaM2.toStringAsFixed(2))),
                    const DataCell(Text('')),
                    DataCell(Text(money.format(group.amount))),
                  ],
                ),
              ],
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
  edge: l10n.mdfEdgeDefault,
  radius: l10n.mdfColEdge,
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
  material: l10n.mdfMaterial,
  film: l10n.mdfFilm,
  back: l10n.mdfBackSideShort,
  subtotal: l10n.mdfFilmSubtotal,
  materialColumn: l10n.mdfColMaterial,
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
