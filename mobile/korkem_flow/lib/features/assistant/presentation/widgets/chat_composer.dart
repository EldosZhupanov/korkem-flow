import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/motion/app_busy_indicator.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Where a message is written.
///
/// Two controls, and both do something. There is no attachment button: nothing
/// in the app can receive a file, and a control that does nothing is precisely
/// the tell that separates a demo from a product.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.onSend,
    required this.enabled,
    this.dictation,
    super.key,
  });

  final ValueChanged<String> onSend;

  /// False while a reply is in flight — a second question sent before the first
  /// is answered has nowhere to go.
  final bool enabled;

  /// Absent where dictation cannot run: an unsupported device, a refused
  /// permission, or a test. The button is then not drawn at all rather than
  /// drawn and made useless.
  final ChatDictation? dictation;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

/// Voice input, as the composer needs to see it.
///
/// An interface rather than the plugin, so the composer can be built in a test
/// without a platform channel, and so a different recogniser is a different
/// implementation rather than an edit here.
abstract class ChatDictation {
  bool get isListening;

  /// Appends what it hears to the field; the user still presses send.
  Future<void> start(ValueChanged<String> onResult);

  Future<void> stop();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  bool get _canSend => widget.enabled && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _send() {
    if (!_canSend) return;
    widget.onSend(_controller.text);
    _controller.clear();
    // Focus is kept: a conversation is usually more than one question, and
    // dismissing the keyboard after every send makes the second one a chore.
    _focus.requestFocus();
  }

  Future<void> _toggleDictation() async {
    final dictation = widget.dictation;
    if (dictation == null) return;

    if (dictation.isListening) {
      await dictation.stop();
    } else {
      await dictation.start((text) {
        _controller
          ..text = text
          ..selection = TextSelection.collapsed(offset: text.length);
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dictation = widget.dictation;
    final listening = dictation?.isListening ?? false;

    // Bottom only. The keyboard inset is the Scaffold's job — it resizes the
    // body, which is what keeps this above the keyboard — but the gesture bar
    // underneath is not, and without this the send button sits on it. Taking
    // the top too would add the status bar height a second time, below an app
    // bar that has already accounted for it.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? AppColors.outlineStrongDark
                  : AppColors.outlineStrongLight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grows with what is typed and then stops, so a long question
                // stays readable without the field eating the conversation.
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: _maxLines,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.chatPlaceholder,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (dictation != null)
                      IconButton(
                        icon: Icon(
                          listening ? AppIcons.close : AppIcons.microphone,
                        ),
                        color: listening ? theme.colorScheme.error : null,
                        tooltip: listening
                            ? l10n.chatDictateStop
                            : l10n.chatDictate,
                        onPressed: _toggleDictation,
                      ),
                    // Cross-faded rather than enabled in place: the disabled
                    // arrow was the only thing on the row that ever looked
                    // broken, and there is nothing to press until there are
                    // words to send.
                    AnimatedSwitcher(
                      duration: motionOf(context, AppDuration.quick),
                      switchInCurve: AppCurves.enter,
                      switchOutCurve: AppCurves.exit,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: switch ((widget.enabled, _canSend)) {
                        // A reply is in flight. The slot says so rather than
                        // going blank, so the pause reads as the assistant
                        // working and not as the composer having broken.
                        (false, _) => Padding(
                          key: const ValueKey('busy'),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Semantics(
                            label: l10n.chatThinking,
                            liveRegion: true,
                            child: const AppBusyIndicator(),
                          ),
                        ),
                        (true, true) => IconButton.filled(
                          key: const ValueKey('send'),
                          icon: const Icon(AppIcons.send),
                          tooltip: l10n.chatSend,
                          onPressed: _send,
                        ),
                        (true, false) => const SizedBox.square(
                          key: ValueKey('idle'),
                          dimension: AppTouchTarget.min,
                        ),
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How tall the field may grow before it scrolls instead.
const int _maxLines = 6;
