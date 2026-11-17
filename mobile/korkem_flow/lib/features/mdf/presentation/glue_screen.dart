import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_receipt_terms.dart';
import 'package:korkem_flow/features/mdf/data/glue_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/glue_stock.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/paint_stock_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _kg(double v) => filmMetres(v);

/// «Клей для ПВХ» (owner, 17.11.2026): each glue — what it is, its norm,
/// what is here, what a kilo and a m² cost, what it sells for by the bucket
/// and the litre; who sells it and for how much with the bringing; what the
/// vacuum queue needs; the millings' factors; what is owed.
class GlueScreen extends ConsumerWidget {
  const GlueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stock = ref.watch(glueStockProvider);
    final canEdit = stock.value?.canEdit ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.glueTitle),
        actions: [
          IconButton(
            key: const ValueKey('glueMonth'),
            tooltip: l10n.glueMonthTitle,
            icon: const Icon(AppIcons.report),
            onPressed: () => unawaited(context.push(Routes.glueMonth)),
          ),
          if (canEdit)
            IconButton(
              key: const ValueKey('glueAdd'),
              tooltip: l10n.glueAdd,
              icon: const Icon(AppIcons.add),
              onPressed: () => unawaited(_addGlue(context, ref)),
            ),
        ],
      ),
      floatingActionButton: canEdit && (stock.value?.glues.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              key: const ValueKey('glueReceive'),
              onPressed: () => unawaited(_receive(context, ref)),
              icon: const Icon(AppIcons.moveIn),
              label: Text(l10n.glueReceive),
            )
          : null,
      body: stock.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(glueStockProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(glueStockProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ReadableWidth(child: _Body(stock: s)),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _addGlue(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final card = await showGlueCard(context);
  if (card == null) return;
  try {
    await ref.read(glueStockRepositoryProvider).addGlue(card);
    ref.invalidate(glueStockProvider);
  } on Object catch (e) {
    messenger.showFailure(e, l10n);
  }
}

Future<void> _receive(BuildContext context, WidgetRef ref) async {
  final stock = ref.read(glueStockProvider).value;
  if (stock == null) return;
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => _ReceiveDialog(stock: stock),
  );
  if (done ?? false) ref.invalidate(glueStockProvider);
}

class _Body extends ConsumerWidget {
  const _Body({required this.stock});

  final GlueStock stock;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function(GlueStockRepository repo) call,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await call(ref.read(glueStockRepositoryProvider));
      ref.invalidate(glueStockProvider);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final s = stock;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.glueHint, style: muted),
        const SizedBox(height: AppSpacing.md),
        // What the vacuum queue needs of the glue in work.
        Card(
          key: const ValueKey('glueQueue'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.glueQueue(
                    '${s.queueOrders}',
                    s.queueM2.toStringAsFixed(2),
                    _kg(s.queueKg),
                  ),
                  style: theme.textTheme.titleSmall,
                ),
                if (s.working == null && s.glues.isNotEmpty)
                  Text(
                    l10n.glueNoInWork,
                    style: TextStyle(color: status.warning),
                  )
                else if (s.queueShortKg > 0)
                  Text(
                    l10n.glueQueueShort(_kg(s.queueShortKg)),
                    key: const ValueKey('glueQueueShort'),
                    style: TextStyle(color: status.danger),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionLabel(l10n.glueGlues),
        // The first glue first: a receipt needs a glue to come in as
        // (owner, 17.11.2026: «а где вообще приход клея?»).
        if (s.glues.isEmpty) ...[
          Text(l10n.glueEmpty, style: muted),
          if (s.canEdit)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('glueAddFirst'),
                  onPressed: () => unawaited(_addGlue(context, ref)),
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.glueAddFirst),
                ),
              ),
            ),
        ],
        for (final g in s.glues)
          Card(
            key: ValueKey('glue:${g.item}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [g.title, ?g.origin].join(' · '),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (g.inWork)
                        Chip(
                          key: ValueKey('glueInWork:${g.item}'),
                          label: Text(l10n.glueInWork),
                          backgroundColor: status.success.withValues(
                            alpha: AppTint.surface,
                          ),
                        )
                      else if (s.canEdit)
                        TextButton(
                          key: ValueKey('glueTake:${g.item}'),
                          onPressed: () => _run(
                            context,
                            ref,
                            (repo) => repo.setInWork(g.item),
                          ),
                          child: Text(l10n.glueTakeInWork),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      Text(l10n.glueNormLine(g.normGM2.round().toString())),
                      Text(
                        l10n.glueOnHand(_kg(g.onHandKg)),
                        key: ValueKey('glueOnHand:${g.item}'),
                      ),
                      if (g.costKg case final c?)
                        Text(l10n.glueCostKg(money.format(c))),
                      if (g.costM2 case final c?)
                        Text(
                          l10n.glueCostM2(money.format(c)),
                          key: ValueKey('glueCostM2:${g.item}'),
                        ),
                    ],
                  ),
                  if (g.sellBucket != null || g.sellLitre != null)
                    Text(
                      l10n.glueSell(
                        g.sellBucket == null ? '—' : money.format(g.sellBucket),
                        g.sellLitre == null ? '—' : money.format(g.sellLitre),
                      ),
                      style: muted,
                    ),
                  if (g.fact?.factGM2 case final f?)
                    Text(
                      l10n.glueFact(f.round().toString()),
                      key: ValueKey('glueFact:${g.item}'),
                      style: TextStyle(
                        color: f > g.normGM2 * 1.1 ? status.warning : null,
                      ),
                    ),
                  if (s.canEdit)
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton.icon(
                          key: ValueKey('glueEdit:${g.item}'),
                          onPressed: () async {
                            final card = await showGlueCard(
                              context,
                              current: g,
                            );
                            if (card == null || !context.mounted) return;
                            await _run(
                              context,
                              ref,
                              (repo) => repo.setGlue(g.item, card),
                            );
                          },
                          icon: const Icon(AppIcons.edit),
                          label: Text(l10n.glueEdit),
                        ),
                        TextButton.icon(
                          key: ValueKey('glueCount:${g.item}'),
                          onPressed: () async {
                            final kg = await _askNumber(
                              context,
                              title: l10n.glueCountTitle(g.title),
                              initial: _kg(g.onHandKg),
                              fieldKey: 'glueCountValue',
                            );
                            if (kg == null || !context.mounted) return;
                            await _run(
                              context,
                              ref,
                              (repo) => repo.count(g.item, kg),
                            );
                          },
                          icon: const Icon(AppIcons.calculate),
                          label: Text(l10n.glueCount),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: SectionLabel(l10n.glueSuppliers)),
            if (s.canEdit)
              TextButton.icon(
                key: const ValueKey('glueSupplierAdd'),
                onPressed: () async {
                  final card = await showPaintSupplierCard(
                    context,
                    title: l10n.glueSupplierAdd,
                  );
                  if (card == null || !context.mounted) return;
                  await _run(context, ref, (repo) => repo.addSupplier(card));
                },
                icon: const Icon(AppIcons.add),
                label: Text(l10n.glueSupplierAdd),
              ),
          ],
        ),
        for (final sup in s.suppliers)
          Card(
            key: ValueKey('glueSupplier:${sup.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [sup.name, ?sup.city].join(' · '),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (s.canEdit)
                        IconButton(
                          key: ValueKey('glueSupplierEdit:${sup.id}'),
                          tooltip: l10n.paintSupplierEdit,
                          icon: const Icon(AppIcons.edit),
                          onPressed: () async {
                            final card = await showPaintSupplierCard(
                              context,
                              current: sup.asCard,
                            );
                            if (card == null || !context.mounted) return;
                            await _run(
                              context,
                              ref,
                              (repo) => repo.setSupplier(sup.id, card),
                            );
                          },
                        ),
                    ],
                  ),
                  if ([
                        ?sup.contact,
                        ?(sup.whatsapp ?? sup.phone),
                        if (sup.minOrder case final m?)
                          l10n.paintSupplierMin(m),
                      ].join(' · ')
                      case final about when about.isNotEmpty)
                    Text(about, style: muted),
                  for (final b in sup.bought)
                    if (b.landedKg != null)
                      Text(
                        [
                          l10n.glueBought(
                            b.title,
                            money.format(b.priceKg ?? 0),
                            money.format(b.deliveryKg ?? 0),
                            money.format(b.landedKg),
                          ),
                          if (b.cheapest) l10n.glueCheapest,
                        ].join(' · '),
                        key: ValueKey('glueBought:${sup.id}:${b.item}'),
                        style: TextStyle(
                          color: b.cheapest ? status.success : null,
                          fontWeight: b.cheapest ? FontWeight.w600 : null,
                        ),
                      ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        SectionLabel(l10n.glueMilling),
        Text(l10n.glueMillingHint(s.edgeCoats.toString()), style: muted),
        for (final m in s.milling.entries)
          ListTile(
            key: ValueKey('glueMilling:${m.key}'),
            contentPadding: EdgeInsets.zero,
            title: Text(m.key),
            trailing: Text(m.value.toStringAsFixed(2)),
            onTap: !s.canEdit
                ? null
                : () async {
                    final value = await _askNumber(
                      context,
                      title: l10n.glueMillingTitle(m.key),
                      initial: m.value.toStringAsFixed(2),
                      fieldKey: 'glueMillingValue',
                    );
                    if (value == null || !context.mounted) return;
                    await _run(
                      context,
                      ref,
                      (repo) => repo.setMilling({...s.milling, m.key: value}),
                    );
                  },
          ),
        if (s.owed.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionLabel(l10n.glueOwed),
          for (final o in s.owed)
            ListTile(
              key: ValueKey('glueOwed:${o.receipt}'),
              contentPadding: EdgeInsets.zero,
              title: Text('${o.supplier} · ${o.glue}'),
              subtitle: Text(
                [
                  mdfDay(o.date),
                  l10n.paintKgShort(_kg(o.kg)),
                  if (o.invoiceNo case final no?) l10n.filmByInvoiceNo(no),
                  if (o.dueOn case final due?) l10n.filmInvoiceDue(mdfDay(due)),
                ].join(' · '),
                style: TextStyle(color: o.overdue ? status.danger : null),
              ),
              trailing: Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (o.amount case final amount?) Text(money.format(amount)),
                  PopupMenuButton<String>(
                    key: ValueKey('gluePay:${o.receipt}'),
                    tooltip: l10n.paintPaid,
                    onSelected: (method) async {
                      final bank = await filmAskBank(context, ref, method);
                      if (bank == null || !context.mounted) return;
                      await _run(
                        context,
                        ref,
                        (repo) => repo.paySupplier(
                          o.receipt,
                          method,
                          bank: bank.isEmpty ? null : bank,
                        ),
                      );
                    },
                    itemBuilder: (_) => [
                      for (final m in [filmCash, filmTransfer, filmCard])
                        PopupMenuItem(
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
        ],
      ],
    );
  }
}

/// A number asked for, in a dialog that owns its field.
Future<double?> _askNumber(
  BuildContext context, {
  required String title,
  required String fieldKey,
  String initial = '',
}) => showDialog<double>(
  context: context,
  builder: (_) =>
      _NumberDialog(title: title, initial: initial, fieldKey: fieldKey),
);

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.initial,
    required this.fieldKey,
  });

  final String title;
  final String initial;
  final String fieldKey;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = filmNumber(_field.text);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: ValueKey(widget.fieldKey),
        controller: _field,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('glueNumberSave'),
          onPressed: value == null
              ? null
              : () => Navigator.of(context).pop(value),
          child: Text(l10n.glueSave),
        ),
      ],
    );
  }
}

/// A glue's card — new, or [current] put right.
Future<GlueCard?> showGlueCard(BuildContext context, {GlueItem? current}) =>
    showDialog<GlueCard>(
      context: context,
      builder: (_) => _GlueCardDialog(current: current),
    );

class _GlueCardDialog extends StatefulWidget {
  const _GlueCardDialog({this.current});

  final GlueItem? current;

  @override
  State<_GlueCardDialog> createState() => _GlueCardDialogState();
}

class _GlueCardDialogState extends State<_GlueCardDialog> {
  late final GlueItem? _g = widget.current;
  late final _name = TextEditingController(text: _g?.title);
  late final _origin = TextEditingController(text: _g?.origin);
  late final _bucket = TextEditingController(
    text: _g?.bucketKg == null ? '' : _kg(_g!.bucketKg!),
  );
  late final _density = TextEditingController(
    text: (_g?.kgPerLitre ?? 1).toString(),
  );
  late final _norm = TextEditingController(
    text: (_g?.normGM2 ?? 100).round().toString(),
  );
  late final _reserve = TextEditingController(
    text: _kg(_g?.reserveKg ?? 0),
  );
  late final _markupBucket = TextEditingController(
    text: (_g?.markupBucket ?? 0).round().toString(),
  );
  late final _markupLitre = TextEditingController(
    text: (_g?.markupLitre ?? 0).round().toString(),
  );

  List<TextEditingController> get _all => [
    _name,
    _origin,
    _bucket,
    _density,
    _norm,
    _reserve,
    _markupBucket,
    _markupLitre,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label,
    String key, {
    String? hint,
    bool number = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: TextField(
      key: ValueKey(key),
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))]
          : null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, helperText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final density = filmNumber(_density.text);
    final norm = filmNumber(_norm.text);
    final ready =
        _name.text.trim().length >= 2 && density != null && norm != null;
    return AlertDialog(
      title: Text(_g == null ? l10n.glueAdd : l10n.glueEdit),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_g == null)
                _field(_name, l10n.glueName, 'glueCard:name', number: false),
              _field(
                _origin,
                l10n.glueOrigin,
                'glueCard:origin',
                hint: l10n.glueOriginHint,
                number: false,
              ),
              _field(_bucket, l10n.glueBucketKg, 'glueCard:bucket'),
              _field(
                _density,
                l10n.glueKgPerLitre,
                'glueCard:density',
                hint: l10n.glueKgPerLitreHint,
              ),
              _field(_norm, l10n.glueNorm, 'glueCard:norm'),
              _field(_reserve, l10n.glueReserve, 'glueCard:reserve'),
              _field(
                _markupBucket,
                l10n.glueMarkupBucket,
                'glueCard:markupBucket',
              ),
              _field(
                _markupLitre,
                l10n.glueMarkupLitre,
                'glueCard:markupLitre',
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
          key: const ValueKey('glueCard:save'),
          onPressed: !ready
              ? null
              : () => Navigator.of(context).pop((
                  name: _name.text.trim(),
                  origin: _origin.text.trim().isEmpty
                      ? null
                      : _origin.text.trim(),
                  bucketKg: filmNumber(_bucket.text),
                  kgPerLitre: density,
                  normGM2: norm,
                  reserveKg: filmNumber(_reserve.text) ?? 0,
                  markupBucket: filmNumber(_markupBucket.text) ?? 0,
                  markupLitre: filmNumber(_markupLitre.text) ?? 0,
                )),
          child: Text(l10n.glueSave),
        ),
      ],
    );
  }
}

/// «Приход клея»: which glue, from whom, how much — kilograms, litres or
/// buckets — at what price a kilo, a litre or a bucket; how it came and was
/// paid, as a film receipt says it.
class _ReceiveDialog extends ConsumerStatefulWidget {
  const _ReceiveDialog({required this.stock});

  final GlueStock stock;

  @override
  ConsumerState<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends ConsumerState<_ReceiveDialog> {
  late GlueStock _stock = widget.stock;
  late String? _item = _stock.working?.item ?? _stock.glues.firstOrNull?.item;
  late String? _supplier = _stock.suppliers.firstOrNull?.id;
  final _qty = TextEditingController();
  final _price = TextEditingController();
  late GlueUnit _unit = _glue?.bucketKg == null ? GlueUnit.kg : GlueUnit.bucket;
  late GlueUnit _per = _unit;
  final _terms = FilmReceiptTerms();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _terms.dispose();
    super.dispose();
  }

  GlueItem? get _glue => _stock.glues.where((g) => g.item == _item).firstOrNull;

  /// Kilograms of one unit of this glue; null when its bucket is not known.
  double? _kgOf(GlueUnit unit) => switch (unit) {
    GlueUnit.kg => 1,
    GlueUnit.litre => _glue?.kgPerLitre,
    GlueUnit.bucket => _glue?.bucketKg,
  };

  String _unitLabel(AppLocalizations l10n, GlueUnit u) => switch (u) {
    GlueUnit.kg => l10n.glueUnitKg,
    GlueUnit.litre => l10n.glueUnitLitre,
    GlueUnit.bucket => l10n.glueUnitBucket,
  };

  Future<void> _addSupplier() async {
    final l10n = AppLocalizations.of(context);
    final card = await showPaintSupplierCard(
      context,
      title: l10n.glueSupplierAdd,
    );
    if (card == null || !mounted) return;
    try {
      final now = await ref.read(glueStockRepositoryProvider).addSupplier(card);
      if (!mounted) return;
      setState(() {
        _stock = now;
        _supplier = now.suppliers
            .where((s) => s.name == card.name)
            .firstOrNull
            ?.id;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save() async {
    final opts = ref.read(filmDeliveryOptionsProvider).value;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(glueStockRepositoryProvider)
          .receive(
            item: _item!,
            qty: filmNumber(_qty.text)!,
            unit: _unit,
            price: filmNumber(_price.text)!,
            pricePer: _per,
            supplier: _supplier!,
            delivery: _terms.delivery(opts, _supplier),
            receivedBy: _terms.takerOf(opts),
            supplierPay: _terms.supplierPay,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final opts = ref.watch(filmDeliveryOptionsProvider).value;
    final qty = filmNumber(_qty.text) ?? 0;
    final price = filmNumber(_price.text) ?? 0;
    final unitKg = _kgOf(_unit);
    final perKg = _kgOf(_per);
    final kg = unitKg == null ? 0.0 : qty * unitKg;
    final priceKg = perKg == null || perKg == 0 ? 0.0 : price / perKg;
    final total = kg * priceKg;
    final cost = _terms.costAmount;
    final ready =
        _item != null &&
        _supplier != null &&
        kg > 0 &&
        priceKg > 0 &&
        !_terms.incomplete;
    Widget units(GlueUnit selected, ValueChanged<GlueUnit> pick, String key) =>
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final u in GlueUnit.values)
              ChoiceChip(
                key: ValueKey('$key:${u.name}'),
                label: Text(_unitLabel(l10n, u)),
                selected: selected == u,
                onSelected: _kgOf(u) == null ? null : (_) => pick(u),
              ),
          ],
        );
    Widget number(TextEditingController c, String label, String key) =>
        SizedBox(
          width: AppSpacing.xxxl * 3,
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
    return AlertDialog(
      title: Text(l10n.glueReceive),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('glueReceiveItem:$_item'),
                initialValue: _item,
                isExpanded: true,
                items: [
                  for (final g in _stock.glues)
                    DropdownMenuItem(value: g.item, child: Text(g.title)),
                ],
                onChanged: (v) => setState(() {
                  _item = v;
                  if (_kgOf(_unit) == null) _unit = GlueUnit.kg;
                  if (_kgOf(_per) == null) _per = GlueUnit.kg;
                }),
                decoration: InputDecoration(labelText: l10n.glueGlue),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('glueReceiveSupplier:$_supplier'),
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
                        labelText: l10n.glueSupplier,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('glueReceiveSupplierAdd'),
                    tooltip: l10n.glueSupplierAdd,
                    icon: const Icon(AppIcons.add),
                    onPressed: _addSupplier,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  number(_qty, l10n.glueQty, 'glueReceiveQty'),
                  units(_unit, (u) => setState(() => _unit = u), 'glueUnit'),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  number(_price, l10n.gluePrice, 'glueReceivePrice'),
                  Text(l10n.gluePer),
                  units(_per, (u) => setState(() => _per = u), 'gluePer'),
                ],
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
                ),
              ],
              if (total > 0)
                Container(
                  key: const ValueKey('glueReceiveSum'),
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.glueReceiveSum(_kg(kg), money.format(priceKg)),
                      ),
                      Text(
                        l10n.glueLanded(money.format(priceKg + cost / kg)),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(money.format(total + cost)),
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
          key: const ValueKey('glueReceiveSave'),
          onPressed: _busy || !ready ? null : _save,
          child: Text(l10n.glueSave),
        ),
      ],
    );
  }
}
