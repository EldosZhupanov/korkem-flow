import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:korkem_flow/core/design/motion/app_busy_indicator.dart';
import 'package:korkem_flow/core/design/motion/entrance.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
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
/// External untrusted messages (e.g. customer inputs) are rendered as quotes
/// with a left bar and provenance caption.
class ChatMessageView extends StatelessWidget {
  const ChatMessageView({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Entrance(
        child: switch (message.role) {
          ChatRole.user =>
            message.isOwner
                ? _UserTurn(body: message.body)
                : _ExternalTurn(message: message),
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

/// An untrusted message from an external origin (customer, WhatsApp, etc.).
///
/// Displayed as a quoted block with a left accent bar, a distinct background,
/// and a header stating the origin and clarifying that it is incoming data
/// rather than a direct instruction from the workshop owner.
class _ExternalTurn extends StatelessWidget {
  const _ExternalTurn({required this.message});

  final ChatMessage message;

  static const double _maxWidthFraction = 0.88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusColors = context.statusColors;

    final sourceTitle =
        (message.sourceLabel != null && message.sourceLabel!.trim().isNotEmpty)
        ? message.sourceLabel!.trim()
        : l10n.chatExternalMessageDefault;

    // Слева, а не справа: справа стоят ваши собственные сообщения, и чужой
    // текст в той же колонке читается как ваш, сколько бы полос мы вокруг него
    // ни нарисовали.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * _maxWidthFraction,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: AppSpacing.xs,
                    color: statusColors.info,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ExternalSourceHeader(title: sourceTitle),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            message.body,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExternalSourceHeader extends StatelessWidget {
  const _ExternalSourceHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusColors = context.statusColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.conversation,
              size: AppIconSize.dense,
              color: statusColors.info,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColors.info,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.chatExternalDataNotice,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
        // Every one of these is worded here rather than in the data layer, so
        // it is translated like everything else the user reads. A turn that
        // failed used to render as nothing at all — an empty bubble is the one
        // outcome a person cannot act on.
        if (message.failure case final reason?)
          _Failure(reason: reason)
        else if (message.unrecognised)
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
        // Said on the turn itself, not only in the screen's subtitle. A card
        // full of real KORKEM figures is indistinguishable from an answer a
        // model wrote, and letting it pass for one is a claim the app cannot
        // support.
        //
        // Only where there is something to mistake for an answer. A failure
        // and an "I don't understand" are already unambiguous about the fact
        // that no model spoke, and badging them would be noise on the two
        // turns that least need it.
        if (message.fromFallback &&
            message.failure == null &&
            !message.unrecognised &&
            (message.body.isNotEmpty || message.card != null)) ...[
          const SizedBox(height: AppSpacing.sm),
          const _FallbackBadge(),
        ],
      ],
    );
  }
}

/// Marks a reply that no language model produced.
class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          AppIcons.info,
          size: AppIconSize.dense,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          l10n.chatFallbackBadge,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Why a turn produced no answer.
///
/// Distinct from the assistant simply not understanding: that is a limit of
/// what it knows, this is something wrong with the setup, and telling the two
/// apart is what decides whether the user rephrases or calls an administrator.
class _Failure extends StatelessWidget {
  const _Failure({required this.reason});

  final AssistantFailure reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Each reason gets the icon the design system already has for that state,
    // rather than one generic warning: "no connection" and "not allowed" are
    // different problems and the glyph is the fastest way to say which.
    final (text, icon, tint) = switch (reason) {
      AssistantFailure.notConfigured => (
        l10n.chatErrorNotConfigured,
        AppIcons.info,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.providerUnavailable => (
        l10n.chatErrorProviderUnavailable,
        AppIcons.offline,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.rateLimited => (
        l10n.chatErrorRateLimited,
        AppIcons.schedule,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.toolError => (
        l10n.chatErrorToolError,
        AppIcons.danger,
        theme.colorScheme.error,
      ),
      AssistantFailure.timedOut => (
        l10n.chatErrorTimedOut,
        AppIcons.schedule,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.modelNotFound => (
        l10n.chatErrorModelNotFound,
        AppIcons.info,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.contextTooLarge => (
        l10n.chatErrorContextTooLarge,
        AppIcons.info,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.offline => (
        l10n.chatErrorOffline,
        AppIcons.offline,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.refused => (
        l10n.chatErrorRefused,
        AppIcons.noAccess,
        theme.colorScheme.onSurfaceVariant,
      ),
      AssistantFailure.unknown => (
        l10n.chatErrorUnknown,
        AppIcons.danger,
        theme.colorScheme.error,
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.small, color: tint),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
  const ChatTypingIndicator({this.activity, super.key});

  /// The tool being run right now, e.g. `crm.search_deals`. Null between tool
  /// calls, when all that can honestly be said is that it is thinking.
  final String? activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = activity == null ? null : _activityLabel(activity!, l10n);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Semantics(
        label: label ?? l10n.chatThinking,
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AssistantLabel(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const AppBusyIndicator(),
                // Naming the step matters more than the animation does. Four
                // seconds of silent dots and then a figure asks to be trusted
                // without showing any work; "Searching deals…" says where the
                // number is about to come from.
                if (label != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A registered tool name, said in the user's language.
///
/// Falls back to a generic phrase rather than showing `crm.search_deals` — an
/// identifier on screen is a debug console, and a tool added on the server
/// should not need a client release to avoid looking broken.
String _activityLabel(String tool, AppLocalizations l10n) => switch (tool) {
  'crm.search_deals' || 'crm.get_deal' => l10n.chatToolDeals,
  'crm.search_leads' => l10n.chatToolLeads,
  'crm.search_organizations' => l10n.chatToolCustomers,
  'tasks.list' => l10n.chatToolTasks,
  // `production.list_work_orders` is no longer registered — kept because
  // transcripts recorded before it was retired still name it.
  'production.list_work_orders' ||
  'manufacturing.search_work_orders' ||
  'manufacturing.production_control' ||
  'manufacturing.production_readiness' ||
  'manufacturing.get_bom_materials' => l10n.chatToolProduction,
  'sales.search_sales_orders' || 'sales.get_sales_order' => l10n.chatToolOrders,
  'inventory.factory_shortage' ||
  'inventory.material_shortage' => l10n.chatToolShortage,
  'inventory.get_stock' => l10n.chatToolStock,
  'inventory.create_material_request' => l10n.chatToolProcurement,
  'profile.current_user' => l10n.chatToolProfile,
  _ => l10n.chatWorking,
};

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
