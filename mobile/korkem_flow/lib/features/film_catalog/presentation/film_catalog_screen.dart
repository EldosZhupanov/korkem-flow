import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_collections.dart';
import 'package:korkem_flow/features/film_sources/presentation/film_sources.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
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

  /// Whether the archive is shown instead of the films in use.
  bool _archive = false;

  /// The collection open at each maker — every maker has its own.
  final _collection = <String, String>{};

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
                _Unassigned(colours: c.unassigned, canEdit: c.canEdit),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _makerTab(FilmCatalog c, String maker, AppLocalizations l10n) {
    final collections = c.collectionsOf(maker);
    // A collection renamed or removed meanwhile is no longer a filter.
    final collection = collections.contains(_collection[maker])
        ? _collection[maker]
        : null;
    final archived = c.of(maker, archived: true);
    final archive = _archive && archived.isNotEmpty;
    final films = c.of(
      maker,
      type: _type,
      collection: collection,
      search: _search,
      archived: archive,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // The maker's own collections (owner, 11.11.2026): ALDA, Solid
        // Color, Древесные… — and the button that keeps their list.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              key: ValueKey('filmCollectionAll:$maker'),
              label: Text(l10n.filmAllCollections),
              selected: collection == null,
              onSelected: (_) => setState(() => _collection.remove(maker)),
            ),
            for (final name in collections)
              ChoiceChip(
                key: ValueKey('filmCollectionChip:$maker:$name'),
                label: Text(name),
                selected: collection == name,
                onSelected: (on) => setState(() {
                  if (on) {
                    _collection[maker] = name;
                  } else {
                    _collection.remove(maker);
                  }
                }),
              ),
            if (c.canEdit)
              ActionChip(
                key: ValueKey('filmCollections:$maker'),
                avatar: const Icon(AppIcons.edit),
                label: Text(l10n.filmCollections),
                onPressed: () async {
                  // A collection tapped there is opened here.
                  final name = await showFilmCollections(context, maker);
                  if (name != null && mounted) {
                    setState(() => _collection[maker] = name);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
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
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (c.canEdit)
              FilledButton.icon(
                key: ValueKey('filmAdd:$maker'),
                onPressed: () => _add(c, maker, collection),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.filmAdd),
              ),
            // Where this maker's film is bought, and whom to ring (owner,
            // 11.11.2026).
            OutlinedButton.icon(
              key: ValueKey('filmMakerCard:$maker'),
              onPressed: () => showFilmMakerCard(context, maker),
              icon: const Icon(AppIcons.call),
              label: Text(l10n.filmMakerCard),
            ),
            // Films taken off the list, each with its history (owner,
            // 11.11.2026); shown in place of the films in use.
            if (archived.isNotEmpty)
              FilterChip(
                key: ValueKey('filmArchive:$maker'),
                label: Text(l10n.filmArchiveChip('${archived.length}')),
                selected: archive,
                onSelected: (on) => setState(() => _archive = on),
              ),
          ],
        ),
        if (films.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.filmEmpty(maker)),
          ),
        for (final f in films)
          FilmTile(
            film: f,
            supplier: c.suppliers
                .where((s) => s.id == f.supplier)
                .map((s) => s.name)
                .firstOrNull,
            onTap: c.canEdit ? () => showFilmCard(context, f, c) : null,
          ),
      ],
    );
  }

  Future<void> _add(FilmCatalog c, String maker, String? collection) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _FilmAddDialog(maker: maker, catalog: c, collection: collection),
    );
    if (added ?? false) ref.invalidate(filmCatalogProvider);
  }
}

/// The supplier picked last for each maker: the next film of that maker is
/// most likely bought at the same place.
final _lastSupplier = <String, String>{};

/// A field of a film's window with its list's own button (owner,
/// 11.11.2026: «чтобы все окошки редактировались»): the list opens to be
/// added to, renamed, cleaned — and what is tapped there is chosen here.
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

/// The lists a film's window keeps, each returning what was chosen there
/// (null: nothing chosen, keep what was). The catalogue is reloaded after,
/// so whatever was added or renamed shows at once.
mixin _FilmLists<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  void _reload() {
    if (mounted) ref.invalidate(filmCatalogProvider);
  }

  Future<String?> _fromDictionary(
    MdfDictKind kind,
    String title,
    String? current,
  ) async {
    final picked = await showMdfDictionary(
      context,
      kind,
      title: title,
      current: current,
    );
    _reload();
    return picked;
  }

  Future<String?> _collectionFrom(String maker, String? current) async {
    final picked = await showFilmCollections(
      context,
      maker,
      current: current,
    );
    _reload();
    return picked;
  }

  Future<String?> _supplierFrom(String maker, String? current) async {
    final picked = await showFilmSourcePicker(
      context,
      maker: maker,
      current: current,
    );
    _reload();
    return picked;
  }
}

/// The suppliers a film of [maker] is offered, with [current] kept even
/// when it is another maker's.
List<({String id, String name})> _suppliersOf(
  FilmCatalog c,
  String maker,
  String? current,
) => [
  ...c.suppliersFor(maker),
  for (final s in c.suppliers)
    if (s.id == current && !c.suppliersFor(maker).contains(s)) s,
];

/// A new film with all that is known of it, in one window (owner,
/// 11.11.2026: the manager should not open the card after every film) —
/// and «Сохранить и ещё» keeps the window for the next one.
class _FilmAddDialog extends ConsumerStatefulWidget {
  const _FilmAddDialog({
    required this.maker,
    required this.catalog,
    this.collection,
  });

  final String maker;
  final FilmCatalog catalog;

  /// The collection open in the catalogue: the new film goes into it
  /// unless another is picked.
  final String? collection;

  @override
  ConsumerState<_FilmAddDialog> createState() => _FilmAddDialogState();
}

class _FilmAddDialogState extends ConsumerState<_FilmAddDialog>
    with _FilmLists<_FilmAddDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _thickness = TextEditingController(text: '0,3');
  final _width = TextEditingController(text: '1400');
  final _price = TextEditingController();
  final _retail = TextEditingController();
  final _wholesale = TextEditingController();
  final _nameFocus = FocusNode();
  late String? _collection = widget.collection;
  late String? _supplier = _firstSupplier();
  String? _type;
  bool _busy = false;
  bool _added = false;
  String? _last;
  String? _error;

  /// The maker's only source, else the one picked last for this maker.
  String? _firstSupplier() {
    final own = widget.catalog.sourcesByMaker[widget.maker] ?? const [];
    final offered = widget.catalog.suppliersFor(widget.maker);
    final last = _lastSupplier[widget.maker];
    if (offered.any((s) => s.id == last)) return last;
    return own.length == 1 && offered.length == 1 ? offered.single.id : null;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _thickness,
      _width,
      _price,
      _retail,
      _wholesale,
    ]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save({required bool more}) async {
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
            collection: _collection,
            card: {
              'code': _code.text.trim(),
              'type': _type ?? '',
              'supplier': _supplier ?? '',
              'price_m': _price.text.trim(),
              'retail_m': _retail.text.trim(),
              'wholesale_m': _wholesale.text.trim(),
            },
          );
      if (_supplier case final supplier?) {
        _lastSupplier[widget.maker] = supplier;
      }
      if (!mounted) return;
      if (!more) {
        Navigator.of(context).pop(true);
        return;
      }
      // The next film: the same collection, surface, supplier and roll;
      // only what tells one film from another is cleared.
      ref.invalidate(filmCatalogProvider);
      setState(() {
        _busy = false;
        _added = true;
        _last = made.colour;
        _name.clear();
        _code.clear();
        _price.clear();
        _retail.clear();
        _wholesale.clear();
      });
      _nameFocus.requestFocus();
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
    // Live: a list changed from here shows at once.
    final c = ref.watch(filmCatalogProvider).value ?? widget.catalog;
    final collections = c.collectionsOf(widget.maker);
    final suppliers = _suppliersOf(c, widget.maker, _supplier);
    final ready = !_busy && _name.text.trim().length >= 2;
    Widget pair(Widget left, Widget right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    );
    Widget money(String key, TextEditingController ctl, String label) =>
        Expanded(
          child: TextField(
            key: ValueKey('filmAdd:$key'),
            controller: ctl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: label),
          ),
        );
    return AlertDialog(
      title: Text('${l10n.filmAdd} · ${widget.maker}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 11,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_last case final last?)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    l10n.filmAddedOne(last),
                    key: const ValueKey('filmAdd:added'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              TextField(
                key: const ValueKey('filmAdd:name'),
                controller: _name,
                focusNode: _nameFocus,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.filmName),
              ),
              pair(
                TextField(
                  key: const ValueKey('filmAdd:code'),
                  controller: _code,
                  decoration: InputDecoration(labelText: l10n.filmCode),
                ),
                _withList(
                  context,
                  key: 'filmAdd:type:edit',
                  onEdit: () async {
                    final v = await _fromDictionary(
                      MdfDictKind.filmType,
                      l10n.filmType,
                      _type,
                    );
                    if (v != null && mounted) setState(() => _type = v);
                  },
                  child: DropdownButtonFormField<String?>(
                    // The value is in the key: one chosen in the list must
                    // show at once.
                    key: ValueKey('filmAdd:type:$_type:${c.types.length}'),
                    initialValue: c.types.contains(_type) ? _type : null,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(child: Text(l10n.mdfNone)),
                      for (final t in c.types)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setState(() => _type = v),
                    decoration: InputDecoration(labelText: l10n.filmType),
                  ),
                ),
              ),
              pair(
                _withList(
                  context,
                  key: 'filmAdd:collection:edit',
                  onEdit: () async {
                    final v = await _collectionFrom(widget.maker, _collection);
                    if (v != null && mounted) setState(() => _collection = v);
                  },
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'filmAdd:collection:$_collection:${collections.length}',
                    ),
                    initialValue: collections.contains(_collection)
                        ? _collection
                        : null,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(child: Text(l10n.mdfNone)),
                      for (final name in collections)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => setState(() => _collection = v),
                    decoration: InputDecoration(
                      labelText: l10n.filmCollection,
                    ),
                  ),
                ),
                _withList(
                  context,
                  key: 'filmAdd:supplier:edit',
                  onEdit: () async {
                    final v = await _supplierFrom(widget.maker, _supplier);
                    if (v != null && mounted) setState(() => _supplier = v);
                  },
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'filmAdd:supplier:$_supplier:${suppliers.length}',
                    ),
                    initialValue: suppliers.any((s) => s.id == _supplier)
                        ? _supplier
                        : null,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(child: Text(l10n.mdfNone)),
                      for (final s in suppliers)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _supplier = v),
                    decoration: InputDecoration(labelText: l10n.filmSupplier),
                  ),
                ),
              ),
              pair(
                _withList(
                  context,
                  key: 'filmAdd:thickness:edit',
                  onEdit: () async {
                    final v = await _fromDictionary(
                      MdfDictKind.filmThickness,
                      l10n.filmThickness,
                      _thickness.text.trim(),
                    );
                    if (v != null) _thickness.text = v;
                  },
                  child: TextField(
                    key: const ValueKey('filmAdd:thickness'),
                    controller: _thickness,
                    decoration: InputDecoration(
                      labelText: l10n.filmThickness,
                    ),
                  ),
                ),
                _withList(
                  context,
                  key: 'filmAdd:width:edit',
                  onEdit: () async {
                    final v = await _fromDictionary(
                      MdfDictKind.filmWidth,
                      l10n.filmWidth,
                      _width.text.trim(),
                    );
                    if (v != null) _width.text = v;
                  },
                  child: TextField(
                    key: const ValueKey('filmAdd:width'),
                    controller: _width,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.filmWidth),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  money('price', _price, l10n.filmPriceM),
                  const SizedBox(width: AppSpacing.sm),
                  money('retail', _retail, l10n.filmRetailM),
                  const SizedBox(width: AppSpacing.sm),
                  money('wholesale', _wholesale, l10n.filmWholesaleM),
                ],
              ),
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
          key: const ValueKey('filmAdd:cancel'),
          onPressed: () => Navigator.of(context).pop(_added),
          child: Text(_added ? l10n.filmClose : l10n.mdfCancel),
        ),
        OutlinedButton(
          key: const ValueKey('filmAdd:more'),
          onPressed: ready ? () => _save(more: true) : null,
          child: Text(l10n.filmSaveMore),
        ),
        FilledButton(
          key: const ValueKey('filmAdd:save'),
          onPressed: ready ? () => _save(more: false) : null,
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}

/// One film's row: its sample, name and code, type and thickness, and what
/// is on hand — «есть · 84 м» or «заказать».
class FilmTile extends StatelessWidget {
  const FilmTile({required this.film, this.supplier, this.onTap, super.key});

  final Film film;

  /// Where it is bought, by name — under the film's name with its
  /// collection and surface, so the card need not be opened to see them.
  final String? supplier;
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
        leading: f.argb == null ? null : FilmSample(argb: f.argb),
        title: Text(
          [f.colour, ?f.code].join(' · '),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            ?f.collection,
            ?f.type,
            ?supplier,
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

/// A film's sample square — shown only for a film that was given a colour
/// (the makers publish RAL, not a colour code, so the card no longer asks).
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

class _Unassigned extends ConsumerWidget {
  const _Unassigned({required this.colours, required this.canEdit});

  final List<String> colours;
  final bool canEdit;

  Future<void> _drop(BuildContext context, WidgetRef ref, String c) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showConfirmDialog(
      context: context,
      title: l10n.filmLooseDropAsk(c),
      message: l10n.filmLooseDropHint,
      confirmLabel: l10n.mdfDictDelete,
      isDestructive: true,
    );
    if (!yes) return;
    try {
      await ref.read(filmCatalogRepositoryProvider).dropUnassigned(c);
      ref.invalidate(filmCatalogProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.filmUnassignedHint),
        const SizedBox(height: AppSpacing.sm),
        for (final c in colours)
          ListTile(
            key: ValueKey('filmLoose:$c'),
            title: Text(c),
            // The old list is no longer kept by hand: a colour that is
            // not a film of some maker is taken off here (11.11.2026).
            trailing: canEdit
                ? IconButton(
                    key: ValueKey('filmLooseDrop:$c'),
                    tooltip: l10n.mdfDictDelete,
                    onPressed: () => _drop(context, ref, c),
                    icon: const Icon(AppIcons.delete),
                  )
                : null,
          ),
      ],
    );
  }
}

/// A film's card: what it is and what it costs us, per running metre.
///
/// Gives true when the film was deleted — there is nothing left to show.
Future<bool?> showFilmCard(BuildContext context, Film film, FilmCatalog c) =>
    showDialog<bool>(
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

class _FilmCardDialogState extends ConsumerState<_FilmCardDialog>
    with _FilmLists<_FilmCardDialog> {
  late final _name = TextEditingController(text: widget.film.colour);
  late final _thickness = TextEditingController(
    text: widget.film.thicknessMm == null
        ? ''
        : _metres(widget.film.thicknessMm!),
  );
  late final _width = TextEditingController(
    text: widget.film.widthMm?.toStringAsFixed(0),
  );
  bool _history = false;
  late final _code = TextEditingController(text: widget.film.code);
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
  late String? _collection = widget.film.collection;
  late String? _supplier = widget.film.supplier;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _thickness,
      _width,
      _code,
      _ral,
      _price,
      _url,
      _retail,
      _wholesale,
    ]) {
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
        // What the film is: its name and its roll (owner, 11.11.2026).
        'colour': _name.text.trim(),
        if (_thickness.text.trim().isNotEmpty)
          'thickness': _thickness.text.trim(),
        if (_width.text.trim().isNotEmpty) 'width': _width.text.trim(),
        'code': _code.text.trim(),
        'type': _type,
        'collection': _collection,
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

  /// Runs [action], then closes the card with [result]; a refusal — a
  /// film with history cannot be deleted — stays on the card.
  Future<void> _act(Future<void> Function() action, {bool? result}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(filmCatalogProvider);
      if (mounted) Navigator.of(context).pop(result);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _toggleArchive() {
    final repo = ref.read(filmCatalogRepositoryProvider);
    final item = widget.film.item;
    return _act(
      () => widget.film.enabled ? repo.archive(item) : repo.restore(item),
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final yes = await showConfirmDialog(
      context: context,
      title: l10n.filmDeleteAsk(widget.film.colour),
      message: l10n.filmDeleteHint,
      confirmLabel: l10n.filmDelete,
      isDestructive: true,
    );
    if (!yes) return;
    await _act(
      () => ref.read(filmCatalogRepositoryProvider).delete(widget.film.item),
      result: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = widget.film;
    final c = ref.watch(filmCatalogProvider).value ?? widget.catalog;
    final collections = c.collectionsOf(f.maker);
    final suppliers = _suppliersOf(c, f.maker, _supplier);
    Widget field(String key, TextEditingController ctl, String label) =>
        TextField(
          key: ValueKey('filmCard:$key'),
          controller: ctl,
          decoration: InputDecoration(labelText: label),
        );
    return AlertDialog(
      title: Text('${f.colour}\n${f.maker}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                !f.enabled
                    ? l10n.filmOff
                    : f.free > 0
                    ? l10n.filmHave(_metres(f.free))
                    : l10n.filmToOrder,
              ),
              field('name', _name, l10n.filmName),
              Row(
                children: [
                  Expanded(
                    child: _withList(
                      context,
                      key: 'filmCard:thickness:edit',
                      onEdit: () async {
                        final v = await _fromDictionary(
                          MdfDictKind.filmThickness,
                          l10n.filmThickness,
                          _thickness.text.trim(),
                        );
                        if (v != null) _thickness.text = v;
                      },
                      child: field(
                        'thickness',
                        _thickness,
                        l10n.filmThickness,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _withList(
                      context,
                      key: 'filmCard:width:edit',
                      onEdit: () async {
                        final v = await _fromDictionary(
                          MdfDictKind.filmWidth,
                          l10n.filmWidth,
                          _width.text.trim(),
                        );
                        if (v != null) _width.text = v;
                      },
                      child: field('width', _width, l10n.filmWidth),
                    ),
                  ),
                ],
              ),
              field('code', _code, l10n.filmCode),
              _withList(
                context,
                key: 'filmCard:collection:edit',
                onEdit: () async {
                  final v = await _collectionFrom(f.maker, _collection);
                  if (v != null && mounted) setState(() => _collection = v);
                },
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(
                    'filmCard:collection:$_collection:${collections.length}',
                  ),
                  initialValue: collections.contains(_collection)
                      ? _collection
                      : null,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(child: Text(l10n.mdfNone)),
                    for (final name in collections)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (v) => setState(() => _collection = v),
                  decoration: InputDecoration(labelText: l10n.filmCollection),
                ),
              ),
              _withList(
                context,
                key: 'filmCard:type:edit',
                onEdit: () async {
                  final v = await _fromDictionary(
                    MdfDictKind.filmType,
                    l10n.filmType,
                    _type,
                  );
                  if (v != null && mounted) setState(() => _type = v);
                },
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('filmCard:type:$_type:${c.types.length}'),
                  initialValue: c.types.contains(_type) ? _type : null,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(child: Text(l10n.mdfNone)),
                    for (final t in c.types)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                  decoration: InputDecoration(labelText: l10n.filmType),
                ),
              ),
              field('ral', _ral, l10n.filmRal),
              _withList(
                context,
                key: 'filmCard:supplier:edit',
                onEdit: () async {
                  final v = await _supplierFrom(f.maker, _supplier);
                  if (v != null && mounted) setState(() => _supplier = v);
                },
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(
                    'filmCard:supplier:$_supplier:${suppliers.length}',
                  ),
                  initialValue: suppliers.any((s) => s.id == _supplier)
                      ? _supplier
                      : null,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(child: Text(l10n.mdfNone)),
                    for (final s in suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplier = v),
                  decoration: InputDecoration(labelText: l10n.filmSupplier),
                ),
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
              // Who changed what, and when — asked for, not loaded with
              // every card.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('filmCard:history'),
                  onPressed: () => setState(() => _history = !_history),
                  child: Text(l10n.filmChanges),
                ),
              ),
              if (_history) _FilmChanges(item: f.item),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actionsOverflowButtonSpacing: AppSpacing.xs,
      actions: [
        TextButton(
          key: const ValueKey('filmCard:delete'),
          onPressed: _busy ? null : _delete,
          child: Text(l10n.filmDelete),
        ),
        TextButton(
          key: const ValueKey('filmCard:archive'),
          onPressed: _busy ? null : _toggleArchive,
          child: Text(f.enabled ? l10n.filmArchive : l10n.filmRestore),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmCard:save'),
          onPressed: _busy || _name.text.trim().length < 2 ? null : _save,
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}

/// A film's history of changes, the newest first.
class _FilmChanges extends ConsumerWidget {
  const _FilmChanges({required this.item});

  final String item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final changes = ref.watch(filmChangesProvider(item));
    return changes.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('$e'),
      data: (rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty) Text(l10n.filmChangesEmpty),
          for (final (i, r) in rows.indexed)
            Padding(
              key: ValueKey('filmChange:$i'),
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${r.when} · ${r.who}\n',
                      style: theme.textTheme.labelSmall,
                    ),
                    TextSpan(text: r.line),
                  ],
                ),
              ),
            ),
        ],
      ),
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
  String? _collection;
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
    final collections = c == null || maker == null
        ? const <String>[]
        : c.collectionsOf(maker);
    final films = c == null || maker == null
        ? const <Film>[]
        : [
            for (final f in c.of(
              maker,
              type: _type,
              collection: collections.contains(_collection)
                  ? _collection
                  : null,
              search: _search,
            ))
              if (f.enabled && f.label != null) f,
          ];
    return AlertDialog(
      title: Text(l10n.filmCatalogTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 11,
        height: AppSpacing.xxxl * 10,
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
                          onSelected: (_) => setState(() {
                            _maker = m;
                            _collection = null;
                          }),
                        ),
                    ],
                  ),
                  if (collections.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.filmCollection,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('pickCollection:all'),
                          label: Text(l10n.filmAllCollections),
                          selected: !collections.contains(_collection),
                          onSelected: (_) => setState(() => _collection = null),
                        ),
                        for (final name in collections)
                          ChoiceChip(
                            key: ValueKey('pickCollection:$name'),
                            label: Text(name),
                            selected: _collection == name,
                            onSelected: (on) => setState(
                              () => _collection = on ? name : null,
                            ),
                          ),
                      ],
                    ),
                  ],
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
