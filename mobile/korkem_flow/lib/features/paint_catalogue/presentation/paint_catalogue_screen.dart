import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What the catalogue shows of a system.
enum PaintShow { all, popular, top, trend, stock, starred, hidden }

/// «Каталог красок» (owner, 19.11.2026: «каталог красок тоже с карточками,
/// группами, цветом со своим родным, примерно как каталог ПВХ плёнок —
/// самые ходовые, топовые, трендовые»): a tab a colour system, a card a
/// colour with its shade; the shop's own colours first, the furniture top
/// and the year's trends; a colour added, renamed, starred or hidden; the
/// nearest colours to one, or to a photo of a sample.
class PaintCatalogueScreen extends ConsumerStatefulWidget {
  const PaintCatalogueScreen({super.key});

  @override
  ConsumerState<PaintCatalogueScreen> createState() =>
      _PaintCatalogueScreenState();
}

class _PaintCatalogueScreenState extends ConsumerState<PaintCatalogueScreen> {
  String _search = '';
  PaintShow _show = PaintShow.all;
  String? _family;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogue = ref.watch(paintCatalogueProvider);
    return catalogue.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.pcTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.pcTitle)),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(paintCatalogueProvider),
        ),
      ),
      data: (c) {
        final systems = [
          for (final s in c.systems)
            if (s.count > 0 || s.name != null) s,
        ];
        return DefaultTabController(
          length: systems.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.pcTitle),
              actions: [
                TextButton.icon(
                  key: const ValueKey('pcPhoto'),
                  onPressed: () => unawaited(_byPhoto(c)),
                  icon: const Icon(AppIcons.camera),
                  label: Text(l10n.pcByPhoto),
                ),
                if (c.canEdit)
                  TextButton.icon(
                    key: const ValueKey('pcAdd'),
                    onPressed: () => unawaited(_add(c)),
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.pcAdd),
                  ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final s in systems)
                    Tab(
                      key: ValueKey('pcSystem:${s.name ?? '-'}'),
                      text: '${s.name ?? l10n.pcNoSystem} · ${s.count}',
                    ),
                ],
              ),
            ),
            body: TabBarView(
              children: [for (final s in systems) _system(c, s.name, l10n)],
            ),
          ),
        );
      },
    );
  }

  Widget _system(PaintCatalogue c, String? system, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelLarge;
    final all = c.of(system, hidden: true);
    final families = [
      for (final f in c.families)
        if (all.any((x) => x.family == f)) f,
    ];
    bool keep(PaintColour x) =>
        x.matches(_search) &&
        (_family == null || x.family == _family) &&
        switch (_show) {
          PaintShow.all => !x.hidden,
          PaintShow.popular => !x.hidden && x.popular,
          PaintShow.top => !x.hidden && x.top,
          PaintShow.trend => !x.hidden && x.trend,
          PaintShow.stock => !x.hidden && x.kg > 0,
          PaintShow.starred => x.starred,
          PaintShow.hidden => x.hidden,
        };
    final shown = [
      for (final x in all)
        if (keep(x)) x,
    ];
    if (_show == PaintShow.popular) {
      shown.sort((a, b) => b.areaM2.compareTo(a.areaM2));
    }
    // With nothing narrowed: ours and the trends first, then all of it.
    final plain =
        _show == PaintShow.all && _family == null && _search.trim().isEmpty;
    final ours = !plain
        ? const <PaintColour>[]
        : ([
            for (final x in all)
              if (!x.hidden && x.popular) x,
          ]..sort((a, b) => b.areaM2.compareTo(a.areaM2)));
    final trends = !plain
        ? const <PaintColour>[]
        : [
            for (final x in all)
              if (!x.hidden && x.trend) x,
          ];
    Widget grid(List<PaintColour> list, String key) => GridView.builder(
      key: ValueKey(key),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: AppSpacing.xxxl * 3.5,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.82,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) => PaintCard(
        colour: list[i],
        onTap: () => unawaited(showPaintColour(context, list[i], c)),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        TextField(
          key: ValueKey('pcSearch:${system ?? '-'}'),
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(AppIcons.search),
            hintText: l10n.pcSearch,
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (s, text) in [
              (PaintShow.all, l10n.pcShowAll),
              (PaintShow.popular, l10n.pcShowPopular),
              (PaintShow.top, l10n.pcShowTop),
              (PaintShow.trend, l10n.pcShowTrend),
              (PaintShow.stock, l10n.pcShowStock),
              (PaintShow.starred, l10n.pcShowStarred),
              if (c.canEdit && all.any((x) => x.hidden))
                (PaintShow.hidden, l10n.pcShowHidden),
            ])
              ChoiceChip(
                key: ValueKey('pcShow:${s.name}'),
                label: Text(text),
                selected: _show == s,
                onSelected: (_) => setState(() => _show = s),
              ),
          ],
        ),
        if (families.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final f in families)
                FilterChip(
                  key: ValueKey('pcFamily:$f'),
                  label: Text(f),
                  selected: _family == f,
                  onSelected: (on) => setState(() => _family = on ? f : null),
                ),
            ],
          ),
        ],
        if (ours.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.pcOurs(c.usageDays), style: label),
          const SizedBox(height: AppSpacing.xs),
          grid(ours.take(12).toList(), 'pcOurs'),
        ],
        if (trends.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.pcTrends, style: label),
          const SizedBox(height: AppSpacing.xs),
          grid(trends, 'pcTrends'),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.pcAllOf(system ?? l10n.pcNoSystem, shown.length),
          key: const ValueKey('pcAllHead'),
          style: label,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.pcNothing),
          )
        else
          grid(shown, 'pcAll'),
      ],
    );
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.pcByPhotoTitle),
          content: SizedBox(
            width: AppSpacing.xxxl * 9,
            child: SimilarList(
              colours: near,
              onTap: (x) => unawaited(showPaintColour(context, x, c)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.mdfCancel),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  Future<void> _add(PaintCatalogue c) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _ColourDialog(catalogue: c),
    );
    if (added ?? false) ref.invalidate(paintCatalogueProvider);
  }
}

/// «+ Свой цвет» — the catalogue's own window, from anywhere: true when a
/// colour was added.
Future<bool?> showPaintColourAdd(BuildContext context, PaintCatalogue c) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _ColourDialog(catalogue: c),
    );

/// A colour's card: its shade, its code and name, what is on the shelf and
/// how much of it was painted.
class PaintCard extends StatelessWidget {
  const PaintCard({
    required this.colour,
    this.onTap,
    this.onOpen,
    this.note,
    this.noteDanger = false,
    super.key,
  });

  final PaintColour colour;
  final VoidCallback? onTap;

  /// A word of the window it is shown in — «нужно 4 кг» on the paint's
  /// receipt (owner, 20.11.2026); red when it asks for action.
  final String? note;
  final bool noteDanger;

  /// The colour's own card — to look at and to change — where a press
  /// already means something else (owner, 20.11.2026: the order's window
  /// chooses on a press, «ⓘ» or a long press opens the card).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final x = colour;
    Widget badge(String text, Color tone) => Container(
      margin: const EdgeInsets.only(right: AppSpacing.xxs, top: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: AppTint.surface),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: tone),
      ),
    );
    return Card(
      key: ValueKey('pcColour:${x.key}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: PaintSwatch(colour: x)),
                  if (onOpen != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton.filledTonal(
                        key: ValueKey('pcOpen:${x.key}'),
                        tooltip: l10n.pcOpenCard,
                        visualDensity: VisualDensity.compact,
                        iconSize: AppIconSize.small,
                        onPressed: onOpen,
                        icon: const Icon(AppIcons.info),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          x.code.isEmpty ? x.name : x.code,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (x.starred)
                        Icon(
                          AppIcons.favourite,
                          size: AppIconSize.small,
                          color: status.warning,
                        ),
                    ],
                  ),
                  if (x.code.isNotEmpty)
                    Text(
                      x.name,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Wrap(
                    children: [
                      if (x.kg > 0)
                        badge(
                          l10n.pcKg(_n(x.kg)),
                          x.enoughM2 != null && x.enoughM2! < 5
                              ? status.warning
                              : status.success,
                        )
                      else if (x.popular)
                        badge(l10n.pcNone, status.danger),
                      if (x.areaM2 > 0)
                        badge(l10n.pcM2(_n(x.areaM2)), status.neutral),
                      if (x.trend) badge(l10n.pcTrend, status.info),
                      if (x.delta != null)
                        badge(
                          paintLookText(l10n, x.look),
                          paintLookTone(context, x.look),
                        ),
                      if (note case final n?)
                        badge(n, noteDanger ? status.danger : status.neutral),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A colour's shade — a plain grey when none is known.
class PaintSwatch extends StatelessWidget {
  const PaintSwatch({required this.colour, super.key});

  final PaintColour colour;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: colour.argb == null
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Color(colour.argb!),
    child: colour.argb == null
        ? const Center(child: Icon(AppIcons.colour))
        : const SizedBox.expand(),
  );
}

String paintLookText(AppLocalizations l10n, PaintLook? look) => switch (look) {
  PaintLook.same => l10n.pcLookSame,
  PaintLook.close => l10n.pcLookClose,
  _ => l10n.pcLookOther,
};

Color paintLookTone(BuildContext context, PaintLook? look) {
  final status = context.statusColors;
  return switch (look) {
    PaintLook.same => status.success,
    PaintLook.close => status.warning,
    _ => status.danger,
  };
}

String _n(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');

/// The colours nearest one, each with how near it looks.
class SimilarList extends StatelessWidget {
  const SimilarList({
    required this.colours,
    this.onTap,
    this.selected,
    super.key,
  });

  final List<PaintColour> colours;
  final void Function(PaintColour)? onTap;

  /// The one picked, highlighted.
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (colours.isEmpty) return Text(l10n.pcNothing);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final x in colours)
          ListTile(
            key: ValueKey('pcSimilar:${x.key}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: x.key == selected,
            onTap: onTap == null ? null : () => onTap!(x),
            leading: SizedBox(
              width: AppSpacing.xxxl,
              height: AppSpacing.xl,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: PaintSwatch(colour: x),
              ),
            ),
            title: Text(x.title),
            subtitle: Text(
              x.kg > 0 ? l10n.pcKg(_n(x.kg)) : l10n.pcNoneShelf,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              paintLookText(l10n, x.look),
              style: theme.textTheme.labelSmall?.copyWith(
                color: paintLookTone(context, x.look),
              ),
            ),
          ),
      ],
    );
  }
}

/// A colour up close: its shade, what the shop has and painted of it, the
/// nearest colours; put into work, starred, changed or hidden.
Future<void> showPaintColour(
  BuildContext context,
  PaintColour colour,
  PaintCatalogue catalogue,
) => showDialog<void>(
  context: context,
  builder: (_) => _ColourCard(colour: colour, catalogue: catalogue),
);

class _ColourCard extends ConsumerStatefulWidget {
  const _ColourCard({required this.colour, required this.catalogue});

  final PaintColour colour;
  final PaintCatalogue catalogue;

  @override
  ConsumerState<_ColourCard> createState() => _ColourCardState();
}

class _ColourCardState extends ConsumerState<_ColourCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() step) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await step();
      ref.invalidate(paintCatalogueProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final x = widget.colour;
    final c = widget.catalogue;
    final repo = ref.read(paintCatalogueRepositoryProvider);
    final near = ref.watch(paintSimilarProvider(x.value));
    return AlertDialog(
      key: ValueKey('pcCard:${x.key}'),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: AppSpacing.xxxl * 2.5,
                child: PaintSwatch(colour: x),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.title, style: theme.textTheme.titleMedium),
                    Text(
                      [?x.system, ?x.hex, ?x.family].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      x.kg > 0
                          ? (x.enoughM2 != null
                                ? l10n.pcShelfEnough(
                                    _n(x.kg),
                                    _n(x.enoughM2!),
                                  )
                                : l10n.pcKg(_n(x.kg)))
                          : l10n.pcNoneShelf,
                      key: const ValueKey('pcCardShelf'),
                    ),
                    if (x.orders > 0)
                      Text(
                        l10n.pcPainted(
                          x.orders,
                          _n(x.areaM2),
                          c.usageDays,
                        ),
                      ),
                    Text(x.onList ? l10n.pcOnList : l10n.pcNotOnList),
                    if (x.note case final note?) Text(note),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.pcSimilar, style: theme.textTheme.labelLarge),
                    near.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (list) =>
                          SimilarList(colours: list.take(5).toList()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (c.canEdit) ...[
          IconButton(
            key: const ValueKey('pcStar'),
            tooltip: l10n.pcStar,
            onPressed: _busy
                ? null
                : () => _run(() => repo.setColour(x.key, starred: !x.starred)),
            icon: Icon(x.starred ? AppIcons.favourite : AppIcons.add),
          ),
          TextButton(
            key: const ValueKey('pcEdit'),
            onPressed: _busy
                ? null
                : () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => _ColourDialog(catalogue: c, colour: x),
                    );
                    if ((changed ?? false) && mounted) {
                      ref.invalidate(paintCatalogueProvider);
                      Navigator.of(this.context).pop();
                    }
                  },
            child: Text(l10n.pcEdit),
          ),
          if (!x.onList)
            FilledButton(
              key: const ValueKey('pcTake'),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => repo.take(x.value, system: x.system),
                    ),
              child: Text(l10n.pcTake),
            ),
        ],
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
      ],
    );
  }
}

/// «+ Краска» — a colour of the shop's own, or one by its code in a
/// system; with [colour], that colour's own card changed.
class _ColourDialog extends ConsumerStatefulWidget {
  const _ColourDialog({required this.catalogue, this.colour});

  final PaintCatalogue catalogue;
  final PaintColour? colour;

  @override
  ConsumerState<_ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends ConsumerState<_ColourDialog> {
  late final _name = TextEditingController(text: widget.colour?.name ?? '');
  final _code = TextEditingController();
  late final _hex = TextEditingController(text: widget.colour?.hex ?? '');
  late final _note = TextEditingController(text: widget.colour?.note ?? '');
  late String? _system =
      widget.colour?.system ??
      widget.catalogue.systems.map((s) => s.name).nonNulls.lastOrNull;
  late bool _hidden = widget.colour?.hidden ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _code, _hex, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(paintCatalogueRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final x = widget.colour;
      final hex = _hex.text.trim();
      if (x == null) {
        await repo.addColour(
          name: _name.text.trim(),
          system: _system ?? '',
          code: _code.text.trim().isEmpty ? null : _code.text.trim(),
          hex: hex.isEmpty ? null : hex,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      } else {
        await repo.setColour(
          x.key,
          title: _name.text.trim(),
          hex: hex,
          note: _note.text.trim(),
          hidden: _hidden,
        );
      }
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
    final editing = widget.colour != null;
    final preview = paintArgb(
      _hex.text.trim().startsWith('#')
          ? _hex.text.trim().toUpperCase()
          : '#${_hex.text.trim().toUpperCase()}',
    );
    return AlertDialog(
      key: const ValueKey('pcColourDialog'),
      title: Text(editing ? l10n.pcEditTitle : l10n.pcAddTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!editing) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('pcAddSystem'),
                  initialValue: _system,
                  decoration: InputDecoration(labelText: l10n.pcSystem),
                  items: [
                    for (final s in widget.catalogue.systems)
                      if (s.name case final name?)
                        DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (v) => setState(() => _system = v),
                ),
                TextField(
                  key: const ValueKey('pcAddCode'),
                  controller: _code,
                  decoration: InputDecoration(
                    labelText: l10n.pcCode,
                    helperText: l10n.pcCodeHint,
                  ),
                ),
              ],
              TextField(
                key: const ValueKey('pcAddName'),
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.pcName),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('pcAddHex'),
                      controller: _hex,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.pcHex,
                        helperText: l10n.pcHexHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    key: const ValueKey('pcHexPreview'),
                    width: AppSpacing.xxxl,
                    height: AppSpacing.xxl,
                    decoration: BoxDecoration(
                      color: preview == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : Color(preview),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ],
              ),
              TextField(
                key: const ValueKey('pcAddNote'),
                controller: _note,
                maxLines: null,
                decoration: InputDecoration(labelText: l10n.filmSrcNote),
              ),
              if (editing)
                SwitchListTile(
                  key: const ValueKey('pcHidden'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pcHide),
                  value: _hidden,
                  onChanged: (v) => setState(() => _hidden = v),
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
          key: const ValueKey('pcSave'),
          onPressed:
              _busy ||
                  (!editing &&
                      (_system == null ||
                          (_name.text.trim().length < 2 &&
                              _code.text.trim().length < 2)))
              ? null
              : _save,
          child: Text(editing ? l10n.pcSave : l10n.pcAddSave),
        ),
      ],
    );
  }
}
