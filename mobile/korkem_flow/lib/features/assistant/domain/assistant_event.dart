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
  const AssistantNeedsConfirmation({required this.text, required this.calls});

  /// What the assistant said while asking.
  final String? text;

  final List<PendingToolCall> calls;
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
enum AssistantFailure {
  /// No provider is configured on the server yet.
  notConfigured,

  /// The device could not reach KORKEM.
  offline,

  /// Reached it, and it said no.
  refused,

  /// Anything else.
  unknown,
}
