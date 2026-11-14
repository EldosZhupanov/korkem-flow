import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/size_paste.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_client_paint.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_coating.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_customers_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_hand_over.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_margin_view.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_print.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_tags_view.dart';
import 'package:korkem_flow/features/press_layout/data/press_layout_repository.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_layout_screen.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_print.dart';
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

/// A group of positions: its coating type and its colour (none for raw).
typedef _Group = ({MdfCoating? coating, String? film});

/// The first group of a new order, before anything is chosen — not even its
/// type: a manager may start with paint or a raw facade (09.11.2026).
const _Group _noGroup = (coating: null, film: null);

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
    this.thicknessMm,
    this.coating,
    this.clientPaint = false,
    this.clientFilm = false,
    this.clientMdf = false,
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

  /// The group it is in: a coating type and a colour of that type; no type
  /// yet on a new order's first group.
  MdfCoating? coating;
  String? film;

  _Group get group => (coating: coating, film: film);

  /// Its group's marks: the customer's own paint or film, his own LMDF.
  bool clientPaint;
  bool clientFilm;
  bool clientMdf;

  /// Its back film; null — one-sided.
  String? filmBack;

  /// Its own board; null — the order's.
  String? material;

  /// Its own thickness, mm; null — the order's.
  int? thicknessMm;

  /// Its edge; R3 unless the manager says, R0 a sharp corner.
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
      thicknessMm: thicknessMm,
      coating: coating,
      clientPaint: clientPaint && coating == MdfCoating.paint,
      clientFilm: clientFilm && coating == MdfCoating.pvc,
      clientMdf: clientMdf,
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
    thicknessMm: thicknessMm,
    coating: coating,
    clientPaint: clientPaint,
    clientFilm: clientFilm,
    clientMdf: clientMdf,
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
  final List<_Group> _films = [];

  /// Each film group's price per m².
  final Map<String?, TextEditingController> _filmRates = {};
  MdfPricing _pricing = MdfPricing.empty;
  Timer? _debounce;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order ?? widget.template;
    // A new order — a copy too — is due in a week (owner, 09.11.2026).
    if (widget.order == null) _due = mdfDueIn(DateTime.now());
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
        final g = (coating: l.coating ?? MdfCoating.pvc, film: l.film);
        if (!_films.contains(g)) _films.add(g);
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
            coating: g.coating,
            filmBack: l.filmBack,
            material: l.material == o.head.material ? null : l.material,
            thicknessMm: l.thicknessMm == o.head.thicknessMm
                ? null
                : l.thicknessMm,
            edge: l.edge ?? o.head.edgeProfile ?? mdfDefaultEdge,
            patina: l.patina,
            clientPaint: l.clientPaint,
            clientFilm: l.clientFilm,
            clientMdf: l.clientMdf,
          ),
        );
      }
    }
    if (_films.isEmpty) _films.add(_noGroup);
    if (_lines.isEmpty) _lines.add(_blank(_films.first));
    if (o == null) unawaited(_startFromLastHead());
    _initial = _snapshot();
    _initialLines = _inputs;
    _initialHead = _readHead();
    _initialDue = _due;
    _reprice();
  }

  /// The order as it was opened — to tell a change from none (09.11.2026:
  /// «хотели что-то изменить, но не изменили, а система не пропускает»).
  late String _initial;
  late List<MdfLineInput> _initialLines;
  late MdfHead _initialHead;
  DateTime? _initialDue;

  String _snapshot() => jsonEncode({
    'lines': [for (final l in _inputs) l.toJson()],
    'head': _readHead().toJson(),
    'due': _due?.toIso8601String().substring(0, 10),
  });

  bool get _dirty => _snapshot() != _initial;

  /// What changed, in words, for the reason dialog — sizes and the rest by
  /// position number, the head's fields by name.
  List<String> _changes(AppLocalizations l10n) {
    String show(Object? v) => v == null || v == '' ? '—' : '$v';
    String day(DateTime? d) => d == null ? '—' : mdfDayOf(d);
    final out = <String>[];
    if (_initialDue != _due) {
      out.add('${l10n.mdfDue}: ${day(_initialDue)} → ${day(_due)}');
    }
    final before = _initialHead.toJson();
    final after = _readHead().toJson();
    for (final key in {...before.keys, ...after.keys}) {
      if (jsonEncode(before[key]) != jsonEncode(after[key])) {
        final name = _fieldName(key, l10n);
        out.add('$name: ${show(before[key])} → ${show(after[key])}');
      }
    }
    final now = _inputs;
    for (var i = 0; i < now.length || i < _initialLines.length; i++) {
      if (i >= _initialLines.length) {
        out.add(l10n.mdfChangeAdded(i + 1));
        continue;
      }
      if (i >= now.length) {
        out.add(l10n.mdfChangeRemoved(i + 1));
        continue;
      }
      final a = _initialLines[i].toJson();
      final b = now[i].toJson();
      final diffs = [
        for (final key in {...a.keys, ...b.keys})
          if (jsonEncode(a[key]) != jsonEncode(b[key]))
            '${_fieldName(key, l10n)} ${show(a[key])} → ${show(b[key])}',
      ];
      if (diffs.isNotEmpty) out.add('${i + 1}: ${diffs.join('; ')}');
    }
    return out;
  }

  String _fieldName(String key, AppLocalizations l10n) => switch (key) {
    'height_mm' => l10n.mdfHeight,
    'width_mm' => l10n.mdfWidth,
    'qty' => l10n.mdfQty,
    'milling' => l10n.mdfMilling,
    'edge' || 'edge_profile' => l10n.mdfColEdge,
    'thickness_mm' => l10n.mdfThicknessShort,
    'material' => l10n.mdfMaterial,
    'film' || 'decor_top' => l10n.mdfColCoating,
    'film_back' => l10n.mdfBackSide,
    'patina' => l10n.mdfPatina,
    'note' => l10n.mdfNote,
    'rate' || 'film_rates' || 'default_rate' => l10n.mdfRate,
    'coating' => l10n.mdfColCoating,
    'tags' => l10n.mdfTagsTitle,
    _ => key,
  };

  /// A new order starts with the head of the last one this manager wrote:
  /// the same finish, thickness and edge more often than not — and, where
  /// that says nothing, our 16 mm LMDF (owner, 14.11.2026).
  Future<void> _startFromLastHead() async {
    try {
      final repo = ref.read(mdfOrderRepositoryProvider);
      final head = await repo.lastHead();
      final materials = await repo
          .dictionaries()
          .then((d) => d.values(MdfDictKind.material))
          .catchError((Object _) => const <String>[]);
      if (!mounted) return;
      setState(() {
        // Milling is a position's and the price a film group's now: the
        // head brings neither.
        _head = MdfHead(
          thicknessMm: head?.thicknessMm ?? mdfDefaultThicknessMm,
          decorTop: head?.decorTop,
          decorBottom: head?.decorBottom,
          edgeProfile: head?.edgeProfile,
          material: head?.material ?? mdfDefaultMaterialIn(materials),
        );
        for (final l in _lines) {
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
      builder: (_) => _PasteDialog(milling: _lastMilling(_films.last)),
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
            film: _films.last.film,
            coating: _films.last.coating,
            edge: _defaultEdge,
            clientPaint: _owns(_films.last).paint,
            clientFilm: _owns(_films.last).film,
            clientMdf: _owns(_films.last).mdf,
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

  /// A new row's milling: the row above it — the same milling runs on more
  /// often than not; the head's on an older order, which still has one.
  String? _lastMilling(_Group group) {
    final mates = [
      for (final l in _lines)
        if (l.group == group) l,
    ];
    final above = mates.isNotEmpty ? mates.last : _lines.lastOrNull;
    return above?.milling ?? _head.milling;
  }

  _LineFields _blank(_Group group) => _LineFields(
    milling: _lastMilling(group),
    film: group.film,
    coating: group.coating,
    edge: _defaultEdge,
    clientPaint: _owns(group).paint,
    clientFilm: _owns(group).film,
    clientMdf: _owns(group).mdf,
  );

  /// A group's marks — the customer's own paint or film, his own LMDF — as
  /// its lines carry them.
  ({bool paint, bool film, bool mdf}) _owns(_Group group) {
    final mates = _lines.where((l) => l.group == group);
    return (
      paint: mates.any((l) => l.clientPaint),
      film: mates.any((l) => l.clientFilm),
      mdf: mates.any((l) => l.clientMdf),
    );
  }

  /// Marks or unmarks a group: every line of it, and the total follows —
  /// his own paint is cheaper.
  void _setOwn(_Group group, MdfOrderTag mark, {required bool on}) {
    setState(() {
      for (final l in _lines.where((l) => l.group == group)) {
        switch (mark) {
          case MdfOrderTag.clientPaint:
            l.clientPaint = on;
          case MdfOrderTag.clientFilm:
            l.clientFilm = on;
          case MdfOrderTag.clientParts:
            l.clientMdf = on;
          case MdfOrderTag.urgent ||
              MdfOrderTag.rework ||
              MdfOrderTag.warranty:
            break;
        }
      }
    });
    _reprice();
  }

  TextEditingController _rateOf(String? film) =>
      _filmRates[film] ??= TextEditingController();

  /// The lines as they are shown and sent: film group by film group.
  List<_LineFields> get _ordered => [
    for (final g in _films)
      for (final l in _lines)
        if (l.group == g) l,
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
    thicknessMm: _head.thicknessMm ?? thicknessOf(_head.material),
    finish: _head.finish,
    // The first film stands for the order where one film is asked for;
    // a paint is no film.
    decorTop:
        _films
            .where((g) => g.coating == MdfCoating.pvc && g.film != null)
            .firstOrNull
            ?.film ??
        _head.decorTop,
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
            _films.any((g) => g.film == e.key) &&
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

  void _setTag(MdfOrderTag tag, {required bool on}) {
    setState(
      () => _head = _copyHead(
        tags: [
          for (final x in MdfOrderTag.values)
            if (x == tag ? on : _head.tags.contains(x)) x,
        ],
      ),
    );
    // His own paint is cheaper: the total follows.
    _reprice();
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

  void _addLine({_LineFields? from, _Group? group}) {
    final line = from?.copy() ?? _blank(group ?? _films.last);
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

  /// Up or down within its group.
  void _move(_LineFields line, int by) {
    final mates = [
      for (final l in _lines)
        if (l.group == line.group) l,
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

  /// «+ Добавить покрытие»: the type first — ПВХ, краска, черновой — then a
  /// colour from that type's own list, so they never mix (09.11.2026).
  Future<void> _addFilm() async {
    final l10n = AppLocalizations.of(context);
    final coating = await showDialog<MdfCoating>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.mdfCoatingPick),
        children: [
          for (final c in MdfCoating.values)
            SimpleDialogOption(
              key: ValueKey('mdfCoating:${c.name}'),
              onPressed: () => Navigator.of(context).pop(c),
              child: Text(mdfCoatingLabel(c, l10n)),
            ),
        ],
      ),
    );
    if (coating == null || !mounted) return;
    final kind = mdfCoatingList(coating);
    String? film;
    if (coating == MdfCoating.pvc) {
      // A film comes from the catalogue: maker, collection, film (owner,
      // 11.11.2026 — the old colour list is no longer picked from).
      film = await showFilmPicker(context);
      if (film == null || !mounted) return;
    } else if (kind != null) {
      film = await showMdfDictionary(
        context,
        kind,
        title: mdfCoatingLabel(coating, l10n),
      );
      if (film == null || !mounted) return;
    }
    final group = (coating: coating, film: film);
    if (_films.contains(group)) {
      _addLine(group: group);
      return;
    }
    setState(() {
      // A first group still without a colour and without sizes takes it.
      final blank =
          _films.length == 1 &&
          _films.first == _noGroup &&
          _lines.every((l) => l.input() == null);
      if (blank) {
        _films[0] = group;
        for (final l in _lines) {
          l
            ..coating = coating
            ..film = film;
        }
      } else {
        _films.add(group);
        _lines.add(_blank(group));
      }
    });
    _reprice();
  }

  /// The group's colour changed — within its type: its lines and its price
  /// go with it.
  void _renameFilm(_Group from, String? to) {
    final next = (coating: from.coating, film: to);
    if (from == next) return;
    setState(() {
      if (_films.contains(next)) {
        _films.remove(from);
      } else {
        _films[_films.indexOf(from)] = next;
      }
      for (final l in _lines) {
        if (l.group == from) l.film = to;
      }
      final rate = _filmRates.remove(from.film);
      if (rate != null && !_filmRates.containsKey(to)) _filmRates[to] = rate;
    });
    _reprice();
  }

  /// The group's type chosen or changed from its header. A colour of the old
  /// type is not one of the new type's, so it goes — the positions, sizes,
  /// millings and prices stay (09.11.2026).
  Future<void> _setType(_Group from, MdfCoating to) async {
    if (from.coating == to) return;
    final l10n = AppLocalizations.of(context);
    if (from.film != null) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(
            l10n.mdfCoatingSwitchAsk(from.film!, mdfCoatingLabel(to, l10n)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('mdfCoatingSwitchYes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    final next = (coating: to, film: null);
    setState(() {
      if (_films.contains(next)) {
        _films.remove(from); // a group of that type without colour: one block
      } else {
        _films[_films.indexOf(from)] = next;
      }
      for (final l in _lines) {
        if (l.group == from) {
          l
            ..coating = to
            ..film = null;
          if (to == MdfCoating.raw) {
            l
              ..filmBack = null
              ..extras.remove(_Extra.back);
          }
        }
      }
    });
    _reprice();
  }

  Future<void> _removeFilm(_Group group) async {
    final l10n = AppLocalizations.of(context);
    final mates = [
      for (final l in _lines)
        if (l.group == group) l,
    ];
    if (mates.any((l) => l.input() != null)) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(
            l10n.mdfFilmRemoveAsk(
              group.film ?? mdfCoatingNone(group.coating, l10n),
            ),
          ),
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
      _films.remove(group);
      if (!_films.any((g) => g.film == group.film)) {
        _filmRates.remove(group.film)?.dispose();
      }
      if (_films.isEmpty) _films.add(_noGroup);
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
    // Nothing changed: back to the card, no reason to ask for.
    if (!_dirty) {
      widget.onChanged!(widget.order!);
      return;
    }
    if (_inputs.isEmpty) {
      messenger.showFailureMessage(l10n.mdfNeedLine);
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ChangeReasonDialog(changes: _changes(l10n)),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
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

  /// «Срок»: +3, +7, +10, +14 days in one tap (a Sunday moves to Monday),
  /// or the calendar.
  Future<void> _pickDue() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final quick = await showDialog<DateTime?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.mdfDue),
        children: [
          for (final days in mdfDueQuickDays)
            SimpleDialogOption(
              key: ValueKey('mdfDueIn:$days'),
              onPressed: () =>
                  Navigator.of(context).pop(mdfDueIn(now, days: days)),
              child: Text(
                '${l10n.mdfDueInDays(days)} — '
                '${mdfDayOf(mdfDueIn(now, days: days))}',
              ),
            ),
          SimpleDialogOption(
            key: const ValueKey('mdfDueCalendar'),
            onPressed: () => Navigator.of(context).pop(DateTime(0)),
            child: Text(l10n.mdfDueCalendar),
          ),
        ],
      ),
    );
    if (quick == null || !mounted) return;
    if (quick.year != 0) {
      setState(() => _due = quick);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? mdfDueIn(now),
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
    final edges = mdfEdges(dicts.values(MdfDictKind.edge));
    final thicknesses = dicts.values(MdfDictKind.thickness);
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
      List<String>? values,
      bool required = false,
    }) {
      final choices = mdfChoices(values ?? dicts.values(kind), current);
      return SizedBox(
        width: width,
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey('$key:${choices.length}:$current'),
                initialValue: current,
                isExpanded: true,
                items: [
                  if (!required) DropdownMenuItem(child: Text(l10n.mdfNone)),
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

    // Changes not saved: «назад» asks before they are lost (09.11.2026).
    return PopScope(
      canPop: !widget.changing || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(AppLocalizations.of(context).mdfLeaveUnsaved),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const ValueKey('mdfLeaveYes'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context).mdfLeave),
              ),
            ],
          ),
        );
        if (leave ?? false) {
          _initial = _snapshot();
          setState(() {});
          navigator.pop();
        }
      },
      child: Column(
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
                            : '${l10n.mdfDue}: ${mdfDayOf(_due!)}',
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
                    // Thickness and material apart (owner, 09.11.2026).
                    pick(
                      'mdfThickness',
                      l10n.mdfThicknessShort,
                      MdfDictKind.thickness,
                      mdfThicknessLabel(thicknesses, _head.thicknessMm),
                      (v) => _head = _copyHead(thicknessMm: thicknessOf(v)),
                      width: AppSpacing.xxxl * 4,
                    ),
                    pick(
                      'mdfMaterial',
                      l10n.mdfMaterial,
                      MdfDictKind.material,
                      _head.material,
                      (v) => _head = _copyHead(material: v),
                      width: AppSpacing.xxxl * 4,
                    ),
                    // No «Покрытие» here (09.11.2026): each group has its own.
                    // No milling and no price here (owner, 09.11.2026): each
                    // position has its own milling, each film group its price.
                    pick(
                      'mdfEdge',
                      l10n.mdfEdgeDefault,
                      MdfDictKind.edge,
                      _defaultEdge,
                      (next) {
                        final was = _defaultEdge;
                        _head = _copyHead(edgeProfile: next);
                        // Rows on the old default follow; changed ones stay.
                        for (final l in _lines) {
                          if (l.edge == was) l.edge = _defaultEdge;
                        }
                      },
                      values: edges,
                      required: true,
                    ),
                    text('mdfExtra', l10n.mdfExtraName, _extra),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    // His own paint and his own facades sit with the
                    // coating group they are about (owner, 14.11.2026).
                    for (final t in MdfOrderTag.values)
                      if (!t.byGroup)
                        FilterChip(
                          key: ValueKey('mdfOrderTag:${t.wire}'),
                          label: Text(mdfOrderTagLabel(t, l10n)),
                          selected: _head.tags.contains(t),
                          onSelected: (on) => _setTag(t, on: on),
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
                    final group = _films[g];
                    final film = group.film;
                    final kind = mdfCoatingList(group.coating);
                    // A film is picked in the catalogue, so its drop-down
                    // holds only what the order already names (11.11.2026).
                    final colors =
                        kind == null || group.coating == MdfCoating.pvc
                        ? const <String>[]
                        : dicts.values(kind);
                    final mates = [
                      for (final l in _lines)
                        if (l.group == group) l,
                    ];
                    final priced = [for (final l in mates) ?pricedOf(l)];
                    final first = number;
                    number += mates.length;
                    return _FilmGroup(
                      key: ValueKey('mdfFilmGroup:$g'),
                      index: g,
                      coating: group.coating,
                      film: film,
                      films: colors,
                      rate: _rateOf(film),
                      pieces: priced.fold(0, (sum, p) => sum + p.qty),
                      areaM2: priced.fold<double>(
                        0,
                        (sum, p) => sum + p.areaM2,
                      ),
                      amount: priced.fold<double>(
                        0,
                        (sum, p) => sum + p.amount,
                      ),
                      onFilm: (to) => _renameFilm(group, to),
                      onType: (to) => _setType(group, to),
                      onRateChanged: _reprice,
                      onRemove: () => _removeFilm(group),
                      onAddLine: () => _addLine(group: group),
                      tags: [
                        if (_owns(group).paint) MdfOrderTag.clientPaint,
                        if (_owns(group).film) MdfOrderTag.clientFilm,
                        if (_owns(group).mdf) MdfOrderTag.clientParts,
                      ],
                      onTag: (t, {required on}) => _setOwn(group, t, on: on),
                      children: [
                        for (var i = 0; i < mates.length; i++)
                          _LineRow(
                            key: ObjectKey(mates[i]),
                            index: first + i,
                            line: mates[i],
                            priced: pricedOf(mates[i]),
                            millings: millings,
                            materials: materials,
                            films: colors,
                            edges: edges,
                            patinas: patinas,
                            thicknesses: thicknesses,
                            headThickness: _head.thicknessMm,
                            defaultEdge: _defaultEdge,
                            headMaterial: _head.material,
                            groupRate: _rateOf(film).text.trim(),
                            isLast:
                                g == _films.length - 1 && i == mates.length - 1,
                            onChanged: () {
                              setState(() {});
                              _reprice();
                            },
                            onNext: () => _addLine(group: group),
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
                      onPressed: _busy
                          ? null
                          : () => _saveAndShow(accept: true),
                      child: Text(l10n.mdfAccept),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
    required this.coating,
    required this.film,
    required this.films,
    required this.rate,
    required this.pieces,
    required this.areaM2,
    required this.amount,
    required this.onFilm,
    required this.onType,
    required this.onRateChanged,
    required this.onRemove,
    required this.onAddLine,
    required this.children,
    this.tags = const [],
    this.onTag,
    super.key,
  });

  final int index;

  /// Null on a new order's first group until the manager picks one.
  final MdfCoating? coating;
  final String? film;

  /// The colours of its coating type — films, or paints; none for raw.
  final List<String> films;
  final TextEditingController rate;
  final int pieces;
  final double areaM2;
  final double amount;
  final ValueChanged<String?> onFilm;
  final ValueChanged<MdfCoating> onType;
  final VoidCallback onRateChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddLine;
  final List<Widget> children;

  /// This group's marks: the customer's own paint (a paint group) or film
  /// (a PVC group), and his own LMDF (any group).
  final List<MdfOrderTag> tags;
  final void Function(MdfOrderTag tag, {required bool on})? onTag;

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
                  // The type, then a colour of that type only. No type yet:
                  // the three to pick from; a type: a button to change it.
                  if (coating == null) ...[
                    Text(
                      l10n.mdfCoatingPick,
                      style: theme.textTheme.labelLarge,
                    ),
                    for (final c in MdfCoating.values)
                      ChoiceChip(
                        key: ValueKey('mdfGroupType:$index:${c.name}'),
                        label: Text(mdfCoatingLabel(c, l10n)),
                        selected: false,
                        onSelected: (_) => onType(c),
                      ),
                  ] else
                    PopupMenuButton<MdfCoating>(
                      key: ValueKey('mdfGroupCoating:$index:${coating!.name}'),
                      tooltip: l10n.mdfCoatingPick,
                      onSelected: onType,
                      itemBuilder: (_) => [
                        for (final c in MdfCoating.values)
                          CheckedPopupMenuItem(
                            key: ValueKey('mdfGroupTypeTo:${c.name}'),
                            value: c,
                            checked: c == coating,
                            child: Text(mdfCoatingLabel(c, l10n)),
                          ),
                      ],
                      child: Chip(
                        label: Text(mdfCoatingLabel(coating!, l10n)),
                        avatar: const Icon(AppIcons.down),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (coating != null && coating != MdfCoating.raw)
                    SizedBox(
                      width: AppSpacing.xxxl * 5,
                      child: DropdownButtonFormField<String?>(
                        // The film is in the key: one picked from the
                        // catalogue must show at once.
                        key: ValueKey(
                          'mdfFilmPick:$index:${films.length}:$film',
                        ),
                        initialValue: film,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            child: Text(mdfCoatingNone(coating, l10n)),
                          ),
                          for (final f in mdfChoices(films, film))
                            DropdownMenuItem(value: f, child: Text(f)),
                        ],
                        onChanged: onFilm,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                        ),
                        decoration: InputDecoration(
                          labelText: mdfCoatingLabel(coating!, l10n),
                          isDense: true,
                        ),
                      ),
                    ),
                  for (final t in [
                    if (coating == MdfCoating.paint) MdfOrderTag.clientPaint,
                    if (coating == MdfCoating.pvc) MdfOrderTag.clientFilm,
                    if (coating != null) MdfOrderTag.clientParts,
                  ])
                    FilterChip(
                      key: ValueKey('mdfGroupTag:$index:${t.wire}'),
                      label: Text(mdfOrderTagLabel(t, l10n)),
                      selected: tags.contains(t),
                      onSelected: onTag == null
                          ? null
                          : (on) => onTag!(t, on: on),
                    ),
                  // A film from the catalogue: the maker, the type, then that
                  // maker's film (owner, 10.11.2026).
                  if (coating == MdfCoating.pvc)
                    IconButton(
                      key: ValueKey('filmPick:$index'),
                      tooltip: l10n.filmCatalogTitle,
                      icon: const Icon(AppIcons.search),
                      onPressed: () async {
                        final picked = await showFilmPicker(
                          context,
                          current: film,
                        );
                        if (picked != null) onFilm(picked);
                      },
                    ),
                  // The type's own list, here: add, rename, delete a film
                  // or a paint without leaving the order (09.11.2026).
                  if (mdfCoatingList(coating) case final kind?
                      when coating != MdfCoating.pvc)
                    IconButton(
                      key: ValueKey('dict:group:$index'),
                      tooltip: l10n.mdfDictOpen,
                      icon: const Icon(AppIcons.dictionary),
                      onPressed: () async {
                        final picked = await showMdfDictionary(
                          context,
                          kind,
                          title: mdfCoatingLabel(coating!, l10n),
                          current: film,
                        );
                        if (picked != null) onFilm(picked);
                      },
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
    required this.thicknesses,
    required this.headThickness,
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
  final List<String> thicknesses;

  /// The order's thickness, mm: what a row without its own shows.
  final int? headThickness;

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

    // «ЛМДФ · клиента»: the customer's own board, in the material's list.
    final clients = ' · ${l10n.mdfClientShort}';

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

    /// A list's own button beside its pick: add, rename, delete, choose.
    Widget dictButton(
      String key,
      MdfDictKind kind,
      String title,
      String? current,
      ValueChanged<String> set,
    ) => IconButton(
      key: ValueKey('dict:$key:$index'),
      tooltip: l10n.mdfDictOpen,
      icon: const Icon(AppIcons.dictionary),
      onPressed: () async {
        // A film — the back side of a PVC position — is from the catalogue.
        final picked =
            kind == MdfDictKind.decor && line.coating == MdfCoating.pvc
            ? await showFilmPicker(context, current: current)
            : await showMdfDictionary(
                context,
                kind,
                title: title,
                current: current,
              );
        if (picked != null) {
          set(picked);
          onChanged();
        }
      },
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              drop(
                'mdfBackFilm',
                l10n.mdfBackSide,
                line.filmBack,
                films,
                200,
                (v) => line.filmBack = v,
                required: true,
              ),
              if (mdfCoatingList(line.coating) case final kind?)
                dictButton('back', kind, l10n.mdfBackSide, line.filmBack, (v) {
                  line.filmBack = v;
                }),
            ],
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              drop(
                'mdfLinePatina',
                l10n.mdfPatina,
                line.patina,
                patinas,
                180,
                (v) => line.patina = v,
              ),
              // The patina list, here: add, rename, delete (09.11.2026).
              dictButton(
                'patina',
                MdfDictKind.patina,
                l10n.mdfPatina,
                line.patina,
                (v) => line.patina = v,
              ),
            ],
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
              // The milling list is here now, not in the head (09.11.2026).
              IconButton(
                key: ValueKey('dict:milling:$index'),
                tooltip: l10n.mdfDictOpen,
                icon: const Icon(AppIcons.dictionary),
                onPressed: () async {
                  final picked = await showMdfDictionary(
                    context,
                    MdfDictKind.milling,
                    title: l10n.mdfMilling,
                    current: line.milling,
                  );
                  if (picked != null) {
                    line.milling = picked;
                    onChanged();
                  }
                },
              ),
              drop(
                'mdfLineEdge',
                l10n.mdfColEdge,
                edge,
                edges,
                130,
                (v) => line.edge = v,
                required: true,
                highlight: edge != defaultEdge,
              ),
              SizedBox(
                width: 140,
                child: Text(
                  [
                    if (line.coating == MdfCoating.raw)
                      mdfCoatingLabel(MdfCoating.raw, l10n)
                    else
                      line.film ?? mdfCoatingNone(line.coating, l10n),
                    if (mdfLineIsClients(
                      line.coating,
                      paint: line.clientPaint,
                      film: line.clientFilm,
                    ))
                      l10n.mdfClientShort,
                  ].join(' · '),
                  key: ValueKey('mdfLineFilm:$index'),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        mdfLineIsClients(
                          line.coating,
                          paint: line.clientPaint,
                          film: line.clientFilm,
                        )
                        ? context.statusColors.warning
                        : null,
                  ),
                ),
              ),
              drop(
                'mdfLineThickness',
                l10n.mdfThicknessShort,
                mdfThicknessLabel(thicknesses, line.thicknessMm),
                thicknesses,
                100,
                (v) {
                  final mm = thicknessOf(v);
                  line.thicknessMm = mm == headThickness ? null : mm;
                },
                none: mdfThicknessLabel(thicknesses, headThickness),
                highlight: line.thicknessMm != null,
              ),
              // Ours by default — the order's LMDF; his own is picked right
              // here, position by position (owner, 14.11.2026): a customer
              // may bring some of the facades, or 16 and 18 mm.
              drop(
                'mdfLineMaterial',
                l10n.mdfMaterial,
                line.clientMdf
                    ? '${line.material ?? headMaterial ?? ''}$clients'
                    : line.material,
                [
                  ...materials,
                  for (final m in materials) '$m$clients',
                ],
                160,
                (v) {
                  final his = v != null && v.endsWith(clients);
                  final base = his
                      ? v.substring(0, v.length - clients.length)
                      : v;
                  line
                    ..clientMdf = his
                    ..material = base == headMaterial ? null : base;
                },
                none: headMaterial ?? l10n.mdfNone,
                highlight: line.material != null || line.clientMdf,
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
                    // A raw facade has no colour, so no back side either.
                    if (!line.extras.contains(e) &&
                        !(e == _Extra.back && line.coating == MdfCoating.raw))
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
    final result = await showDialog<_Payments>(
      context: context,
      builder: (_) => _PaymentDialog(order: o),
    );
    if (result == null) return;
    // Each part is a payment of its own: the cash book splits the day by
    // method and bank, and a wrong part is fixed on its own.
    await _run(() async {
      final repo = ref.read(mdfOrderRepositoryProvider);
      for (final p in result.parts) {
        await repo.addPayment(
          o.name,
          amount: p.amount,
          method: p.method,
          bank: p.bank,
        );
      }
      return o;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showDone(l10n.mdfSaved);
  }

  /// «Исправить» (owner, 09.11.2026): the payment's own figures to start
  /// from, and why.
  Future<void> _fixPayment(MdfPayment p) async {
    final result = await showDialog<_Payments>(
      context: context,
      builder: (_) => _PaymentDialog(order: o, fixing: p),
    );
    if (result == null || p.entry == null) return;
    final part = result.parts.single;
    await _run(
      () => ref
          .read(mdfOrderRepositoryProvider)
          .fixPayment(
            o.name,
            entry: p.entry!,
            reason: result.reason ?? '',
            amount: part.amount,
            method: part.method,
            bank: part.bank,
          ),
    );
  }

  Future<void> _deletePayment(MdfPayment p) async {
    final reason = await showMdfPaymentDelete(
      context,
      p,
      mdfMoney(context).format(p.amount),
    );
    if (reason == null || p.entry == null) return;
    await _run(
      () => ref
          .read(mdfOrderRepositoryProvider)
          .deletePayment(o.name, entry: p.entry!, reason: reason),
    );
  }

  /// The check before a hand-over, then «Заказ выдан» — the manager sees it
  /// went through (09.11.2026: the buttons only vanished).
  Future<void> _handOver() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final got = await showMdfHandOver(context, o);
    if (got == null) return;
    var ok = false;
    await _run(() async {
      final card = await ref
          .read(mdfOrderRepositoryProvider)
          .handOver(
            o.name,
            comment: got.comment,
            takenBy: got.takenBy,
            takenPhone: got.takenPhone,
          );
      ok = true;
      return card;
    });
    if (ok) messenger.showDone(l10n.mdfHandedOverDone);
  }

  Future<void> _returnToWork() async {
    final l10n = AppLocalizations.of(context);
    final reason = await _ask(l10n.mdfReturnToWork, l10n.mdfReturnReason, l10n);
    if (reason == null) return;
    await _run(
      () => ref.read(mdfOrderRepositoryProvider).returnToWork(o.name, reason),
    );
  }

  Future<void> _print({required bool withPrices}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final words = mdfPrintWords(l10n);
    // The shop's copy carries the press map after the order (owner,
    // 12.11.2026): the film each group takes, and a page per press load.
    OrderPressLayout? found;
    if (!withPrices && o.press.isNotEmpty) {
      try {
        found = await ref.read(pressLayoutRepositoryProvider).layout(o.name);
      } on Object {
        // No map is no reason not to print the order.
        found = null;
      }
    }
    final layout = found;
    final pressWords = pressPrintWordsOf(l10n);
    try {
      await printMdfOrder(
        name: o.name,
        build: () => buildMdfOrderPdf(
          o,
          words,
          withPrices: withPrices,
          locale: locale,
          filmNotes: withPrices
              ? const {}
              : {
                  for (final e in o.press.entries)
                    e.key: mdfFilmPressText(e.value, l10n),
                },
          more: layout == null
              ? null
              : (doc) => addPressPages(
                  doc,
                  layout.films,
                  layout.press,
                  pressWords,
                  locale: locale,
                  footer: pressPrintFooter(l10n, layout),
                ),
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
    final millings = {for (final l in o.lines) ?l.milling}.join(', ');
    final headLine = [
      if (h.thicknessMm != null) '${h.thicknessMm} мм',
      h.material,
      h.finish,
      h.decorTop,
      if (h.decorBottom != null) '/ ${h.decorBottom}',
      if (millings.isNotEmpty) millings else h.milling,
      if (h.edgeProfile != null) '${l10n.mdfColEdge}: ${h.edgeProfile}',
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
            '${mdfDay(o.createdOn)} → ${mdfDay(o.deliveryDate)}',
          ].whereType<String>().join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (o.holdReason != null)
          Text(
            '${l10n.mdfStatusOnHold}: ${o.holdReason}',
            style: theme.textTheme.bodyMedium,
          ),
        if (o.status == MdfStatus.handedOver) ...[
          const SizedBox(height: AppSpacing.sm),
          MdfHandedOverBanner(
            order: o,
            money: money,
            onReturn: _busy ? null : _returnToWork,
          ),
        ],
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
        // The customer's own paint: what he brought, whether it is here.
        MdfClientPaintView(order: o),
        // What the order earned (owner, 14.11.2026).
        MdfMarginView(order: o.name),
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
              key: const ValueKey('mdfPrintShop'),
              onPressed: () => _print(withPrices: false),
              icon: const Icon(AppIcons.print),
              label: Text(l10n.mdfPrintShop),
            ),
            // Rarely needed (owner, 09.11.2026): out of the way, in «⋮».
            PopupMenuButton<String>(
              key: const ValueKey('mdfMoreMenu'),
              icon: const Icon(AppIcons.more),
              onSelected: (_) => context.push(Routes.mdfOrderNew, extra: o),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const ValueKey('mdfRepeat'),
                  value: 'copy',
                  child: Text(l10n.mdfCopyOrder),
                ),
              ],
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
                    if (doneOn != null) mdfDay(doneOn, year: false),
                    ?o.stageWorkers[stage],
                  ].join(' · '),
                ),
                selected: doneOn != null,
                onSelected: !open || _busy || o.status == MdfStatus.onHold
                    ? null
                    : (v) => _run(() => repo.setStage(o.name, stage, done: v)),
                // A stage added for a rework goes again while unticked.
                onDeleted:
                    open &&
                        !_busy &&
                        doneOn == null &&
                        o.extraStages.contains(stage)
                    ? () => _run(
                        () => repo.extraStage(o.name, stage, on: false),
                      )
                    : null,
              ),
            if (open && MdfStage.extra.any((s) => !o.stages.containsKey(s)))
              PopupMenuButton<MdfStage>(
                key: const ValueKey('mdfAddStage'),
                tooltip: l10n.mdfAddStage,
                enabled: !_busy,
                onSelected: (s) =>
                    _run(() => repo.extraStage(o.name, s, on: true)),
                itemBuilder: (_) => [
                  for (final s in MdfStage.extra)
                    if (!o.stages.containsKey(s))
                      PopupMenuItem(
                        key: ValueKey('mdfAddStage:${s.name}'),
                        value: s,
                        child: Text(mdfStageLabel(s, l10n)),
                      ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    '+ ${l10n.mdfAddStage}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.mdfLinesSection),
        // The table is at least as wide as the window, so a group's head
        // reaches its right edge — where the layout's button stands, in
        // sight in any window (owner, 13.11.2026).
        LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth),
              child: _linesTable(context, o, money, box.maxWidth),
            ),
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
        for (final (i, p) in o.payments.indexed)
          ListTile(
            key: ValueKey('mdfPayment:$i'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            // Fixed or deleted: struck through, the history says why.
            title: Text(
              [
                money.format(p.amount),
                if (p.cancelled) l10n.mdfPaymentCancelled,
              ].join(' · '),
              style: p.cancelled
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.outline,
                    )
                  : null,
            ),
            subtitle: Text(
              [
                mdfDay(p.date),
                p.method,
                p.bank,
              ].whereType<String>().join(' · '),
            ),
            trailing:
                p.cancelled ||
                    p.entry == null ||
                    o.status == MdfStatus.cancelled
                ? null
                : PopupMenuButton<bool>(
                    key: ValueKey('mdfPaymentMenu:$i'),
                    icon: const Icon(AppIcons.more),
                    enabled: !_busy,
                    onSelected: (fix) =>
                        fix ? _fixPayment(p) : _deletePayment(p),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        key: ValueKey('mdfPaymentFix:$i'),
                        value: true,
                        child: Text(l10n.mdfPaymentFix),
                      ),
                      PopupMenuItem(
                        key: ValueKey('mdfPaymentDelete:$i'),
                        value: false,
                        child: Text(l10n.mdfPaymentDelete),
                      ),
                    ],
                  ),
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
                  onPressed: _busy ? null : _handOver,
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

/// Text that runs on across the empty cells to its right, so one row of a
/// table can carry a line as wide as the table without widening a column.
/// «Плёнка 8,3 м · 3 загрузки · −1 м» — a film group's metres on the press.
/// The order's positions, by coating group: each group headed by its
/// name and — for a film — the press layout's button at the window's
/// right edge (owner, 13.11.2026).
Widget _linesTable(
  BuildContext context,
  MdfOrder o,
  NumberFormat money,
  double width,
) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  return DataTable(
    key: const ValueKey('mdfLinesTable'),
    // A group's head opens its layout by a tap on the row (below); no
    // checkboxes come with that.
    showCheckboxColumn: false,
    // A coating with a back side and a patina is three lines high.
    dataRowMaxHeight: double.infinity,
    columns: [
      const DataColumn(label: Text('№')),
      DataColumn(label: Text(l10n.mdfHeight), numeric: true),
      DataColumn(label: Text(l10n.mdfWidth), numeric: true),
      DataColumn(label: Text(l10n.mdfQty), numeric: true),
      DataColumn(label: Text(l10n.mdfMilling)),
      DataColumn(label: Text(l10n.mdfColEdge)),
      DataColumn(label: Text(l10n.mdfColCoating)),
      DataColumn(label: Text(l10n.mdfThicknessShort), numeric: true),
      DataColumn(label: Text(l10n.mdfMaterial)),
      DataColumn(label: Text(l10n.mdfArea), numeric: true),
      DataColumn(label: Text(l10n.mdfRate), numeric: true),
      DataColumn(label: Text(l10n.mdfAmount), numeric: true),
    ],
    rows: [
      for (final (g, group) in mdfFilmGroups(o.lines).indexed) ...[
        // The coating's name over its positions (owner, 10.11.2026).
        DataRow(
          key: ValueKey('mdfGroupHead:$g'),
          color: WidgetStatePropertyAll(
            AppColors.filmGroup(g).withValues(alpha: AppTint.groupHead),
          ),
          // The layout's button is drawn past its cell, out to the window's
          // edge, and a tap there never reached it: a widget is hit only
          // inside its own box, and the cell's is narrow (owner,
          // 14.11.2026: «окно раскладки не открывается»). The whole row
          // takes the tap instead — the button included.
          onSelectChanged: o.press[group.film] == null
              ? null
              : (_) => context.push(Routes.pressLayoutOf(o.name)),
          cells: [
            DataCell(
              _GroupHead(
                index: g,
                name: mdfGroupName(group.coating, group.film, l10n),
                press: o.press[group.film],
                // From the first cell's start to the window's edge.
                width: width - AppSpacing.xl * 2,
                onOpen: () => context.push(Routes.pressLayoutOf(o.name)),
              ),
            ),
            for (var i = 1; i < 12; i++) const DataCell(Text('')),
          ],
        ),
        for (final (n, line) in group.lines) ...[
          DataRow(
            color: WidgetStatePropertyAll(
              AppColors.filmGroup(g).withValues(alpha: AppTint.surface),
            ),
            cells: [
              DataCell(Text('$n')),
              DataCell(Text('${line.heightMm}')),
              DataCell(Text('${line.widthMm}')),
              DataCell(Text('${line.qty}')),
              DataCell(Text(line.milling ?? '')),
              DataCell(
                Text(
                  line.edge ?? '',
                  key: ValueKey('mdfLineEdgeShown:$n'),
                  // Not the usual R3: the shop must see it.
                  style: line.edge != null && line.edge != mdfDefaultEdge
                      ? const TextStyle(fontWeight: FontWeight.w700)
                      : null,
                ),
              ),
              // The back side and a patina under the coating
              // (owner, 10.11.2026, variant А).
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mdfGroupName(line.coating, line.film, l10n),
                      style: TextStyle(
                        color: AppColors.filmGroup(g),
                      ),
                    ),
                    for (final x in mdfCoatingExtras(
                      line,
                      back: l10n.mdfBackSideShort,
                      patina: l10n.mdfPatina,
                    ))
                      Text(x, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              DataCell(
                Text(
                  line.thicknessMm == null ? '' : '${line.thicknessMm} мм',
                ),
              ),
              DataCell(Text(line.material ?? '')),
              DataCell(Text(line.areaM2.toStringAsFixed(2))),
              DataCell(
                Text(
                  line.noPrice ? l10n.mdfNoPrice : money.format(line.rateM2),
                ),
              ),
              DataCell(Text(money.format(line.amount))),
            ],
          ),
          // The note on a row of its own under the position, from
          // «Выс.» on (owner, 10.11.2026).
          if (mdfLineNote(line) case final note?)
            DataRow(
              key: ValueKey('mdfLineExtras:$n'),
              color: WidgetStatePropertyAll(
                AppColors.filmGroup(
                  g,
                ).withValues(alpha: AppTint.surface),
              ),
              cells: [
                const DataCell(Text('')),
                DataCell(
                  _Spanning(
                    '${l10n.mdfNoteShort}: $note',
                    key: ValueKey('mdfLineExtras:$n'),
                  ),
                ),
                for (var i = 2; i < 12; i++) const DataCell(Text('')),
              ],
            ),
        ],
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
                mdfGroupName(group.coating, group.film, l10n),
                style: TextStyle(color: AppColors.filmGroup(g)),
              ),
            ),
            const DataCell(Text('')),
            const DataCell(Text('')),
            DataCell(Text(group.areaM2.toStringAsFixed(2))),
            const DataCell(Text('')),
            DataCell(Text(money.format(group.amount))),
          ],
        ),
      ],
    ],
  );
}

/// A group's head: its name and the state of its layout on the left, the
/// layout's button on the right — grey until checked, green once checked,
/// blue when laid out by hand, red when something does not fit.
class _GroupHead extends StatelessWidget {
  const _GroupHead({
    required this.index,
    required this.name,
    required this.press,
    required this.width,
    required this.onOpen,
  });

  final int index;
  final String name;
  final MdfFilmPress? press;
  final double width;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final p = press;
    final colour = p == null
        ? null
        : p.tooBig > 0
        ? status.danger
        : p.approvedBy != null
        ? status.success
        : p.manual
        ? status.info
        : theme.colorScheme.outline;
    final state = p == null
        ? null
        : p.tooBig > 0
        ? l10n.mdfPressTooBig(p.tooBig)
        : p.approvedBy != null
        ? l10n.mdfPressCheckedBy(p.approvedBy!)
        : l10n.mdfPressNotChecked;
    final head = Row(
      children: [
        Text(
          name,
          key: ValueKey('mdfGroupHeadText:$index'),
          softWrap: false,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (state != null) ...[
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              state,
              key: ValueKey('mdfGroupState:$index'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colour == theme.colorScheme.outline
                    ? theme.colorScheme.onSurfaceVariant
                    : colour,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (p != null && colour != null)
          OutlinedButton.icon(
            key: ValueKey('mdfGroupPress:$index'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colour == theme.colorScheme.outline
                  ? theme.colorScheme.onSurface
                  : colour,
              backgroundColor: colour.withValues(alpha: AppTint.surface),
              side: BorderSide(color: colour),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onOpen,
            icon: Icon(
              p.approvedBy != null ? AppIcons.check : AppIcons.pressLayout,
              size: AppIconSize.small,
            ),
            label: KeyedSubtree(
              key: ValueKey('mdfGroupFilm:$index'),
              child: Text(mdfFilmPressText(p, l10n, checked: false)),
            ),
          ),
      ],
    );
    // As wide as the window from the first cell on; the row grows to it.
    return SizedBox(
      width: 0,
      height: AppTouchTarget.min,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: width,
        maxWidth: width,
        child: head,
      ),
    );
  }
}

String mdfFilmPressText(
  MdfFilmPress p,
  AppLocalizations l10n, {
  bool checked = true,
}) {
  String m(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  return [
    l10n.mdfPressFilm(m(p.filmM), p.loads.length),
    if (p.manual)
      l10n.mdfPressManual
    else if (p.corrected)
      l10n.mdfPressCorrected
    else if (p.saved > 0)
      l10n.mdfPressSaved(m(p.saved)),
    if (checked && p.approvedBy != null) l10n.mdfPressApproved,
    if (p.tooBig > 0) l10n.mdfPressTooBig(p.tooBig),
  ].join(' · ');
}

class _Spanning extends StatelessWidget {
  const _Spanning(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final shown = DefaultTextStyle.of(
      context,
    ).style.merge(const TextStyle(fontStyle: FontStyle.italic));
    // The row grows with its tallest cell, so no height comes from above:
    // the box is as tall as its one line of text, measured.
    final line = TextPainter(
      text: TextSpan(text: text, style: shown),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = line.height;
    line.dispose();
    return SizedBox(
      width: 0,
      height: height,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: double.infinity,
        child: Text(text, softWrap: false, style: shown),
      ),
    );
  }
}

/// How a payment came: one of three, and for a transfer or a card the bank
/// (owner, 09.11.2026). The words are the server's — what the cash book shows.
const _transfer = 'Перевод';
const _cash = 'Наличные';
const _card = 'Карта';
const List<String> _methods = [_transfer, _cash, _card];

typedef _Payment = ({double amount, String method, String? bank});

/// What the payment dialog gives back: one part or several (cash and a
/// transfer at once, owner 09.11.2026), and why, when a payment is fixed.
typedef _Payments = ({List<_Payment> parts, String? reason});

/// One way of paying in the dialog: the method, its bank, the amount.
class _Part {
  _Part({this.method = _transfer, this.bank, String amount = ''})
    : amount = TextEditingController(text: amount);

  String method;
  String? bank;
  final TextEditingController amount;

  bool get withBank => method != _cash;
  double get value => double.tryParse(amount.text.trim()) ?? 0;
}

class _PaymentDialog extends ConsumerStatefulWidget {
  const _PaymentDialog({required this.order, this.fixing});

  /// Its total, what is paid and what is left — shown on top.
  final MdfOrder order;

  /// The payment being fixed: its figures to start from, and a reason asked.
  final MdfPayment? fixing;

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  final _reason = TextEditingController();
  final _parts = <_Part>[];
  String? _reasonChip;
  bool _overpayOk = false;

  @override
  void initState() {
    super.initState();
    final p = widget.fixing;
    _parts.add(
      p == null
          ? _Part()
          : _Part(
              method: _methods.contains(p.method) ? p.method! : _transfer,
              bank: p.bank,
              amount: p.amount.toStringAsFixed(0),
            ),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final part in _parts) {
      part.amount.dispose();
    }
    super.dispose();
  }

  String? get _why => mdfReason(_reasonChip, _reason.text);

  /// What is left to pay before this dialog — a fixed payment counts as
  /// not paid, since it is entered again.
  double get _left => widget.order.debt + (widget.fixing?.amount ?? 0);

  double get _sum => _parts.fold(0, (s, p) => s + p.value);

  bool get _over => _sum > _left + 0.5;

  void _addPart() {
    final rest = _left - _sum;
    setState(
      () => _parts.add(
        _Part(
          method: _parts.last.method == _cash ? _transfer : _cash,
          amount: rest > 0 ? rest.toStringAsFixed(0) : '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final fixing = widget.fixing != null;
    final o = widget.order;
    final banks =
        (ref.watch(mdfDictionariesProvider).value ?? MdfDictionaries.empty)
            .values(MdfDictKind.bank);
    String label(String m) => switch (m) {
      _transfer => l10n.mdfPayTransfer,
      _cash => l10n.mdfPayCash,
      _ => l10n.mdfPayCard,
    };
    Widget figure(String name, double value) => Expanded(
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.labelSmall),
              Text(money.format(value), style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
    Widget part(int i, _Part p) {
      // The first row keeps its plain keys; a second, «:1» and on.
      final k = i == 0 ? '' : ':$i';
      final bankKey = 'mdfPaymentBank$k:${banks.length}:${p.bank}';
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('mdfPaymentAmount$k'),
                    controller: p.amount,
                    autofocus: i == 0,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.mdfPaymentAmount,
                    ),
                  ),
                ),
                if (i > 0)
                  IconButton(
                    key: ValueKey('mdfPaymentPartRemove$k'),
                    icon: const Icon(AppIcons.close),
                    onPressed: () => setState(() {
                      _parts.removeAt(i).amount.dispose();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final m in _methods)
                  ChoiceChip(
                    key: ValueKey('mdfPaymentMethod:$m$k'),
                    label: Text(label(m)),
                    selected: p.method == m,
                    onSelected: (_) => setState(() => p.method = m),
                  ),
              ],
            ),
            if (p.withBank) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(bankKey),
                      initialValue: p.bank,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(child: Text(l10n.mdfNone)),
                        for (final b in mdfChoices(banks, p.bank))
                          DropdownMenuItem(value: b, child: Text(b)),
                      ],
                      onChanged: (v) => setState(() => p.bank = v),
                      decoration: InputDecoration(labelText: l10n.mdfPayBank),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('dict:bank$k'),
                    tooltip: l10n.mdfDictOpen,
                    icon: const Icon(AppIcons.dictionary),
                    onPressed: () async {
                      final picked = await showMdfDictionary(
                        context,
                        MdfDictKind.bank,
                        title: l10n.mdfPayBank,
                        current: p.bank,
                      );
                      if (picked != null && mounted) {
                        setState(() => p.bank = picked);
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    final after = _left - _sum;
    final ready =
        _sum > 0 &&
        _parts.every((p) => p.value > 0) &&
        (!_over || _overpayOk) &&
        (!fixing || _why != null);
    return AlertDialog(
      title: Text(fixing ? l10n.mdfPaymentFixTitle : l10n.mdfAddPayment),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                key: const ValueKey('mdfPaymentFigures'),
                children: [
                  figure(l10n.mdfPayOrderTotal, o.total),
                  figure(
                    l10n.mdfPayPaid,
                    o.paid - (widget.fixing?.amount ?? 0),
                  ),
                  figure(l10n.mdfPayLeft, _left),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final (i, p) in _parts.indexed) part(i, p),
              if (!fixing)
                TextButton.icon(
                  key: const ValueKey('mdfPaymentAddPart'),
                  onPressed: _addPart,
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.mdfPayAddPart),
                ),
              Text(
                l10n.mdfPayAfter(
                  money.format(_sum),
                  money.format(after < 0 ? 0 : after),
                ),
                key: const ValueKey('mdfPaymentAfter'),
                style: theme.textTheme.titleSmall,
              ),
              // More than is owed: the 294 300 of order 00013 (09.11.2026).
              if (_over) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.mdfPayOver(money.format(_sum - _left)),
                  key: const ValueKey('mdfPaymentOver'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('mdfPaymentOverOk'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _overpayOk,
                  onChanged: (v) => setState(() => _overpayOk = v ?? false),
                  title: Text(l10n.mdfPayOverOk),
                ),
              ],
              if (fixing) ...[
                const SizedBox(height: AppSpacing.md),
                MdfReasonPicker(
                  reasons: mdfPaymentReasons(l10n),
                  chip: _reasonChip,
                  controller: _reason,
                  label: l10n.mdfPaymentReason,
                  onChip: (c) => setState(() => _reasonChip = c),
                  onText: () => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('mdfPaymentSave'),
          onPressed: !ready
              ? null
              : () => Navigator.of(context).pop<_Payments>((
                  parts: [
                    for (final p in _parts)
                      (
                        amount: p.value,
                        method: p.method,
                        bank: p.withBank ? p.bank : null,
                      ),
                  ],
                  reason: _why,
                )),
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
  thickness: l10n.mdfThicknessShort,
  finish: l10n.mdfFinish,
  decorTop: l10n.mdfDecorTop,
  decorBottom: l10n.mdfDecorBottom,
  patina: l10n.mdfPatina,
  milling: l10n.mdfMilling,
  edge: l10n.mdfEdgeDefault,
  radius: l10n.mdfColEdge,
  extraName: l10n.mdfExtraName,
  paid: l10n.mdfPayPaid,
  debt: l10n.mdfPrintDebt,
  note: l10n.mdfNoteShort,
  height: l10n.mdfPrintHeightShort,
  width: l10n.mdfPrintWidthShort,
  qty: l10n.mdfQty,
  area: l10n.mdfArea,
  rate: l10n.mdfRate,
  amount: l10n.mdfAmount,
  total: l10n.mdfPrintTotal,
  material: l10n.mdfMaterial,
  film: l10n.mdfColCoating,
  back: l10n.mdfBackSideShort,
  subtotal: l10n.mdfFilmSubtotal,
  coating: (c) => mdfCoatingLabel(c, l10n),
  thicknessColumn: l10n.mdfPrintThickShort,
  materialColumn: l10n.mdfPrintMaterialShort,
  client: l10n.mdfClientShort,
  pieces: l10n.mdfPrintPieces,
  tags: l10n.mdfTagsTitle,
  tag: (t) => mdfOrderTagLabel(t, l10n),
  weekday: (d) => DateFormat.EEEE(l10n.localeName).format(d),
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

/// «Изменить заказ»: what changed, in words, a ready reason to tap, a
/// note if there is more to say. A reason is needed — a chip or words.
class _ChangeReasonDialog extends StatefulWidget {
  const _ChangeReasonDialog({required this.changes});

  final List<String> changes;

  @override
  State<_ChangeReasonDialog> createState() => _ChangeReasonDialogState();
}

class _ChangeReasonDialogState extends State<_ChangeReasonDialog> {
  final _note = TextEditingController();
  String? _chip;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _reason =>
      [?_chip, if (_note.text.trim().isNotEmpty) _note.text.trim()].join(' — ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chips = [
      l10n.mdfReasonClient,
      l10n.mdfReasonMistake,
      l10n.mdfReasonAdded,
      l10n.mdfReasonPrice,
    ];
    return AlertDialog(
      title: Text(l10n.mdfChangeOrder),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.changes.isNotEmpty) ...[
              Text(l10n.mdfChangesTitle, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: AppSpacing.xxxl * 4,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.changes.join('\n'),
                    key: const ValueKey('mdfChangesList'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (i, c) in chips.indexed)
                  ChoiceChip(
                    key: ValueKey('mdfReasonChip:$i'),
                    label: Text(c),
                    selected: _chip == c,
                    onSelected: (on) => setState(() => _chip = on ? c : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('mdfChangeReasonField'),
              controller: _note,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.mdfChangeReason),
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
          key: const ValueKey('mdfChangeReasonYes'),
          onPressed: _reason.isEmpty
              ? null
              : () => Navigator.of(context).pop(_reason),
          child: Text(l10n.mdfConfirm),
        ),
      ],
    );
  }
}
