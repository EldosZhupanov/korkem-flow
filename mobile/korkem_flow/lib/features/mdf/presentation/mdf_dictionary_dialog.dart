import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// OnayBaza's blue button: one list, with add, rename and delete. Tapping a
/// value chooses it — the dialog returns it; closing returns null.
Future<String?> showMdfDictionary(
  BuildContext context,
  MdfDictKind kind, {
  required String title,
  String? current,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      MdfDictionaryDialog(kind: kind, title: title, current: current),
);

class MdfDictionaryDialog extends ConsumerStatefulWidget {
  const MdfDictionaryDialog({
    required this.kind,
    required this.title,
    this.current,
    super.key,
  });

  final MdfDictKind kind;
  final String title;
  final String? current;

  @override
  ConsumerState<MdfDictionaryDialog> createState() =>
      _MdfDictionaryDialogState();
}

class _MdfDictionaryDialogState extends ConsumerState<MdfDictionaryDialog> {
  bool _busy = false;

  /// The colour systems opened (owner, 15.11.2026: «NCS, RAL должны
  /// свернуться, и дальше нам должен открываться список»). The one the
  /// current colour is in opens by itself; a search opens all it finds.
  final _open = <String>{};
  bool _seeded = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<MdfDictionaries> Function() call) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await call();
      ref.invalidate(mdfDictionariesProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, {String initial = ''}) => showDialog(
    context: context,
    builder: (_) => _ValueDialog(title: title, initial: initial),
  );

  /// [group]: a milling variant under it (owner, 14.11.2026), or a colour
  /// under its system (15.11.2026). On the paint list without a group, the
  /// title's «+» adds a colour system.
  Future<void> _add({String? group}) async {
    final l10n = AppLocalizations.of(context);
    final value = await _ask(
      group == null
          ? (_millings
                ? l10n.mdfDictAddGroup
                : _paints
                ? l10n.mdfPaintAddSystem
                : l10n.mdfDictAdd)
          : (_paints
                ? l10n.mdfPaintAddColour(group)
                : l10n.mdfDictAddVariant(group)),
    );
    if (value == null || value.trim().isEmpty) return;
    final kind = _paints && group == null
        ? MdfDictKind.paintSystem
        : widget.kind;
    // The new colour is seen where it went.
    if (_paints && group != null) setState(() => _open.add(group));
    await _run(
      () => ref
          .read(mdfOrderRepositoryProvider)
          .dictionaryAdd(kind, value.trim(), group: group),
    );
  }

  bool get _millings => widget.kind == MdfDictKind.milling;
  bool get _paints => widget.kind == MdfDictKind.paint;

  /// One value: tap chooses it; edit and delete beside it. A colour
  /// system ([system]) is a heading: it is not chosen, its own list is the
  /// one renamed and deleted from.
  Widget _entry(
    MdfDictEntry e, {
    bool variant = false,
    String? group,
    bool system = false,
    int? count,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = system ? MdfDictKind.paintSystem : widget.kind;
    return ListTile(
      key: ValueKey('dictEntry:${system ? 'system:' : ''}${e.value}'),
      dense: true,
      contentPadding: EdgeInsetsDirectional.only(
        start: variant ? AppSpacing.xl : AppSpacing.md,
        end: AppSpacing.sm,
      ),
      selected: !system && e.value == widget.current,
      leading: system ? _chevron(e.value) : null,
      title: Text(
        system && count != null ? '${e.value} · $count' : e.value,
        style: variant || !(_millings || system)
            ? null
            : theme.textTheme.titleSmall,
      ),
      onTap: system
          ? () => _toggle(e.value)
          : () => Navigator.of(context).pop(e.value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (group != null)
            IconButton(
              key: ValueKey('dictAddVariant:${e.value}'),
              tooltip: system
                  ? l10n.mdfPaintAddColour(group)
                  : l10n.mdfDictAddVariant(group),
              onPressed: _busy ? null : () => _add(group: group),
              icon: const Icon(AppIcons.add),
            ),
          IconButton(
            key: ValueKey('dictEdit:${e.value}'),
            tooltip: l10n.mdfDictRename,
            onPressed: _busy ? null : () => _rename(e, kind),
            icon: const Icon(AppIcons.edit),
          ),
          IconButton(
            key: ValueKey('dictDelete:${e.value}'),
            tooltip: l10n.mdfDictDelete,
            onPressed: _busy ? null : () => _delete(e, kind),
            icon: const Icon(AppIcons.delete),
          ),
        ],
      ),
    );
  }

  Widget _chevron(String group) => Icon(
    _open.contains(group) ? AppIcons.collapse : AppIcons.expand,
    key: ValueKey('dictFold:$group'),
  );

  void _toggle(String group) => setState(
    () => _open.contains(group) ? _open.remove(group) : _open.add(group),
  );

  /// Colour systems, each folded until opened; a search shows every colour
  /// it finds, under its system.
  Widget _paintList(MdfDictionaries d) {
    final l10n = AppLocalizations.of(context);
    final groups = d.paintGroups();
    if (!_seeded) {
      _seeded = true;
      for (final g in groups) {
        if (g.colours.any((c) => c.value == widget.current)) _open.add(g.name);
      }
    }
    final query = _search.text.trim().toLowerCase();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            key: const ValueKey('dictSearch'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(AppIcons.search),
              hintText: l10n.mdfPaintSearch,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final g in groups)
                if (query.isEmpty ||
                    g.colours.any(
                      (c) => c.value.toLowerCase().contains(query),
                    )) ...[
                  if (g.head case final head?)
                    _entry(
                      head,
                      group: g.name,
                      system: true,
                      count: g.colours.length,
                    )
                  else
                    ListTile(
                      key: ValueKey('dictEntry:system:${g.name}'),
                      dense: true,
                      leading: _chevron(g.name),
                      onTap: () => _toggle(g.name),
                      title: Text(
                        '${g.name.isEmpty ? l10n.mdfPaintNoSystem : g.name}'
                        ' · ${g.colours.length}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  if (query.isNotEmpty || _open.contains(g.name))
                    for (final c in g.colours)
                      if (query.isEmpty ||
                          c.value.toLowerCase().contains(query))
                        _entry(c, variant: true),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _rename(MdfDictEntry e, MdfDictKind kind) async {
    final l10n = AppLocalizations.of(context);
    final value = await _ask(l10n.mdfDictRename, initial: e.value);
    if (value == null || value.trim().isEmpty || value.trim() == e.value) {
      return;
    }
    await _run(
      () => ref
          .read(mdfOrderRepositoryProvider)
          .dictionaryRename(kind, e.id, value.trim()),
    );
  }

  Future<void> _delete(MdfDictEntry e, MdfDictKind kind) async {
    final l10n = AppLocalizations.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.mdfDictDeleteAsk(e.value)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('dictDeleteYes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mdfDictDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _run(
      () => ref.read(mdfOrderRepositoryProvider).dictionaryRemove(kind, e.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dicts = ref.watch(mdfDictionariesProvider);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          IconButton(
            key: const ValueKey('dictAdd'),
            tooltip: _millings
                ? l10n.mdfDictAddGroup
                : _paints
                ? l10n.mdfPaintAddSystem
                : l10n.mdfDictAdd,
            onPressed: _busy ? null : _add,
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        height: AppSpacing.xxxl * 8,
        child: dicts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(mdfDictionariesProvider),
          ),
          data: (d) {
            final entries = d.entries(widget.kind);
            // R0 and R3 are always there and stay (09.11.2026).
            final locked = widget.kind == MdfDictKind.edge
                ? mdfStandardEdges
                : const <String>[];
            final standing = [
              for (final v in locked)
                if (!entries.any((e) => e.value == v)) v,
            ];
            // Paints by colour system (owner, 15.11.2026): RAL Classic —
            // RAL 9010, RAL 7016 …; NCS — …; the unfiled ones last.
            if (_paints && d.entries(MdfDictKind.paintSystem).isNotEmpty) {
              return _paintList(d);
            }
            if (entries.isEmpty && standing.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l10n.mdfDictEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            Widget lock(String value) => ListTile(
              key: ValueKey('dictEntry:$value'),
              dense: true,
              selected: value == widget.current,
              title: Text(value),
              onTap: () => Navigator.of(context).pop(value),
              trailing: Tooltip(
                message: l10n.mdfDictLocked,
                child: Icon(
                  AppIcons.noAccess,
                  key: ValueKey('dictLocked:$value'),
                ),
              ),
            );
            // Millings by group, each with its variants under it
            // (owner, 14.11.2026: «Рифлёный — 16-14, 6-14, 6-11»).
            if (_millings) {
              return ListView(
                children: [
                  for (final g in d.millingGroups()) ...[
                    if (g.head case final head?)
                      _entry(head, group: g.name)
                    else
                      ListTile(
                        dense: true,
                        title: Text(
                          g.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    for (final v in g.variants) _entry(v, variant: true),
                  ],
                ],
              );
            }
            return ListView(
              children: [
                for (final v in standing) lock(v),
                for (final e in entries)
                  if (locked.contains(e.value)) lock(e.value) else _entry(e),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

class _ValueDialog extends StatefulWidget {
  const _ValueDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('dictValue'),
        controller: _c,
        autofocus: true,
        maxLength: 140,
        decoration: InputDecoration(labelText: l10n.mdfDictValue),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('dictSave'),
          onPressed: () => Navigator.of(context).pop(_c.text),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
