import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';
import 'package:korkem_flow/features/assistant/domain/thread_groups.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The history of conversations, opened from the assistant's own screen
/// (owner, 11.11.2026: in the sidebar it took the whole panel and pushed
/// the sections — Главная, Продажи, МДФ — out of view, on every screen,
/// though it is wanted only here).
///
/// Small talk — a lone «привет» — is left out of the list: it is not a
/// conversation anyone comes back to. It is hidden, not deleted.
Future<void> showChatHistory(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const ChatHistoryDialog(),
);

/// Words that alone make no conversation worth keeping in the list.
const _smallTalk = {
  'привет',
  'здравствуй',
  'здравствуйте',
  'салам',
  'сәлем',
  'салем',
  'hi',
  'hello',
  'hey',
  'ок',
  'ok',
  'спасибо',
  'рахмет',
  'тест',
  'test',
};

/// Whether [thread] is only a greeting: not renamed, one or two messages,
/// and what was said is a greeting and nothing else.
bool isSmallTalk(ChatThread thread) {
  if ((thread.name ?? '').trim().isNotEmpty || thread.messages.length > 2) {
    return false;
  }
  final said = thread.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '')
      .trim();
  return said.isEmpty || _smallTalk.contains(said);
}

class ChatHistoryDialog extends ConsumerWidget {
  const ChatHistoryDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final groups = groupThreads(
      [
        for (final t in ref.watch(threadsControllerProvider))
          if (!isSmallTalk(t)) t,
      ],
      ref.watch(clockProvider)(),
    );
    final activeId = ref.watch(activeThreadProvider)?.id;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.chatHistory)),
          IconButton(
            key: const ValueKey('chatHistory:new'),
            tooltip: l10n.chatNew,
            onPressed: () {
              ref.read(threadsControllerProvider.notifier).startNew();
              Navigator.of(context).pop();
            },
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        height: AppSpacing.xxxl * 9,
        child: groups.isEmpty
            ? Center(child: Text(l10n.chatHistoryEmpty))
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                children: [
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xxs,
                      ),
                      child: Text(
                        _bandLabel(group.band, l10n),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final thread in group.threads)
                      _ThreadTile(
                        key: ValueKey('chatThread:${thread.id}'),
                        title: thread.title,
                        selected: thread.id == activeId,
                        onTap: () {
                          ref
                              .read(threadsControllerProvider.notifier)
                              .open(thread.id);
                          Navigator.of(context).pop();
                        },
                        onRename: () => _rename(context, ref, thread),
                        onDelete: () => _delete(context, ref, thread),
                      ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('chatHistory:close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ChatThread thread,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: thread.title),
    );
    if (name == null) return;
    ref.read(threadsControllerProvider.notifier).rename(thread.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ChatThread thread,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Confirmed, because this is the one control in the list that destroys
    // something, and it sits a few points from the row that merely opens it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteBody(thread.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.chatDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      ref.read(threadsControllerProvider.notifier).delete(thread.id);
    }
  }

  String _bandLabel(ThreadBand band, AppLocalizations l10n) => switch (band) {
    ThreadBand.today => l10n.chatToday,
    ThreadBand.yesterday => l10n.chatYesterday,
    ThreadBand.earlier => l10n.chatEarlier,
  };
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final String title;

  /// The conversation currently open. Marked, because with history this close
  /// to the top it is otherwise impossible to tell which row you are reading.
  final bool selected;

  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: AppTint.surfaceFaint)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // A menu rather than a swipe or a long press: both of those are
              // invisible, and a conversation someone cannot find how to
              // delete is a conversation they cannot delete.
              _ThreadMenu(
                title: title,
                onRename: onRename,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rename and delete, behind one discreet button per row.
///
/// `PopupMenuButton` rather than a `Dismissible` or a long press: a swipe is
/// undiscoverable and a long press is worse on a panel people are scanning, and
/// a conversation nobody can work out how to delete is a conversation they
/// cannot delete.
class _ThreadMenu extends StatelessWidget {
  const _ThreadMenu({
    required this.title,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      tooltip: title,
      icon: Icon(
        AppIcons.more,
        size: AppIconSize.small,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: onRename,
          child: Row(
            children: [
              const Icon(AppIcons.edit, size: AppIconSize.small),
              const SizedBox(width: AppSpacing.md),
              Text(l10n.chatRename),
            ],
          ),
        ),
        PopupMenuItem(
          value: onDelete,
          child: Row(
            children: [
              Icon(
                AppIcons.delete,
                size: AppIconSize.small,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                l10n.chatDelete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asks for a new name, pre-filled with the current one and fully selected, so
/// typing replaces it and the common case is one gesture.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.chatRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.chatRename)),
      ],
    );
  }
}
