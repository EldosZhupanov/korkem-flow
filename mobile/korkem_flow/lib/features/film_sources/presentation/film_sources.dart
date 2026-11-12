import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_sources/data/film_sources_repository.dart';
import 'package:korkem_flow/features/film_sources/domain/film_source.dart';
import 'package:korkem_flow/features/film_sources/domain/film_supplier_board.dart';
import 'package:korkem_flow/features/film_sources/presentation/film_supplier_board_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What a field of a source's card is called.
String filmSourceLabel(AppLocalizations l10n, String key) => switch (key) {
  'kind' => l10n.filmSrcKind,
  'city' => l10n.filmSrcCity,
  'contact' => l10n.filmSrcContact,
  'phone' => l10n.filmSrcPhone,
  'phone2' => l10n.filmSrcPhone2,
  'whatsapp' => l10n.filmSrcWhatsapp,
  'address' => l10n.filmSrcAddress,
  'lead' => l10n.filmSrcLead,
  'min_order' => l10n.filmSrcMinOrder,
  _ => l10n.filmSrcNote,
};

void _refresh(WidgetRef ref, [String? maker]) {
  ref
    ..invalidate(filmSourcesProvider)
    ..invalidate(filmSupplierBoardProvider)
    ..invalidate(filmStockProvider)
    ..invalidate(filmCatalogProvider);
  if (maker != null) ref.invalidate(filmMakerProvider(maker));
}

/// «Поставщики» (owner, 11.11.2026): where film is bought — a maker's
/// branch in each city, a wholesaler — each with its own telephone.
///
/// A board since 12.11.2026 (owner: «какая фирма лучше покупается»): the
/// source whose film sells best first, with what lies on the shelf, what
/// is on its way, and what to order from it.
class FilmSourcesTab extends ConsumerStatefulWidget {
  const FilmSourcesTab({super.key});

  @override
  ConsumerState<FilmSourcesTab> createState() => _FilmSourcesTabState();
}

class _FilmSourcesTabState extends ConsumerState<FilmSourcesTab> {
  /// Ranked by this month, or by all time.
  bool _allTime = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sources = ref.watch(filmSourcesProvider);
    final board = ref.watch(filmSupplierBoardProvider(_allTime));
    void retry() => ref
      ..invalidate(filmSourcesProvider)
      ..invalidate(filmSupplierBoardProvider(_allTime));
    return sources.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: retry),
      data: (s) => board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: retry),
        data: (b) {
          final cards = {for (final src in s.sources) src.id: src};
          // The board's order; a source it does not know yet goes last.
          final rows = [
            ...b.rows,
            for (final src in s.sources)
              if (b.row(src.id) == null)
                FilmSupplierRow(id: src.id, name: src.name, phone: src.phone),
          ];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    key: const ValueKey('filmSup:period'),
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.filmCustomersByMonth),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.filmCustomersByAll),
                      ),
                    ],
                    selected: {_allTime},
                    onSelectionChanged: (v) =>
                        setState(() => _allTime = v.first),
                  ),
                  if (s.canEdit)
                    FilledButton.icon(
                      key: const ValueKey('filmSource:add'),
                      onPressed: () =>
                          showFilmSourceCard(context, makers: s.makers),
                      icon: const Icon(AppIcons.add),
                      label: Text(l10n.filmSourceAdd),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FilmSupplierSummary(board: b),
              const SizedBox(height: AppSpacing.sm),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(l10n.filmSourcesEmpty),
                ),
              for (final (i, r) in rows.indexed)
                FilmSupplierTile(
                  row: r,
                  place: r.soldM > 0 ? i : null,
                  topM: b.topM,
                  source: cards[r.id],
                  onTap: s.canEdit && cards[r.id] != null
                      ? () => showFilmSourceCard(
                          context,
                          source: cards[r.id],
                          makers: s.makers,
                        )
                      : null,
                ),
              if (rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    l10n.filmSupLegend,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One source's row: its name, whom to ring, and whose films it sells.
class FilmSourceTile extends StatelessWidget {
  const FilmSourceTile({required this.source, this.onTap, super.key});

  final FilmSource source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = source;
    final lines = [
      if (s.line.isNotEmpty) s.line,
      if (s.makers.isNotEmpty) s.makers.join(', '),
    ];
    return ListTile(
      key: ValueKey('filmSource:${s.id}'),
      onTap: onTap,
      leading: const Icon(AppIcons.delivery),
      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
      isThreeLine: lines.length > 1,
    );
  }
}

/// A source's card — a new one when [source] is null, with [maker] ticked.
Future<bool?> showFilmSourceCard(
  BuildContext context, {
  required List<String> makers,
  FilmSource? source,
  String? maker,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _SourceDialog(source: source, makers: makers, maker: maker),
);

class _SourceDialog extends ConsumerStatefulWidget {
  const _SourceDialog({required this.makers, this.source, this.maker});

  final FilmSource? source;
  final List<String> makers;
  final String? maker;

  @override
  ConsumerState<_SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends ConsumerState<_SourceDialog> {
  late final _name = TextEditingController(text: widget.source?.name);
  late final Map<String, TextEditingController> _fields = {
    for (final key in FilmSource.cardKeys)
      key: TextEditingController(text: widget.source?.card[key]),
  };
  late final _makers = <String>{...?widget.source?.makers, ?widget.maker};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _refresh(ref, widget.maker);
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

  Future<void> _save() => _run(
    () => ref
        .read(filmSourcesRepositoryProvider)
        .save(
          id: widget.source?.id,
          name: _name.text.trim(),
          card: {for (final e in _fields.entries) e.key: e.value.text.trim()},
          makers: [
            for (final m in widget.makers)
              if (_makers.contains(m)) m,
          ],
        ),
  );

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final yes = await showConfirmDialog(
      context: context,
      title: l10n.filmSourceRemoveAsk(widget.source!.name),
      message: l10n.filmSourceRemoveHint,
      confirmLabel: l10n.filmSourceRemove,
      isDestructive: true,
    );
    if (!yes) return;
    await _run(
      () => ref.read(filmSourcesRepositoryProvider).remove(widget.source!.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.source?.name ?? l10n.filmSourceAdd),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('filmSrc:name'),
                controller: _name,
                autofocus: widget.source == null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.filmSourceName),
              ),
              for (final e in _fields.entries)
                TextField(
                  key: ValueKey('filmSrc:${e.key}'),
                  controller: e.value,
                  keyboardType: e.key.startsWith('phone') || e.key == 'whatsapp'
                      ? TextInputType.phone
                      : TextInputType.text,
                  maxLines: e.key == 'note' ? null : 1,
                  decoration: InputDecoration(
                    labelText: filmSourceLabel(l10n, e.key),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.filmSrcMakers),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in widget.makers)
                    FilterChip(
                      key: ValueKey('filmSrc:maker:$m'),
                      label: Text(m),
                      selected: _makers.contains(m),
                      onSelected: (on) => setState(
                        () => on ? _makers.add(m) : _makers.remove(m),
                      ),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.source != null)
          TextButton(
            key: const ValueKey('filmSrc:remove'),
            onPressed: _busy ? null : _remove,
            child: Text(l10n.filmSourceRemove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmSrc:save'),
          onPressed: _busy || _name.text.trim().length < 2 ? null : _save,
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}

/// A maker's card: its site, a note, and where its film is bought — each
/// place with its telephone, so that when one has no film the next is rung.
Future<void> showFilmMakerCard(BuildContext context, String maker) =>
    showDialog<void>(
      context: context,
      builder: (_) => _MakerDialog(maker: maker),
    );

class _MakerDialog extends ConsumerStatefulWidget {
  const _MakerDialog({required this.maker});

  final String maker;

  @override
  ConsumerState<_MakerDialog> createState() => _MakerDialogState();
}

class _MakerDialogState extends ConsumerState<_MakerDialog> {
  final _site = TextEditingController();
  final _note = TextEditingController();
  bool _filled = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _site.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(filmSourcesRepositoryProvider)
          .setMaker(
            widget.maker,
            site: _site.text.trim(),
            note: _note.text.trim(),
          );
      ref.invalidate(filmMakerProvider(widget.maker));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final card = ref.watch(filmMakerProvider(widget.maker));
    final m = card.value;
    if (m != null && !_filled) {
      _filled = true;
      _site.text = m.site ?? '';
      _note.text = m.note ?? '';
    }
    final makers = ref.watch(filmSourcesProvider).value?.makers;
    return AlertDialog(
      title: Text(widget.maker),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: m == null
            ? card.hasError
                  ? Text('${card.error}')
                  : const Center(
                      heightFactor: 3,
                      child: CircularProgressIndicator(),
                    )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('filmMakerCard:site'),
                      controller: _site,
                      enabled: m.canEdit,
                      decoration: InputDecoration(
                        labelText: l10n.filmMakerSite,
                      ),
                    ),
                    TextField(
                      key: const ValueKey('filmMakerCard:note'),
                      controller: _note,
                      enabled: m.canEdit,
                      maxLines: null,
                      decoration: InputDecoration(labelText: l10n.filmSrcNote),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.filmMakerSources,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (m.sources.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(l10n.filmMakerNoSources),
                      ),
                    for (final s in m.sources)
                      FilmSourceTile(
                        source: s,
                        onTap: m.canEdit && makers != null
                            ? () => showFilmSourceCard(
                                context,
                                source: s,
                                makers: makers,
                                maker: widget.maker,
                              )
                            : null,
                      ),
                    if (m.canEdit && makers != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('filmMakerCard:addSource'),
                          onPressed: () => showFilmSourceCard(
                            context,
                            makers: makers,
                            maker: widget.maker,
                          ),
                          icon: const Icon(AppIcons.add),
                          label: Text(l10n.filmSourceNew),
                        ),
                      ),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.filmClose),
        ),
        if (m?.canEdit ?? false)
          FilledButton(
            key: const ValueKey('filmMakerCard:save'),
            onPressed: _busy ? null : _save,
            child: Text(l10n.filmSave),
          ),
      ],
    );
  }
}

/// Where a film of [maker] is bought, picked from its own window (owner,
/// 11.11.2026): the maker's sources first, then the rest; each opens its
/// card to be changed or removed, and a new one is added already selling
/// [maker]. Tapping a source chooses it — the dialog gives back its id.
Future<String?> showFilmSourcePicker(
  BuildContext context, {
  required String maker,
  String? current,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SourcePickerDialog(maker: maker, current: current),
);

class _SourcePickerDialog extends ConsumerWidget {
  const _SourcePickerDialog({required this.maker, this.current});

  final String maker;
  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sources = ref.watch(filmSourcesProvider);
    final s = sources.value;
    final ordered = s == null
        ? const <FilmSource>[]
        : [
            for (final src in s.sources)
              if (src.makers.contains(maker)) src,
            for (final src in s.sources)
              if (!src.makers.contains(maker)) src,
          ];
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('${l10n.filmSupplier} · $maker')),
          if (s?.canEdit ?? false)
            IconButton(
              key: const ValueKey('filmSourcePick:add'),
              tooltip: l10n.filmSourceAdd,
              onPressed: () => showFilmSourceCard(
                context,
                makers: s!.makers,
                maker: maker,
              ),
              icon: const Icon(AppIcons.add),
            ),
        ],
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        height: AppSpacing.xxxl * 8,
        child: sources.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(filmSourcesProvider),
          ),
          data: (s) => ordered.isEmpty
              ? Center(child: Text(l10n.filmSourcesEmpty))
              : ListView(
                  children: [
                    for (final src in ordered)
                      ListTile(
                        key: ValueKey('filmSourcePick:${src.id}'),
                        dense: true,
                        selected: src.id == current,
                        onTap: () => Navigator.of(context).pop(src.id),
                        title: Text(src.name),
                        subtitle: src.line.isEmpty ? null : Text(src.line),
                        trailing: s.canEdit
                            ? IconButton(
                                key: ValueKey('filmSourcePick:edit:${src.id}'),
                                tooltip: l10n.filmSourceAdd,
                                onPressed: () => showFilmSourceCard(
                                  context,
                                  source: src,
                                  makers: s.makers,
                                ),
                                icon: const Icon(AppIcons.edit),
                              )
                            : null,
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('filmSourcePick:close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.filmClose),
        ),
      ],
    );
  }
}
