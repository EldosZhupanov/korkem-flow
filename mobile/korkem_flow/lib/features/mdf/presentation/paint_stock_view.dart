import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_receipt_terms.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/paint_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/paint_stock.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/paint_recipe_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _kgText(double v) => filmMetres(v);

/// «Склад краски» on the paint board (owner, 15.11.2026): what is short for
/// the queue, colour by colour; each paint with what is left and where it
/// was last bought; what is owed for paint; «Приход краски».
class PaintStockSection extends ConsumerWidget {
  const PaintStockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final stock = ref.watch(paintStockProvider).value;
    if (stock == null) return const SizedBox.shrink();
    Future<void> receive({String? colour, String? base}) async {
      final done = await showPaintReceive(
        context,
        stock,
        colour: colour,
        base: base,
      );
      if (done ?? false) ref.invalidate(paintStockProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        ReadableWidth(child: SectionLabel(l10n.paintStock)),
        ReadableWidth(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const ValueKey('paintReceive'),
                onPressed: receive,
                icon: const Icon(AppIcons.moveIn),
                label: Text(l10n.paintReceive),
              ),
              // The shop's recipe (owner, 15.11.2026): primer, enamel,
              // lacquer, and what goes into each.
              TextButton.icon(
                key: const ValueKey('paintRecipe'),
                onPressed: () => showPaintRecipe(context, stock.recipe),
                icon: const Icon(AppIcons.recipe),
                label: Text(l10n.paintRecipe(_kgText(stock.kgPerM2))),
              ),
              TextButton.icon(
                key: const ValueKey('paintCalc'),
                onPressed: () => showPaintPlan(context, stock),
                icon: const Icon(AppIcons.calculate),
                label: Text(l10n.paintCalc),
              ),
            ],
          ),
        ),
        // What a m² really took this month, against the figure.
        if (stock.usage case final u? when u.m2 > 0)
          ReadableWidth(
            child: Text(
              [
                l10n.paintUsage(
                  '${u.days}',
                  filmMetres(u.m2),
                  _kgText(u.kgByNorm + u.kgCounted),
                ),
                if (u.factKgM2 case final fact?)
                  l10n.paintUsageFact(_kgText(fact), _kgText(stock.kgPerM2)),
              ].join(' · '),
              key: const ValueKey('paintUsage'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: (u.factKgM2 ?? 0) > stock.kgPerM2 * 1.1
                    ? status.warning
                    : null,
              ),
            ),
          ),
        // Enough for the queue? The short ones first, in red, with a
        // receipt one tap away.
        for (final n in [
          ...stock.queue.where((n) => n.shortKg > 0),
          ...stock.queue.where((n) => n.shortKg <= 0),
        ])
          ReadableWidth(
            child: ListTile(
              key: ValueKey('paintNeed:${n.colour}'),
              dense: true,
              leading: Icon(
                n.shortKg > 0 ? AppIcons.warning : AppIcons.success,
                color: n.shortKg > 0 ? status.danger : status.success,
              ),
              title: Text(n.colour),
              // What the colour's queue takes, to send to the supplier.
              onTap: () => showPaintPlan(
                context,
                stock,
                m2: n.queueM2,
                colour: n.colour,
              ),
              subtitle: Text(
                [
                  l10n.paintNeed(
                    filmMetres(n.queueM2),
                    _kgText(n.needKg),
                    _kgText(n.onHandKg),
                  ),
                  if (n.shortKg > 0)
                    l10n.paintShort(_kgText(n.shortKg))
                  else
                    l10n.paintEnough,
                ].join(' · '),
                style: TextStyle(
                  color: n.shortKg > 0 ? status.danger : null,
                ),
              ),
              trailing: n.shortKg > 0
                  ? TextButton(
                      key: ValueKey('paintNeedBuy:${n.colour}'),
                      onPressed: () => receive(colour: n.colour),
                      child: Text(l10n.paintReceiveShort),
                    )
                  : null,
            ),
          ),
        // Primer, hardener, thinner — for the whole queue.
        if (stock.materials.isNotEmpty)
          ReadableWidth(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.paintForQueue,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
        for (final m in stock.materials)
          ReadableWidth(
            child: ListTile(
              key: ValueKey('paintMaterial:${m.name}'),
              dense: true,
              leading: Icon(
                m.shortKg > 0 ? AppIcons.warning : AppIcons.success,
                color: m.shortKg > 0 ? status.danger : status.success,
              ),
              title: Text(m.name),
              subtitle: Text(
                [
                  l10n.paintMaterialNeed(
                    _kgText(m.needKg),
                    _kgText(m.onHandKg),
                  ),
                  if (m.shortKg > 0)
                    l10n.paintShort(_kgText(m.shortKg))
                  else
                    l10n.paintEnough,
                ].join(' · '),
                style: TextStyle(color: m.shortKg > 0 ? status.danger : null),
              ),
              trailing: m.shortKg > 0
                  ? TextButton(
                      key: ValueKey('paintMaterialBuy:${m.name}'),
                      onPressed: () => receive(base: m.name),
                      child: Text(l10n.paintReceiveShort),
                    )
                  : null,
            ),
          ),
        if (stock.paints.isEmpty)
          ReadableWidth(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(l10n.paintNone, style: theme.textTheme.bodySmall),
            ),
          ),
        for (final p in stock.paints)
          ReadableWidth(
            child: ListTile(
              key: ValueKey('paintItem:${p.item}'),
              dense: true,
              title: Text(
                [
                  if (p.colour.isNotEmpty) p.colour,
                  ?p.base,
                ].join(' · '),
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                [
                  if (p.last case final last?) ...[
                    mdfDay(last.date, year: false),
                    ?last.supplierName,
                    ?last.city,
                    if (last.priceKg case final price?)
                      l10n.paintPerKg(money.format(price)),
                  ],
                ].join(' · '),
              ),
              trailing: Wrap(
                spacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.paintOnHand(_kgText(p.onHandKg)),
                    style: theme.textTheme.titleSmall,
                  ),
                  IconButton(
                    key: ValueKey('paintCount:${p.item}'),
                    tooltip: l10n.paintCount,
                    icon: const Icon(AppIcons.edit),
                    onPressed: () => _count(context, ref, p),
                  ),
                ],
              ),
              onTap: () => showPaintHistory(context, p),
            ),
          ),
        if (stock.deliveryOwed.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ReadableWidth(child: SectionLabel(l10n.paintDeliveryOwed)),
          for (final d in stock.deliveryOwed)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('paintDeliveryOwed:${d.receipt}'),
                dense: true,
                title: Text(
                  [
                    if (d.employee case final who?)
                      l10n.paintDeliveryToEmployee(who)
                    else
                      l10n.paintDeliveryToCarrier,
                    ?d.transport,
                  ].join(' · '),
                ),
                subtitle: Text(
                  [
                    mdfDay(d.date, year: false),
                    ?d.supplier,
                    ?d.driver,
                    ?d.phone,
                  ].join(' · '),
                ),
                trailing: Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (d.amount case final amount?) Text(money.format(amount)),
                    PopupMenuButton<String>(
                      key: ValueKey('paintDeliverySettle:${d.receipt}'),
                      tooltip: d.employee != null
                          ? l10n.paintDeliveryBack
                          : l10n.paintDeliveryPaid,
                      onSelected: (method) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final bank = await filmAskBank(context, ref, method);
                        if (bank == null) return;
                        try {
                          await ref
                              .read(paintStockRepositoryProvider)
                              .settleDelivery(
                                d.receipt,
                                method,
                                bank: bank.isEmpty ? null : bank,
                              );
                          ref.invalidate(paintStockProvider);
                        } on Object catch (e) {
                          messenger.showFailure(e, l10n);
                        }
                      },
                      itemBuilder: (_) => [
                        for (final m in [filmCash, filmTransfer, filmCard])
                          PopupMenuItem(
                            key: ValueKey('paintDeliveryHow:$m'),
                            value: m,
                            child: Text(filmMethodLabel(l10n, m)),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          d.employee != null
                              ? l10n.paintDeliveryBack
                              : l10n.paintDeliveryPaid,
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (stock.owed.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ReadableWidth(child: SectionLabel(l10n.paintOwed)),
          for (final o in stock.owed)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('paintOwed:${o.receipt}'),
                dense: true,
                title: Text('${o.supplier} · ${o.paint}'),
                subtitle: Text(
                  [
                    mdfDay(o.date, year: false),
                    l10n.paintKgShort(_kgText(o.kg)),
                    if (o.invoiceNo case final no?) l10n.filmByInvoiceNo(no),
                    if (o.dueOn case final due?)
                      l10n.filmInvoiceDue(mdfDay(due)),
                  ].join(' · '),
                  style: TextStyle(color: o.overdue ? status.danger : null),
                ),
                trailing: Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (o.amount case final amount?) Text(money.format(amount)),
                    PopupMenuButton<String>(
                      key: ValueKey('paintPay:${o.receipt}'),
                      tooltip: l10n.paintPaid,
                      onSelected: (method) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final bank = await filmAskBank(context, ref, method);
                        if (bank == null) return;
                        try {
                          await ref
                              .read(paintStockRepositoryProvider)
                              .paySupplier(
                                o.receipt,
                                method,
                                bank: bank.isEmpty ? null : bank,
                              );
                          ref.invalidate(paintStockProvider);
                        } on Object catch (e) {
                          messenger.showFailure(e, l10n);
                        }
                      },
                      itemBuilder: (_) => [
                        for (final m in [filmCash, filmTransfer, filmCard])
                          PopupMenuItem(
                            key: ValueKey('paintPayHow:$m'),
                            value: m,
                            child: Text(filmMethodLabel(l10n, m)),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          l10n.paintPaid,
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// «Пересчитать»: the painter weighed what is left.
  Future<void> _count(BuildContext context, WidgetRef ref, PaintItem p) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = await _ask(
      context,
      title: l10n.paintCountTitle(p.title),
      initial: _kgText(p.onHandKg),
      label: l10n.paintKg,
      hint: l10n.paintCountHint,
      fieldKey: 'paintCountValue',
      saveKey: 'paintCountSave',
      number: true,
    );
    final value = text == null ? null : filmNumber(text);
    if (value == null) return;
    try {
      await ref.read(paintStockRepositoryProvider).count(p.item, value);
      ref.invalidate(paintStockProvider);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }
}

/// One line asked for — a number or a name — in a dialog that owns its
/// field, so closing it never touches a field already let go.
Future<String?> _ask(
  BuildContext context, {
  required String title,
  required String fieldKey,
  required String saveKey,
  String initial = '',
  String? label,
  String? hint,
  bool number = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _AskDialog(
    title: title,
    initial: initial,
    label: label,
    hint: hint,
    fieldKey: fieldKey,
    saveKey: saveKey,
    number: number,
  ),
);

class _AskDialog extends StatefulWidget {
  const _AskDialog({
    required this.title,
    required this.initial,
    required this.fieldKey,
    required this.saveKey,
    required this.number,
    this.label,
    this.hint,
  });

  final String title;
  final String initial;
  final String? label;
  final String? hint;
  final String fieldKey;
  final String saveKey;
  final bool number;

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  late final _c = TextEditingController(text: widget.initial);

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: ValueKey(widget.fieldKey),
            controller: _c,
            autofocus: true,
            keyboardType: widget.number
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            inputFormatters: widget.number
                ? [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))]
                : null,
            decoration: InputDecoration(labelText: widget.label),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          if (widget.hint case final hint?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: ValueKey(widget.saveKey),
          onPressed: () => Navigator.of(context).pop(_c.text),
          child: Text(l10n.filmReqSave),
        ),
      ],
    );
  }
}

/// One paint's receipts: when, how much, at what price and with the
/// bringing, from whom and where, who took it in.
Future<void> showPaintHistory(BuildContext context, PaintItem paint) =>
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final l10n = AppLocalizations.of(context);
          final money = mdfMoney(context);
          final status = context.statusColors;
          return AlertDialog(
            title: Text(l10n.paintHistory(paint.title)),
            content: SizedBox(
              width: AppSpacing.xxxl * 10,
              child: FutureBuilder<List<PaintReceipt>>(
                future: ref
                    .read(paintStockRepositoryProvider)
                    .history(paint.item),
                builder: (context, snap) {
                  final rows = snap.data;
                  if (rows == null) {
                    return const LinearProgressIndicator();
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final r in rows)
                        ListTile(
                          key: ValueKey('paintReceipt:${r.receipt}'),
                          dense: true,
                          title: Text(
                            [
                              mdfDay(r.date),
                              l10n.paintKgShort(_kgText(r.kg)),
                              if (r.priceKg case final p?)
                                l10n.paintPerKg(money.format(p)),
                            ].join(' · '),
                            style: TextStyle(
                              decoration: r.cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            [
                              ?r.supplier,
                              ?r.city,
                              ?r.transport,
                              if ((r.deliveryCost ?? 0) > 0)
                                [
                                  l10n.filmDeliveryCost,
                                  money.format(r.deliveryCost),
                                ].join(' '),
                              if (r.landedKg case final l?)
                                l10n.paintLanded(money.format(l)),
                              if (r.receivedBy case final who?)
                                l10n.paintTakenBy(who),
                            ].join(' · '),
                            style: TextStyle(
                              color: r.owed ? status.warning : null,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.filmClose),
              ),
            ],
          );
        },
      ),
    );

/// «Приход краски» (owner, 15.11.2026): a colour and what it is, kilograms
/// — or cans of so many kilos — at a price a kilo; the supplier and his
/// city; paid now, on credit or by his invoice; how it came and what that
/// cost; who took it in. What a kilo came to with the bringing, and whether
/// it costs more than last time.
Future<bool?> showPaintReceive(
  BuildContext context,
  PaintStock stock, {
  String? colour,
  String? base,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _ReceiveDialog(stock: stock, colour: colour, base: base),
);

class _ReceiveDialog extends ConsumerStatefulWidget {
  const _ReceiveDialog({required this.stock, this.colour, this.base});

  final PaintStock stock;
  final String? colour;

  /// A material of the recipe with no colour — «Грунт», «Отвердитель».
  final String? base;

  @override
  ConsumerState<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends ConsumerState<_ReceiveDialog> {
  late PaintStock _stock = widget.stock;
  late String? _colour = widget.colour;
  late final _base = TextEditingController(text: widget.base ?? '');
  final _kgField = TextEditingController();
  final _cans = TextEditingController();
  final _canKg = TextEditingController();
  final _price = TextEditingController();
  bool _byCans = false;
  String? _supplier;
  final _terms = FilmReceiptTerms();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromLast();
  }

  /// Primer, hardener, thinner, lacquer: kept by name, with no colour
  /// (owner, 15.11.2026: «грунт мы покупаем вёдрами»).
  bool get _component {
    final base = _base.text.trim().toLowerCase();
    if (base.isEmpty) return false;
    return _stock.recipe.materials.any((m) {
      final name = m.toLowerCase();
      return base == name || base.startsWith('$name ');
    });
  }

  /// What last time says: the supplier, what the paint was, its price.
  void _fromLast() {
    final colour = _component ? '' : _colour;
    final last = colour == null
        ? null
        : _stock.lastOf(
            colour,
            base: _component ? _base.text.trim() : null,
          );
    _supplier =
        last?.supplier ??
        _supplier ??
        _stock.suppliers.where((s) => s.paint).firstOrNull?.id;
    if (colour != null && _base.text.isEmpty) {
      final known = _stock.paints.where((p) => p.colour == colour);
      if (known.length == 1 && known.single.base != null) {
        _base.text = known.single.base!;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_base, _kgField, _cans, _canKg, _price]) {
      c.dispose();
    }
    _terms.dispose();
    super.dispose();
  }

  double get _kg => _byCans
      ? (filmNumber(_cans.text) ?? 0) * (filmNumber(_canKg.text) ?? 0)
      : filmNumber(_kgField.text) ?? 0;

  double get _priceKg => filmNumber(_price.text) ?? 0;

  /// A new paint supplier with its card, or the chosen one's card put
  /// right — paint's own, apart from film (owner, 15.11.2026).
  Future<void> _editSupplier({PaintSupplier? current}) async {
    final card = await showPaintSupplierCard(context, current: current);
    if (card == null || !mounted) return;
    try {
      final repo = ref.read(paintStockRepositoryProvider);
      final now = current == null
          ? await repo.addSupplier(card)
          : await repo.setSupplier(current.id, card);
      if (!mounted) return;
      setState(() {
        _stock = now;
        _supplier =
            current?.id ??
            now.suppliers.where((s) => s.name == card.name).firstOrNull?.id;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// What the queue needs of what is being received: the colour's enamel,
  /// or the material by its name.
  double? get _queueNeed {
    if (_component) {
      final base = _base.text.trim().toLowerCase();
      final m = _stock.materials.where((m) {
        final name = m.name.toLowerCase();
        return base == name || base.startsWith('$name ');
      }).firstOrNull;
      return m?.needKg;
    }
    final colour = _colour;
    if (colour == null) return null;
    final rows = _stock.queue.where(
      (n) => n.colour == colour || n.colour.startsWith('$colour · '),
    );
    if (rows.isEmpty) return null;
    return rows.fold<double>(0, (a, n) => a + n.needKg);
  }

  /// «4 × 5 кг» — how it came, on the receipt.
  String _cansNote(AppLocalizations l10n) =>
      '${_cans.text.trim()} × ${l10n.paintKgShort(_canKg.text.trim())}';

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final opts = ref.read(filmDeliveryOptionsProvider).value;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(paintStockRepositoryProvider)
          .receive(
            colour: _component ? '' : _colour!,
            kg: double.parse(_kg.toStringAsFixed(3)),
            priceKg: _priceKg,
            supplier: _supplier!,
            base: _base.text.trim().isEmpty ? null : _base.text.trim(),
            delivery: _terms.delivery(opts, _supplier),
            receivedBy: _terms.takerOf(opts),
            supplierPay: _terms.supplierPay,
            note: _byCans ? _cansNote(l10n) : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  /// Each colour system a heading, its colours under it.
  List<DropdownMenuItem<String>> _colourItems(
    MdfDictionaries dicts,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final groups = dicts.paintGroups();
    final listed = {
      for (final g in groups)
        for (final c in g.colours) c.value,
    };
    return [
      for (final g in groups)
        if (g.colours.isNotEmpty) ...[
          DropdownMenuItem<String>(
            enabled: false,
            value: '\u0000${g.name}',
            child: Text(
              g.name.isEmpty ? l10n.mdfPaintNoSystem : g.name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final c in g.colours)
            DropdownMenuItem<String>(
              value: c.value,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
                child: Text(c.value),
              ),
            ),
        ],
      if (_colour case final c? when !listed.contains(c))
        DropdownMenuItem<String>(value: c, child: Text(c)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final dicts =
        ref.watch(mdfDictionariesProvider).value ?? MdfDictionaries.empty;
    final opts = ref.watch(filmDeliveryOptionsProvider).value;
    final kg = _kg;
    final price = _priceKg;
    final total = kg * price;
    final cost = _terms.costAmount;
    final component = _component;
    final last = component
        ? _stock.lastOf('', base: _base.text.trim())
        : _colour == null
        ? null
        : _stock.lastOf(
            _colour!,
            base: _base.text.trim().isEmpty ? null : _base.text.trim(),
          );
    final lastPrice = last?.priceKg;
    final chosen = _stock.suppliers.where((s) => s.id == _supplier).firstOrNull;
    // The supplier's smallest batch is more than the queue takes: the rest
    // goes on the shelf, and the painter is told the norm (owner, 15.11.2026).
    final need = _queueNeed;
    final left = need == null || need <= 0 ? 0.0 : kg - need;
    final ready =
        (component || _colour != null) &&
        _supplier != null &&
        kg > 0 &&
        price > 0 &&
        !_terms.incomplete;
    final suggestions = {
      ..._stock.bases,
      l10n.paintBaseEnamelMatt,
      l10n.paintBaseEnamelGloss,
      l10n.paintBasePrimer,
      l10n.paintBaseLacquer,
      // Whatever the recipe uses — hardener, thinner (owner, 15.11.2026).
      ..._stock.recipe.materials,
    };
    Widget row(String a, String b, {Key? key, TextStyle? style}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(a, style: style)),
          Text(b, style: style),
        ],
      ),
    );
    return AlertDialog(
      title: Text(l10n.paintReceive),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // No colour for primer, hardener, thinner.
              if (!component)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('paintColour:$_colour'),
                        initialValue: _colour,
                        isExpanded: true,
                        items: _colourItems(dicts, theme, l10n),
                        onChanged: (v) => setState(() {
                          _colour = v;
                          _fromLast();
                        }),
                        decoration: InputDecoration(
                          labelText: l10n.paintColour,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('paintColourDict'),
                      tooltip: l10n.mdfDictOpen,
                      icon: const Icon(AppIcons.dictionary),
                      onPressed: () async {
                        final picked = await showMdfDictionary(
                          context,
                          MdfDictKind.paint,
                          title: l10n.mdfDictPaint,
                          current: _colour,
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _colour = picked;
                            _fromLast();
                          });
                        }
                      },
                    ),
                  ],
                ),
              TextField(
                key: const ValueKey('paintBase'),
                controller: _base,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.paintBase),
              ),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final b in suggestions)
                    ActionChip(
                      key: ValueKey('paintBase:$b'),
                      label: Text(b),
                      onPressed: () => setState(() {
                        _base.text = b;
                        _fromLast();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_byCans) ...[
                    _number(_cans, l10n.paintCanCount, 'paintCans'),
                    const Text('×'),
                    _number(_canKg, l10n.paintCanKg, 'paintCanKg'),
                    Text('= ${l10n.paintKgShort(_kgText(kg))}'),
                  ] else
                    _number(_kgField, l10n.paintKg, 'paintKgValue'),
                  FilterChip(
                    key: const ValueKey('paintByCans'),
                    label: Text(l10n.paintCans),
                    selected: _byCans,
                    onSelected: (on) => setState(() => _byCans = on),
                  ),
                  _number(_price, l10n.paintPriceKg, 'paintPriceKgValue'),
                ],
              ),
              if (left > 0.005)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.paintBatchLeft(_kgText(need!), _kgText(left)),
                    key: const ValueKey('paintBatchLeft'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status.warning,
                    ),
                  ),
                ),
              // Dearer or cheaper than last time — and from whom it was.
              if (lastPrice != null && price > 0 && lastPrice > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    () {
                      final pct = ((price - lastPrice) / lastPrice * 100)
                          .round();
                      final was = money.format(lastPrice);
                      final who = last?.supplierName ?? '';
                      if (pct > 0) return l10n.paintPriceUp('$pct', was, who);
                      if (pct < 0) {
                        return l10n.paintPriceDown('${-pct}', was, who);
                      }
                      return l10n.paintPriceSame(was, who);
                    }(),
                    key: const ValueKey('paintPriceVsLast'),
                    style: TextStyle(
                      color: price > lastPrice
                          ? status.warning
                          : price < lastPrice
                          ? status.success
                          : null,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('paintSupplier:$_supplier'),
                      initialValue: _supplier,
                      isExpanded: true,
                      items: [
                        for (final s in _stock.suppliers)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text([s.name, ?s.city].join(' · ')),
                          ),
                      ],
                      onChanged: (v) => setState(() => _supplier = v),
                      decoration: InputDecoration(
                        labelText: l10n.paintSupplier,
                      ),
                    ),
                  ),
                  if (chosen != null)
                    IconButton(
                      key: const ValueKey('paintSupplierEdit'),
                      tooltip: l10n.paintSupplierEdit,
                      icon: const Icon(AppIcons.edit),
                      onPressed: () => _editSupplier(current: chosen),
                    ),
                  IconButton(
                    key: const ValueKey('paintSupplierAdd'),
                    tooltip: l10n.paintNewSupplier,
                    icon: const Icon(AppIcons.add),
                    onPressed: _editSupplier,
                  ),
                ],
              ),
              // Who to ring, and the smallest batch it sells.
              if (chosen != null)
                Builder(
                  builder: (context) {
                    final about = [
                      ?chosen.contact,
                      ?(chosen.whatsapp ?? chosen.phone),
                      if (chosen.minOrder case final min?)
                        l10n.paintSupplierMin(min),
                    ];
                    if (about.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      key: const ValueKey('paintSupplierAbout'),
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        about.join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              FilmSupplierPayField(
                terms: _terms,
                update: setState,
                deptCash: false,
              ),
              if (opts != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilmDeliveryField(
                  terms: _terms,
                  opts: opts,
                  supplier: _supplier,
                  update: setState,
                  costHelper: kg > 0
                      ? l10n.paintDeliveryPerKg(money.format(cost / kg))
                      : null,
                ),
              ],
              if (total > 0)
                Container(
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
                        [
                          l10n.paintToSupplier(_kgText(kg)),
                          _terms.supplierLabel(l10n, deptCash: false),
                        ].join(' · '),
                        money.format(total),
                        key: const ValueKey('paintSum:supplier'),
                      ),
                      if (cost > 0)
                        row(
                          [
                            l10n.filmDeliveryCost,
                            _terms.driverLabel(l10n, deptCash: false),
                          ].join(' · '),
                          money.format(cost),
                          key: const ValueKey('paintSum:delivery'),
                        ),
                      const Divider(),
                      row(
                        l10n.filmReceiveGrand,
                        money.format(total + cost),
                        key: const ValueKey('paintSum:total'),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.paintLanded(money.format(price + cost / kg)),
                        key: const ValueKey('paintSum:landed'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
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
          key: const ValueKey('paintReceiveSave'),
          onPressed: _busy || !ready ? null : _save,
          child: Text(
            [
              l10n.paintReceiveSave,
              if (total > 0) money.format(total + cost),
            ].join(' · '),
          ),
        ),
      ],
    );
  }

  Widget _number(TextEditingController c, String label, String key) => SizedBox(
    width: AppSpacing.xxxl * 2,
    child: TextField(
      key: ValueKey(key),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );
}

/// A paint supplier's card: the company or the person, city, contact,
/// phones, the smallest batch it sells, a note.
///
/// [title] for another department's supplier — the glue's (17.11.2026).
Future<PaintSupplierCard?> showPaintSupplierCard(
  BuildContext context, {
  PaintSupplier? current,
  String? title,
}) => showDialog<PaintSupplierCard>(
  context: context,
  builder: (_) => _SupplierCardDialog(current: current, title: title),
);

class _SupplierCardDialog extends StatefulWidget {
  const _SupplierCardDialog({this.current, this.title});

  final PaintSupplier? current;
  final String? title;

  @override
  State<_SupplierCardDialog> createState() => _SupplierCardDialogState();
}

class _SupplierCardDialogState extends State<_SupplierCardDialog> {
  late final _name = TextEditingController(text: widget.current?.name);
  late final _city = TextEditingController(text: widget.current?.city);
  late final _contact = TextEditingController(text: widget.current?.contact);
  late final _phone = TextEditingController(text: widget.current?.phone);
  late final _whatsapp = TextEditingController(
    text: widget.current?.whatsapp,
  );
  late final _min = TextEditingController(text: widget.current?.minOrder);
  late final _note = TextEditingController(text: widget.current?.note);

  @override
  void dispose() {
    for (final c in [_name, _city, _contact, _phone, _whatsapp, _min, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _of(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(
      TextEditingController c,
      String label,
      String key, {
      String? hint,
      TextInputType? type,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: TextField(
        key: ValueKey(key),
        controller: c,
        keyboardType: type,
        inputFormatters: [
          if (type == TextInputType.phone) const PhoneMaskFormatter(),
        ],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
    return AlertDialog(
      title: Text(
        widget.current == null
            ? widget.title ?? l10n.paintSupplierCard
            : l10n.paintSupplierEdit,
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(_name, l10n.paintSupplierName, 'paintSupplierCard:name'),
              field(_city, l10n.paintSupplierCity, 'paintSupplierCard:city'),
              field(
                _contact,
                l10n.paintSupplierContact,
                'paintSupplierCard:contact',
              ),
              field(
                _phone,
                l10n.paintSupplierPhone,
                'paintSupplierCard:phone',
                type: TextInputType.phone,
              ),
              field(
                _whatsapp,
                l10n.paintSupplierWhatsApp,
                'paintSupplierCard:whatsapp',
                type: TextInputType.phone,
              ),
              field(
                _min,
                l10n.paintSupplierMinOrder,
                'paintSupplierCard:min',
                hint: l10n.paintSupplierMinHint,
              ),
              field(_note, l10n.paintSupplierNote, 'paintSupplierCard:note'),
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
          key: const ValueKey('paintSupplierCard:save'),
          onPressed: _name.text.trim().length < 2
              ? null
              : () => Navigator.of(context).pop((
                  name: _name.text.trim(),
                  city: _of(_city),
                  contact: _of(_contact),
                  phone: _of(_phone),
                  whatsapp: _of(_whatsapp),
                  minOrder: _of(_min),
                  note: _of(_note),
                )),
          child: Text(l10n.filmReqSave),
        ),
      ],
    );
  }
}
