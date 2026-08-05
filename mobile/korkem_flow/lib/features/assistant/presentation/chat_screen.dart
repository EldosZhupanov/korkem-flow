import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
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

  @override
  void initState() {
    super.initState();
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
    _scroll.dispose();
    unawaited(_dictation.dispose());
    super.dispose();
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
    final messages = thread?.messages ?? const [];

    return AppScreen(
      title: assistantName,
      // Says plainly that there is no language model behind this. A demo that
      // does not admit to being one is not a demo.
      subtitle: l10n.chatLocalMode,
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? ChatEmptyView(onSuggestion: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    itemCount: messages.length + (busy ? 1 : 0),
                    itemBuilder: (context, index) => index >= messages.length
                        ? const ChatTypingIndicator()
                        : ChatMessageView(message: messages[index]),
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
