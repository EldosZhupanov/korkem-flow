import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/server_image.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Каталоги поставщиков» (owner, 18.11.2026): each maker's decors with
/// their swatches — a reference, not stock. A decor becomes a film with one
/// button; a film of the same name shows its decor's picture by itself.
class FilmDecorsScreen extends ConsumerStatefulWidget {
  const FilmDecorsScreen({this.maker, this.search, super.key});

  /// The maker to open at; the first one else.
  final String? maker;

  /// What to look for at once — the general search opens a decor this way.
  final String? search;

  @override
  ConsumerState<FilmDecorsScreen> createState() => _FilmDecorsScreenState();
}

class _FilmDecorsScreenState extends ConsumerState<FilmDecorsScreen> {
  late String? _maker = widget.maker;
  String? _collection;
  late String _search = widget.search ?? '';
  bool _busy = false;

  Future<void> _importPack() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final files = await ref
        .read(filmFilePickerProvider)
        .pick(extensions: const ['zip']);
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final got = await ref
          .read(filmDecorRepositoryProvider)
          .importPack(files.first.bytes);
      ref
        ..invalidate(filmDecorsProvider)
        ..invalidate(filmCatalogProvider);
      messenger.showDone(
        l10n.fdcImported('${got['added'] ?? 0}', '${got['updated'] ?? 0}'),
      );
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A folder of pictures named by the films' codes or names: each finds its
  /// film by itself (owner, 18.11.2026: «загрузка папки по кодам»).
  Future<void> _picturesByName() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final files = await ref
        .read(filmFilePickerProvider)
        .pick(extensions: const ['jpg', 'jpeg', 'png', 'webp'], many: true);
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final catalog = await ref.read(filmCatalogRepositoryProvider).catalog();
      final repo = ref.read(filmDecorRepositoryProvider);
      final missed = <String>[];
      var done = 0;
      for (final f in files) {
        final film = filmByFileName(catalog.films, f.name);
        if (film == null) {
          missed.add(f.name);
          continue;
        }
        await repo.setFilmImage(film.item, f);
        done++;
      }
      ref
        ..invalidate(filmCatalogProvider)
        ..invalidate(filmDecorsProvider);
      messenger.showDone(
        missed.isEmpty
            ? l10n.fdcPicturesDone('$done')
            : l10n.fdcPicturesMissed('$done', missed.take(5).join(', ')),
      );
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decors = ref.watch(filmDecorsProvider);
    final canEdit = decors.value?.canEdit ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fdcTitle),
        actions: [
          if (canEdit) ...[
            IconButton(
              key: const ValueKey('fdcPictures'),
              tooltip: l10n.fdcPictures,
              icon: const Icon(AppIcons.gallery),
              onPressed: _busy ? null : () => unawaited(_picturesByName()),
            ),
            IconButton(
              key: const ValueKey('fdcImport'),
              tooltip: l10n.fdcImport,
              icon: const Icon(AppIcons.attachment),
              onPressed: _busy ? null : () => unawaited(_importPack()),
            ),
          ],
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(AppSpacing.xs),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: decors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(filmDecorsProvider),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(FilmDecors d) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (d.makers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.fdcEmpty,
          key: const ValueKey('fdcEmpty'),
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final maker = d.makers.any((m) => m.maker == _maker)
        ? _maker!
        : d.makers.first.maker;
    final collections = d.collectionsOf(maker);
    final collection = collections.contains(_collection) ? _collection : null;
    final shown = [
      for (final x in d.decors)
        if (x.maker == maker &&
            (collection == null || x.collection == collection) &&
            x.matches(_search))
          x,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in d.makers)
                ChoiceChip(
                  key: ValueKey('fdcMaker:${m.maker}'),
                  label: Text('${m.maker} · ${m.count}'),
                  selected: m.maker == maker,
                  onSelected: (_) => setState(() {
                    _maker = m.maker;
                    _collection = null;
                  }),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                key: const ValueKey('fdcCollection:all'),
                label: Text(l10n.filmAllCollections),
                selected: collection == null,
                onSelected: (_) => setState(() => _collection = null),
              ),
              for (final c in collections)
                ChoiceChip(
                  key: ValueKey('fdcCollection:$c'),
                  label: Text(c),
                  selected: c == collection,
                  onSelected: (on) =>
                      setState(() => _collection = on ? c : null),
                ),
              SizedBox(
                width: AppSpacing.xxxl * 6,
                child: TextFormField(
                  key: const ValueKey('fdcSearch'),
                  initialValue: widget.search,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(AppIcons.search),
                    hintText: l10n.fdcSearch,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Text(
            l10n.fdcHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: GridView.extent(
            key: const ValueKey('fdcGrid'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            maxCrossAxisExtent: AppSpacing.xxxl * 6,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.95,
            children: [
              for (final x in shown)
                _DecorCard(
                  decor: x,
                  onTap: () => unawaited(
                    showFilmDecor(context, x, canEdit: d.canEdit),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The film a picture's file name means: its code, else its name; a
/// maker in front («MC Group · сиена верде») is fine too.
Film? filmByFileName(List<Film> films, String fileName) {
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  String key(String? s) => (s ?? '')
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[\s_\-.·]+'), '');
  final k = key(stem);
  if (k.isEmpty) return null;
  return films.where((f) => f.code != null && key(f.code) == k).firstOrNull ??
      films.where((f) => key(f.colour) == k).firstOrNull ??
      films.where((f) => key('${f.maker}${f.colour}') == k).firstOrNull;
}

class _DecorCard extends StatelessWidget {
  const _DecorCard({required this.decor, required this.onTap});

  final FilmDecor decor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = decor;
    final have = d.films.fold<double>(0, (s, f) => s + f.onHand);
    return Card(
      key: ValueKey('fdcDecor:${d.name}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: DecorPicture(decor: d)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    d.collection ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (d.films.isNotEmpty)
                    Text(
                      l10n.fdcYouHave(_m(have)),
                      key: ValueKey('fdcHave:${d.name}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.statusColors.success,
                      ),
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

String _m(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'.replaceAll('.', ',');

/// A decor's swatch; its average colour while it loads or when it cannot.
class DecorPicture extends StatelessWidget {
  const DecorPicture({required this.decor, super.key});

  final FilmDecor decor;

  @override
  Widget build(BuildContext context) {
    final argb = decor.argb;
    final colour = ColoredBox(
      color: argb == null
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Color(argb),
    );
    final path = decor.image;
    return path == null ? colour : ServerImage(path: path, fallback: colour);
  }
}

/// A decor up close: what it is, the films of it the shop has, and — when
/// none — «Завести плёнку».
Future<void> showFilmDecor(
  BuildContext context,
  FilmDecor decor, {
  required bool canEdit,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DecorDialog(decor: decor, canEdit: canEdit),
);

class _DecorDialog extends ConsumerStatefulWidget {
  const _DecorDialog({required this.decor, required this.canEdit});

  final FilmDecor decor;
  final bool canEdit;

  @override
  ConsumerState<_DecorDialog> createState() => _DecorDialogState();
}

class _DecorDialogState extends ConsumerState<_DecorDialog> {
  final _thickness = TextEditingController(text: '0,3');
  final _width = TextEditingController(text: '1400');
  bool _busy = false;

  @override
  void dispose() {
    _thickness.dispose();
    _width.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final film = await ref
          .read(filmDecorRepositoryProvider)
          .fromDecor(
            widget.decor.decor,
            thickness: _thickness.text.trim(),
            width: _width.text.trim(),
          );
      ref
        ..invalidate(filmCatalogProvider)
        ..invalidate(filmDecorsProvider);
      messenger.showDone(l10n.fdcMade(film.label ?? film.colour));
      navigator.pop();
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = widget.decor;
    return AlertDialog(
      title: Text(d.name),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 1.6, child: DecorPicture(decor: d)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                [d.maker, ?d.collection, ?d.code].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
              if (d.thickness != null) Text(l10n.fdcThicknesses(d.thickness!)),
              const SizedBox(height: AppSpacing.sm),
              if (d.films.isNotEmpty) ...[
                Text(l10n.fdcYourFilms, style: theme.textTheme.titleSmall),
                for (final f in d.films)
                  Text(l10n.fdcFilmLine(f.label, _m(f.onHand))),
              ] else if (widget.canEdit) ...[
                Text(l10n.fdcMakeHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('fdcThickness'),
                        controller: _thickness,
                        decoration: InputDecoration(
                          labelText: l10n.filmThickness,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('fdcWidth'),
                        controller: _width,
                        decoration: InputDecoration(
                          labelText: l10n.filmWidth,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
        if (d.films.isEmpty && widget.canEdit)
          FilledButton.icon(
            key: const ValueKey('fdcMake'),
            onPressed: _busy ? null : () => unawaited(_make()),
            icon: const Icon(AppIcons.add),
            label: Text(l10n.fdcMake),
          ),
      ],
    );
  }
}
