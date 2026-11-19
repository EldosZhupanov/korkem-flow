import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_decors_screen.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/domain/film_orders.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_screen.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_orders_page.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Приход» (owner, 19.11.2026: «он мне чё-то не нравится»): what is waited
/// for first — rolls on their way and what was ordered from each supplier,
/// one tap each — then any film by search, the makers' catalogues with it.
/// Gives true when something came in.
///
/// Its parts fold (owner, 19.11.2026: «чтобы приход плёнки могли мы
/// свернуть»), and the makers' catalogues are named under the search, to
/// be opened without typing («а где там название каталогов?»).
Future<bool?> showFilmReceiveStart(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (_) => const _ReceiveStart(),
);

class _ReceiveStart extends ConsumerStatefulWidget {
  const _ReceiveStart();

  @override
  ConsumerState<_ReceiveStart> createState() => _ReceiveStartState();
}

class _ReceiveStartState extends ConsumerState<_ReceiveStart> {
  String _search = '';
  bool _busy = false;
  bool _done = false;

  /// «Ждём» shown; folded once a film is looked for.
  bool _waitOpen = true;

  /// Suppliers whose «Заказано у …» is folded.
  final _folded = <String>{};

  /// The maker whose films and catalogue are open, and its collection.
  String? _maker;
  String? _collection;

  /// How many catalogue decors are shown at once.
  static const _decorsShown = 60;

  static String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  bool _found(List<String?> parts) {
    final q = _norm(_search.trim());
    if (q.isEmpty) return true;
    final hay = _norm(parts.whereType<String>().join(' '));
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  void _refresh() {
    _done = true;
    ref
      ..invalidate(filmStockProvider)
      ..invalidate(filmWantedProvider)
      ..invalidate(filmCatalogProvider);
  }

  Future<void> _run(Future<bool?> Function() step) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (await step() ?? false) _refresh();
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A roll on its way is here — all of it or fewer metres.
  Future<void> _arrived(FilmComing c) => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final metres = await showFilmArrived(context, c);
    if (metres == null) return false;
    await ref.read(filmDeptRepositoryProvider).arrived(c.entry, metres: metres);
    final rest = c.metres - metres;
    messenger.showDone(
      rest > 0.005
          ? l10n.filmReceiveRestComing(filmMetres(rest))
          : l10n.filmReceiveDone,
    );
    return true;
  });

  /// What was ordered from a supplier came — all of [films], or one.
  Future<void> _delivered(
    FilmCatalog c,
    FilmWantGroup g,
    List<List<FilmWant>> films,
  ) => _run(() {
    final l10n = AppLocalizations.of(context);
    return showFilmDelivery(
      context,
      c,
      supplier: g.supplier,
      supplierName: g.name,
      wants: [
        for (final f in films)
          (
            item: f.first.item,
            metres: f.fold<double>(0, (sum, l) => sum + l.metres),
            customer: null,
            customerName: filmForWhom(l10n, f),
            orders: [for (final l in f) ?l.id],
          ),
      ],
    );
  });

  Future<void> _film(FilmCatalog c, Film f) =>
      _run(() => showFilmReceive(context, f, c));

  /// A catalogue decor not on the books yet: taken in, then received.
  Future<void> _decor(FilmDecor d) => _run(() async {
    final label = await ref
        .read(filmDecorRepositoryProvider)
        .takeDecor(
          d.decor,
        );
    ref.invalidate(filmStockProvider);
    final c = await ref.read(filmStockProvider.future);
    final film = c.films.where((f) => f.label == label).firstOrNull;
    if (film == null || !mounted) return true;
    return showFilmReceive(context, film, c);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final screen = MediaQuery.sizeOf(context);
    final label = theme.textTheme.labelLarge;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final c = ref.watch(filmStockProvider).value;
    final wanted = ref.watch(filmWantedProvider).value;
    final decors =
        ref.watch(filmPickExtrasProvider(null)).value?.decors ?? const [];
    Widget body;
    if (c == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final coming = [
        for (final f in c.films)
          for (final w in f.coming) (f, w),
      ]..sort((a, b) => a.$2.due.compareTo(b.$2.due));
      final ordered = [
        for (final g in wanted?.groups ?? const <FilmWantGroup>[])
          if (g.sent.isNotEmpty) g,
      ];
      final typed = _search.trim();
      final maker = _maker;
      // The makers: ours and those known by their catalogue alone.
      final makers = {
        for (final f in c.films)
          if (f.enabled) f.maker,
        for (final d in decors) d.maker,
      }.where((m) => m.isNotEmpty).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final looking = typed.isNotEmpty || maker != null;
      final films = !looking
          ? const <List<Film>>[]
          : [
              for (final g in FilmCatalog.grouped([
                for (final f in c.films)
                  if (f.enabled && (maker == null || f.maker == maker)) f,
              ]))
                if (_found([
                  g.first.maker,
                  g.first.colour,
                  g.first.code,
                  g.first.collection,
                ]))
                  g,
            ];
      final known = {for (final f in c.films) _norm('${f.maker} ${f.colour}')};
      final ofMaker = [
        for (final d in decors)
          if (d.maker == maker) d,
      ];
      final collections = {
        for (final d in ofMaker) ?d.collection,
      }.toList()..sort();
      final catalogue = maker == null && typed.length < 2
          ? const <FilmDecor>[]
          : [
              for (final d in maker == null ? decors : ofMaker)
                if (!known.contains(_norm('${d.maker} ${d.name}')) &&
                    (_collection == null || d.collection == _collection) &&
                    _found([d.maker, d.name, d.code, d.collection]))
                  d,
            ];
      final fromCatalog = catalogue.take(_decorsShown).toList();
      final waitCount =
          coming.length +
          ordered.fold<int>(0, (n, g) => n + FilmWantGroup.byFilm(g.sent).length);
      body = ListView(
        children: [
          _Fold(
            key: const ValueKey('rcvWaitFold'),
            title: waitCount > 0
                ? '${l10n.filmReceiveWaiting} · $waitCount'
                : l10n.filmReceiveWaiting,
            style: label,
            open: _waitOpen,
            onTap: () => setState(() => _waitOpen = !_waitOpen),
          ),
          if (_waitOpen && coming.isEmpty && ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(l10n.filmReceiveNothingWaited, style: muted),
            ),
          if (_waitOpen)
          for (final (f, w) in coming)
            ListTile(
              key: ValueKey('rcvComing:${w.entry}'),
              contentPadding: EdgeInsets.zero,
              leading: FilmSample(argb: f.argb, image: f.image),
              title: Text('${f.maker} · ${filmTitle(f.colour, f.code)}'),
              subtitle: Text(
                [
                  filmComingLine(w, l10n),
                  ?w.supplier,
                ].join(' · '),
                style: TextStyle(
                  color: w.lateDays > 0 ? status.danger : null,
                ),
              ),
              trailing: FilledButton.tonal(
                key: ValueKey('rcvArrived:${w.entry}'),
                onPressed: _busy ? null : () => _arrived(w),
                child: Text(l10n.filmComingArrived),
              ),
            ),
          if (_waitOpen)
          for (final g in ordered) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _Fold(
                    key: ValueKey('rcvGroupFold:${g.supplier ?? '-'}'),
                    title:
                        '${l10n.filmReceiveOrderedFrom(g.name)} · '
                        '${FilmWantGroup.byFilm(g.sent).length}',
                    style: theme.textTheme.titleSmall,
                    open: !_folded.contains(g.supplier ?? '-'),
                    onTap: () => setState(() {
                      final k = g.supplier ?? '-';
                      if (!_folded.remove(k)) _folded.add(k);
                    }),
                  ),
                ),
                if (FilmWantGroup.byFilm(g.sent).length > 1)
                  TextButton(
                    key: ValueKey('rcvSupplier:${g.supplier ?? '-'}'),
                    onPressed: _busy
                        ? null
                        : () => _delivered(c, g, FilmWantGroup.byFilm(g.sent)),
                    child: Text(l10n.filmReceiveAllCame),
                  ),
              ],
            ),
            if (!_folded.contains(g.supplier ?? '-'))
            for (final lines in FilmWantGroup.byFilm(g.sent))
              ListTile(
                key: ValueKey('rcvOrdered:${lines.first.item}'),
                contentPadding: EdgeInsets.zero,
                leading: switch (c.film(lines.first.item)) {
                  final f? => FilmSample(argb: f.argb, image: f.image),
                  null => const Icon(AppIcons.material),
                },
                title: Text(lines.first.title),
                subtitle: Text(
                  [
                    l10n.filmReceiveMetres(
                      filmMetres(
                        lines.fold<double>(0, (s, l) => s + l.metres),
                      ),
                    ),
                    ?filmForWhom(l10n, lines),
                  ].join(' · '),
                ),
                trailing: FilledButton.tonal(
                  key: ValueKey('rcvCame:${lines.first.item}'),
                  onPressed: _busy ? null : () => _delivered(c, g, [lines]),
                  child: Text(l10n.filmComingArrived),
                ),
              ),
          ],
          const Divider(),
          Text(l10n.filmReceiveOther, style: label),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const ValueKey('rcvSearch'),
            onChanged: (v) => setState(() {
              // Looking for a film: «Ждём» makes room for it.
              if (_search.trim().isEmpty && v.trim().isNotEmpty) {
                _waitOpen = false;
              }
              _search = v;
            }),
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.search),
              hintText: l10n.filmReceiveSearch,
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // The makers' catalogues by name: one tap opens a maker's films
          // and the decors of its catalogue not on the books yet.
          Text(l10n.filmReceiveCatalogues, style: muted),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in makers)
                ChoiceChip(
                  key: ValueKey('rcvMaker:$m'),
                  label: Text(m),
                  selected: m == maker,
                  onSelected: (on) => setState(() {
                    _maker = on ? m : null;
                    _collection = null;
                    if (on) _waitOpen = false;
                  }),
                ),
            ],
          ),
          if (maker != null && collections.length > 1) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  key: const ValueKey('rcvCollection:-'),
                  label: Text(l10n.filmAllCollections),
                  selected: _collection == null,
                  onSelected: (_) => setState(() => _collection = null),
                ),
                for (final col in collections)
                  ChoiceChip(
                    key: ValueKey('rcvCollection:$col'),
                    label: Text(col),
                    selected: _collection == col,
                    onSelected: (on) =>
                        setState(() => _collection = on ? col : null),
                  ),
              ],
            ),
          ],
          if (films.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.filmOurs('${films.length}'),
              key: const ValueKey('rcvOurs'),
              style: label,
            ),
          ],
          for (final g in films)
            FilmTile(
              film: g.first,
              variants: g,
              onTap: _busy
                  ? null
                  : () async {
                      final f = g.length == 1
                          ? g.single
                          : await showDialog<Film>(
                              context: context,
                              builder: (context) => SimpleDialog(
                                title: Text(l10n.filmThickness),
                                children: [
                                  for (final v in g)
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.of(context).pop(v),
                                      child: Text(
                                        switch (v.thicknessMm) {
                                          final t? => '${filmMetres(t)} мм',
                                          null => l10n.filmThicknessUnknown,
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            );
                      if (f != null) await _film(c, f);
                    },
            ),
          if (fromCatalog.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              maker == null
                  ? l10n.filmReceiveCatalogFound(catalogue.length)
                  : l10n.filmReceiveCatalogOf(maker, catalogue.length),
              key: const ValueKey('rcvCatalogHead'),
              style: label,
            ),
            const SizedBox(height: AppSpacing.xs),
            GridView.builder(
              key: const ValueKey('rcvCatalog'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: AppSpacing.xxxl * 3,
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 0.85,
              ),
              itemCount: fromCatalog.length,
              itemBuilder: (context, i) => DecorCard(
                key: ValueKey('rcvDecor:${fromCatalog[i].decor}'),
                decor: fromCatalog[i],
                onTap: _busy ? () {} : () => _decor(fromCatalog[i]),
              ),
            ),
            if (catalogue.length > fromCatalog.length)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  l10n.filmReceiveCatalogMore(
                    catalogue.length - fromCatalog.length,
                  ),
                  style: muted,
                ),
              ),
          ],
          if (looking && films.isEmpty && fromCatalog.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(l10n.fpkNothing, style: muted),
            ),
        ],
      );
    }
    return AlertDialog(
      key: const ValueKey('filmReceiveStart'),
      title: Text(l10n.filmReceiveTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 14 < screen.width * 0.9
            ? AppSpacing.xxxl * 14
            : screen.width * 0.9,
        height: AppSpacing.xxxl * 13 < screen.height * 0.7
            ? AppSpacing.xxxl * 13
            : screen.height * 0.7,
        child: body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_done),
          child: Text(l10n.mdfCancel),
        ),
      ],
    );
  }
}

/// A heading that folds what is under it: a tap opens or shuts it.
class _Fold extends StatelessWidget {
  const _Fold({
    required this.title,
    required this.open,
    required this.onTap,
    this.style,
    super.key,
  });

  final String title;
  final bool open;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(open ? AppIcons.collapse : AppIcons.expand),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(title, style: style)),
        ],
      ),
    ),
  );
}
