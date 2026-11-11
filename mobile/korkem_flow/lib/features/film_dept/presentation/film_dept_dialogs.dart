import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
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

  @override
  void dispose() {
    _metres.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metres = _number(_metres.text) ?? 0;
    final price = _number(_price.text) ?? 0;
    return AlertDialog(
      title: Text('${l10n.filmReceive} · ${filmName(widget.film)}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _metresField(_metres, l10n.filmMetresLabel, () => setState(() {})),
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
                      ),
                ),
          child: Text(l10n.filmReceive),
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

class _SaleLine {
  _SaleLine(this.film);

  Film film;
  final metres = TextEditingController();
  final price = TextEditingController();

  double get m => _number(metres.text) ?? 0;
  double get p => _number(price.text) ?? 0;
  double get sum => (m * p).roundToDouble();

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
  final _paid = TextEditingController();
  late String? _customer = widget.customer;
  String _method = filmCash;
  String? _bank;
  bool _paidTouched = false;

  /// What can be sold: still made, named, and with metres on the shelf.
  late final List<Film> _films = [
    for (final f in widget.stock.films)
      if (f.enabled && f.label != null && f.free > 0) f,
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
    _paid.dispose();
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
      if (!mounted || price.priceM == null) return;
      setState(() => line.price.text = price.priceM!.toStringAsFixed(0));
      _fillPaid();
    } on Object {
      // No price on the card yet: the seller types it.
    }
  }

  double get _sum => _lines.fold(0, (s, l) => s + l.sum);

  void _fillPaid() {
    if (!_paidTouched) _paid.text = _sum.toStringAsFixed(0);
  }

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
    final paid = _number(_paid.text) ?? 0;
    final ok =
        _customer != null &&
        _lines.isNotEmpty &&
        _lines.every(
          (l) => l.m > 0 && l.p > 0 && l.m <= l.film.free + 0.0001,
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
              const SizedBox(height: AppSpacing.sm),
              for (final (i, line) in _lines.indexed)
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
                            errorText: line.m > line.film.free + 0.0001
                                ? l10n.filmNotEnough
                                : null,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('filmSalePaid'),
                      controller: _paid,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() => _paidTouched = true),
                      decoration: InputDecoration(
                        labelText: l10n.filmSalePaid,
                        helperText: paid < _sum
                            ? l10n.filmSaleDebt(money.format(_sum - paid))
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final m in const [filmCash, filmTransfer, filmCard])
                        ChoiceChip(
                          key: ValueKey('filmSaleMethod:$m'),
                          label: Text(label(m)),
                          selected: _method == m,
                          onSelected: (_) => setState(() => _method = m),
                        ),
                    ],
                  ),
                ],
              ),
              if (_method != filmCash)
                DropdownButtonFormField<String?>(
                  key: ValueKey('filmSaleBank:${banks.length}'),
                  initialValue: banks.contains(_bank) ? _bank : null,
                  items: [
                    DropdownMenuItem(child: Text(l10n.mdfNone)),
                    for (final b in banks)
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (v) => setState(() => _bank = v),
                  decoration: InputDecoration(labelText: l10n.mdfPayBank),
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
                        paid: paid,
                        method: paid > 0 ? _method : null,
                        bank: paid > 0 && _method != filmCash ? _bank : null,
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
