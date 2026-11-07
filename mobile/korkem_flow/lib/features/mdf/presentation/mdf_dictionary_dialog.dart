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

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final value = await _ask(l10n.mdfDictAdd);
    if (value == null || value.trim().isEmpty) return;
    await _run(
      () => ref
          .read(mdfOrderRepositoryProvider)
          .dictionaryAdd(widget.kind, value.trim()),
    );
  }

  Future<void> _rename(MdfDictEntry e) async {
    final l10n = AppLocalizations.of(context);
    final value = await _ask(l10n.mdfDictRename, initial: e.value);
    if (value == null || value.trim().isEmpty || value.trim() == e.value) {
      return;
    }
    await _run(
      () => ref
          .read(mdfOrderRepositoryProvider)
          .dictionaryRename(widget.kind, e.id, value.trim()),
    );
  }

  Future<void> _delete(MdfDictEntry e) async {
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
      () => ref
          .read(mdfOrderRepositoryProvider)
          .dictionaryRemove(widget.kind, e.id),
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
            tooltip: l10n.mdfDictAdd,
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
            if (entries.isEmpty) {
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
            return ListView(
              children: [
                for (final e in entries)
                  ListTile(
                    key: ValueKey('dictEntry:${e.value}'),
                    dense: true,
                    selected: e.value == widget.current,
                    title: Text(e.value),
                    onTap: () => Navigator.of(context).pop(e.value),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey('dictEdit:${e.value}'),
                          tooltip: l10n.mdfDictRename,
                          onPressed: _busy ? null : () => _rename(e),
                          icon: const Icon(AppIcons.edit),
                        ),
                        IconButton(
                          key: ValueKey('dictDelete:${e.value}'),
                          tooltip: l10n.mdfDictDelete,
                          onPressed: _busy ? null : () => _delete(e),
                          icon: const Icon(AppIcons.delete),
                        ),
                      ],
                    ),
                  ),
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
