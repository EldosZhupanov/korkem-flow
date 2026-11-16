import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_receipt_terms.dart';
import 'package:korkem_flow/features/mdf/data/paint_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/domain/paint_stock.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _num(double v) => filmMetres(v);

/// What a plan takes, material by material, and what it all costs — in the
/// calculator and on an order's card (owner, 15.11.2026).
class PaintPlanView extends StatelessWidget {
  const PaintPlanView({required this.plan, super.key});

  final PaintPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final small = theme.textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in plan.lines)
          Padding(
            key: ValueKey('paintPlanLine:${line.name}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text([line.name, ?line.colour].join(' · ')),
                ),
                Text(l10n.paintKgShort(_num(line.kg))),
                SizedBox(
                  width: AppSpacing.xxxl * 2,
                  child: Text(
                    line.cost == null ? '—' : money.format(line.cost),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        Text(
          l10n.paintCalcTotal(
            _num(plan.kg),
            plan.cost == null ? '—' : money.format(plan.cost),
          ),
          key: const ValueKey('paintPlanTotal'),
          style: theme.textTheme.titleSmall,
        ),
        if (plan.costM2 case final perM2?)
          Text(
            l10n.paintCalcPerM2(money.format(perM2)),
            key: const ValueKey('paintPlanPerM2'),
            style: small,
          ),
        if (!plan.priced)
          Text(
            l10n.paintCalcUnpriced,
            key: const ValueKey('paintPlanUnpriced'),
            style: small?.copyWith(color: context.statusColors.warning),
          ),
      ],
    );
  }
}

/// The plan's text to WhatsApp — to [phone] when said, else to whoever the
/// person picks there — or to the clipboard.
List<Widget> paintShareButtons(
  BuildContext context,
  String text, {
  String? phone,
  String? whatsAppLabel,
  String keyPrefix = 'paintShare',
}) {
  final l10n = AppLocalizations.of(context);
  return [
    TextButton.icon(
      key: ValueKey('$keyPrefix:copy'),
      icon: const Icon(AppIcons.copy),
      label: Text(l10n.paintCopy),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: text));
        messenger.showSnackBar(SnackBar(content: Text(l10n.paintCopied)));
      },
    ),
    FilledButton.tonalIcon(
      key: ValueKey('$keyPrefix:wa'),
      icon: const Icon(AppIcons.whatsApp),
      label: Text(whatsAppLabel ?? l10n.paintSendWhatsApp),
      onPressed: () => phone == null
          ? ContactActions.whatsAppText(text)
          : ContactActions.whatsAppMessage(phone, text),
    ),
  ];
}

/// «Сколько краски»: so many m², in a colour or any — each material in
/// kilograms, what it costs, the whole and a m²; sent to the supplier who
/// tints, or copied.
Future<void> showPaintPlan(
  BuildContext context,
  PaintStock stock, {
  double? m2,
  String? colour,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PlanDialog(stock: stock, m2: m2, colour: colour),
);

class _PlanDialog extends ConsumerStatefulWidget {
  const _PlanDialog({required this.stock, this.m2, this.colour});

  final PaintStock stock;
  final double? m2;
  final String? colour;

  @override
  ConsumerState<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends ConsumerState<_PlanDialog> {
  late final _m2 = TextEditingController(
    text: widget.m2 == null ? '' : _num(widget.m2!),
  );
  late String? _colour = widget.colour;
  late PaintRecipe _recipe = widget.stock.recipe;
  late final _priceM2 = TextEditingController(
    text: _recipe.priceM2 > 0 ? _num(_recipe.priceM2) : '',
  );
  late final _markup = TextEditingController(
    text: _recipe.markupPct > 0 ? _num(_recipe.markupPct) : '',
  );

  /// Who the plan goes to: a paint supplier with a number, or whoever is
  /// picked in WhatsApp.
  late String? _to = widget.stock.suppliers
      .where((s) => (s.whatsapp ?? s.phone) != null)
      .firstOrNull
      ?.id;
  PaintPlan? _plan;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if ((widget.m2 ?? 0) > 0) unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _m2.dispose();
    _priceM2.dispose();
    _markup.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(AppDebounce.search, () => unawaited(_load()));
  }

  Future<void> _load() async {
    final m2 = filmNumber(_m2.text) ?? 0;
    if (m2 <= 0) {
      setState(() => _plan = null);
      return;
    }
    try {
      final plan = await ref
          .read(paintStockRepositoryProvider)
          .plan(m2, colour: _colour);
      if (mounted) {
        setState(() {
          _plan = plan;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _editRecipe() async {
    final saved = await showPaintRecipe(context, _recipe);
    if (saved == null || !mounted) return;
    setState(() => _recipe = saved);
    await _load();
  }

  Future<void> _remember(double? priceM2, double? markup) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recipe = _recipe.withPrices(
      priceM2: priceM2 ?? 0,
      markupPct: markup ?? 0,
    );
    try {
      await ref.read(paintStockRepositoryProvider).setRecipe(recipe);
      ref.invalidate(paintStockProvider);
      if (mounted) setState(() => _recipe = recipe);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  /// Beside the cost: the shop's price, what is left of it, what the
  /// markup asks (owner, 15.11.2026).
  List<Widget> _money(PaintPlan plan) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final priceM2 = filmNumber(_priceM2.text);
    final markup = filmNumber(_markup.text);
    final costM2 = plan.costM2;
    final changed =
        (priceM2 ?? 0) != _recipe.priceM2 || (markup ?? 0) != _recipe.markupPct;
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
    return [
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          number(_priceM2, l10n.paintPriceM2, 'paintPlanPriceM2'),
          number(_markup, l10n.paintMarkup, 'paintPlanMarkup'),
          if (changed)
            TextButton(
              key: const ValueKey('paintPlanRemember'),
              onPressed: () => _remember(priceM2, markup),
              child: Text(l10n.paintRemember),
            ),
        ],
      ),
      if (costM2 != null && priceM2 != null && priceM2 > 0) ...[
        Text(
          l10n.paintLeftM2(money.format(priceM2 - costM2)),
          key: const ValueKey('paintPlanLeftM2'),
          style: theme.textTheme.titleSmall?.copyWith(
            color: priceM2 > costM2 ? status.success : status.danger,
          ),
        ),
        Text(
          l10n.paintLeftOrder(
            money.format((priceM2 - costM2) * plan.m2),
            _num(plan.m2),
          ),
          key: const ValueKey('paintPlanLeftOrder'),
        ),
      ],
      if (costM2 != null && markup != null && markup > 0)
        Text(
          l10n.paintByMarkup(
            money.format(costM2 * (1 + markup / 100)),
            money.format(costM2 * (1 + markup / 100) * plan.m2),
          ),
          key: const ValueKey('paintPlanByMarkup'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final to = widget.stock.suppliers.where((s) => s.id == _to).firstOrNull;
    final colours = {
      for (final n in widget.stock.queue) n.colour,
      for (final p in widget.stock.paints)
        if (p.colour.isNotEmpty) p.colour,
      ?_colour,
    }.toList();
    final plan = _plan;
    return AlertDialog(
      title: Text(l10n.paintCalc),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: AppSpacing.xxxl * 2,
                    child: TextField(
                      key: const ValueKey('paintPlanM2'),
                      controller: _m2,
                      autofocus: widget.m2 == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                      ],
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(
                        labelText: l10n.paintCalcM2,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('paintPlanColour:$_colour'),
                      initialValue: _colour,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(child: Text(l10n.paintCalcNoColour)),
                        for (final c in colours)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) {
                        setState(() => _colour = v);
                        unawaited(_load());
                      },
                      decoration: InputDecoration(labelText: l10n.paintColour),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (plan != null) ...[
                PaintPlanView(plan: plan),
                ..._money(plan),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  key: ValueKey('paintPlanTo:$_to'),
                  initialValue: _to,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(child: Text(l10n.paintSendToAnyone)),
                    for (final s in widget.stock.suppliers)
                      if ((s.whatsapp ?? s.phone) != null)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _to = v),
                  decoration: InputDecoration(labelText: l10n.paintSendTo),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('paintPlanRecipe'),
          icon: const Icon(AppIcons.recipe),
          label: Text(l10n.paintRecipeEdit),
          onPressed: _editRecipe,
        ),
        if (plan != null)
          ...paintShareButtons(
            context,
            plan.text,
            phone: to?.whatsapp ?? to?.phone,
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.filmClose),
        ),
      ],
    );
  }
}

/// «Рецепт покраски» (owner, 15.11.2026): the shop's layers — primer,
/// enamel, lacquer — grams a m² a coat, coats, a price for before it was
/// bought; what goes into each kilogram — hardener, thinner.
Future<PaintRecipe?> showPaintRecipe(
  BuildContext context,
  PaintRecipe recipe,
) => showDialog<PaintRecipe>(
  context: context,
  builder: (_) => _RecipeDialog(recipe: recipe),
);

class _PartDraft {
  _PartDraft(PaintPart p)
    : name = TextEditingController(text: p.name),
      // As painters say it: «отвердитель 50 %» of the weight.
      perKg = TextEditingController(
        text: p.perKg > 0 ? _num(p.perKg * 100) : '',
      ),
      price = TextEditingController(
        text: p.priceKg > 0 ? _num(p.priceKg) : '',
      );

  final TextEditingController name;
  final TextEditingController perKg;
  final TextEditingController price;

  PaintPart get value => PaintPart(
    name: name.text.trim(),
    perKg: (filmNumber(perKg.text) ?? 0) / 100,
    priceKg: filmNumber(price.text) ?? 0,
  );

  void dispose() {
    name.dispose();
    perKg.dispose();
    price.dispose();
  }
}

class _LayerDraft {
  _LayerDraft(PaintLayer l)
    : name = TextEditingController(text: l.name),
      gM2 = TextEditingController(text: l.gM2 > 0 ? _num(l.gM2) : ''),
      coats = TextEditingController(text: '${l.coats}'),
      price = TextEditingController(
        text: l.priceKg > 0 ? _num(l.priceKg) : '',
      ),
      colour = l.colour,
      parts = [for (final p in l.parts) _PartDraft(p)];

  final TextEditingController name;
  final TextEditingController gM2;
  final TextEditingController coats;
  final TextEditingController price;
  bool colour;
  final List<_PartDraft> parts;

  PaintLayer get value => PaintLayer(
    name: name.text.trim(),
    colour: colour,
    gM2: filmNumber(gM2.text) ?? 0,
    coats: (filmNumber(coats.text) ?? 0).round(),
    priceKg: filmNumber(price.text) ?? 0,
    parts: [
      for (final p in parts)
        if (p.name.text.trim().isNotEmpty) p.value,
    ],
  );

  void dispose() {
    for (final c in [name, gM2, coats, price]) {
      c.dispose();
    }
    for (final p in parts) {
      p.dispose();
    }
  }
}

class _RecipeDialog extends ConsumerStatefulWidget {
  const _RecipeDialog({required this.recipe});

  final PaintRecipe recipe;

  @override
  ConsumerState<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends ConsumerState<_RecipeDialog> {
  late final List<_LayerDraft> _layers = [
    for (final l in widget.recipe.layers) _LayerDraft(l),
  ];
  // Taken out of the form: disposed with the dialog, not under a field
  // still being torn down.
  final List<_LayerDraft> _gone = [];
  final List<_PartDraft> _goneParts = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final l in [..._layers, ..._gone]) {
      l.dispose();
    }
    for (final p in _goneParts) {
      p.dispose();
    }
    super.dispose();
  }

  PaintRecipe get _recipe => PaintRecipe(
    layers: [
      for (final l in _layers)
        if (l.name.text.trim().isNotEmpty) l.value,
    ],
    priceM2: widget.recipe.priceM2,
    markupPct: widget.recipe.markupPct,
  );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recipe = _recipe;
      await ref.read(paintStockRepositoryProvider).setRecipe(recipe);
      ref.invalidate(paintStockProvider);
      if (mounted) Navigator.of(context).pop(recipe);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      } else {
        messenger.showFailure(e, l10n);
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String label,
    String key, {
    bool number = true,
    double width = AppSpacing.xxxl * 2,
  }) => SizedBox(
    width: width,
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
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  Widget _layer(int i, _LayerDraft l) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('paintLayer:$i'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('paintLayerName:$i'),
                  controller: l.name,
                  onChanged: (_) => setState(() {}),
                  style: theme.textTheme.titleSmall,
                  decoration: InputDecoration(
                    labelText: l10n.paintLayerName,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilterChip(
                key: ValueKey('paintLayerColour:$i'),
                label: Text(l10n.paintLayerColour),
                selected: l.colour,
                // One layer is the order's colour.
                onSelected: (on) => setState(() {
                  for (final other in _layers) {
                    other.colour = false;
                  }
                  l.colour = on;
                }),
              ),
              IconButton(
                key: ValueKey('paintLayerRemove:$i'),
                tooltip: l10n.paintRemove,
                icon: const Icon(AppIcons.delete),
                onPressed: () => setState(() {
                  _gone.add(_layers.removeAt(i));
                }),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _field(l.gM2, l10n.paintLayerGM2, 'paintLayerG:$i'),
              _field(
                l.coats,
                l10n.paintLayerCoats,
                'paintLayerCoats:$i',
                width: AppSpacing.xxxl * 1.5,
              ),
              _field(l.price, l10n.paintPriceKg, 'paintLayerPrice:$i'),
            ],
          ),
          for (final (j, p) in l.parts.indexed)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                top: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _field(
                      p.name,
                      l10n.paintPartName,
                      'paintPartName:$i:$j',
                      number: false,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _field(p.perKg, l10n.paintPartPct, 'paintPartPerKg:$i:$j'),
                  const SizedBox(width: AppSpacing.xs),
                  _field(p.price, l10n.paintPriceKg, 'paintPartPrice:$i:$j'),
                  IconButton(
                    key: ValueKey('paintPartRemove:$i:$j'),
                    tooltip: l10n.paintRemove,
                    icon: const Icon(AppIcons.close),
                    onPressed: () => setState(() {
                      _goneParts.add(l.parts.removeAt(j));
                    }),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                key: ValueKey('paintPartAdd:$i'),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.paintPartAdd),
                onPressed: () => setState(
                  () => l.parts.add(_PartDraft(const PaintPart(name: ''))),
                ),
              ),
              const Spacer(),
              Text(
                l10n.paintLayerKg(_num(l.value.kgM2)),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.paintRecipeTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 12,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.paintRecipeHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (final (i, l) in _layers.indexed) _layer(i, l),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('paintLayerAdd'),
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.paintLayerAdd),
                  onPressed: () => setState(
                    () => _layers.add(
                      _LayerDraft(const PaintLayer(name: '', coats: 1)),
                    ),
                  ),
                ),
              ),
              Text(
                l10n.paintRecipe(_num(_recipe.kgM2)),
                key: const ValueKey('paintRecipeTotal'),
                style: theme.textTheme.titleSmall,
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
          key: const ValueKey('paintRecipeSave'),
          onPressed: _busy || _recipe.layers.isEmpty ? null : _save,
          child: Text(l10n.filmReqSave),
        ),
      ],
    );
  }
}

/// The order card's paint (owner, 15.11.2026): each colour's kilograms and
/// what they cost; opened, material by material, with the text for the
/// supplier who tints — or, for the customer's own paint, what he brings.
class MdfOrderPaintView extends StatefulWidget {
  const MdfOrderPaintView({required this.order, super.key});

  final MdfOrder order;

  @override
  State<MdfOrderPaintView> createState() => _MdfOrderPaintViewState();
}

class _MdfOrderPaintViewState extends State<MdfOrderPaintView> {
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (o.paint.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final own = o.clientPaint != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in o.paint) ...[
          InkWell(
            key: ValueKey('mdfPaintPlan:${p.colour}'),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => setState(
              () => _open.contains(p.colour ?? '')
                  ? _open.remove(p.colour ?? '')
                  : _open.add(p.colour ?? ''),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        l10n.mdfPaintPlan(p.colour ?? '', _num(p.kg)),
                        // The customer's own paint costs the shop nothing.
                        if (!own && p.cost != null) money.format(p.cost),
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Icon(
                    _open.contains(p.colour ?? '')
                        ? AppIcons.collapse
                        : AppIcons.expand,
                  ),
                ],
              ),
            ),
          ),
          if (_open.contains(p.colour ?? '')) ...[
            PaintPlanView(plan: p),
            Wrap(
              spacing: AppSpacing.sm,
              children: paintShareButtons(
                context,
                p.text,
                phone: own ? o.phone : null,
                whatsAppLabel: own
                    ? l10n.mdfPaintAskClient
                    : l10n.mdfPaintAskSupplier,
                keyPrefix: 'mdfPaintShare:${p.colour}',
              ),
            ),
          ],
        ],
      ],
    );
  }
}
