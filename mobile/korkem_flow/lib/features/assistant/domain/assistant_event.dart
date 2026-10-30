import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:meta/meta.dart';

/// Something the assistant did while answering.
///
/// A reply is no longer one value that arrives at the end. The turn is queued
/// on the server, and text, tool activity and the final answer come back
/// separately — so the seam between the UI and the assistant is a stream of
/// these rather than a `Future`.
///
/// Sealed, because every case has to be handled somewhere visible: a new event
/// kind that the UI silently ignores is a feature the user never learns exists.
@immutable
sealed class AssistantEvent {
  const AssistantEvent();
}

/// A fragment of the answer. Append it; never replace on it.
@immutable
final class AssistantDelta extends AssistantEvent {
  const AssistantDelta(this.text);

  final String text;
}

/// The assistant reached into KORKEM.
///
/// Shown as it happens ("Searching deals…") because an assistant that goes
/// quiet for four seconds and then produces figures is asking to be trusted
/// without showing its work.
@immutable
final class AssistantToolActivity extends AssistantEvent {
  const AssistantToolActivity({required this.tool, required this.ok});

  /// The registered tool name, e.g. `crm.search_deals`.
  final String tool;

  final bool ok;
}

/// The assistant wants to do something that changes data, and is asking first.
///
/// Nothing has happened yet: the server stopped the turn before executing.
/// Confirming sends the call ids back; doing nothing leaves the data untouched.
@immutable
final class AssistantNeedsConfirmation extends AssistantEvent {
  const AssistantNeedsConfirmation({
    required this.text,
    required this.calls,
    this.turnId = '',
  });

  /// What the assistant said while asking.
  final String? text;

  final List<PendingToolCall> calls;

  /// The turn to resume once a human answers. Carried on the event because
  /// the screen showing the prompt is not the code that knows the turn id.
  final String turnId;
}

@immutable
class PendingToolCall {
  const PendingToolCall({
    required this.id,
    required this.tool,
    required this.arguments,
  });

  factory PendingToolCall.fromJson(Map<String, dynamic> json) =>
      PendingToolCall(
        id: json['id'] as String? ?? '',
        tool: json['tool'] as String? ?? '',
        arguments: Map<String, dynamic>.from(
          (json['arguments'] as Map?) ?? const {},
        ),
      );

  final String id;
  final String tool;
  final Map<String, dynamic> arguments;
}

/// The turn finished.
@immutable
final class AssistantDone extends AssistantEvent {
  const AssistantDone({this.text, this.card});

  /// The complete answer. Present even when deltas already arrived, so a
  /// client that missed a fragment still ends up with the whole thing.
  final String? text;

  /// Live KORKEM data to attach, for the local assistant. A real model
  /// attaches records by citing them, not by naming a card kind.
  final ContextCardKind? card;
}

/// The turn failed, in a way worth saying out loud.
///
/// Carries a sentence fit to show a user — never a stack trace, and never a
/// provider's raw error, both of which can quote things the user should not
/// see and neither of which helps them.
@immutable
final class AssistantFailed extends AssistantEvent {
  const AssistantFailed(this.reason);

  final AssistantFailure reason;
}

/// Why a turn failed, as something the UI can word in the user's language.
///
/// An enum rather than a message, because the data layer has no `BuildContext`
/// and a server-authored English sentence in a Russian interface is worse than
/// no explanation at all.
///
/// The cases mirror `korkem_ai/errors.py`. They are distinct because the *user*
/// does something different about each: an administrator fixes a missing key,
/// nobody fixes a rate limit but it passes, and a refusal is neither.
enum AssistantFailure {
  /// No provider is configured on the server yet.
  notConfigured,

  /// A provider is configured but could not be reached, or answered with an
  /// error that is not about credentials or quota.
  providerUnavailable,

  /// The provider is throttling us. Distinct from unavailable: waiting helps.
  rateLimited,

  /// A tool failed in a way the turn could not absorb.
  toolError,

  /// The provider answered the connection but never finished.
  timedOut,

  /// The configured model does not exist, or this key may not use it.
  modelNotFound,

  /// The conversation no longer fits the model's context window.
  contextTooLarge,

  /// The device could not reach KORKEM.
  offline,

  /// Reached it, and it said no.
  refused,

  /// Anything else.
  unknown;

  /// The code the gateway sends, mapped onto what the UI can say.
  ///
  /// One table, matching the one in `errors.py`. An unrecognised code — an
  /// older client meeting a newer server — degrades to [unknown] rather than
  /// throwing: a failure to name a failure should not itself be a crash.
  static AssistantFailure fromCode(String? code) => switch (code) {
    'AI_NOT_CONFIGURED' => notConfigured,
    'PROVIDER_UNAVAILABLE' => providerUnavailable,
    'AUTH_ERROR' => refused,
    'RATE_LIMITED' => rateLimited,
    'TOOL_ERROR' => toolError,
    'AI_TIMEOUT' => timedOut,
    'AI_MODEL_NOT_FOUND' => modelNotFound,
    'AI_CONTEXT_TOO_LARGE' => contextTooLarge,
    // Offering tools to a model that cannot use them is a configuration
    // mistake with the same remedy as a missing model: choose another one.
    'AI_TOOL_NOT_SUPPORTED' => modelNotFound,
    'AI_INVALID_TOOL_ARGUMENTS' => toolError,
    _ => unknown,
  };
}
