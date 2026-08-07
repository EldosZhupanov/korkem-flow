import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_composer.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_empty_view.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_message_view.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/speech_dictation.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The assistant, and the app's home.
///
/// It is deliberately the plainest screen in the product: a column of turns and
/// somewhere to type. Everything that makes an AI tool feel capable is in what
/// it says and how quickly, not in chrome around the conversation.
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
    final thread = ref.watch(activeThreadProvider);
    final busy = ref.watch(assistantBusyProvider);
    final activity = ref.watch(assistantActivityProvider);
    final messages = thread?.messages ?? const [];

    return AppScreen(
      title: assistantName,
      // Says plainly that there is no language model behind this. A demo that
      // does not admit to being one is not a demo.
      subtitle: l10n.chatLocalMode,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (messages.isEmpty)
                  ChatEmptyView(onSuggestion: _send)
                else
                  ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    itemCount: messages.length + (busy ? 1 : 0),
                    itemBuilder: (context, index) => index >= messages.length
                        ? ChatTypingIndicator(activity: activity)
                        : ChatMessageView(message: messages[index]),
                  ),
                PositionedDirectional(
                  end: AppSpacing.lg,
                  bottom: AppSpacing.md,
                  child: _ScrollToEndButton(
                    visible: _canScrollToEnd,
                    onPressed: _scrollToEnd,
                  ),
                ),
              ],
            ),
          ),
          ChatComposer(
            onSend: _send,
            enabled: !busy,
            dictation: _dictation.isAvailable ? _dictation : null,
          ),
        ],
      ),
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
