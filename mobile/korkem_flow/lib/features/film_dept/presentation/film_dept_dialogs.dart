import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_print.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The server's words for how money came (the cash book's own).
const filmTransfer = 'Перевод';
const filmCash = 'Наличные';
const filmCard = 'Карта';

double? _number(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.').replaceAll(' ', ''));

/// The name an order and a sale call a film by: «KIRA · Белый Матовый».
String filmName(Film f) => f.label ?? '${f.maker} · ${f.colour}';

/// Runs what a dialog saves: an error stays in the dialog, a success
/// closes it.
mixin _Saving<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  Future<void> save(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
        });
      }
    }
  }

  Widget errorLine(BuildContext context) => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
}

Widget _metresField(
  TextEditingController c,
  String label,
  VoidCallback onChanged,
) => TextField(
  key: const ValueKey('filmMetres'),
  controller: c,
  autofocus: true,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
  onChanged: (_) => onChanged(),
  decoration: InputDecoration(labelText: label),
);

/// A field with its list's own ✎: the list opens to be added to, renamed,
/// cleaned (owner, 11.11.2026: «чтобы редактировался и мог бы удалить»).
Widget _withList(
  BuildContext context, {
  required String key,
  required Widget child,
  required VoidCallback onEdit,
}) => Row(
  children: [
    Expanded(child: child),
    IconButton(
      key: ValueKey(key),
      tooltip: AppLocalizations.of(context).mdfDictOpen,
      onPressed: onEdit,
      icon: const Icon(AppIcons.edit),
    ),
  ],
);

/// «пятница, 13.11» — the day a roll is due, as the shop says it.
String _dayName(BuildContext context, DateTime day) =>
    '${DateFormat.EEEE(Localizations.localeOf(context).toString()).format(day)}'
    ', ${mdfDay(mdfIso(day), year: false)}';

/// Who works here, to pick who took a roll in or who sold — the one
/// signed in first.
Widget _personField({
  required String key,
  required String label,
  required FilmDeliveryOptions? opts,
  required String? value,
  required ValueChanged<String?> onChanged,
}) {
  final staff = opts?.staff ?? const [];
  final chosen = value ?? opts?.me;
  return DropdownButtonFormField<String>(
    key: ValueKey('$key:${staff.length}'),
    initialValue: staff.any((p) => p.user == chosen) ? chosen : null,
    isExpanded: true,
    items: [
      for (final p in staff)
        DropdownMenuItem(value: p.user, child: Text(p.name)),
    ],
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label),
  );
}

/// «Приход»: a roll or a cut from a wholesaler — metres at a price a metre.
Future<bool?> showFilmReceive(BuildContext context, Film film, FilmCatalog c) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _ReceiveDialog(film: film, catalog: c),
    );

class _ReceiveDialog extends ConsumerStatefulWidget {
  const _ReceiveDialog({required this.film, required this.catalog});

  final Film film;
  final FilmCatalog catalog;

  @override
  ConsumerState<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends ConsumerState<_ReceiveDialog> with _Saving {
  final _metres = TextEditingController();
  late final _price = TextEditingController(
    text: widget.film.priceM?.toStringAsFixed(0),
  );
  // Only where this maker's film is bought (owner, 11.11.2026).
  late final List<({String id, String name})> _sources = widget.catalog
      .suppliersFor(widget.film.maker);
  late String? _supplier = _sources.any((s) => s.id == widget.film.supplier)
      ? widget.film.supplier
      : _sources.firstOrNull?.id;

  /// The price paid becomes the card's purchase price — unless unticked,
  /// for a one-off discount (owner, 11.11.2026).
  bool _updatePrice = true;

  // How it came (owner, 11.11.2026): by default as this supplier's last
  // roll came, from the city on its card; nothing paid; taken in by me.
  final _cost = TextEditingController();

  // Who brought it and how to reach him — optional (owner, 12.11.2026).
  final _driver = TextEditingController();
  final _phone = TextEditingController();

  /// When it arrives (owner, 11.11.2026): in two days unless said; 0 — it
  /// is here already. A day picked on the calendar wins.
  int _inDays = 2;
  DateTime? _picked;

  DateTime? get _due {
    if (_picked != null) return _picked;
    if (_inDays == 0) return null;
    // A Sunday — the shop's day off — moves to Monday (12.11.2026).
    return mdfDueIn(DateTime.now(), days: _inDays);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked == null || !mounted) return;
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _picked = picked.isAfter(today) ? picked : null;
      if (_picked == null) _inDays = 0;
    });
  }

  String? _transport;
  String? _city;
  String? _taker;
  bool _urgent = false;

  // Who paid for the bringing (owner, 11.11.2026): the film department's
  // cash, in cash, unless said.
  String _payer = FilmPayer.cash;
  String? _paidBy;
  String _payMethod = filmCash;

  String? _transportOf(FilmDeliveryOptions? o) =>
      _transport ?? o?.last[_supplier]?.transport ?? o?.transports.firstOrNull;

  String? _cityOf(FilmDeliveryOptions? o) =>
      _city ?? o?.last[_supplier]?.city ?? o?.supplierCities[_supplier];

  Future<void> _editList(MdfDictKind kind, String title, String? now) async {
    final picked = await showMdfDictionary(
      context,
      kind,
      title: title,
      current: now,
    );
    if (!mounted) return;
    ref.invalidate(filmDeliveryOptionsProvider);
    if (picked != null) {
      setState(() {
        if (kind == MdfDictKind.transport) {
          _transport = picked;
        } else {
          _city = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _metres.dispose();
    _price.dispose();
    _cost.dispose();
    _driver.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metres = _number(_metres.text) ?? 0;
    final price = _number(_price.text) ?? 0;
    final cost = _number(_cost.text) ?? 0;
    final opts = ref.watch(filmDeliveryOptionsProvider).value;
    final transport = _transportOf(opts);
    final city = _cityOf(opts);
    final cities = {...?opts?.cities, ?city}.toList();
    final money = mdfMoney(context);
    return AlertDialog(
      title: Text('${l10n.filmReceive} · ${filmName(widget.film)}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metresField(
                _metres,
                l10n.filmMetresLabel,
                () => setState(() {}),
              ),
              TextField(
                key: const ValueKey('filmPrice'),
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.filmPriceM),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('filmSupplier'),
                initialValue: _supplier,
                items: [
                  for (final s in _sources)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _supplier = v),
                decoration: InputDecoration(labelText: l10n.filmReceiveFrom),
              ),
              if (price > 0 && price != widget.film.priceM)
                CheckboxListTile(
                  key: const ValueKey('filmReceiveUpdatePrice'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _updatePrice,
                  onChanged: (v) => setState(() => _updatePrice = v ?? false),
                  title: Text(
                    widget.film.priceM == null
                        ? l10n.filmReceiveSetPrice(price.toStringAsFixed(0))
                        : l10n.filmReceiveUpdatePrice(
                            widget.film.priceM!.toStringAsFixed(0),
                            price.toStringAsFixed(0),
                          ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.filmArrival,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (days, label) in [
                    (0, l10n.filmArrivalHere),
                    (1, l10n.filmArrivalTomorrow),
                    (2, l10n.filmArrivalTwo),
                    (3, l10n.filmArrivalThree),
                    (7, l10n.filmArrivalWeek),
                  ])
                    ChoiceChip(
                      key: ValueKey('filmArrival:$days'),
                      label: Text(label),
                      selected: _picked == null && _inDays == days,
                      onSelected: (_) => setState(() {
                        _picked = null;
                        _inDays = days;
                      }),
                    ),
                  ActionChip(
                    key: const ValueKey('filmArrival:pick'),
                    avatar: const Icon(AppIcons.calendar),
                    label: Text(
                      _picked == null
                          ? l10n.filmArrivalPick
                          : mdfDayOf(_picked!),
                    ),
                    onPressed: _pickDay,
                  ),
                ],
              ),
              if (_due case final due?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.filmArrivesOn(_dayName(context, due)),
                    key: const ValueKey('filmArrival:day'),
                  ),
                ),
              if (opts != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.filmDelivery,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                _withList(
                  context,
                  key: 'filmDelivery:transport:edit',
                  onEdit: () => _editList(
                    MdfDictKind.transport,
                    l10n.filmTransport,
                    transport,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final t in opts.transports)
                        ChoiceChip(
                          key: ValueKey('filmDelivery:transport:$t'),
                          label: Text(t),
                          selected: t == transport,
                          onSelected: (_) => setState(() => _transport = t),
                        ),
                    ],
                  ),
                ),
                _withList(
                  context,
                  key: 'filmDelivery:city:edit',
                  onEdit: () =>
                      _editList(MdfDictKind.city, l10n.filmCity, city),
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('filmDelivery:city:$city:${cities.length}'),
                    initialValue: city,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(child: Text(l10n.mdfNone)),
                      for (final c in cities)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _city = v),
                    decoration: InputDecoration(labelText: l10n.filmCity),
                  ),
                ),
                TextField(
                  key: const ValueKey('filmDelivery:cost'),
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.filmDeliveryCost,
                    // What bringing it added to each metre.
                    helperText: cost > 0 && metres > 0
                        ? l10n.filmDeliveryPerM(money.format(cost / metres))
                        : null,
                  ),
                ),
                if (cost > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.filmDeliveryPayer),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final (p, label) in [
                        (FilmPayer.cash, l10n.filmPayerCash),
                        (FilmPayer.employee, l10n.filmPayerEmployee),
                        (FilmPayer.unpaid, l10n.filmPayerUnpaid),
                      ])
                        ChoiceChip(
                          key: ValueKey('filmDelivery:payer:$p'),
                          label: Text(label),
                          selected: _payer == p,
                          onSelected: (_) => setState(() => _payer = p),
                        ),
                    ],
                  ),
                  if (_payer == FilmPayer.employee)
                    _personField(
                      key: 'filmDelivery:paidBy',
                      label: l10n.filmPaidBy,
                      opts: opts,
                      value: _paidBy,
                      onChanged: (v) => setState(() => _paidBy = v),
                    ),
                  if (_payer != FilmPayer.unpaid)
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final (m, label) in [
                          (filmCash, l10n.mdfPayCash),
                          (filmTransfer, l10n.mdfPayTransfer),
                          (filmCard, l10n.mdfPayCard),
                        ])
                          ChoiceChip(
                            key: ValueKey('filmDelivery:method:$m'),
                            label: Text(label),
                            selected: _payMethod == m,
                            onSelected: (_) => setState(() => _payMethod = m),
                          ),
                      ],
                    ),
                ],
                // Drivers who brought film before: a tap fills both.
                if (opts.drivers.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final d in opts.drivers.take(6))
                        ActionChip(
                          key: ValueKey('filmDelivery:driver:${d.driver}'),
                          label: Text([d.driver, ?d.phone].join(' · ')),
                          onPressed: () => setState(() {
                            _driver.text = d.driver;
                            _phone.text = d.phone ?? '';
                          }),
                        ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('filmDelivery:driver'),
                        controller: _driver,
                        decoration: InputDecoration(
                          labelText: l10n.filmDriver,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('filmDelivery:phone'),
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: l10n.filmDriverPhone,
                        ),
                      ),
                    ),
                  ],
                ),
                _personField(
                  key: 'filmDelivery:taker',
                  label: l10n.filmReceivedBy,
                  opts: opts,
                  value: _taker,
                  onChanged: (v) => setState(() => _taker = v),
                ),
                CheckboxListTile(
                  key: const ValueKey('filmDelivery:urgent'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v ?? false),
                  title: Text(l10n.filmUrgent),
                ),
              ],
              errorLine(context),
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
          key: const ValueKey('filmReceiveSave'),
          onPressed: busy || metres <= 0 || price <= 0 || _supplier == null
              ? null
              : () => save(
                  () => ref
                      .read(filmDeptRepositoryProvider)
                      .receive(
                        item: widget.film.item,
                        metres: metres,
                        priceM: price,
                        supplier: _supplier!,
                        updatePrice: _updatePrice,
                        delivery: opts == null
                            ? null
                            : {
                                'transport': transport,
                                'city': city ?? '',
                                'amount': cost,
                                'urgent': _urgent,
                                if (_driver.text.trim().isNotEmpty)
                                  'driver': _driver.text.trim(),
                                if (_phone.text.trim().isNotEmpty)
                                  'phone': _phone.text.trim(),
                                if (cost > 0) ...{
                                  'payer': _payer,
                                  if (_payer == FilmPayer.employee)
                                    'paid_by': _paidBy ?? opts.me,
                                  if (_payer != FilmPayer.unpaid)
                                    'method': _payMethod,
                                },
                              },
                        receivedBy: opts == null ? null : _taker ?? opts.me,
                        arrivesOn: _due == null ? null : mdfIso(_due!),
                      ),
                ),
          // On its way: ordered, not taken in yet.
          child: Text(
            _due == null ? l10n.filmReceive : l10n.filmArrivalOrder,
          ),
        ),
      ],
    );
  }
}

/// «В цех» and «Списать»: metres off the shelf — to our own press, with an
/// order's number if there is one; or gone, with a reason that must be said.
Future<bool?> showFilmIssue(
  BuildContext context,
  Film film, {
  required bool writeOff,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _IssueDialog(film: film, writeOff: writeOff),
);

class _IssueDialog extends ConsumerStatefulWidget {
  const _IssueDialog({required this.film, required this.writeOff});

  final Film film;
  final bool writeOff;

  @override
  ConsumerState<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends ConsumerState<_IssueDialog> with _Saving {
  final _metres = TextEditingController();
  final _text = TextEditingController();
  String? _chip;

  @override
  void dispose() {
    _metres.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final off = widget.writeOff;
    final metres = _number(_metres.text) ?? 0;
    final reason = [
      ?_chip,
      if (_text.text.trim().isNotEmpty) _text.text.trim(),
    ].join(' — ');
    final over = metres > widget.film.free + 0.0001;
    final reasons = [
      l10n.filmReasonSample,
      l10n.filmReasonDamaged,
      l10n.filmReasonTest,
    ];
    final what = off ? l10n.filmWriteOff : l10n.filmToShop;
    return AlertDialog(
      title: Text('$what · ${filmName(widget.film)}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.filmHave(filmMetres(widget.film.free))),
            _metresField(_metres, l10n.filmMetresLabel, () => setState(() {})),
            if (over)
              Text(
                l10n.filmNotEnough,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (off)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final (i, r) in reasons.indexed)
                    ChoiceChip(
                      key: ValueKey('filmReason:$i'),
                      label: Text(r),
                      selected: _chip == r,
                      onSelected: (on) => setState(() => _chip = on ? r : null),
                    ),
                ],
              ),
            TextField(
              key: const ValueKey('filmIssueText'),
              controller: _text,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: off ? l10n.filmReason : l10n.filmForOrder,
              ),
            ),
            errorLine(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmIssueSave'),
          onPressed: busy || metres <= 0 || over || (off && reason.length < 3)
              ? null
              : () => save(() {
                  final repo = ref.read(filmDeptRepositoryProvider);
                  return off
                      ? repo.writeOff(
                          item: widget.film.item,
                          metres: metres,
                          reason: reason,
                        )
                      : repo.toShop(
                          item: widget.film.item,
                          metres: metres,
                          order: _text.text.trim().isEmpty
                              ? null
                              : _text.text.trim(),
                        );
                }),
          child: Text(off ? l10n.filmWriteOff : l10n.filmToShop),
        ),
      ],
    );
  }
}

/// One way a sale is paid (owner, 11.11.2026): the method, its bank, the
/// sum — cash and a transfer at once, as on an order's payment.
class _PayPart {
  _PayPart({this.method = filmCash, String amount = ''})
    : amount = TextEditingController(text: amount);

  String method;
  String? bank;
  final TextEditingController amount;

  double get value => _number(amount.text) ?? 0;

  void dispose() => amount.dispose();
}

class _SaleLine {
  _SaleLine(this.film);

  Film film;
  final metres = TextEditingController();
  final price = TextEditingController();

  /// The card has no price for this customer's tier: the seller types one,
  /// and it is remembered on the card unless unticked (11.11.2026).
  bool cardless = false;
  bool wholesale = false;
  bool remember = true;

  double get m => _number(metres.text) ?? 0;
  double get p => _number(price.text) ?? 0;
  double get sum => (m * p).roundToDouble();

  /// Put by for this sale's customer: his to take besides what is free.
  double mine = 0;

  /// What this customer may take: what is free and what is put by for him.
  double get have => film.free + mine;

  /// More typed than is free on the shelf.
  bool get over => m > have + 0.0001;

  /// What stays on the shelf after this sale.
  double get left => film.free + mine - m;

  /// What stays is under the film's minimum: time to order.
  bool get low =>
      m > 0 && !over && film.minStock != null && left < film.minStock!;

  void dispose() {
    metres.dispose();
    price.dispose();
  }
}

/// «Продажа»: a customer, one film or several by the metre, what is paid
/// now — the rest is the customer's debt. A metre's price comes from the
/// customer's card (retail or trade, less the discount) and may be retyped.
Future<bool?> showFilmSale(
  BuildContext context,
  FilmCatalog stock, {
  Film? film,
  String? customer,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _SaleDialog(stock: stock, film: film, customer: customer),
);

class _SaleDialog extends ConsumerStatefulWidget {
  const _SaleDialog({required this.stock, this.film, this.customer});

  final FilmCatalog stock;
  final Film? film;
  final String? customer;

  @override
  ConsumerState<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends ConsumerState<_SaleDialog> with _Saving {
  final _lines = <_SaleLine>[];
  final _parts = [_PayPart()];
  late String? _customer = widget.customer;

  /// Who sold it — the one signed in unless said otherwise; the team's
  /// bonus is counted by seller (owner, 11.11.2026).
  String? _seller;

  /// Who cuts and hands it out — the seller unless said (owner,
  /// 12.11.2026).
  String? _issuer;

  /// Whether the seller touched a sum: until then the one part follows the
  /// sale's total, «paid in full».
  bool _paidTouched = false;

  /// What can be sold: named, and with metres on the shelf — a film in
  /// the archive too, until its metres are sold out (11.11.2026).
  late final List<Film> _films = [
    for (final f in widget.stock.films)
      if (f.label != null && (f.free > 0 || f.holds.isNotEmpty)) f,
  ];

  @override
  void initState() {
    super.initState();
    final first = widget.film ?? _films.firstOrNull;
    if (first != null) _add(first);
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  void _add(Film film) {
    final line = _SaleLine(film);
    _lines.add(line);
    unawaited(_reprice(line));
  }

  /// The customer's price for this film — unless the seller typed one.
  Future<void> _reprice(_SaleLine line) async {
    try {
      final price = await ref
          .read(filmDeptRepositoryProvider)
          .priceFor(line.film.item, customer: _customer);
      if (!mounted) return;
      setState(() {
        line
          ..cardless = price.priceM == null
          ..wholesale = price.wholesale;
        if (price.priceM != null) {
          line.price.text = price.priceM!.toStringAsFixed(0);
        }
      });
      _fillPaid();
    } on Object {
      // No price on the card yet: the seller types it.
    }
  }

  double get _sum => _lines.fold(0, (s, l) => s + l.sum);

  void _fillPaid() {
    if (!_paidTouched && _parts.length == 1) {
      _parts.single.amount.text = _sum.toStringAsFixed(0);
    }
  }

  double get _paid => _parts.fold(0, (s, p) => s + p.value);

  /// «+ ещё способ»: a new part takes what is left to pay.
  void _addPart() => setState(() {
    _paidTouched = true;
    final left = _sum - _paid;
    _parts.add(
      _PayPart(
        method: filmTransfer,
        amount: left > 0 ? left.toStringAsFixed(0) : '',
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final customers =
        ref.watch(mdfCustomersProvider).value ?? const <FacadeCustomer>[];
    final banks =
        (ref.watch(mdfDictionariesProvider).value ?? MdfDictionaries.empty)
            .values(MdfDictKind.bank);
    final sellers = ref.watch(filmDeliveryOptionsProvider).value;
    for (final l in _lines) {
      l.mine = l.film.heldFor(_customer);
    }
    final paid = _paid;
    final ok =
        _customer != null &&
        _lines.isNotEmpty &&
        _lines.every(
          (l) => l.m > 0 && l.p > 0 && !l.over,
        ) &&
        paid <= _sum + 0.5;
    String label(String m) => switch (m) {
      filmTransfer => l10n.mdfPayTransfer,
      filmCash => l10n.mdfPayCash,
      _ => l10n.mdfPayCard,
    };
    return AlertDialog(
      title: Text(l10n.filmSell),
      content: SizedBox(
        width: AppSpacing.xxxl * 12,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('filmSaleCustomer:${customers.length}'),
                initialValue: customers.any((c) => c.name == _customer)
                    ? _customer
                    : null,
                isExpanded: true,
                items: [
                  for (final c in customers)
                    DropdownMenuItem(value: c.name, child: Text(c.title)),
                ],
                onChanged: (v) {
                  setState(() => _customer = v);
                  for (final l in _lines) {
                    unawaited(_reprice(l));
                  }
                },
                decoration: InputDecoration(labelText: l10n.mdfCustomer),
              ),
              if (sellers != null && sellers.staff.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: _personField(
                        key: 'filmSaleSeller',
                        label: l10n.filmSeller,
                        opts: sellers,
                        value: _seller,
                        onChanged: (v) => setState(() => _seller = v),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _personField(
                        key: 'filmSaleIssuer',
                        label: l10n.filmIssuedBy,
                        opts: sellers,
                        value: _issuer ?? _seller,
                        onChanged: (v) => setState(() => _issuer = v),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              for (final (i, line) in _lines.indexed) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('filmSaleFilm:$i'),
                          initialValue: line.film.item,
                          isExpanded: true,
                          items: [
                            for (final f in {..._films, line.film})
                              DropdownMenuItem(
                                value: f.item,
                                child: Text(
                                  '${filmName(f)} · ${filmMetres(f.free)} м',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            final f = {..._films, line.film}.firstWhere(
                              (f) => f.item == v,
                            );
                            setState(() => line.film = f);
                            unawaited(_reprice(line));
                          },
                          decoration: InputDecoration(
                            labelText: l10n.filmAdd,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: ValueKey('filmSaleMetres:$i'),
                          controller: line.metres,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[0-9.,]'),
                            ),
                          ],
                          onChanged: (_) => setState(_fillPaid),
                          decoration: InputDecoration(
                            labelText: l10n.filmMetresLabel,
                            // Red when too much; the words go on a line
                            // of their own below, so the three fields
                            // stay level (owner, 12.11.2026).
                            error: line.over ? const SizedBox.shrink() : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: ValueKey('filmSalePrice:$i'),
                          controller: line.price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(_fillPaid),
                          decoration: InputDecoration(
                            labelText: l10n.filmSalePriceM,
                          ),
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(
                          key: ValueKey('filmSaleRemove:$i'),
                          icon: const Icon(AppIcons.close),
                          onPressed: () => setState(() {
                            _lines.removeAt(i).dispose();
                            _fillPaid();
                          }),
                        ),
                    ],
                  ),
                ),
                // What stays on the shelf, as it is typed — in full
                // (owner, 11.11.2026).
                if (line.m > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      line.over
                          ? l10n.filmOnlyHave(filmMetres(line.have))
                          : line.low
                          ? l10n.filmLeftLow(filmMetres(line.left))
                          : l10n.filmLeft(filmMetres(line.left)),
                      key: ValueKey('filmSaleLeft:$i'),
                      style: TextStyle(
                        color: line.over
                            ? Theme.of(context).colorScheme.error
                            : line.low
                            ? context.statusColors.warning
                            : context.statusColors.success,
                      ),
                    ),
                  ),
                if (line.over || line.low)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (line.over && line.have > 0)
                          ActionChip(
                            key: ValueKey('filmSaleAll:$i'),
                            label: Text(
                              l10n.filmTakeAll(filmMetres(line.have)),
                            ),
                            onPressed: () => setState(() {
                              line.metres.text = filmMetres(line.have);
                              _fillPaid();
                            }),
                          ),
                        for (final c in line.film.coming)
                          Chip(
                            key: ValueKey('filmSaleComing:$i:${c.entry}'),
                            avatar: const Icon(AppIcons.delivery),
                            label: Text(
                              l10n.filmMoreComing(
                                filmMetres(c.metres),
                                mdfDay(c.due, year: false),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (line.cardless && line.p > 0)
                  CheckboxListTile(
                    key: ValueKey('filmSaleRemember:$i'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: line.remember,
                    onChanged: (v) =>
                        setState(() => line.remember = v ?? false),
                    title: Text(
                      line.wholesale
                          ? l10n.filmSaleRememberWholesale(
                              line.p.toStringAsFixed(0),
                            )
                          : l10n.filmSaleRememberRetail(
                              line.p.toStringAsFixed(0),
                            ),
                    ),
                  ),
              ],
              if (_films.length > _lines.length)
                TextButton.icon(
                  key: const ValueKey('filmSaleAddLine'),
                  onPressed: () => setState(() {
                    final used = {for (final l in _lines) l.film.item};
                    _add(_films.firstWhere((f) => !used.contains(f.item)));
                  }),
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.filmSaleAddLine),
                ),
              Text(
                l10n.filmSaleTotal(money.format(_sum)),
                key: const ValueKey('filmSaleTotal'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              // How it is paid — one way or several (owner, 11.11.2026).
              for (final (i, p) in _parts.indexed)
                Padding(
                  key: ValueKey('filmSalePart:$i'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Wrap(
                            spacing: AppSpacing.xs,
                            children: [
                              for (final m in const [
                                filmCash,
                                filmTransfer,
                                filmCard,
                              ])
                                ChoiceChip(
                                  key: ValueKey(
                                    i == 0
                                        ? 'filmSaleMethod:$m'
                                        : 'filmSaleMethod:$i:$m',
                                  ),
                                  label: Text(label(m)),
                                  selected: p.method == m,
                                  onSelected: (_) =>
                                      setState(() => p.method = m),
                                ),
                            ],
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Spacer(),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: AppSpacing.xxxl * 3,
                            child: TextField(
                              key: ValueKey(
                                i == 0 ? 'filmSalePaid' : 'filmSalePaid:$i',
                              ),
                              controller: p.amount,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) =>
                                  setState(() => _paidTouched = true),
                              decoration: InputDecoration(
                                labelText: l10n.filmSalePaid,
                              ),
                            ),
                          ),
                          if (_parts.length > 1)
                            IconButton(
                              key: ValueKey('filmSalePartRemove:$i'),
                              icon: const Icon(AppIcons.close),
                              onPressed: () => setState(() {
                                _parts.removeAt(i).dispose();
                              }),
                            ),
                        ],
                      ),
                      // The bank on a line of its own: beside the chips
                      // its name did not fit (owner, 12.11.2026).
                      if (p.method != filmCash)
                        DropdownButtonFormField<String?>(
                          key: ValueKey('filmSaleBank:$i:${banks.length}'),
                          initialValue: banks.contains(p.bank) ? p.bank : null,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(child: Text(l10n.mdfNone)),
                            for (final b in banks)
                              DropdownMenuItem(value: b, child: Text(b)),
                          ],
                          onChanged: (v) => setState(() => p.bank = v),
                          decoration: InputDecoration(
                            labelText: l10n.mdfPayBank,
                          ),
                        ),
                    ],
                  ),
                ),
              if (_parts.length < 4)
                TextButton.icon(
                  key: const ValueKey('filmSaleAddPart'),
                  onPressed: _addPart,
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.filmSaleAddPart),
                ),
              Text(
                paid > _sum + 0.5
                    ? l10n.filmSaleOverpaid(money.format(paid - _sum))
                    : paid < _sum
                    ? l10n.filmSaleDebt(money.format(_sum - paid))
                    : l10n.filmSalePaidFull,
                key: const ValueKey('filmSaleBalance'),
                style: TextStyle(
                  color: paid > _sum + 0.5 ? theme.colorScheme.error : null,
                ),
              ),
              errorLine(context),
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
          key: const ValueKey('filmSaleSave'),
          onPressed: busy || !ok
              ? null
              : () => save(
                  () => ref
                      .read(filmDeptRepositoryProvider)
                      .sell(
                        customer: _customer!,
                        lines: [
                          for (final l in _lines)
                            (item: l.film.item, metres: l.m, priceM: l.p),
                        ],
                        remember: {
                          for (final l in _lines)
                            if (l.cardless && l.remember) l.film.item,
                        },
                        payments: [
                          for (final p in _parts)
                            if (p.value > 0)
                              (
                                amount: p.value,
                                method: p.method,
                                bank: p.method != filmCash ? p.bank : null,
                              ),
                        ],
                        seller: _seller ?? sellers?.me,
                        issuedBy: _issuer ?? _seller ?? sellers?.me,
                      ),
                ),
          child: Text(l10n.filmSell),
        ),
      ],
    );
  }
}

/// The customer's film terms, on the customer's own card: retail or trade,
/// and a discount of their own.
Future<bool?> showFilmCustomerTerms(BuildContext context, FilmCustomer c) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _TermsDialog(customer: c),
    );

class _TermsDialog extends ConsumerStatefulWidget {
  const _TermsDialog({required this.customer});

  final FilmCustomer customer;

  @override
  ConsumerState<_TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends ConsumerState<_TermsDialog> with _Saving {
  late bool _wholesale = widget.customer.wholesale;
  late final _discount = TextEditingController(
    text: filmMetres(widget.customer.discount),
  );

  @override
  void dispose() {
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final discount = _number(_discount.text) ?? 0;
    return AlertDialog(
      title: Text(widget.customer.name),
      content: SizedBox(
        width: AppSpacing.xxxl * 7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  key: const ValueKey('filmTier:retail'),
                  label: Text(l10n.filmRetail),
                  selected: !_wholesale,
                  onSelected: (_) => setState(() => _wholesale = false),
                ),
                ChoiceChip(
                  key: const ValueKey('filmTier:wholesale'),
                  label: Text(l10n.filmWholesale),
                  selected: _wholesale,
                  onSelected: (_) => setState(() => _wholesale = true),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('filmDiscount'),
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.filmDiscount),
            ),
            errorLine(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmTermsSave'),
          onPressed: busy || discount < 0 || discount > 50
              ? null
              : () => save(
                  () => ref
                      .read(filmDeptRepositoryProvider)
                      .setCustomer(
                        widget.customer.customer,
                        wholesale: _wholesale,
                        discount: discount,
                      ),
                ),
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}

/// A sale opened from the list: what was sold, what is paid — and the two
/// things done to it afterwards: more money against a debt, and a cancel
/// for one entered by mistake (the metres go back on the shelf).
Future<bool?> showFilmSaleCard(BuildContext context, FilmSale sale) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _SaleCardDialog(sale: sale),
    );

class _SaleCardDialog extends ConsumerStatefulWidget {
  const _SaleCardDialog({required this.sale});

  final FilmSale sale;

  @override
  ConsumerState<_SaleCardDialog> createState() => _SaleCardDialogState();
}

class _SaleCardDialogState extends ConsumerState<_SaleCardDialog> with _Saving {
  late final _amount = TextEditingController(
    text: (widget.sale.debt ?? 0) > 0
        ? widget.sale.debt!.toStringAsFixed(0)
        : '',
  );
  String _method = filmCash;
  String? _bank;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final reason = await showReasonDialog(
      context,
      title: l10n.filmCancelMove,
      label: l10n.filmCancelReason,
      confirm: l10n.mdfConfirm,
      cancel: l10n.mdfCancel,
      fieldKey: const ValueKey('filmCancelReason'),
    );
    if (reason == null) return;
    await save(
      () => ref
          .read(filmDeptRepositoryProvider)
          .cancel(widget.sale.entry, reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final s = widget.sale;
    final debt = s.debt ?? 0;
    final banks =
        (ref.watch(mdfDictionariesProvider).value ?? MdfDictionaries.empty)
            .values(MdfDictKind.bank);
    final amount = _number(_amount.text) ?? 0;
    String label(String m) => switch (m) {
      filmTransfer => l10n.mdfPayTransfer,
      filmCash => l10n.mdfPayCash,
      _ => l10n.mdfPayCard,
    };
    return AlertDialog(
      title: Text(s.customerName ?? l10n.filmMoveSale),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in s.lines)
                Text(
                  [
                    l.title,
                    '${filmMetres(l.metres)} м',
                    if (l.priceM != null) '${money.format(l.priceM)}/м',
                  ].join(' · '),
                ),
              const SizedBox(height: AppSpacing.sm),
              if (s.amount != null)
                Text(
                  l10n.filmSaleTotal(money.format(s.amount)),
                  style: theme.textTheme.titleMedium,
                ),
              // Every payment, each its way (owner, 11.11.2026).
              for (final (i, p) in s.payments.indexed)
                Text(
                  [
                    if (p.date.isNotEmpty) p.date,
                    p.method,
                    ?p.bank,
                    money.format(p.amount),
                  ].join(' · '),
                  key: ValueKey('filmSaleCardPayment:$i'),
                ),
              if (debt > 0) ...[
                Text(
                  l10n.filmSaleDebt(money.format(debt)),
                  key: const ValueKey('filmSaleCardDebt'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                TextField(
                  key: const ValueKey('filmPayAmount'),
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l10n.filmPayDebt),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final m in const [filmCash, filmTransfer, filmCard])
                      ChoiceChip(
                        key: ValueKey('filmPayMethod:$m'),
                        label: Text(label(m)),
                        selected: _method == m,
                        onSelected: (_) => setState(() => _method = m),
                      ),
                  ],
                ),
                if (_method != filmCash)
                  DropdownButtonFormField<String?>(
                    key: ValueKey('filmPayBank:${banks.length}'),
                    initialValue: banks.contains(_bank) ? _bank : null,
                    items: [
                      DropdownMenuItem(child: Text(l10n.mdfNone)),
                      for (final b in banks)
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => _bank = v),
                    decoration: InputDecoration(labelText: l10n.mdfPayBank),
                  ),
              ],
              errorLine(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('filmSaleCancel'),
          onPressed: busy ? null : _cancel,
          child: Text(l10n.filmCancelMove),
        ),
        // The customer's receipt, to send or print (owner, 11.11.2026).
        TextButton.icon(
          key: const ValueKey('filmSaleReceipt'),
          onPressed: () async {
            final locale = Localizations.localeOf(context).toString();
            final bytes = await buildFilmReceiptPdf(widget.sale, (
              title: l10n.filmReceipt,
              date: l10n.filmReceiptDate,
              customer: l10n.filmReceiptCustomer,
              film: l10n.filmReceiptFilm,
              metres: l10n.filmReceiptMetres,
              price: l10n.filmReceiptPrice,
              amount: l10n.filmReceiptAmount,
              total: l10n.filmReceiptTotal,
              paid: l10n.filmReceiptPaid,
              debt: l10n.filmReceiptDebt,
              payment: l10n.filmReceiptPayment,
              method: (m) => switch (m) {
                filmCash => l10n.mdfPayCash,
                filmTransfer => l10n.mdfPayTransfer,
                filmCard => l10n.mdfPayCard,
                _ => m,
              },
              servedBy: l10n.filmReceiptServedBy,
              phone: l10n.filmReceiptPhone,
              signedSold: l10n.filmReceiptSignSold,
              issuedBy: l10n.filmReceiptIssuedBy,
              signedIssued: l10n.filmReceiptSignIssued,
              signedGot: l10n.filmReceiptSignGot,
              code: l10n.filmReceiptCode,
              thickness: (mm) => l10n.filmReceiptThickness(filmMetres(mm)),
              thanks: l10n.filmReceiptThanks,
              wish: l10n.filmReceiptWish,
            ), locale: locale);
            await shareFilmReceipt(widget.sale, bytes);
          },
          icon: const Icon(AppIcons.share),
          label: Text(l10n.filmReceipt),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.filmClose),
        ),
        if (debt > 0)
          FilledButton(
            key: const ValueKey('filmPaySave'),
            onPressed: busy || amount <= 0 || amount > debt + 0.5
                ? null
                : () => save(
                    () => ref
                        .read(filmDeptRepositoryProvider)
                        .pay(
                          s.entry,
                          amount: amount,
                          method: _method,
                          bank: _method != filmCash ? _bank : null,
                        ),
                  ),
            child: Text(l10n.filmPayDebt),
          ),
      ],
    );
  }
}

/// A movement of the film's history opened to be put right (owner,
/// 11.11.2026: «менеджер может затупить»): the same figures to change, why
/// — a must — and, for one that should not be there at all, a cancel.
Future<bool?> showFilmCorrect(
  BuildContext context, {
  required FilmMove move,
  required Film film,
  required FilmCatalog stock,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _CorrectDialog(move: move, film: film, stock: stock),
);

class _CorrectDialog extends ConsumerStatefulWidget {
  const _CorrectDialog({
    required this.move,
    required this.film,
    required this.stock,
  });

  final FilmMove move;
  final Film film;
  final FilmCatalog stock;

  @override
  ConsumerState<_CorrectDialog> createState() => _CorrectDialogState();
}

class _CorrectDialogState extends ConsumerState<_CorrectDialog> with _Saving {
  late final _metres = TextEditingController(
    text: filmMetres(widget.move.metres.abs()),
  );
  late final _price = TextEditingController(
    text: widget.move.priceM?.toStringAsFixed(0),
  );
  late final _order = TextEditingController(text: widget.move.party);
  late final _why = TextEditingController(text: widget.move.reason);
  final _reason = TextEditingController();

  /// A receipt's supplier: null keeps the one it has.
  String? _supplier;

  FilmMoveKind get _kind => widget.move.kind;

  @override
  void dispose() {
    for (final c in [_metres, _price, _order, _why, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = widget.move;
    final metres = _number(_metres.text) ?? 0;
    final reason = _reason.text.trim();
    final repo = ref.read(filmDeptRepositoryProvider);
    final priced = _kind == FilmMoveKind.receipt || _kind == FilmMoveKind.sale;
    return AlertDialog(
      title: Text(
        '${l10n.filmCorrectTitle} · ${mdfDay(m.date)} · '
        '${filmName(widget.film)}',
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metresField(
                _metres,
                l10n.filmMetresLabel,
                () => setState(() {}),
              ),
              if (priced && m.priceM != null)
                TextField(
                  key: const ValueKey('filmCorrect:price'),
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.filmSalePriceM),
                ),
              if (_kind == FilmMoveKind.receipt)
                DropdownButtonFormField<String?>(
                  key: const ValueKey('filmCorrect:supplier'),
                  initialValue: _supplier,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      child: Text(m.party ?? l10n.mdfNone),
                    ),
                    for (final s in widget.stock.suppliersFor(
                      widget.film.maker,
                    ))
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplier = v),
                  decoration: InputDecoration(
                    labelText: l10n.filmReceiveFrom,
                  ),
                ),
              if (_kind == FilmMoveKind.shop)
                TextField(
                  key: const ValueKey('filmCorrect:order'),
                  controller: _order,
                  decoration: InputDecoration(labelText: l10n.filmForOrder),
                ),
              if (_kind == FilmMoveKind.writeOff)
                TextField(
                  key: const ValueKey('filmCorrect:why'),
                  controller: _why,
                  decoration: InputDecoration(
                    labelText: l10n.filmReason,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('filmCorrect:reason'),
                controller: _reason,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.filmCorrectReason,
                  helperText: l10n.filmCorrectHint,
                  helperMaxLines: 2,
                ),
              ),
              errorLine(context),
            ],
          ),
        ),
      ),
      actions: [
        // A receipt is put right, never cancelled here: its metres may be
        // sold already.
        if (_kind != FilmMoveKind.receipt)
          TextButton(
            key: const ValueKey('filmCorrect:cancel'),
            onPressed: busy || reason.length < 3
                ? null
                : () => save(() => repo.cancel(m.entry, reason)),
            child: Text(l10n.filmCorrectCancel),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmCorrect:save'),
          onPressed: busy || reason.length < 3 || metres <= 0
              ? null
              : () => save(
                  () => repo.correct(
                    entry: m.entry,
                    item: widget.film.item,
                    reason: reason,
                    metres: metres,
                    priceM: priced && m.priceM != null
                        ? _number(_price.text)
                        : null,
                    supplier: _supplier,
                    order: _kind == FilmMoveKind.shop
                        ? _order.text.trim()
                        : null,
                    why: _kind == FilmMoveKind.writeOff
                        ? _why.text.trim()
                        : null,
                  ),
                ),
          child: Text(l10n.filmCorrectSave),
        ),
      ],
    );
  }
}

/// «Пришла»: the roll on its way is here — as many metres as were ordered
/// unless fewer (or more) came. Returns the metres, or null if not saved.
Future<double?> showFilmArrived(BuildContext context, FilmComing coming) =>
    showDialog<double>(
      context: context,
      builder: (_) => _ArrivedDialog(coming: coming),
    );

class _ArrivedDialog extends StatefulWidget {
  const _ArrivedDialog({required this.coming});

  final FilmComing coming;

  @override
  State<_ArrivedDialog> createState() => _ArrivedDialogState();
}

class _ArrivedDialogState extends State<_ArrivedDialog> {
  late final _metres = TextEditingController(
    text: filmMetres(widget.coming.metres),
  );

  @override
  void dispose() {
    _metres.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metres = _number(_metres.text) ?? 0;
    return AlertDialog(
      title: Text(l10n.filmComingArrived),
      content: SizedBox(
        width: AppSpacing.xxxl * 6,
        child: _metresField(
          _metres,
          l10n.filmComingMetres,
          () => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmArrivedSave'),
          onPressed: metres <= 0
              ? null
              : () => Navigator.of(context).pop(metres),
          child: Text(l10n.filmComingArrived),
        ),
      ],
    );
  }
}

/// «Заказать»: every film that ran low, as last time — metres, from whom,
/// at what — each can be changed or left out; all go on their way at once,
/// due in two days (owner, 11.11.2026).
Future<bool?> showFilmReorder(BuildContext context, FilmCatalog stock) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _ReorderDialog(stock: stock),
    );

class _ReorderLine {
  _ReorderLine(this.film)
    : metres = TextEditingController(text: filmMetres(film.reorder!.metres)),
      price = TextEditingController(
        text: film.reorder!.priceM?.toStringAsFixed(0) ?? '',
      );

  final Film film;
  final TextEditingController metres;
  final TextEditingController price;
  bool on = true;

  double get m => _number(metres.text) ?? 0;
  double get p => _number(price.text) ?? 0;
  bool get ready => m > 0 && p > 0 && film.reorder!.supplier != null;

  void dispose() {
    metres.dispose();
    price.dispose();
  }
}

class _ReorderDialog extends ConsumerStatefulWidget {
  const _ReorderDialog({required this.stock});

  final FilmCatalog stock;

  @override
  ConsumerState<_ReorderDialog> createState() => _ReorderDialogState();
}

class _ReorderDialogState extends ConsumerState<_ReorderDialog> with _Saving {
  late final List<_ReorderLine> _lines = [
    for (final f in widget.stock.films)
      if (f.reorder != null) _ReorderLine(f),
  ];

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final chosen = [
      for (final l in _lines)
        if (l.on && l.ready) l,
    ];
    final total = chosen.fold<double>(0, (s, l) => s + l.m * l.p);
    final due = mdfDueIn(DateTime.now(), days: 2);
    return AlertDialog(
      title: Text(l10n.filmReorderTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 12,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, l) in _lines.indexed)
                Padding(
                  key: ValueKey('filmReorder:$i'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Checkbox(
                        key: ValueKey('filmReorder:on:$i'),
                        value: l.on,
                        onChanged: (v) => setState(() => l.on = v ?? false),
                      ),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(filmName(l.film)),
                            Text(
                              [
                                l10n.filmReorderLeft(filmMetres(l.film.free)),
                                ?l.film.reorder!.supplierName,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: ValueKey('filmReorder:metres:$i'),
                          controller: l.metres,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[0-9.,]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l10n.filmMetresLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: ValueKey('filmReorder:price:$i'),
                          controller: l.price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l10n.filmPriceM,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                l10n.filmReorderTotal(
                  money.format(total),
                  _dayName(context, due),
                ),
                key: const ValueKey('filmReorder:total'),
              ),
              errorLine(context),
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
          key: const ValueKey('filmReorder:save'),
          onPressed: busy || chosen.isEmpty
              ? null
              : () => save(() async {
                  final repo = ref.read(filmDeptRepositoryProvider);
                  for (final l in chosen) {
                    await repo.receive(
                      item: l.film.item,
                      metres: l.m,
                      priceM: l.p,
                      supplier: l.film.reorder!.supplier!,
                      arrivesOn: mdfIso(due),
                    );
                  }
                }),
          child: Text(l10n.filmReorderSave(chosen.length)),
        ),
      ],
    );
  }
}

/// «Отложить»: metres of this film put by for a customer — three days
/// unless said (owner, 11.11.2026).
Future<bool?> showFilmHold(BuildContext context, Film film) => showDialog<bool>(
  context: context,
  builder: (_) => _HoldDialog(film: film),
);

class _HoldDialog extends ConsumerStatefulWidget {
  const _HoldDialog({required this.film});

  final Film film;

  @override
  ConsumerState<_HoldDialog> createState() => _HoldDialogState();
}

class _HoldDialogState extends ConsumerState<_HoldDialog> with _Saving {
  final _metres = TextEditingController();
  String? _customer;
  int _days = 3;

  /// A day picked on the calendar wins over the quick choices.
  DateTime? _picked;

  /// Until when: a Sunday — the shop's day off — moves to Monday
  /// (owner, 12.11.2026), as an order's due date does.
  DateTime get _until {
    if (_picked != null) return _picked!;
    final now = DateTime.now();
    if (_days == 0) return DateTime(now.year, now.month, now.day);
    return mdfDueIn(now, days: _days);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _until.weekday == DateTime.sunday
          ? _until.add(const Duration(days: 1))
          : _until,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      selectableDayPredicate: (d) => d.weekday != DateTime.sunday,
    );
    if (picked != null && mounted) setState(() => _picked = picked);
  }

  @override
  void dispose() {
    _metres.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customers =
        ref.watch(mdfCustomersProvider).value ?? const <FacadeCustomer>[];
    final metres = _number(_metres.text) ?? 0;
    final until = _until;
    final over = metres > widget.film.free + 0.0001;
    return AlertDialog(
      title: Text('${l10n.filmHold} · ${filmName(widget.film)}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('filmHoldCustomer:${customers.length}'),
              initialValue: _customer,
              isExpanded: true,
              items: [
                for (final c in customers)
                  DropdownMenuItem(value: c.name, child: Text(c.title)),
              ],
              onChanged: (v) => setState(() => _customer = v),
              decoration: InputDecoration(labelText: l10n.mdfCustomer),
            ),
            TextField(
              key: const ValueKey('filmMetres'),
              controller: _metres,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.filmMetresLabel,
                errorText: over
                    ? l10n.filmOnlyHave(filmMetres(widget.film.free))
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.filmHoldUntil),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (d, label) in [
                  (0, l10n.filmToday),
                  (1, l10n.filmArrivalTomorrow),
                  (3, l10n.filmArrivalThree),
                  (7, l10n.filmArrivalWeek),
                ])
                  ChoiceChip(
                    key: ValueKey('filmHoldDays:$d'),
                    label: Text(label),
                    selected: _picked == null && _days == d,
                    onSelected: (_) => setState(() {
                      _picked = null;
                      _days = d;
                    }),
                  ),
                ActionChip(
                  key: const ValueKey('filmHoldDays:pick'),
                  avatar: const Icon(AppIcons.calendar),
                  label: Text(
                    _picked == null ? l10n.filmArrivalPick : mdfDayOf(_picked!),
                  ),
                  onPressed: _pickDay,
                ),
              ],
            ),
            Text(_dayName(context, until)),
            errorLine(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmHoldSave'),
          onPressed: busy || _customer == null || metres <= 0 || over
              ? null
              : () => save(
                  () => ref
                      .read(filmDeptRepositoryProvider)
                      .hold(
                        item: widget.film.item,
                        customer: _customer!,
                        metres: metres,
                        until: mdfIso(until),
                      ),
                ),
          child: Text(l10n.filmHold),
        ),
      ],
    );
  }
}
