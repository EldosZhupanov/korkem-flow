import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/time/clock.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';
import 'package:korkem_flow/features/assistant/domain/thread_groups.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_composer.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_empty_view.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_message_view.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/speech_dictation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The assistant, and the app's home.
///
/// On wide windows, adapts into a two-pane layout: conversation list on the
/// left (grouped by recency) and the active discussion on the right.
/// On compact screens, preserves a single conversation column with access to
/// history via the shell navigation.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  late final SpeechDictation _dictation = SpeechDictation();

  /// Whether the newest turn is off screen above the fold.
  ///
  /// A long answer pushes the end of the conversation out of view, and reading
  /// back up through it is exactly when someone loses the thread — so the way
  /// back down is offered rather than left as a long scroll.
  bool _canScrollToEnd = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Asked once, and the button only appears if the answer is yes. A device
    // with no recogniser, or a user who declines the microphone, is never
    // offered a control that cannot work.
    unawaited(
      _dictation.ensureReady().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    unawaited(_dictation.dispose());
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // A threshold rather than an exact comparison: a couple of points of
    // overscroll bounce should not flash a button in and out.
    final away =
        position.maxScrollExtent - position.pixels > _scrollToEndThreshold;
    if (away != _canScrollToEnd) setState(() => _canScrollToEnd = away);
  }

  Future<void> _send(String text) async {
    await sendMessage(ref, text);
    _scrollToEnd();
  }

  /// Keeps the newest turn in view.
  ///
  /// After the frame, because the message that was just added has not been laid
  /// out yet and `maxScrollExtent` would still describe the old list.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: motionOf(context, AppDuration.standard),
          curve: AppCurves.enter,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRemote = ref.watch(assistantIsRemoteProvider);

    final size = MediaQuery.sizeOf(context);
    final isWide =
        size.width >= AppBreakpoints.medium &&
        size.height >= AppBreakpoints.compact;

    final conversation = _ChatConversationView(
      scroll: _scroll,
      dictation: _dictation,
      canScrollToEnd: _canScrollToEnd,
      onScrollToEnd: _scrollToEnd,
      onSend: _send,
    );

    if (isWide) {
      return AppScreen(
        title: assistantName,
        subtitle: isRemote ? null : l10n.chatLocalMode,
        fullWidth: true,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: AppBreakpoints.listPaneWidth,
              child: _ThreadListPane(
                onSelectThread: (id) {
                  ref.read(threadsControllerProvider.notifier).open(id);
                  _scrollToEnd();
                },
                onNewThread: () {
                  ref.read(threadsControllerProvider.notifier).startNew();
                },
              ),
            ),
            const VerticalDivider(
              width: AppStroke.hairline,
              thickness: AppStroke.hairline,
            ),
            Expanded(child: conversation),
          ],
        ),
      );
    }

    return AppScreen(
      title: assistantName,
      subtitle: isRemote ? null : l10n.chatLocalMode,
      body: conversation,
    );
  }
}

class _ChatConversationView extends ConsumerWidget {
  const _ChatConversationView({
    required this.scroll,
    required this.dictation,
    required this.canScrollToEnd,
    required this.onScrollToEnd,
    required this.onSend,
  });

  final ScrollController scroll;
  final SpeechDictation dictation;
  final bool canScrollToEnd;
  final VoidCallback onScrollToEnd;
  final Future<void> Function(String) onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(activeThreadProvider);
    final busy = ref.watch(assistantBusyProvider);
    final activity = ref.watch(assistantActivityProvider);
    final pending = ref.watch(pendingConfirmationProvider);
    final messages = thread?.messages ?? const [];

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (messages.isEmpty)
                ChatEmptyView(onSuggestion: onSend)
              else
                ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  itemCount:
                      messages.length +
                      (busy ? 1 : 0) +
                      (pending != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return ChatMessageView(message: messages[index]);
                    }
                    if (pending != null && index == messages.length) {
                      return ConfirmationCard(request: pending);
                    }
                    return ChatTypingIndicator(activity: activity);
                  },
                ),
              PositionedDirectional(
                end: AppSpacing.lg,
                bottom: AppSpacing.md,
                child: _ScrollToEndButton(
                  visible: canScrollToEnd,
                  onPressed: onScrollToEnd,
                ),
              ),
            ],
          ),
        ),
        ChatComposer(
          onSend: onSend,
          enabled: !busy,
          // Всегда, а не только когда платформа уже сказала «умею».
          // Готовность выясняется по нажатию: до него спросить разрешение
          // не у кого, и кнопка не появлялась бы никогда.
          dictation: dictation,
        ),
      ],
    );
  }
}

class _ThreadListPane extends ConsumerWidget {
  const _ThreadListPane({
    required this.onSelectThread,
    required this.onNewThread,
  });

  final ValueChanged<String> onSelectThread;
  final VoidCallback onNewThread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final threads = ref.watch(threadsControllerProvider);
    final activeId = ref.watch(activeThreadProvider)?.id;
    final clock = ref.watch(clockProvider)();
    final groups = groupThreads(threads, clock);
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: FilledButton.tonalIcon(
            onPressed: onNewThread,
            icon: const Icon(AppIcons.add, size: AppIconSize.small),
            label: Text(l10n.chatNew),
          ),
        ),
        if (threads.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EmptyView(
                  icon: AppIcons.conversation,
                  title: l10n.chatEmptyThreads,
                  message: l10n.chatEmptyThreadsBody,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.xs,
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
                      thread: thread,
                      timeLabel: _formatThreadTime(
                        thread.updatedAt,
                        clock,
                        locale,
                      ),
                      selected: thread.id == activeId,
                      onTap: () => onSelectThread(thread.id),
                      onRename: () => _rename(context, ref, thread),
                      onDelete: () => _delete(context, ref, thread),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _bandLabel(ThreadBand band, AppLocalizations l10n) => switch (band) {
    ThreadBand.today => l10n.chatToday,
    ThreadBand.yesterday => l10n.chatYesterday,
    ThreadBand.earlier => l10n.chatEarlier,
  };

  String _formatThreadTime(DateTime dt, DateTime now, String locale) {
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat.Hm(locale).format(dt);
    }
    if (dt.year == now.year) {
      return DateFormat.MMMd(locale).format(dt);
    }
    return DateFormat.yMMMd(locale).format(dt);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ChatThread thread,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameDialog(initial: thread.title),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteBody(thread.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.chatDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      ref.read(threadsControllerProvider.notifier).delete(thread.id);
    }
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.timeLabel,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final ChatThread thread;
  final String timeLabel;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.secondaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      thread.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: selected ? FontWeight.bold : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      timeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _ThreadMenu(
                title: thread.title,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.chatRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.chatRename),
        ),
      ],
    );
  }
}

/// The way back to the newest turn.
///
/// Absent, not disabled, when the conversation is already at the end — there is
/// nothing to return to, and a permanently visible control over the transcript
/// would be one more thing between the reader and the words.
class _ScrollToEndButton extends StatelessWidget {
  const _ScrollToEndButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedSwitcher(
      duration: motionOf(context, AppDuration.quick),
      switchInCurve: AppCurves.enter,
      switchOutCurve: AppCurves.exit,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: !visible
          ? const SizedBox.shrink()
          : Semantics(
              button: true,
              label: l10n.chatScrollToEnd,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: l10n.chatScrollToEnd,
                onPressed: onPressed,
                child: const Icon(AppIcons.down),
              ),
            ),
    );
  }
}

/// How far from the end counts as "away from it".
///
/// Roughly one turn: below this the newest message is still on screen and the
/// button would be offering to do nothing.
const double _scrollToEndThreshold = 240;
