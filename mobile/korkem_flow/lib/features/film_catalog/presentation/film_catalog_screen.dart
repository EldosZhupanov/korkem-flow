import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/server_image.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/decor_match.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_collections.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_decors_screen.dart';
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

  /// Only films with a thickness not known yet — to fill them in.
  bool _noThickness = false;

  /// The collection open at each maker — every maker has its own.
  final _collection = <String, String>{};

  /// A maker just added: its tab is opened.
  String? _opening;

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
        final decors = ref.watch(filmCatalogueProvider).value;
        // A maker known only by its catalogue has a tab too.
        final known = decors?.makers ?? const <({String maker, int count})>[];
        final tabs = [
          ...c.tabs,
          for (final m in known)
            if (!c.tabs.contains(m.maker)) m.maker,
        ];
        // «не указан» only while there are colours with no maker.
        final loose = c.unassigned.isNotEmpty;
        // A maker just added opens on its own tab.
        final opening = _opening == null ? -1 : tabs.indexOf(_opening!);
        return DefaultTabController(
          key: ValueKey('filmTabs:${tabs.length}:$loose:$_opening'),
          length: tabs.length + (loose ? 1 : 0),
          initialIndex: opening < 0 ? 0 : opening,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.filmCatalogTitle),
              actions: [
                // Every maker's catalogue is on its tab now (owner,
                // 19.11.2026: «один экран»); loading a catalogue and
                // pictures by name stay a tap away.
                const PhotoMatchButton(),
                IconButton(
                  key: const ValueKey('filmDecors'),
                  tooltip: l10n.filmCatalogueTools,
                  onPressed: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FilmDecorsScreen(),
                      ),
                    ),
                  ),
                  icon: const Icon(AppIcons.attachment),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(kTextTabBarHeight),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          for (final m in tabs)
                            Tab(
                              key: ValueKey('filmMaker:$m'),
                              text: m,
                            ),
                          if (loose)
                            Tab(
                              key: const ValueKey('filmMaker:none'),
                              text:
                                  '${l10n.filmUnassigned} · '
                                  '${c.unassigned.length}',
                            ),
                        ],
                      ),
                    ),
                    // «+ Фирма» (owner, 19.11.2026): a new maker, where it
                    // is bought, in one window.
                    if (c.canEdit)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: TextButton.icon(
                          key: const ValueKey('filmMakerAdd'),
                          onPressed: () async {
                            final made = await showFilmMakerAdd(context);
                            if (made != null && mounted) {
                              setState(() => _opening = made);
                            }
                          },
                          icon: const Icon(AppIcons.add),
                          label: Text(l10n.filmMakerAddButton),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            body: TabBarView(
              children: [
                for (final m in tabs) _makerTab(c, decors, m, l10n),
                if (loose)
                  _Unassigned(colours: c.unassigned, canEdit: c.canEdit),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _makerTab(
    FilmCatalog c,
    FilmDecors? decors,
    String maker,
    AppLocalizations l10n,
  ) {
    final collections = {
      ...c.collectionsOf(maker),
      ...?decors?.collectionsOf(maker),
    }.toList();
    // A collection renamed or removed meanwhile is no longer a filter.
    final collection = collections.contains(_collection[maker])
        ? _collection[maker]
        : null;
    final archived = c.of(maker, archived: true);
    final archive = _archive && archived.isNotEmpty;
    final all = c.of(
      maker,
      type: _type,
      collection: collection,
      search: _search,
      archived: archive,
    );
    bool unknown(Film f) => f.thicknessMm == null;
    final blank = FilmCatalog.grouped(all).where((g) => g.any(unknown)).length;
    final noThickness = _noThickness && blank > 0;
    // A film shows whole, all its thicknesses, when one of them is unknown.
    final films = noThickness
        ? [
            for (final g in FilmCatalog.grouped(all))
              if (g.any(unknown)) ...g,
          ]
        : all;
    // Under the shop's own films, the rest of the maker's catalogue
    // (owner, 19.11.2026): what is not taken in yet, by the same search
    // and collection; a tap takes it in or orders it.
    final catalogue = _type != null || archive || noThickness
        ? const <FilmDecor>[]
        : [
            for (final x in decors?.decors ?? const <FilmDecor>[])
              if (x.maker == maker &&
                  x.films.isEmpty &&
                  (collection == null || x.collection == collection) &&
                  x.matches(_search))
                x,
          ];
    final theme = Theme.of(context);
    final head = <Widget>[
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
          // Films whose thickness is not known yet, to be filled in
          // (owner, 11.11.2026).
          if (blank > 0)
            FilterChip(
              key: ValueKey('filmNoThickness:$maker'),
              label: Text(l10n.filmNoThickness('$blank')),
              selected: noThickness,
              onSelected: (on) => setState(() => _noThickness = on),
            ),
          if (archived.isNotEmpty)
            FilterChip(
              key: ValueKey('filmArchive:$maker'),
              label: Text(l10n.filmArchiveChip('${archived.length}')),
              selected: archive,
              onSelected: (on) => setState(() => _archive = on),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        l10n.filmOurs('${FilmCatalog.grouped(films).length}'),
        key: ValueKey('filmOurs:$maker'),
        style: theme.textTheme.labelLarge,
      ),
      if (films.isEmpty)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(l10n.filmEmpty(maker)),
        ),
      // One row a film, its thicknesses together (owner, 11.11.2026).
      for (final g in FilmCatalog.grouped(films))
        FilmTile(
          film: g.first,
          variants: g,
          supplier: c.suppliers
              .where((s) => s.id == g.first.supplier)
              .map((s) => s.name)
              .firstOrNull,
          onTap: c.canEdit ? () => showFilmCard(context, g.first, c) : null,
        ),
      if (catalogue.isNotEmpty) ...[
        const Divider(),
        Text(
          l10n.filmCatalogueOf(maker, '${catalogue.length}'),
          key: ValueKey('filmCatalogue:$maker'),
          style: theme.textTheme.labelLarge,
        ),
        Text(
          l10n.filmCatalogueHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          sliver: SliverList(delegate: SliverChildListDelegate(head)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: AppSpacing.xxxl * 4,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.9,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => DecorCard(
                decor: catalogue[i],
                onTap: () => unawaited(
                  showFilmDecor(
                    context,
                    catalogue[i],
                    canEdit: decors?.canEdit ?? false,
                  ),
                ),
              ),
              childCount: catalogue.length,
            ),
          ),
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
                      // Empty: not known yet — better than a made-up 0,3.
                      helperText: l10n.filmThicknessHint,
                      helperMaxLines: 2,
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
  const FilmTile({
    required this.film,
    this.variants = const [],
    this.supplier,
    this.onTap,
    this.onInfo,
    super.key,
  });

  final Film film;

  /// The film's thicknesses shown with it — «0,18 · 0,25 · 0,3 мм» — and
  /// what is on hand of them all; empty for [film] alone.
  final List<Film> variants;

  /// Where it is bought, by name — under the film's name with its
  /// collection and surface, so the card need not be opened to see them.
  final String? supplier;
  final VoidCallback? onTap;

  /// The film's card beside the list (owner, 19.11.2026: «зайти в карточку
  /// плёнки» from the order's film window) — an ⓘ after its stock.
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = film;
    final all = variants.isEmpty ? [f] : variants;
    final free = all.fold<double>(0, (s, v) => s + (v.enabled ? v.free : 0));
    final thick = [
      for (final v in all)
        if (v.thicknessMm != null) _metres(v.thicknessMm!),
    ];
    final widths = {
      for (final v in all)
        if (v.widthMm != null) v.widthMm!.toStringAsFixed(0),
    };
    final stock = !f.enabled
        ? l10n.filmOff
        : free > 0
        ? l10n.filmHave(_metres(free))
        : l10n.filmToOrder;
    return Opacity(
      opacity: f.enabled ? 1 : 0.5,
      child: ListTile(
        key: ValueKey('film:${f.item}'),
        onTap: onTap,
        leading: f.argb == null && f.image == null
            ? null
            : FilmSample(argb: f.argb, image: f.image),
        title: Text(
          filmTitle(f.colour, f.code),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            ?f.collection,
            ?f.type,
            ?supplier,
            if (thick.isNotEmpty) '${thick.join(' / ')} мм',
            if (all.any((v) => v.thicknessMm == null))
              l10n.filmThicknessUnknown,
            if (widths.isNotEmpty) '${widths.join(' / ')} мм',
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stock,
              style: TextStyle(
                color: f.enabled && free > 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onInfo != null)
              IconButton(
                key: ValueKey('filmInfo:${f.item}'),
                tooltip: l10n.fpkCard,
                icon: const Icon(AppIcons.info),
                onPressed: onInfo,
              ),
          ],
        ),
      ),
    );
  }
}

/// A film's name with its code — once when they are the same (owner,
/// 19.11.2026: GreenWood names its decors by their code, «AS 1890-SFT-W ·
/// AS 1890-SFT-W»).
String filmTitle(String name, String? code) {
  final c = code?.trim();
  if (c == null || c.isEmpty) return name;
  final n = name.trim().toLowerCase();
  return n == c.toLowerCase() || n.contains(c.toLowerCase())
      ? name
      : '$name · $c';
}

/// A film's sample square — shown only for a film that was given a colour
/// (the makers publish RAL, not a colour code, so the card no longer asks).
class FilmSample extends StatelessWidget {
  const FilmSample({
    required this.argb,
    this.size = AppSpacing.xl,
    this.image,
    super.key,
  });

  final int? argb;
  final double size;

  /// The decor's picture (owner, 18.11.2026): the film «на глаз»; the
  /// colour stands in while it loads or when it cannot.
  final String? image;

  @override
  Widget build(BuildContext context) {
    final colour = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: argb == null ? null : Color(argb!),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
    final path = image;
    if (path == null) return colour;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ServerImage(path: path, fallback: colour),
      ),
    );
  }
}

/// «2026-11-11» → «11.11».
String _day(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}' : iso;
}

/// «1,7», not «1,6999999999999993» (owner, 19.11.2026): two places at most.
String _metres(double v) {
  final r = (v * 100).roundToDouble() / 100;
  if (r == r.roundToDouble()) return r.toStringAsFixed(0);
  return r
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}

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

/// One thickness of a film on its card (owner, 11.11.2026): its roll and
/// its three prices, each changed here.
class _Variant {
  _Variant(this.film)
    : thickness = TextEditingController(
        text: film.thicknessMm == null ? '' : _metres(film.thicknessMm!),
      ),
      width = TextEditingController(text: film.widthMm?.toStringAsFixed(0)),
      price = TextEditingController(text: film.priceM?.toStringAsFixed(0)),
      retail = TextEditingController(text: film.retailM?.toStringAsFixed(0)),
      wholesale = TextEditingController(
        text: film.wholesaleM?.toStringAsFixed(0),
      );

  final Film film;
  final TextEditingController thickness;
  final TextEditingController width;
  final TextEditingController price;
  final TextEditingController retail;
  final TextEditingController wholesale;

  /// What is this thickness's own, as the server names it.
  Map<String, String> get own => {
    if (thickness.text.trim().isNotEmpty) 'thickness': thickness.text.trim(),
    if (width.text.trim().isNotEmpty) 'width': width.text.trim(),
    'price_m': price.text.trim(),
    'retail_m': retail.text.trim(),
    'wholesale_m': wholesale.text.trim(),
  };

  /// Whether anything of its own was changed on the card.
  bool get touched {
    String n(double? v) => v == null ? '' : v.toStringAsFixed(0);
    return thickness.text.trim() !=
            (film.thicknessMm == null ? '' : _metres(film.thicknessMm!)) ||
        width.text.trim() != n(film.widthMm) ||
        price.text.trim() != n(film.priceM) ||
        retail.text.trim() != n(film.retailM) ||
        wholesale.text.trim() != n(film.wholesaleM);
  }

  void dispose() {
    for (final c in [thickness, width, price, retail, wholesale]) {
      c.dispose();
    }
  }
}

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
  bool _history = false;
  late final _code = TextEditingController(text: widget.film.code);
  late final _ral = TextEditingController(text: widget.film.ral);
  late final _url = TextEditingController(text: widget.film.url);
  late String? _type = widget.film.type;
  late String? _collection = widget.film.collection;
  late String? _supplier = widget.film.supplier;
  bool _busy = false;
  String? _error;

  /// Each thickness's fields, by its Item — made as the thicknesses show
  /// up, so one added from here appears at once.
  final _variants = <String, _Variant>{};

  _Variant _variant(Film f) => _variants.putIfAbsent(f.item, () => _Variant(f));

  /// Every thickness of the film, thinnest first.
  List<Film> _films(FilmCatalog c) {
    final group = c.variantsOf(widget.film);
    return group.isEmpty ? [widget.film] : group;
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _ral, _url]) {
      c.dispose();
    }
    for (final v in _variants.values) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _save(List<Film> films) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(filmCatalogRepositoryProvider);
    try {
      // What is the film's goes once — the server writes it to every
      // thickness — with the first thickness's own.
      await repo.setCard(films.first.item, {
        'colour': _name.text.trim(),
        'code': _code.text.trim(),
        'type': _type,
        'collection': _collection,
        'ral': _ral.text.trim(),
        'supplier': _supplier,
        'url': _url.text.trim(),
        ..._variant(films.first).own,
      });
      for (final f in films.skip(1)) {
        final v = _variant(f);
        if (v.touched) await repo.setCard(f.item, v.own);
      }
      ref.invalidate(filmCatalogProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  /// Runs [action]; [close] closes the card with [result] after it, else
  /// it stays open on what is left. A refusal stays on the card.
  Future<void> _act(
    Future<void> Function() action, {
    bool close = true,
    bool? result,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(filmCatalogProvider);
      if (!mounted) return;
      if (close) {
        Navigator.of(context).pop(result);
      } else {
        setState(() => _busy = false);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  /// The whole film — every thickness — into the archive, or back.
  Future<void> _toggleArchive(List<Film> films) {
    final repo = ref.read(filmCatalogRepositoryProvider);
    final off = films.any((x) => x.enabled);
    return _act(() async {
      for (final x in films) {
        await (off ? repo.archive(x.item) : repo.restore(x.item));
      }
    });
  }

  Future<void> _delete(List<Film> films) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showConfirmDialog(
      context: context,
      title: l10n.filmDeleteAsk(widget.film.colour),
      message: l10n.filmDeleteHint,
      confirmLabel: l10n.filmDelete,
      isDestructive: true,
    );
    if (!yes) return;
    final repo = ref.read(filmCatalogRepositoryProvider);
    await _act(() async {
      for (final x in films) {
        await repo.delete(x.item);
      }
    }, result: true);
  }

  /// One thickness off the film: deleted when nothing was done with it,
  /// else into the archive — the film and its other thicknesses stay.
  Future<void> _dropVariant(Film f) async {
    final l10n = AppLocalizations.of(context);
    final thick = f.thicknessMm == null ? '' : _metres(f.thicknessMm!);
    final yes = await showConfirmDialog(
      context: context,
      title: l10n.filmVariantDeleteAsk(thick),
      message: l10n.filmDeleteHint,
      confirmLabel: l10n.filmDelete,
      isDestructive: true,
    );
    if (!yes) return;
    await _act(
      () => ref.read(filmCatalogRepositoryProvider).delete(f.item),
      close: false,
    );
  }

  Future<void> _toggleVariant(Film f) {
    final repo = ref.read(filmCatalogRepositoryProvider);
    return _act(
      () => f.enabled ? repo.archive(f.item) : repo.restore(f.item),
      close: false,
    );
  }

  /// The film «на глаз» (owner, 18.11.2026): its own photo, else its
  /// decor's from the maker's catalogue; a sample photo is put on here.
  Widget _photo(BuildContext context, Film f) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          FilmSample(
            key: const ValueKey('filmCard:picture'),
            argb: f.argb,
            image: f.image,
            size: AppSpacing.xxxl * 2,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('filmCard:photo'),
                  onPressed: _busy ? null : () => unawaited(_pickPhoto(f)),
                  icon: const Icon(AppIcons.camera),
                  label: Text(l10n.fdcPhoto),
                ),
                if (f.imageOwn)
                  TextButton(
                    key: const ValueKey('filmCard:photoClear'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _act(
                              () => ref
                                  .read(filmDecorRepositoryProvider)
                                  .clearFilmImage(f.item),
                              close: false,
                            ),
                          ),
                    child: Text(l10n.fdcPhotoClear),
                  ),
                if (f.image == null)
                  Text(
                    l10n.fdcNoPicture,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(Film f) async {
    final files = await ref
        .read(filmFilePickerProvider)
        .pick(extensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (files.isEmpty || !mounted) return;
    await _act(
      () => ref
          .read(filmDecorRepositoryProvider)
          .setFilmImage(f.item, files.first),
      close: false,
    );
  }

  /// «+ Толщина»: another roll of the same film, with its own prices.
  Future<void> _addVariant(Film first) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _VariantDialog(film: first),
    );
    if (added ?? false) ref.invalidate(filmCatalogProvider);
  }

  Widget _variantFields(
    BuildContext context,
    Film f,
    int i, {
    required bool many,
  }) {
    final l10n = AppLocalizations.of(context);
    final v = _variant(f);
    // The first thickness keeps the card's own keys; the others say which.
    String k(String name) => i == 0 ? 'filmCard:$name' : 'filmCard:$name:$i';
    Widget text(String key, TextEditingController ctl, String label) =>
        TextField(
          key: ValueKey(k(key)),
          controller: ctl,
          decoration: InputDecoration(labelText: label),
        );
    Widget money(
      String key,
      String wire,
      TextEditingController ctl,
      String l,
    ) => Expanded(
      child: TextField(
        key: ValueKey(k(key)),
        controller: ctl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l,
          helperText: switch (f.priceSince[wire]) {
            final s? when ctl.text.isNotEmpty => l10n.filmPriceSince(
              _day(s.date),
              s.via ?? l10n.filmPriceByHand,
            ),
            _ => null,
          },
        ),
      ),
    );
    final stock = !f.enabled
        ? l10n.filmOff
        : f.free > 0
        ? l10n.filmHave(_metres(f.free))
        : l10n.filmToOrder;
    final thickLabel = f.thicknessMm == null
        ? l10n.filmThicknessUnknown
        : '${v.thickness.text} мм';
    return Padding(
      key: ValueKey('filmVariant:${f.item}'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (many)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$thickLabel · $stock',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey('filmVariant:archive:${f.item}'),
                  tooltip: f.enabled ? l10n.filmArchive : l10n.filmRestore,
                  onPressed: _busy ? null : () => _toggleVariant(f),
                  icon: Icon(f.enabled ? AppIcons.hidden : AppIcons.undo),
                ),
                IconButton(
                  key: ValueKey('filmVariant:delete:${f.item}'),
                  tooltip: l10n.filmDelete,
                  onPressed: _busy ? null : () => _dropVariant(f),
                  icon: const Icon(AppIcons.delete),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: _withList(
                  context,
                  key: k('thickness:edit'),
                  onEdit: () async {
                    final t = await _fromDictionary(
                      MdfDictKind.filmThickness,
                      l10n.filmThickness,
                      v.thickness.text.trim(),
                    );
                    if (t != null && mounted) {
                      setState(() => v.thickness.text = t);
                    }
                  },
                  child: text('thickness', v.thickness, l10n.filmThickness),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _withList(
                  context,
                  key: k('width:edit'),
                  onEdit: () async {
                    final w = await _fromDictionary(
                      MdfDictKind.filmWidth,
                      l10n.filmWidth,
                      v.width.text.trim(),
                    );
                    if (w != null) v.width.text = w;
                  },
                  child: text('width', v.width, l10n.filmWidth),
                ),
              ),
            ],
          ),
          // What it costs us and what the department sells a metre at
          // (10.11.2026), each with since when it stands (11.11.2026).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              money('price', 'price_m', v.price, l10n.filmPriceM),
              const SizedBox(width: AppSpacing.sm),
              money('retail', 'retail_m', v.retail, l10n.filmRetailM),
              const SizedBox(width: AppSpacing.sm),
              money(
                'wholesale',
                'wholesale_m',
                v.wholesale,
                l10n.filmWholesaleM,
              ),
            ],
          ),
          if (f.marginM case final margin?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.filmMargin(
                  margin.toStringAsFixed(0),
                  f.priceM! > 0
                      ? (margin / f.priceM! * 100).toStringAsFixed(0)
                      : '—',
                ),
                key: ValueKey(k('margin')),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = widget.film;
    final c = ref.watch(filmCatalogProvider).value ?? widget.catalog;
    final films = _films(c);
    final many = films.length > 1;
    final collections = c.collectionsOf(f.maker);
    final suppliers = _suppliersOf(c, f.maker, _supplier);
    final enabled = films.any((x) => x.enabled);
    final free = films.fold<double>(0, (s, x) => s + (x.enabled ? x.free : 0));
    Widget field(String key, TextEditingController ctl, String label) =>
        TextField(
          key: ValueKey('filmCard:$key'),
          controller: ctl,
          decoration: InputDecoration(labelText: label),
        );
    return AlertDialog(
      title: Text('${f.colour}\n${f.maker}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 11,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _photo(context, films.first),
              Text(
                !enabled
                    ? l10n.filmOff
                    : free > 0
                    ? l10n.filmHave(_metres(free))
                    : l10n.filmToOrder,
              ),
              field('name', _name, l10n.filmName),
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
              field('url', _url, l10n.filmUrl),
              // The film's thicknesses, each its own roll and prices
              // (owner, 11.11.2026: «Белое дерево» 0,18 / 0,25 / 0,3).
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.filmVariants,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final (i, v) in films.indexed)
                _variantFields(context, v, i, many: many),
              if (c.canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('filmCard:addThickness'),
                    onPressed: _busy ? null : () => _addVariant(films.first),
                    icon: const Icon(AppIcons.add),
                    label: Text(l10n.filmVariantAdd),
                  ),
                ),
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
          onPressed: _busy ? null : () => _delete(films),
          child: Text(l10n.filmDelete),
        ),
        TextButton(
          key: const ValueKey('filmCard:archive'),
          onPressed: _busy ? null : () => _toggleArchive(films),
          child: Text(enabled ? l10n.filmArchive : l10n.filmRestore),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmCard:save'),
          onPressed: _busy || _name.text.trim().length < 2
              ? null
              : () => _save(films),
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}

/// «+ Толщина»: the film once more, in another thickness — its own roll
/// and its own three prices; the rest is the film's.
class _VariantDialog extends ConsumerStatefulWidget {
  const _VariantDialog({required this.film});

  final Film film;

  @override
  ConsumerState<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends ConsumerState<_VariantDialog>
    with _FilmLists<_VariantDialog> {
  final _thickness = TextEditingController();
  late final _width = TextEditingController(
    text: widget.film.widthMm?.toStringAsFixed(0) ?? '1400',
  );
  final _price = TextEditingController();
  final _retail = TextEditingController();
  final _wholesale = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_thickness, _width, _price, _retail, _wholesale]) {
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
      await ref
          .read(filmCatalogRepositoryProvider)
          .add(
            maker: widget.film.maker,
            colour: widget.film.colour,
            thickness: _thickness.text.trim(),
            width: _width.text.trim(),
            card: {
              'price_m': _price.text.trim(),
              'retail_m': _retail.text.trim(),
              'wholesale_m': _wholesale.text.trim(),
            },
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
    Widget money(String key, TextEditingController ctl, String label) =>
        Expanded(
          child: TextField(
            key: ValueKey('filmVariantAdd:$key'),
            controller: ctl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: label),
          ),
        );
    return AlertDialog(
      title: Text('${l10n.filmVariantAdd} · ${widget.film.colour}'),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _withList(
                    context,
                    key: 'filmVariantAdd:thickness:edit',
                    onEdit: () async {
                      final t = await _fromDictionary(
                        MdfDictKind.filmThickness,
                        l10n.filmThickness,
                        _thickness.text.trim(),
                      );
                      if (t != null && mounted) {
                        setState(() => _thickness.text = t);
                      }
                    },
                    child: TextField(
                      key: const ValueKey('filmVariantAdd:thickness'),
                      controller: _thickness,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.filmThickness,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const ValueKey('filmVariantAdd:width'),
                    controller: _width,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.filmWidth),
                  ),
                ),
              ],
            ),
            Row(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmVariantAdd:save'),
          onPressed: _busy || _thickness.text.trim().isEmpty ? null : _save,
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

/// The order's film window (owner, 18.11.2026: «должен открываться весь
/// список плёнки»): every film on the books — on the shelf first — and
/// every maker's catalogue decor not taken in yet, found by one search
/// across all makers, with [customer]'s films of late on top and a photo
/// of a sample as another way in. Gives the film's name for the order,
/// «KIRA · Белый Матовый»; with [allowNone], an empty name when the film
/// is taken off.
Future<String?> showFilmPicker(
  BuildContext context, {
  String? current,
  String? customer,
  bool allowNone = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _FilmPickerDialog(
    current: current,
    customer: customer,
    allowNone: allowNone,
  ),
);

class _FilmPickerDialog extends ConsumerStatefulWidget {
  const _FilmPickerDialog({
    this.current,
    this.customer,
    this.allowNone = false,
  });

  final String? current;
  final String? customer;

  /// «Без плёнки» is offered: the group's film may be taken off.
  final bool allowNone;

  @override
  ConsumerState<_FilmPickerDialog> createState() => _FilmPickerDialogState();
}

class _FilmPickerDialogState extends ConsumerState<_FilmPickerDialog> {
  /// How many catalogue decors are shown at once.
  static const _decorsShown = 60;

  String? _maker;
  String? _type;
  bool _onShelf = false;
  String _search = '';
  bool _busy = false;

  /// The film whose card is open beside the list, all its thicknesses.
  List<Film>? _card;

  static String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  bool _found(List<String?> parts) {
    final q = _norm(_search.trim());
    if (q.isEmpty) return true;
    final hay = _norm(parts.whereType<String>().join(' '));
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  Future<void> _pickFilm(List<Film> group) async {
    // A film of several thicknesses: which one (owner, 11.11.2026).
    final picked = group.length == 1
        ? group.single
        : await _pickThickness(context, group);
    if (picked != null && mounted) Navigator.of(context).pop(picked.label);
  }

  Future<void> _pickDecor(String decor) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final label = await ref
          .read(filmDecorRepositoryProvider)
          .takeDecor(decor);
      ref.invalidate(filmCatalogProvider);
      if (mounted) Navigator.of(context).pop(label);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _byPhoto() async {
    final match = await showPhotoMatch(context, ref, pick: true);
    if (match == null || !mounted) return;
    final films = [
      for (final f in match.films)
        if (f.label.isNotEmpty) f,
    ]..sort((a, b) => b.free.compareTo(a.free));
    if (films.isNotEmpty) {
      Navigator.of(context).pop(films.first.label);
    } else {
      await _pickDecor(match.decor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = ref.watch(filmCatalogProvider).value;
    final extras =
        ref.watch(filmPickExtrasProvider(widget.customer)).value ??
        const FilmPickExtras();
    final screen = MediaQuery.sizeOf(context);
    final label = theme.textTheme.labelMedium;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget body;
    if (c == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final names = {for (final s in c.suppliers) s.id: s.name};
      final usable = [
        for (final f in c.films)
          if (f.enabled && f.label != null) f,
      ];
      final groups = FilmCatalog.grouped(usable);
      double freeOf(List<Film> g) => g.fold<double>(0, (s, f) => s + f.free);
      final films =
          [
            for (final g in groups)
              if ((_maker == null || g.first.maker == _maker) &&
                  (_type == null || g.first.type == _type) &&
                  (!_onShelf || freeOf(g) > 0) &&
                  _found([
                    g.first.maker,
                    g.first.colour,
                    g.first.code,
                    g.first.collection,
                    g.first.type,
                  ]))
                g,
          ]..sort((a, b) {
            final fa = freeOf(a);
            final fb = freeOf(b);
            if ((fa > 0) != (fb > 0)) return fa > 0 ? -1 : 1;
            if (fa > 0 && fa != fb) return fb.compareTo(fa);
            return '${a.first.maker} ${a.first.colour}'.compareTo(
              '${b.first.maker} ${b.first.colour}',
            );
          });
      // The maker's catalogue — decors not on the books yet — shown under
      // its films whenever a maker is picked, «На складе» or not (owner,
      // 19.11.2026: «а где тут полный список с плёнками каталоги?»).
      final known = {
        for (final f in c.films) _norm('${f.maker} ${f.colour}'),
      };
      final decors = _type != null || (_onShelf && _maker == null)
          ? const <FilmDecor>[]
          : [
              for (final d in extras.decors)
                if ((_maker == null || d.maker == _maker) &&
                    d.films.isEmpty &&
                    !known.contains(_norm('${d.maker} ${d.name}')) &&
                    _found([d.maker, d.name, d.code, d.collection]))
                  d,
            ];
      final shown = decors.take(_decorsShown).toList();
      final plain =
          _search.trim().isEmpty &&
          _maker == null &&
          _type == null &&
          !_onShelf;
      final recent = !plain
          ? const <List<Film>>[]
          : [
              for (final r in extras.recent)
                ?groups
                    .where(
                      (g) =>
                          g.any((f) => f.label == r) ||
                          '${g.first.maker} · ${g.first.colour}' == r,
                    )
                    .firstOrNull,
            ];
      final makers = {
        ...c.tabs,
        for (final d in extras.decors) d.maker,
      }.toList();
      Widget tile(List<Film> g) => FilmTile(
        film: g.first,
        variants: g,
        supplier: names[g.first.supplier] ?? g.first.supplier,
        onTap: _busy ? null : () => _pickFilm(g),
        onInfo: () => setState(() => _card = g),
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('pickSearch'),
                  autofocus: true,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(AppIcons.search),
                    hintText: l10n.fpkSearch,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('pickPhoto'),
                onPressed: _busy ? null : _byPhoto,
                icon: const Icon(AppIcons.camera),
                label: Text(l10n.fpkByPhoto),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                key: const ValueKey('pickMaker:all'),
                label: Text(l10n.fpkAll),
                selected: _maker == null,
                onSelected: (_) => setState(() => _maker = null),
              ),
              FilterChip(
                key: const ValueKey('pickOnShelf'),
                label: Text(l10n.fpkOnShelf),
                selected: _onShelf,
                onSelected: (on) => setState(() => _onShelf = on),
              ),
              for (final m in makers)
                ChoiceChip(
                  key: ValueKey('pickMaker:$m'),
                  label: Text(m),
                  selected: _maker == m,
                  onSelected: (on) => setState(() => _maker = on ? m : null),
                ),
              for (final t in c.types)
                ChoiceChip(
                  key: ValueKey('pickType:$t'),
                  label: Text(t),
                  selected: _type == t,
                  onSelected: (on) => setState(() => _type = on ? t : null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: films.isEmpty && decors.isEmpty
                ? Center(child: Text(l10n.fpkNothing))
                : ListView(
                    children: [
                      if (recent.isNotEmpty) ...[
                        Text(l10n.fpkRecent, style: label),
                        // The same film is in the list below too: its own key
                        // under another one here.
                        for (final g in recent)
                          KeyedSubtree(
                            key: ValueKey('pickRecent:${g.first.item}'),
                            child: tile(g),
                          ),
                        const Divider(),
                      ],
                      Text(
                        _maker == null
                            ? l10n.fpkFound(films.length + decors.length)
                            : l10n.filmOurs('${films.length}'),
                        key: const ValueKey('pickOurs'),
                        style: label,
                      ),
                      for (final g in films) tile(g),
                      if (shown.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          _maker == null
                              ? l10n.filmReceiveCatalogFound(decors.length)
                              : l10n.filmReceiveCatalogOf(
                                  _maker!,
                                  decors.length,
                                ),
                          key: const ValueKey('pickCatalogHead'),
                          style: label,
                        ),
                        Text(l10n.fpkCatalogHint, style: muted),
                        const SizedBox(height: AppSpacing.xs),
                        GridView.builder(
                          key: const ValueKey('pickCatalog'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: AppSpacing.xxxl * 3,
                                mainAxisSpacing: AppSpacing.xs,
                                crossAxisSpacing: AppSpacing.xs,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: shown.length,
                          itemBuilder: (context, i) => DecorCard(
                            key: ValueKey('pickDecor:${shown[i].decor}'),
                            decor: shown[i],
                            onTap: _busy
                                ? () {}
                                : () => _pickDecor(shown[i].decor),
                          ),
                        ),
                        if (decors.length > shown.length)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              l10n.filmReceiveCatalogMore(
                                decors.length - shown.length,
                              ),
                              style: muted,
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      );
      // The card beside the list, the same film found again in a fresh
      // catalogue once it was changed.
      if (_card case final open?) {
        final fresh = groups
            .where((g) => g.any((f) => f.item == open.first.item))
            .firstOrNull;
        body = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            const VerticalDivider(),
            SizedBox(
              width: AppSpacing.xxxl * 8,
              child: _FilmSide(
                key: ValueKey('filmSide:${open.first.item}'),
                group: fresh ?? open,
                catalog: c,
                supplier: names[open.first.supplier] ?? open.first.supplier,
                onPick: _busy ? null : () => _pickFilm(fresh ?? open),
                onClose: () => setState(() => _card = null),
              ),
            ),
          ],
        );
      }
    }
    return AlertDialog(
      key: const ValueKey('filmPicker'),
      title: Text(l10n.fpkTitle),
      // As much of the window as it may take: hundreds of films.
      content: SizedBox(
        width: math.min(
          AppSpacing.xxxl * (_card == null ? 15 : 23),
          screen.width * (_card == null ? 0.8 : 0.92),
        ),
        height: math.min(AppSpacing.xxxl * 14, screen.height * 0.65),
        child: body,
      ),
      actions: [
        if (widget.allowNone && (widget.current ?? '').isNotEmpty)
          TextButton(
            key: const ValueKey('pickNone'),
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l10n.fpkNone),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
      ],
    );
  }
}

/// A film's card beside the order's film window (owner, 19.11.2026): what
/// is on the shelf and on its way, what it costs, how fast it goes — and its
/// history; «Изменить» opens the full card, which keeps that history.
class _FilmSide extends ConsumerStatefulWidget {
  const _FilmSide({
    required this.group,
    required this.catalog,
    required this.onClose,
    this.supplier,
    this.onPick,
    super.key,
  });

  /// The film in all its thicknesses.
  final List<Film> group;
  final FilmCatalog catalog;
  final String? supplier;
  final VoidCallback? onPick;
  final VoidCallback onClose;

  @override
  ConsumerState<_FilmSide> createState() => _FilmSideState();
}

class _FilmSideState extends ConsumerState<_FilmSide> {
  bool _history = false;

  Future<void> _edit(Film film) async {
    final gone = await showFilmCard(context, film, widget.catalog);
    ref
      ..invalidate(filmCatalogProvider)
      ..invalidate(filmChangesProvider(film.item));
    if ((gone ?? false) && mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final f = widget.group.first;
    String money(double v) => '${v.toStringAsFixed(0)} ₸';
    Widget line(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: TextStyle(color: color)),
    );
    final status = context.statusColors;
    final about = [
      for (final v in widget.group) ...[
        if (widget.group.length > 1)
          Text(
            v.thicknessMm == null
                ? l10n.filmThicknessUnknown
                : '${_metres(v.thicknessMm!)} мм',
            style: theme.textTheme.labelMedium,
          ),
        line(
          v.free > 0 ? l10n.filmHave(_metres(v.free)) : l10n.fpkSideNone,
          color: v.free > 0 ? status.success : status.warning,
        ),
        if (v.held > 0 || v.holds.isNotEmpty)
          line(
            l10n.fpkSideHeld(
              _metres(v.held + v.holds.fold<double>(0, (s, h) => s + h.metres)),
            ),
          ),
        for (final c in v.coming)
          line(
            l10n.fpkSideComing(_metres(c.metres), c.due),
            color: c.lateDays > 0 ? status.danger : null,
          ),
        if (v.dailyM case final d? when d > 0)
          line(
            l10n.fpkSideDaily(
              _metres(d),
              v.daysLeft == null ? '—' : '${v.daysLeft}',
            ),
          ),
        if (v.priceM case final p?) line(l10n.fpkSideBuy(money(p))),
        if (v.retailM case final p?) line(l10n.fpkSideRetail(money(p))),
        if (v.wholesaleM case final p?) line(l10n.fpkSideWholesale(money(p))),
        const SizedBox(height: AppSpacing.xs),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (f.argb != null || f.image != null)
              FilmSample(argb: f.argb, image: f.image, size: AppSpacing.xxl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filmTitle(f.colour, f.code),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [
                      f.maker,
                      ?f.collection,
                      ?f.type,
                      ?widget.supplier,
                    ].join(' · '),
                    style: muted,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('filmSideClose'),
              tooltip: l10n.mdfCancel,
              icon: const Icon(AppIcons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.fpkSideFilm)),
            ButtonSegment(
              value: true,
              label: Text(
                l10n.filmHistory,
                key: const ValueKey('filmSideHistory'),
              ),
            ),
          ],
          selected: {_history},
          onSelectionChanged: (v) => setState(() => _history = v.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: _history
                ? _FilmChanges(item: f.item)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: about,
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton(
              key: const ValueKey('filmSidePick'),
              onPressed: widget.onPick,
              child: Text(l10n.fpkSidePick),
            ),
            OutlinedButton(
              key: const ValueKey('filmSideAnalogues'),
              onPressed: () => showAnalogues(
                context,
                ref,
                title: f.colour,
                item: f.item,
              ),
              child: Text(l10n.fdcAnalogues),
            ),
            if (widget.catalog.canEdit)
              OutlinedButton.icon(
                key: const ValueKey('filmSideEdit'),
                onPressed: () => _edit(f),
                icon: const Icon(AppIcons.edit),
                label: Text(l10n.fpkSideEdit),
              ),
          ],
        ),
      ],
    );
  }
}

/// Which thickness of a film an order takes, with what is on hand of each.
Future<Film?> _pickThickness(BuildContext context, List<Film> variants) =>
    showDialog<Film>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SimpleDialog(
          title: Text('${variants.first.colour} · ${l10n.filmThickness}'),
          children: [
            for (final v in variants)
              SimpleDialogOption(
                key: ValueKey('pickThick:${v.item}'),
                onPressed: () => Navigator.of(context).pop(v),
                child: Text(
                  [
                    if (v.thicknessMm != null)
                      '${_metres(v.thicknessMm!)} мм'
                    else
                      l10n.filmThicknessUnknown,
                    if (v.free > 0)
                      l10n.filmHave(_metres(v.free))
                    else
                      l10n.filmToOrder,
                  ].join(' · '),
                ),
              ),
          ],
        );
      },
    );
