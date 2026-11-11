import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/presentation/chat_history.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_composer.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_empty_view.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_message_view.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/speech_dictation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The assistant, and the app's home.
///
/// One conversation column on every window size. The history of conversations
/// opens from this screen's own button — no longer from the sidebar, where it
/// pushed the sections out of view (owner, 11.11.2026).
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

    // История чатов — одна, под кнопкой этого экрана (владелец, 11.11.2026).
    // В боковой панели она занимала всё место и выталкивала разделы вниз.
    final conversation = _ChatConversationView(
      scroll: _scroll,
      dictation: _dictation,
      canScrollToEnd: _canScrollToEnd,
      onScrollToEnd: _scrollToEnd,
      onSend: _send,
    );

    return AppScreen(
      title: assistantName,
      subtitle: isRemote ? null : l10n.chatLocalMode,
      // The history opens here, not in the sidebar (owner, 11.11.2026).
      actions: [
        IconButton(
          key: const ValueKey('chat:history'),
          tooltip: l10n.chatHistory,
          onPressed: () => showChatHistory(context),
          icon: const Icon(AppIcons.schedule),
        ),
      ],
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
