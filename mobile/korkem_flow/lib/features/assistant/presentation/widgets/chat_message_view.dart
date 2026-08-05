import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:korkem_flow/core/design/motion/app_busy_indicator.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/context_card.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The product's name for itself, in every language. A brand, not a string to
/// translate.
const String assistantName = 'KORKEM AI';

/// One turn of the conversation.
///
/// The two roles are told apart by *shape*, not by two mirrored bubbles. The
/// user's words sit in a tinted block pushed to the trailing edge, because they
/// are short and belong to them; the assistant's answer runs the full width
/// with a small label above it, because an answer may be long and a bubble
/// around a paragraph of Markdown reads as a quotation rather than as a reply.
class ChatMessageView extends StatelessWidget {
  const ChatMessageView({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Entrance(
        child: switch (message.role) {
          ChatRole.user => _UserTurn(body: message.body),
          ChatRole.assistant => _AssistantTurn(message: message),
        },
      ),
    );
  }
}

class _UserTurn extends StatelessWidget {
  const _UserTurn({required this.body});

  final String body;

  /// How much of the width a user's own message may take. Never all of it: a
  /// message reaching both edges is indistinguishable from the reply below it.
  static const double _maxWidthFraction = 0.82;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * _maxWidthFraction,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Text(body, style: theme.textTheme.bodyLarge),
          ),
        ),
      ),
    );
  }
}

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AssistantLabel(),
        const SizedBox(height: AppSpacing.sm),
        // The admission is worded here rather than in the data layer, so it is
        // translated like everything else the user reads.
        if (message.unrecognised)
          MarkdownBody(
            data: _cannotAnswer(l10n),
            styleSheet: assistantMarkdownStyle(context),
          )
        else if (message.body.isNotEmpty)
          MarkdownBody(
            data: message.body,
            styleSheet: assistantMarkdownStyle(context),
          ),
        if (message.card case final kind?) ...[
          if (message.body.isNotEmpty || message.unrecognised)
            const SizedBox(height: AppSpacing.md),
          ContextCard(kind: kind),
        ],
      ],
    );
  }
}

/// What the assistant says when it has nothing: the fact, then what it can do.
///
/// Naming the alternatives matters as much as the admission. "I can't" alone
/// leaves someone guessing what to try; the list turns a dead end into an
/// instruction.
String _cannotAnswer(AppLocalizations l10n) =>
    '${l10n.chatNotConnected}\n\n'
    '- ${l10n.chatSuggestDeals}\n'
    '- ${l10n.chatSuggestAttention}\n'
    '- ${l10n.chatSuggestOverdue}\n'
    '- ${l10n.chatSuggestProduction}';

class AssistantLabel extends StatelessWidget {
  const AssistantLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      assistantName,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Shown while a reply is being prepared.
///
/// The same three dots every busy control in the app uses, so "working" looks
/// like one thing everywhere rather than a bespoke animation for the chat.
class ChatTypingIndicator extends StatelessWidget {
  const ChatTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Semantics(
        label: AppLocalizations.of(context).chatThinking,
        liveRegion: true,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AssistantLabel(),
            SizedBox(height: AppSpacing.md),
            AppBusyIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Markdown mapped onto the app's own type scale.
///
/// `fromTheme` alone keeps the package's own spacing, which is looser than
/// anything else on screen; these overrides are what make a reply look like it
/// belongs to this app rather than to the renderer.
MarkdownStyleSheet assistantMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge,
    listBullet: theme.textTheme.bodyLarge,
    h1: theme.textTheme.titleLarge,
    h2: theme.textTheme.titleMedium,
    h3: theme.textTheme.titleSmall,
    strong: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    blockSpacing: AppSpacing.md,
    listIndent: AppSpacing.xl,
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    ),
    codeblockDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    blockquoteDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
  );
}
