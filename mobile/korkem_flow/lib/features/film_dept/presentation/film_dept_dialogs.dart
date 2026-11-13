import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/domain/film_orders.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_orders_page.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_pick.dart';
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
/// Several films of one supplier come in one delivery (owner, 12.11.2026:
/// «заказываю на фирму Кира один заказ или 10»).
Future<bool?> showFilmReceive(BuildContext context, Film film, FilmCatalog c) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _ReceiveDialog(catalog: c, films: [(film, null)]),
    );

/// A supplier's confirmed list as a delivery: its films with the metres
/// wanted, for whom, and the lines of «К заказу» they answer.
Future<bool?> showFilmDelivery(
  BuildContext context,
  FilmCatalog c, {
  required String? supplier,
  required List<FilmReceiveWant> wants,
  String? supplierName,
}) {
  final films = [
    for (final w in wants)
      if (c.film(w.item) case final f?) (f, w),
  ];
  if (films.isEmpty) return Future.value(false);
  return showDialog<bool>(
    context: context,
    builder: (_) => _ReceiveDialog(
      catalog: c,
      films: films,
      supplier: supplier,
      supplierName: supplierName,
    ),
  );
}

/// One film of a delivery: its metres, its price a metre, and for whom.
class _ReceiveLine {
  _ReceiveLine(this.film, [FilmReceiveWant? want])
    : metres = TextEditingController(
        text: want == null ? '' : filmMetres(want.metres),
      ),
      price = TextEditingController(text: film.priceM?.toStringAsFixed(0)),
      customer = want?.customer,
      customerName = want?.customerName,
      orders = want?.orders ?? const [];

  final Film film;
  final TextEditingController metres;
  final TextEditingController price;

  /// The price paid becomes the card's purchase price — unless unticked,
  /// for a one-off discount (owner, 11.11.2026).
  bool updatePrice = true;

  /// Bought for this customer — put by for him when it comes.
  String? customer;
  String? customerName;

  /// The lines of «К заказу» it answers.
  final List<String> orders;

  /// Where its metres go (owner, 13.11.2026): to customers who buy film,
  /// into MDF orders; what is left is the shelf's.
  final List<_Dest> dests = [];

  /// The shortfall went on «К заказу» already.
  bool shortListed = false;

  double get m => _number(metres.text) ?? 0;
  double get p => _number(price.text) ?? 0;

  /// Metres given out to customers and orders.
  double get given => dests.fold<double>(0, (s, d) => s + d.m);

  double get production =>
      dests.where((d) => d.production).fold<double>(0, (s, d) => s + d.m);

  double get sold =>
      dests.where((d) => !d.production).fold<double>(0, (s, d) => s + d.m);

  /// What is left for the shelf, and what the roll lacks.
  double get shelf => m - given > 0 ? m - given : 0;
  double get short => given - m > 0.005 ? given - m : 0;

  void dispose() {
    metres.dispose();
    price.dispose();
    for (final d in dests) {
      d.metres.dispose();
    }
  }
}

/// Part of a roll: so many metres to a customer, or into an MDF order.
class _Dest {
  _Dest({
    required this.production,
    required this.id,
    required this.name,
    required double metres,
    this.due,
  }) : metres = TextEditingController(
         text: metres > 0 ? filmMetres(metres) : '',
       );

  /// Into production (an MDF order), else a sale to a customer.
  final bool production;

  /// The order's number, or the customer's id.
  final String id;

  /// The customer's name — of the order, or the buyer.
  final String name;

  /// When the order is to be handed over.
  final String? due;
  final TextEditingController metres;

  double get m => _number(metres.text) ?? 0;
}

class _ReceiveDialog extends ConsumerStatefulWidget {
  const _ReceiveDialog({
    required this.catalog,
    required this.films,
    this.supplier,
    this.supplierName,
  });

  final FilmCatalog catalog;
  final List<(Film, FilmReceiveWant?)> films;
  final String? supplier;

  /// What the list calls [supplier] — when the stock's list lacks it.
  final String? supplierName;

  @override
  ConsumerState<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends ConsumerState<_ReceiveDialog> with _Saving {
  late final List<_ReceiveLine> _lines = [
    for (final (f, w) in widget.films) _ReceiveLine(f, w),
  ];

  Film get _first => _lines.first.film;

  // Only where this maker's film is bought (owner, 11.11.2026) — unless the
  // list names another.
  late final List<({String id, String name})> _sources = () {
    final own = widget.catalog.suppliersFor(_first.maker);
    final named = widget.supplier;
    if (named == null || own.any((s) => s.id == named)) return own;
    final all = widget.catalog.suppliers;
    // Named on the list but not among the stock's — offered all the same.
    return all.any((s) => s.id == named)
        ? all
        : [...all, (id: named, name: widget.supplierName ?? named)];
  }();
  late String? _supplier =
      widget.supplier ??
      (_sources.any((s) => s.id == _first.supplier)
          ? _first.supplier
          : _sources.firstOrNull?.id);

  /// Films of this supplier that ran low and are not in the delivery yet.
  List<Film> get _lowHere => [
    for (final f in widget.catalog.films)
      if (f.reorder?.supplier == _supplier &&
          _supplier != null &&
          !_lines.any((l) => l.film.item == f.item))
        f,
  ];

  Future<void> _addFilm() async {
    final l10n = AppLocalizations.of(context);
    final film = await showFilmChoice(
      context,
      widget.catalog.films,
      title: l10n.filmReceiveAddFilm,
      skip: {for (final l in _lines) l.film.item},
    );
    if (film == null || !mounted) return;
    setState(() => _lines.add(_ReceiveLine(film)));
  }

  void _addLow() => setState(() {
    for (final f in _lowHere) {
      _lines.add(
        _ReceiveLine(f, (
          item: f.item,
          metres: f.reorder!.metres,
          customer: null,
          customerName: null,
          orders: const [],
        )),
      );
    }
  });

  /// «+ Продажа клиенту»: a customer takes part of the roll — what is
  /// left of it unless changed.
  Future<void> _pickCustomer(_ReceiveLine line) async {
    final l10n = AppLocalizations.of(context);
    final customers = await ref.read(filmCustomersProvider.future);
    if (!mounted) return;
    final picked = await showDialog<FilmCustomer?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.filmReceiveToSale),
        children: [
          for (final c in customers)
            SimpleDialogOption(
              key: ValueKey('filmReceiveFor:${c.customer}'),
              onPressed: () => Navigator.of(context).pop(c),
              child: Text(c.name),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      line.dests.add(
        _Dest(
          production: false,
          id: picked.customer,
          name: picked.name,
          metres: line.shelf,
        ),
      );
    });
  }

  /// «+ В производство»: an MDF order that lacks this film takes what it
  /// lacks.
  Future<void> _pickOrder(_ReceiveLine line) async {
    final l10n = AppLocalizations.of(context);
    final List<FilmForProduction> wants;
    try {
      wants = await ref.read(
        filmForProductionProvider(line.film.item).future,
      );
    } on Object {
      return;
    }
    if (!mounted) return;
    final taken = {
      for (final d in line.dests)
        if (d.production) d.id,
    };
    final picked = await showDialog<FilmForProduction?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.filmReceiveToProduction),
        children: [
          if (wants.every((w) => taken.contains(w.order)))
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.filmReceiveNoOrders),
            ),
          for (final w in wants)
            if (!taken.contains(w.order))
              SimpleDialogOption(
                key: ValueKey('filmReceiveProd:${w.order}'),
                onPressed: () => Navigator.of(context).pop(w),
                child: Text(
                  l10n.filmReceiveOrderLine(
                    w.order,
                    w.customerName,
                    filmMetres(w.short),
                    w.deliveryDate == null
                        ? '—'
                        : mdfDay(w.deliveryDate, year: false),
                  ),
                ),
              ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      line.dests.add(
        _Dest(
          production: true,
          id: picked.order,
          name: picked.customerName,
          metres: picked.short,
          due: picked.deliveryDate,
        ),
      );
    });
  }

  /// The roll lacks metres: the rest goes on «К заказу».
  Future<void> _listShort(_ReceiveLine line) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(filmOrdersRepositoryProvider)
          .add(
            item: line.film.item,
            metres: double.parse(line.short.toStringAsFixed(2)),
            supplier: _supplier,
          );
      if (mounted) setState(() => line.shortListed = true);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

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

  // The film itself: paid for, unless taken from the supplier on credit.
  bool _supplierPaid = true;
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
    for (final l in _lines) {
      l.dispose();
    }
    _cost.dispose();
    _driver.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// One film's own part: its name, its metres, price and sum, whether
  /// the price moved, and where its metres go.
  Widget _lineView(_ReceiveLine line, int i, double perM) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final card = line.film.priceM;
    final k = i == 0 ? '' : ':$i';
    final since = line.film.priceSince['price_m']?.date;
    // The price against the last one (owner, 13.11.2026).
    final moved = card != null && card > 0 && line.p > 0 && line.p != card
        ? ((line.p - card) / card * 100).round()
        : null;
    final wants = ref.watch(filmForProductionProvider(line.film.item)).value;
    final waiting = [
      for (final w in wants ?? const <FilmForProduction>[])
        if (!line.dests.any((d) => d.production && d.id == w.order)) w,
    ];
    Widget part({
      required Color colour,
      required IconData icon,
      required String text,
      TextEditingController? metres,
      String? metresText,
      VoidCallback? onRemove,
      Key? key,
    }) => Container(
      key: key,
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: AppTint.surface),
        border: Border.all(color: colour),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.xxxl * 1.5,
            child: metres == null
                ? Text(
                    metresText ?? '',
                    style: TextStyle(
                      color: colour,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : TextField(
                    controller: metres,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: l10n.filmM,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, color: colour, size: AppIconSize.dense),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
          if (onRemove != null)
            IconButton(
              tooltip: l10n.filmReceiveRemove,
              icon: const Icon(AppIcons.close, size: AppIconSize.dense),
              onPressed: onRemove,
            ),
        ],
      ),
    );
    return Card(
      key: ValueKey('filmReceiveLine$k'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (line.film.argb != null) ...[
                  FilmSample(argb: line.film.argb),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    filmName(line.film),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (_lines.length > 1)
                  IconButton(
                    key: ValueKey('filmReceiveRemove$k'),
                    tooltip: l10n.filmReceiveRemove,
                    icon: const Icon(AppIcons.close),
                    onPressed: () {
                      final gone = _lines[i];
                      setState(() => _lines.removeAt(i));
                      // Its fields let go of it first.
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => gone.dispose(),
                      );
                    },
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('filmMetres$k'),
                    controller: line.metres,
                    autofocus: i == 0,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.filmMetresLabel,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: ValueKey('filmPrice$k'),
                    controller: line.price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: l10n.filmPriceM),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.filmReceiveLineSum,
                      helperText: perM > 0 && line.p > 0
                          ? l10n.filmReceivePerMWithDelivery(
                              money.format(line.p + perM),
                            )
                          : null,
                    ),
                    child: Text(
                      line.m > 0 && line.p > 0
                          ? money.format(line.m * line.p)
                          : '—',
                      key: ValueKey('filmReceiveSum$k'),
                    ),
                  ),
                ),
              ],
            ),
            if (moved != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  (moved > 0 ? l10n.filmPriceUp : l10n.filmPriceDown)(
                    money.format(card ?? 0),
                    since == null ? '' : ' (${mdfDay(since, year: false)})',
                    '${moved > 0 ? '+' : '−'}${moved.abs()}%',
                  ),
                  key: ValueKey('filmReceivePriceMoved$k'),
                  style: TextStyle(
                    color: moved > 0 ? status.warning : status.success,
                  ),
                ),
              ),
            if (line.p > 0 && line.p != card)
              CheckboxListTile(
                key: ValueKey('filmReceiveUpdatePrice$k'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: line.updatePrice,
                onChanged: (v) => setState(() => line.updatePrice = v ?? false),
                title: Text(
                  card == null
                      ? l10n.filmReceiveSetPrice(line.p.toStringAsFixed(0))
                      : l10n.filmReceiveUpdatePrice(
                          card.toStringAsFixed(0),
                          line.p.toStringAsFixed(0),
                        ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.filmReceiveWhere, style: theme.textTheme.labelMedium),
            // Wanted on the list for someone: comes with it.
            if (line.customerName != null)
              part(
                colour: status.warning,
                icon: AppIcons.deal,
                text: l10n.filmReceiveForCustomer(line.customerName!),
              ),
            for (final (n, d) in line.dests.indexed)
              part(
                key: ValueKey('filmReceiveDest$k:$n'),
                colour: d.production ? status.info : status.warning,
                icon: d.production ? AppIcons.workOrder : AppIcons.deal,
                metres: d.metres,
                text: d.production
                    ? l10n.filmReceiveIntoProduction(
                        d.id,
                        d.name,
                        d.due == null ? '' : mdfDay(d.due, year: false),
                      )
                    : l10n.filmReceiveToCustomer(d.name),
                onRemove: () {
                  setState(() => line.dests.removeAt(n));
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => d.metres.dispose(),
                  );
                },
              ),
            if (line.shelf > 0)
              part(
                key: ValueKey('filmReceiveShelf$k'),
                colour: status.success,
                icon: AppIcons.warehouse,
                metresText: '${filmMetres(line.shelf)} ${l10n.filmM}',
                text: l10n.filmReceiveToShelf,
              ),
            if (line.short > 0)
              Container(
                key: ValueKey('filmReceiveShort$k'),
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: status.danger.withValues(alpha: AppTint.surface),
                  border: Border.all(color: status.danger),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.danger, color: status.danger),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.filmReceiveShort(filmMetres(line.short)),
                        style: TextStyle(color: status.danger),
                      ),
                    ),
                    if (line.shortListed)
                      Text(l10n.filmReceiveShortListed)
                    else
                      TextButton(
                        key: ValueKey('filmReceiveShortList$k'),
                        onPressed: () => _listShort(line),
                        child: Text(l10n.filmReceiveShortToList),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('filmReceiveProd$k'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: status.info,
                  ),
                  onPressed: () => _pickOrder(line),
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.filmReceiveToProduction),
                ),
                OutlinedButton.icon(
                  key: ValueKey('filmReceiveFor$k'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: status.warning,
                  ),
                  onPressed: () => _pickCustomer(line),
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.filmReceiveToSale),
                ),
                if (waiting.isNotEmpty)
                  Text(
                    l10n.filmReceiveOrdersWait(waiting.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status.info,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A film of the delivery as the server takes it. A single customer
  /// taking the whole roll is the roll for him, as before.
  FilmDeliveryLine _deliveryLine(_ReceiveLine l) {
    final sales = [
      for (final d in l.dests)
        if (!d.production && d.m > 0) (customer: d.id, metres: d.m),
    ];
    final production = [
      for (final d in l.dests)
        if (d.production && d.m > 0) (order: d.id, metres: d.m),
    ];
    final whole =
        l.customer == null &&
        production.isEmpty &&
        sales.length == 1 &&
        (sales.single.metres - l.m).abs() < 0.005;
    return (
      item: l.film.item,
      metres: l.m,
      priceM: l.p,
      updatePrice: l.updatePrice,
      customer: whole ? sales.single.customer : l.customer,
      orders: l.orders,
      sales: whole ? const [] : sales,
      production: production,
    );
  }

  /// The delivery in figures: the film, the bringing, the total, a metre
  /// with the bringing, where the metres went (owner, 13.11.2026).
  Widget _summary(double metres, double total, double cost, double perM) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    double sum(double Function(_ReceiveLine) f) =>
        _lines.fold<double>(0, (s, l) => s + f(l));
    Widget row(String a, String b, {TextStyle? style, Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(a, style: style)),
          Text(b, key: key, style: style),
        ],
      ),
    );
    final production = sum((l) => l.production);
    final sold = sum((l) => l.sold);
    final shelf = sum((l) => l.shelf);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            l10n.filmReceiveFilmTotal(_lines.length, filmMetres(metres)),
            money.format(total),
          ),
          if (cost > 0) row(l10n.filmDeliveryCost, money.format(cost)),
          const Divider(),
          row(
            l10n.filmReceiveGrand,
            money.format(total + cost),
            key: const ValueKey('filmReceive:total'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (perM > 0)
            Text(
              l10n.filmReceivePerM(
                [
                  for (final l in _lines)
                    if (l.p > 0) '${l.film.colour} ${money.format(l.p + perM)}',
                ].join(' · '),
              ),
              style: theme.textTheme.bodySmall,
            ),
          Text.rich(
            TextSpan(
              children: [
                if (production > 0)
                  TextSpan(
                    text:
                        '${l10n.filmReceiveSumProduction(
                          filmMetres(production),
                        )}  ',
                    style: TextStyle(color: status.info),
                  ),
                if (sold > 0)
                  TextSpan(
                    text: '${l10n.filmReceiveSumSale(filmMetres(sold))}  ',
                    style: TextStyle(color: status.warning),
                  ),
                if (shelf > 0)
                  TextSpan(
                    text: l10n.filmReceiveSumShelf(filmMetres(shelf)),
                    style: TextStyle(color: status.success),
                  ),
              ],
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metres = _lines.fold<double>(0, (s, l) => s + l.m);
    final total = _lines.fold<double>(0, (s, l) => s + l.m * l.p);
    final ready = _lines.every((l) => l.m > 0 && l.p > 0);
    final cost = _number(_cost.text) ?? 0;
    final perM = cost > 0 && metres > 0 ? cost / metres : 0.0;
    final low = _lowHere;
    final opts = ref.watch(filmDeliveryOptionsProvider).value;
    final transport = _transportOf(opts);
    final city = _cityOf(opts);
    final cities = {...?opts?.cities, ?city}.toList();
    final money = mdfMoney(context);
    return AlertDialog(
      title: Text(
        _lines.length == 1
            ? '${l10n.filmReceive} · ${filmName(_first)}'
            : l10n.filmReceiveMany(_lines.length),
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: AppSpacing.sm),
              for (final (i, line) in _lines.indexed) _lineView(line, i, perM),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('filmReceive:add'),
                    onPressed: _addFilm,
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.filmReceiveAddFilm),
                  ),
                  if (low.isNotEmpty)
                    OutlinedButton.icon(
                      key: const ValueKey('filmReceive:low'),
                      onPressed: _addLow,
                      icon: const Icon(AppIcons.delivery),
                      label: Text(l10n.filmReceiveAddLow(low.length)),
                    ),
                ],
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
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.filmSupplierPay,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (paid, label) in [
                    (true, l10n.filmSupplierPaidNow),
                    (false, l10n.filmSupplierOnCredit),
                  ])
                    ChoiceChip(
                      key: ValueKey(
                        'filmSupplierPay:${paid ? 'paid' : 'credit'}',
                      ),
                      label: Text(label),
                      selected: _supplierPaid == paid,
                      onSelected: (_) => setState(() => _supplierPaid = paid),
                    ),
                ],
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
              if (total > 0) _summary(metres, total, cost, perM),
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
          onPressed: busy || !ready || _supplier == null
              ? null
              : () => save(() {
                  final delivery = opts == null
                      ? null
                      : <String, Object?>{
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
                        };
                  final taker = opts == null ? null : _taker ?? opts.me;
                  final due = _due == null ? null : mdfIso(_due!);
                  final only = _lines.length == 1 ? _lines.single : null;
                  // One film for the shelf: the receipt it always was.
                  if (only != null &&
                      only.customer == null &&
                      only.orders.isEmpty &&
                      only.dests.isEmpty) {
                    return ref
                        .read(filmDeptRepositoryProvider)
                        .receive(
                          item: only.film.item,
                          metres: only.m,
                          priceM: only.p,
                          supplier: _supplier!,
                          updatePrice: only.updatePrice,
                          delivery: delivery,
                          receivedBy: taker,
                          arrivesOn: due,
                          supplierPaid: _supplierPaid,
                        );
                  }
                  return ref
                      .read(filmOrdersRepositoryProvider)
                      .receiveMany(
                        supplier: _supplier!,
                        lines: [
                          for (final l in _lines) _deliveryLine(l),
                        ],
                        delivery: delivery,
                        receivedBy: taker,
                        arrivesOn: due,
                        supplierPaid: _supplierPaid,
                      );
                }),
          // On its way: ordered, not taken in yet — with what it comes to.
          child: Text(
            [
              if (_due == null) l10n.filmReceive else l10n.filmArrivalOrder,
              if (total > 0) money.format(total + cost),
            ].join(' · '),
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

  /// Sold for less than the film cost (its purchase price).
  bool get below =>
      p > 0 && film.priceM != null && film.priceM! > 0 && p < film.priceM!;

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
/// [repeat] — a sale's films and metres, to sell again (13.11.2026).
Future<bool?> showFilmSale(
  BuildContext context,
  FilmCatalog stock, {
  Film? film,
  String? customer,
  List<FilmSaleLine>? repeat,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _SaleDialog(
    stock: stock,
    film: film,
    customer: customer,
    repeat: repeat,
  ),
);

class _SaleDialog extends ConsumerStatefulWidget {
  const _SaleDialog({
    required this.stock,
    this.film,
    this.customer,
    this.repeat,
  });

  final FilmCatalog stock;
  final Film? film;
  final String? customer;
  final List<FilmSaleLine>? repeat;

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

  /// Why a film goes for less than it cost — asked when one does
  /// (owner, 13.11.2026: a sale at a loss is never silent).
  String? _below;

  @override
  void initState() {
    super.initState();
    if (widget.repeat case final again? when _again(again)) return;
    final first = widget.film ?? _films.firstOrNull;
    if (first != null) _add(first);
  }

  /// The lines of an earlier sale, as far as the shelf has their films.
  bool _again(List<FilmSaleLine> lines) {
    var any = false;
    for (final l in lines) {
      final film = _films.where((f) => f.item == l.item).firstOrNull;
      if (film == null || _lines.any((x) => x.film.item == l.item)) continue;
      _add(film);
      _lines.last.metres.text = filmMetres(l.metres);
      any = true;
    }
    return any;
  }

  /// «Как в прошлый раз»: the last sale's films and metres instead.
  void _likeLastTime(FilmSale last) => setState(() {
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();
    if (!_again(last.lines)) {
      final first = _films.firstOrNull;
      if (first != null) _add(first);
    }
    _fillPaid();
  });

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

  /// Past the customer's debt limit — by the sum, or owing too long: said
  /// before the sale, not refused (owner, 13.11.2026).
  Widget? _overLimit(double paid) {
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final card = (ref.watch(filmCustomersProvider).value ?? const [])
        .where((c) => c.customer == _customer)
        .firstOrNull;
    final more = _sum - paid > 0 ? _sum - paid : 0.0;
    final over = card?.overLimit(more);
    if (card == null || over == null) return null;
    final danger = Theme.of(context).colorScheme.error;
    return Padding(
      key: const ValueKey('filmSaleOverLimit'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        [
          if (over.sum)
            l10n.filmSaleOverLimit(
              money.format(card.debt + more),
              money.format(card.debtLimit),
            ),
          if (over.days)
            l10n.filmSaleOverDays(card.debtDays ?? 0, card.debtLimitDays ?? 0),
        ].join(' · '),
        style: TextStyle(color: danger),
      ),
    );
  }

  /// What the seller should know of this customer (owner, 13.11.2026):
  /// what he usually takes and how often, his price, his debt — and his
  /// last sale, to sell again at a tap.
  Widget _hint(String customer) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final card = (ref.watch(filmCustomersProvider).value ?? const [])
        .where((c) => c.customer == customer)
        .firstOrNull;
    final sales = ref.watch(filmCustomerSalesProvider(customer)).value;
    if (card == null && (sales == null || sales.isEmpty)) {
      return const SizedBox.shrink();
    }
    final last = sales?.firstOrNull;
    final every = filmRhythmDays(sales ?? const []);
    final owes = (card?.debt ?? 0) > 0.5;
    final colour = owes ? status.warning : status.info;
    return Container(
      key: const ValueKey('filmSaleHint'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: AppTint.surface),
        border: Border.all(color: colour),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (card?.favourite case final f?) l10n.filmSaleUsually(f),
              if (every != null) l10n.filmSaleEvery(every),
              if (card != null)
                card.wholesale ? l10n.filmWholesale : l10n.filmRetail,
              if (card != null && card.discount > 0)
                '−${card.discount.toStringAsFixed(0)}%',
              if (owes)
                l10n.filmSaleDebt(money.format(card!.debt))
              else
                l10n.filmSaleNoDebt,
            ].join(' · '),
          ),
          if (last != null && last.lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: ActionChip(
                key: const ValueKey('filmSaleLikeLast'),
                avatar: const Icon(AppIcons.refresh),
                label: Text(
                  l10n.filmSaleLikeLast(
                    [
                      for (final l in last.lines)
                        '${l.colour ?? l.title} ${filmMetres(l.metres)} м',
                    ].join(', '),
                  ),
                ),
                onPressed: () => _likeLastTime(last),
              ),
            ),
        ],
      ),
    );
  }

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
        (_below != null || !_lines.any((l) => l.below)) &&
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
              if (_customer case final who?) _hint(who),
              ?_overLimit(paid),
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
                if (line.below)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      l10n.filmSaleBelow(
                        money.format(line.film.priceM),
                        money.format((line.film.priceM! - line.p) * line.m),
                      ),
                      key: ValueKey('filmSaleBelow:$i'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                if (line.over || line.low)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        // Runs low after this sale: on «К заказу» at once.
                        if (line.low)
                          ActionChip(
                            key: ValueKey('filmSaleWant:$i'),
                            avatar: const Icon(AppIcons.delivery),
                            label: Text(l10n.filmSaleToOrders),
                            onPressed: () => showFilmWant(context, line.film),
                          ),
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
              if (_lines.any((l) => l.below)) ...[
                Text(
                  l10n.filmSaleBelowWhy,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final (k, why) in [
                      ('rest', l10n.filmSaleBelowRest),
                      ('defect', l10n.filmSaleBelowDefect),
                      ('agreed', l10n.filmSaleBelowAgreed),
                    ])
                      ChoiceChip(
                        key: ValueKey('filmSaleBelowWhy:$k'),
                        label: Text(why),
                        selected: _below == why,
                        onSelected: (_) => setState(() => _below = why),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
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
                        belowReason: _lines.any((l) => l.below) ? _below : null,
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

  // How far he may owe (owner, 13.11.2026): empty — no limit.
  late final _limit = TextEditingController(
    text: widget.customer.debtLimit?.toStringAsFixed(0) ?? '',
  );
  late final _days = TextEditingController(
    text: widget.customer.debtLimitDays?.toString() ?? '',
  );

  @override
  void dispose() {
    _discount.dispose();
    _limit.dispose();
    _days.dispose();
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('filmDebtLimit'),
                    controller: _limit,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.filmDebtLimit,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const ValueKey('filmDebtDays'),
                    controller: _days,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.filmDebtLimitDays,
                    ),
                  ),
                ),
              ],
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
                        debtLimit: _number(_limit.text) ?? 0,
                        debtDays: int.tryParse(_days.text.trim()) ?? 0,
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
        // The same again (owner, 13.11.2026): the customer and his films,
        // at today's prices.
        if (widget.sale.customer != null)
          TextButton.icon(
            key: const ValueKey('filmSaleRepeat'),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final stock = await ref.read(filmStockProvider.future);
              if (!context.mounted) return;
              final done = await showFilmSale(
                context,
                stock,
                customer: widget.sale.customer,
                repeat: widget.sale.lines,
              );
              if (done ?? false) navigator.pop(true);
            },
            icon: const Icon(AppIcons.refresh),
            label: Text(l10n.filmSaleRepeat),
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
