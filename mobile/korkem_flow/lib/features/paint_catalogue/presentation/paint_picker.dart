import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_order_screen.dart';
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_catalogue_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What the paint window narrows to besides a system.
enum _Narrow { all, stock, trend }

/// The order's paint window (owner, 20.11.2026: «список открывался в стиле
/// как плёнки»): every colour as its shade — what this customer painted
/// before, the shop's own, every RAL by family — a search, a photo of a
/// sample, a colour of our own; the one picked says its gloss and whether
/// the shelf covers the order.
///
/// Gives the colour as the «Краска» list names it — one not in work yet is
/// put there on the way; an empty string with [allowNone] — no colour; null
/// when closed. [needM2] is the area the colour is for; [onGloss] sets the
/// group's gloss from here.
Future<String?> showPaintPicker(
  BuildContext context, {
  String? current,
  String? customer,
  bool allowNone = false,
  double? needM2,
  MdfGloss? gloss,
  ValueChanged<MdfGloss?>? onGloss,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PaintPicker(
    current: current,
    customer: customer,
    allowNone: allowNone,
    needM2: needM2,
    gloss: gloss,
    onGloss: onGloss,
  ),
);

class _PaintPicker extends ConsumerStatefulWidget {
  const _PaintPicker({
    required this.current,
    required this.customer,
    required this.allowNone,
    required this.needM2,
    required this.gloss,
    required this.onGloss,
  });

  final String? current;
  final String? customer;
  final bool allowNone;
  final double? needM2;
  final MdfGloss? gloss;
  final ValueChanged<MdfGloss?>? onGloss;

  @override
  ConsumerState<_PaintPicker> createState() => _PaintPickerState();
}

class _PaintPickerState extends ConsumerState<_PaintPicker> {
  String _search = '';
  String? _system;
  _Narrow _narrow = _Narrow.all;
  String? _family;
  PaintColour? _picked;
  late MdfGloss? _gloss = widget.gloss;
  bool _busy = false;

  /// How many of all the colours are drawn at once.
  static const _shown = 120;

  Future<void> _choose() async {
    final x = _picked;
    if (x == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final value = x.onList
          ? x.value
          : await ref
                .read(paintCatalogueRepositoryProvider)
                .pick(x.value, system: x.system);
      if (_gloss != widget.gloss) widget.onGloss?.call(_gloss);
      if (mounted) Navigator.of(context).pop(value);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _byPhoto(PaintCatalogue c) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await ref
          .read(filmFilePickerProvider)
          .pick(extensions: const ['jpg', 'jpeg', 'png', 'webp']);
      if (files.isEmpty || !mounted) return;
      final near = await ref
          .read(paintCatalogueRepositoryProvider)
          .matchPhoto(files.first.bytes);
      if (!mounted) return;
      final hit = await showDialog<PaintColour>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.pcByPhotoTitle),
          content: SizedBox(
            width: AppSpacing.xxxl * 9,
            child: SimilarList(
              colours: near,
              onTap: (x) => Navigator.of(context).pop(x),
            ),
          ),
        ),
      );
      if (hit != null && mounted) {
        setState(() => _picked = c.byKey(hit.key) ?? hit);
      }
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final catalogue = ref.watch(paintCatalogueForProvider(widget.customer));
    return Dialog(
      key: const ValueKey('paintPicker'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSpacing.xxxl * 22,
          maxHeight: AppSpacing.xxxl * 16,
        ),
        child: catalogue.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () =>
                ref.invalidate(paintCatalogueForProvider(widget.customer)),
          ),
          data: (c) {
            _picked ??= widget.current == null
                ? null
                : c.colours.where((x) => x.value == widget.current).firstOrNull;
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _head(c, l10n, theme),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(child: _body(c, l10n, theme)),
                  const Divider(),
                  _foot(c, l10n, theme),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _head(PaintCatalogue c, AppLocalizations l10n, ThemeData theme) {
    final systems = [
      for (final s in c.systems)
        if (s.name != null && s.count > 0) s.name!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.mdfCoatingPaint,
                style: theme.textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('ppPhoto'),
              onPressed: () => unawaited(_byPhoto(c)),
              icon: const Icon(AppIcons.camera),
              label: Text(l10n.pcByPhoto),
            ),
            if (c.canEdit)
              TextButton.icon(
                key: const ValueKey('ppAdd'),
                onPressed: () async {
                  final added = await showPaintColourAdd(context, c);
                  if (added ?? false) {
                    ref.invalidate(paintCatalogueForProvider(widget.customer));
                  }
                },
                icon: const Icon(AppIcons.add),
                label: Text(l10n.ppOwn),
              ),
          ],
        ),
        TextField(
          key: const ValueKey('ppSearch'),
          autofocus: true,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(AppIcons.search),
            hintText: l10n.pcSearch,
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              key: const ValueKey('ppSystem:all'),
              label: Text(l10n.pcShowAll),
              selected: _system == null && _narrow == _Narrow.all,
              onSelected: (_) => setState(() {
                _system = null;
                _narrow = _Narrow.all;
                _family = null;
              }),
            ),
            for (final s in systems)
              ChoiceChip(
                key: ValueKey('ppSystem:$s'),
                label: Text(s),
                selected: _system == s,
                onSelected: (on) => setState(() {
                  _system = on ? s : null;
                  _family = null;
                }),
              ),
            FilterChip(
              key: const ValueKey('ppStock'),
              label: Text(l10n.pcShowStock),
              selected: _narrow == _Narrow.stock,
              onSelected: (on) =>
                  setState(() => _narrow = on ? _Narrow.stock : _Narrow.all),
            ),
            FilterChip(
              key: const ValueKey('ppTrend'),
              label: Text(l10n.pcShowTrend),
              selected: _narrow == _Narrow.trend,
              onSelected: (on) =>
                  setState(() => _narrow = on ? _Narrow.trend : _Narrow.all),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(PaintCatalogue c, AppLocalizations l10n, ThemeData theme) {
    final label = theme.textTheme.labelLarge;
    bool keep(PaintColour x) =>
        !x.hidden &&
        (_system == null || x.system == _system) &&
        (_family == null || x.family == _family) &&
        x.matches(_search) &&
        switch (_narrow) {
          _Narrow.all => true,
          _Narrow.stock => x.kg > 0,
          _Narrow.trend => x.trend,
        };
    final all = [
      for (final x in c.colours)
        if (keep(x)) x,
    ];
    final plain =
        _search.trim().isEmpty && _family == null && _narrow == _Narrow.all;
    final theirs = !plain
        ? const <PaintColour>[]
        : [
            for (final k in c.customer)
              if (c.byKey(k) case final x? when keep(x)) x,
          ];
    final ours = !plain
        ? const <PaintColour>[]
        : ([
            for (final x in all)
              if (x.popular) x,
          ]..sort((a, b) => b.areaM2.compareTo(a.areaM2)));
    final families = [
      for (final f in c.families)
        if (c.colours.any(
          (x) => x.family == f && (_system == null || x.system == _system),
        ))
          f,
    ];
    Widget grid(List<PaintColour> list, String key) => GridView.builder(
      key: ValueKey(key),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: AppSpacing.xxxl * 3,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 0.82,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: list[i].key == _picked?.key
              ? Border.all(
                  color: theme.colorScheme.primary,
                  width: AppSpacing.xxs,
                )
              : null,
        ),
        child: PaintCard(
          key: ValueKey('ppColour:$key:${list[i].key}'),
          colour: list[i],
          onTap: () => setState(() => _picked = list[i]),
        ),
      ),
    );
    final shown = all.take(_shown).toList();
    return ListView(
      children: [
        if (theirs.isNotEmpty) ...[
          Text(l10n.ppTheirs, style: label),
          const SizedBox(height: AppSpacing.xs),
          grid(theirs, 'theirs'),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (ours.isNotEmpty) ...[
          Text(l10n.pcShowPopular, style: label),
          const SizedBox(height: AppSpacing.xs),
          grid(ours.take(10).toList(), 'ours'),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          l10n.pcAllOf(_system ?? '', all.length).replaceAll('  ', ' '),
          key: const ValueKey('ppAllHead'),
          style: label,
        ),
        if (families.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final f in families)
                FilterChip(
                  key: ValueKey('ppFamily:$f'),
                  label: Text(f),
                  selected: _family == f,
                  onSelected: (on) => setState(() => _family = on ? f : null),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.pcNothing),
          )
        else
          grid(shown, 'all'),
        if (all.length > shown.length)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(l10n.filmReceiveCatalogMore(all.length - shown.length)),
          ),
      ],
    );
  }

  Widget _foot(PaintCatalogue c, AppLocalizations l10n, ThemeData theme) {
    final status = context.statusColors;
    final x = _picked;
    final need = widget.needM2;
    String fmt(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1).replaceAll('.', ',');
    final enough = x?.enoughM2 ?? 0;
    final covered = need == null || need <= 0 || enough >= need;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (x != null) ...[
          SizedBox(
            width: AppSpacing.xxxl,
            height: AppSpacing.xl,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: PaintSwatch(colour: x),
            ),
          ),
          Text(
            x.title,
            key: const ValueKey('ppPicked'),
            style: theme.textTheme.titleSmall,
          ),
          if (widget.onGloss != null)
            for (final g in [MdfGloss.matt, MdfGloss.semi, MdfGloss.gloss])
              ChoiceChip(
                key: ValueKey('ppGloss:${g.wire}'),
                label: Text(mdfGlossLabel(g, l10n)),
                selected: _gloss == g,
                onSelected: (on) => setState(() => _gloss = on ? g : null),
              ),
          Text(
            x.kg <= 0
                ? l10n.pcNoneShelf
                : need != null && need > 0
                ? (covered
                      ? l10n.ppEnough(fmt(enough), fmt(need))
                      : l10n.ppShort(fmt(enough), fmt(need)))
                : l10n.pcShelfEnough(fmt(x.kg), fmt(enough)),
            key: const ValueKey('ppEnough'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: x.kg <= 0 || !covered ? status.danger : status.success,
            ),
          ),
        ] else
          Text(l10n.ppPickHint, style: theme.textTheme.bodySmall),
        if (widget.allowNone)
          TextButton(
            key: const ValueKey('ppNone'),
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l10n.mdfPaintNone),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('ppChoose'),
          onPressed: x == null || _busy ? null : _choose,
          child: Text(l10n.ppChoose),
        ),
      ],
    );
  }
}
