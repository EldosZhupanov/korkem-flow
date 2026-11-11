import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A maker's own collections (owner, 11.11.2026) — ALDA, Solid Color,
/// Древесные…: add, rename, remove. A removed collection's films stay in the
/// catalogue, without one.
Future<void> showFilmCollections(BuildContext context, String maker) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CollectionsDialog(maker: maker),
    );

class _CollectionsDialog extends ConsumerStatefulWidget {
  const _CollectionsDialog({required this.maker});

  final String maker;

  @override
  ConsumerState<_CollectionsDialog> createState() => _CollectionsDialogState();
}

class _CollectionsDialogState extends ConsumerState<_CollectionsDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      ref.invalidate(filmCatalogProvider);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, {String initial = ''}) =>
      showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, initial: initial),
      );

  Future<void> _add() async {
    final name = await _ask(AppLocalizations.of(context).filmCollectionAdd);
    if (name == null || name.isEmpty) return;
    await _run(
      () => ref
          .read(filmCatalogRepositoryProvider)
          .addCollection(widget.maker, name),
    );
  }

  Future<void> _rename(String old) async {
    final name = await _ask(
      AppLocalizations.of(context).filmCollectionRename,
      initial: old,
    );
    if (name == null || name.isEmpty || name == old) return;
    await _run(
      () => ref
          .read(filmCatalogRepositoryProvider)
          .renameCollection(widget.maker, old, name),
    );
  }

  Future<void> _remove(String name) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showConfirmDialog(
      context: context,
      title: l10n.filmCollectionRemoveAsk(name),
      message: l10n.filmCollectionRemoveHint,
      confirmLabel: l10n.mdfDictDelete,
      isDestructive: true,
    );
    if (!yes) return;
    await _run(
      () => ref
          .read(filmCatalogRepositoryProvider)
          .removeCollection(widget.maker, name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names =
        ref.watch(filmCatalogProvider).value?.collectionsOf(widget.maker) ??
        const <String>[];
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('${l10n.filmCollections} · ${widget.maker}')),
          IconButton(
            key: const ValueKey('filmCollection:add'),
            tooltip: l10n.filmCollectionAdd,
            onPressed: _busy ? null : _add,
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (names.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(l10n.filmCollectionsEmpty(widget.maker)),
                ),
              for (final name in names)
                ListTile(
                  key: ValueKey('filmCollection:$name'),
                  dense: true,
                  title: Text(name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('filmCollection:edit:$name'),
                        tooltip: l10n.filmCollectionRename,
                        onPressed: _busy ? null : () => _rename(name),
                        icon: const Icon(AppIcons.edit),
                      ),
                      IconButton(
                        key: ValueKey('filmCollection:delete:$name'),
                        tooltip: l10n.mdfDictDelete,
                        onPressed: _busy ? null : () => _remove(name),
                        icon: const Icon(AppIcons.delete),
                      ),
                    ],
                  ),
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
          key: const ValueKey('filmCollection:close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.filmClose),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('filmCollection:name'),
        controller: _name,
        autofocus: true,
        maxLength: 100,
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        decoration: InputDecoration(labelText: l10n.filmCollectionName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmCollection:ok'),
          onPressed: _name.text.trim().length < 2
              ? null
              : () => Navigator.of(context).pop(_name.text.trim()),
          child: Text(l10n.filmSave),
        ),
      ],
    );
  }
}
