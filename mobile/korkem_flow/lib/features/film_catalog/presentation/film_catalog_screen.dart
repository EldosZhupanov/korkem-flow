import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Плёнки ПВХ» (owner, 10.11.2026): a tab per maker, never one list of all
/// — the same name is a different shade at each maker. In a tab: the types
/// to narrow by, a search, and each film with its sample and what is on hand.
class FilmCatalogScreen extends ConsumerStatefulWidget {
  const FilmCatalogScreen({super.key});

  @override
  ConsumerState<FilmCatalogScreen> createState() => _FilmCatalogScreenState();
}

class _FilmCatalogScreenState extends ConsumerState<FilmCatalogScreen> {
  String? _type;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(filmCatalogProvider);
    return catalog.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.filmCatalogTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.filmCatalogTitle)),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(filmCatalogProvider),
        ),
      ),
      data: (c) {
        final tabs = c.tabs;
        return DefaultTabController(
          length: tabs.length + 1,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.filmCatalogTitle),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final m in tabs)
                    Tab(
                      key: ValueKey('filmMaker:$m'),
                      text: '$m · ${c.of(m).length}',
                    ),
                  Tab(
                    key: const ValueKey('filmMaker:none'),
                    text: '${l10n.filmUnassigned} · ${c.unassigned.length}',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                for (final m in tabs) _makerTab(c, m, l10n),
                _Unassigned(colours: c.unassigned),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _makerTab(FilmCatalog c, String maker, AppLocalizations l10n) {
    final films = c.of(maker, type: _type, search: _search);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              key: const ValueKey('filmType:all'),
              label: Text(l10n.filmAllTypes),
              selected: _type == null,
              onSelected: (_) => setState(() => _type = null),
            ),
            for (final t in c.types)
              ChoiceChip(
                key: ValueKey('filmType:$t'),
                label: Text(t),
                selected: _type == t,
                onSelected: (on) => setState(() => _type = on ? t : null),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('filmSearch'),
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(AppIcons.search),
            labelText: l10n.filmSearchIn(maker),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // A film is added here, at its maker (owner, 10.11.2026) — and its
        // card opens at once to be filled in.
        if (c.canEdit)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: ValueKey('filmAdd:$maker'),
              onPressed: () => _add(c, maker),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.filmAdd),
            ),
          ),
        if (films.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.filmEmpty(maker)),
          ),
        for (final f in films)
          FilmTile(
            film: f,
            onTap: c.canEdit ? () => showFilmCard(context, f, c) : null,
          ),
      ],
    );
  }

  Future<void> _add(FilmCatalog c, String maker) async {
    final made = await showDialog<Film>(
      context: context,
      builder: (_) => _FilmAddDialog(maker: maker),
    );
    if (made == null || !mounted) return;
    ref.invalidate(filmCatalogProvider);
    await showFilmCard(context, made, c);
  }
}

class _FilmAddDialog extends ConsumerStatefulWidget {
  const _FilmAddDialog({required this.maker});

  final String maker;

  @override
  ConsumerState<_FilmAddDialog> createState() => _FilmAddDialogState();
}

class _FilmAddDialogState extends ConsumerState<_FilmAddDialog> {
  final _name = TextEditingController();
  final _thickness = TextEditingController(text: '0,3');
  final _width = TextEditingController(text: '1400');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _thickness.dispose();
    _width.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final made = await ref
          .read(filmCatalogRepositoryProvider)
          .add(
            maker: widget.maker,
            colour: _name.text.trim(),
            thickness: _thickness.text.trim(),
            width: _width.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(made);
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('${l10n.filmAdd} · ${widget.maker}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('filmAdd:name'),
              controller: _name,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.filmName),
            ),
            TextField(
              key: const ValueKey('filmAdd:thickness'),
              controller: _thickness,
              decoration: InputDecoration(labelText: l10n.filmThickness),
            ),
            TextField(
              key: const ValueKey('filmAdd:width'),
              controller: _width,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.filmWidth),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          key: const ValueKey('filmAdd:save'),
          onPressed: _busy || _name.text.trim().length < 2 ? null : _save,
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}

/// One film's row: its sample, name and code, type and thickness, and what
/// is on hand — «есть · 84 м» or «заказать».
class FilmTile extends StatelessWidget {
  const FilmTile({required this.film, this.onTap, super.key});

  final Film film;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = film;
    final stock = !f.enabled
        ? l10n.filmOff
        : f.free > 0
        ? l10n.filmHave(_metres(f.free))
        : l10n.filmToOrder;
    return Opacity(
      opacity: f.enabled ? 1 : 0.5,
      child: ListTile(
        key: ValueKey('film:${f.item}'),
        onTap: onTap,
        leading: FilmSample(argb: f.argb),
        title: Text(
          [f.colour, ?f.code].join(' · '),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            ?f.type,
            if (f.thicknessMm != null) '${_metres(f.thicknessMm!)} мм',
            if (f.widthMm != null) '${f.widthMm!.toStringAsFixed(0)} мм',
          ].join(' · '),
        ),
        trailing: Text(
          stock,
          style: TextStyle(
            color: f.enabled && f.free > 0
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A film's sample square; an empty frame when no colour is set.
class FilmSample extends StatelessWidget {
  const FilmSample({required this.argb, this.size = AppSpacing.xl, super.key});

  final int? argb;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: argb == null ? null : Color(argb!),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
  );
}

String _metres(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'.replaceAll('.', ',');

class _Unassigned extends StatelessWidget {
  const _Unassigned({required this.colours});

  final List<String> colours;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.filmUnassignedHint),
        const SizedBox(height: AppSpacing.sm),
        for (final c in colours)
          ListTile(
            key: ValueKey('filmLoose:$c'),
            leading: const FilmSample(argb: null),
            title: Text(c),
          ),
      ],
    );
  }
}

/// A film's card: what it is and what it costs us, per running metre.
Future<void> showFilmCard(BuildContext context, Film film, FilmCatalog c) =>
    showDialog<void>(
      context: context,
      builder: (_) => _FilmCardDialog(film: film, catalog: c),
    );

class _FilmCardDialog extends ConsumerStatefulWidget {
  const _FilmCardDialog({required this.film, required this.catalog});

  final Film film;
  final FilmCatalog catalog;

  @override
  ConsumerState<_FilmCardDialog> createState() => _FilmCardDialogState();
}

class _FilmCardDialogState extends ConsumerState<_FilmCardDialog> {
  late final _code = TextEditingController(text: widget.film.code);
  late final _hex = TextEditingController(text: widget.film.hex);
  late final _ral = TextEditingController(text: widget.film.ral);
  late final _price = TextEditingController(
    text: widget.film.priceM?.toStringAsFixed(0),
  );
  late final _url = TextEditingController(text: widget.film.url);
  late final _retail = TextEditingController(
    text: widget.film.retailM?.toStringAsFixed(0),
  );
  late final _wholesale = TextEditingController(
    text: widget.film.wholesaleM?.toStringAsFixed(0),
  );
  late String? _type = widget.film.type;
  late String? _supplier = widget.film.supplier;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _hex, _ral, _price, _url, _retail, _wholesale]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(filmCatalogRepositoryProvider).setCard(widget.film.item, {
        'code': _code.text.trim(),
        'type': _type,
        'hex': _hex.text.trim(),
        'ral': _ral.text.trim(),
        'supplier': _supplier,
        'price_m': _price.text.trim(),
        'retail_m': _retail.text.trim(),
        'wholesale_m': _wholesale.text.trim(),
        'url': _url.text.trim(),
      });
      ref.invalidate(filmCatalogProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = widget.film;
    final c = widget.catalog;
    Widget field(String key, TextEditingController ctl, String label) =>
        TextField(
          key: ValueKey('filmCard:$key'),
          controller: ctl,
          decoration: InputDecoration(labelText: label),
        );
    return AlertDialog(
      title: Row(
        children: [
          FilmSample(argb: f.argb, size: AppSpacing.xxl),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text('${f.colour}\n${f.maker}')),
        ],
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                f.free > 0 ? l10n.filmHave(_metres(f.free)) : l10n.filmToOrder,
              ),
              field('code', _code, l10n.filmCode),
              DropdownButtonFormField<String?>(
                key: const ValueKey('filmCard:type'),
                initialValue: c.types.contains(_type) ? _type : null,
                items: [
                  DropdownMenuItem(child: Text(l10n.mdfNone)),
                  for (final t in c.types)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v),
                decoration: InputDecoration(labelText: l10n.filmType),
              ),
              field('hex', _hex, l10n.filmSample),
              field('ral', _ral, l10n.filmRal),
              DropdownButtonFormField<String?>(
                key: const ValueKey('filmCard:supplier'),
                initialValue: c.suppliers.any((s) => s.id == _supplier)
                    ? _supplier
                    : null,
                items: [
                  DropdownMenuItem(child: Text(l10n.mdfNone)),
                  for (final s in c.suppliers)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _supplier = v),
                decoration: InputDecoration(labelText: l10n.filmSupplier),
              ),
              TextField(
                key: const ValueKey('filmCard:price'),
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.filmPriceM),
              ),
              // What the department sells a metre at (10.11.2026).
              for (final (key, ctl, label) in [
                ('retail', _retail, l10n.filmRetailM),
                ('wholesale', _wholesale, l10n.filmWholesaleM),
              ])
                TextField(
                  key: ValueKey('filmCard:$key'),
                  controller: ctl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: label),
                ),
              field('url', _url, l10n.filmUrl),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          key: const ValueKey('filmCard:save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}

/// A film for an order, in three steps (owner, 10.11.2026): the maker, the
/// type, then that maker's film — with what is on hand beside it. Gives the
/// film's name for the order, «KIRA · Белый Матовый».
Future<String?> showFilmPicker(BuildContext context, {String? current}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _FilmPickerDialog(current: current),
    );

class _FilmPickerDialog extends ConsumerStatefulWidget {
  const _FilmPickerDialog({this.current});

  final String? current;

  @override
  ConsumerState<_FilmPickerDialog> createState() => _FilmPickerDialogState();
}

class _FilmPickerDialogState extends ConsumerState<_FilmPickerDialog> {
  String? _maker;
  String? _type;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = ref.watch(filmCatalogProvider).value;
    final tabs = c?.tabs ?? const <String>[];
    // The film the group has now opens its maker; else the first maker.
    final maker =
        _maker ??
        c?.films
            .where((f) => f.label != null && f.label == widget.current)
            .map((f) => f.maker)
            .firstOrNull ??
        tabs.firstOrNull;
    final films = c == null || maker == null
        ? const <Film>[]
        : [
            for (final f in c.of(maker, type: _type, search: _search))
              if (f.enabled && f.label != null) f,
          ];
    return AlertDialog(
      title: Text(l10n.filmCatalogTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 11,
        height: AppSpacing.xxxl * 9,
        child: c == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.filmMaker,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final m in tabs)
                        ChoiceChip(
                          key: ValueKey('pickMaker:$m'),
                          label: Text(m),
                          selected: maker == m,
                          onSelected: (_) => setState(() => _maker = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.filmType,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('pickType:all'),
                        label: Text(l10n.filmAllTypes),
                        selected: _type == null,
                        onSelected: (_) => setState(() => _type = null),
                      ),
                      for (final t in c.types)
                        ChoiceChip(
                          key: ValueKey('pickType:$t'),
                          label: Text(t),
                          selected: _type == t,
                          onSelected: (on) =>
                              setState(() => _type = on ? t : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const ValueKey('pickSearch'),
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(AppIcons.search),
                      labelText: l10n.filmSearchIn(maker ?? ''),
                      isDense: true,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final f in films)
                          FilmTile(
                            film: f,
                            onTap: () => Navigator.of(context).pop(f.label),
                          ),
                      ],
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
      ],
    );
  }
}
