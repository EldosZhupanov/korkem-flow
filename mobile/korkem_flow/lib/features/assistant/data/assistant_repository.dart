import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:meta/meta.dart';

/// What the assistant said, before it becomes a message.
///
/// Either a body it wrote, or an admission that it could not. Both fields being
/// empty is the "not connected" case, and the view is what puts words to it —
/// which keeps translation in the layer that has a `BuildContext` instead of
/// dragging `AppLocalizations` down into data.
@immutable
class AssistantReply {
  const AssistantReply({this.body, this.card});

  /// Markdown, when there is a model to write it. Null for the local
  /// assistant, whose whole answer is the card.
  final String? body;

  /// Live KORKEM data to attach.
  final ContextCardKind? card;

  /// True when the assistant has nothing to offer: no model, no match.
  bool get isUnrecognised => body == null && card == null;
}

/// The seam a real language model plugs into.
///
/// A **stream**, not a future, and that changed when the server side landed: a
/// turn is queued (ADR-0009) and its text, tool activity and final answer come
/// back separately over a realtime channel. A future could only represent the
/// last of those, which would throw away the two that make the assistant feel
/// like it is working rather than hung.
///
/// A class rather than a typedef'd function: a real implementation holds a
/// client, a socket and a subscription, and none of that fits in a closure
/// without becoming a closure over hidden state.
abstract class AssistantRepository {
  const AssistantRepository();

  /// Answers [prompt]. [history] is the conversation so far, oldest first.
  ///
  /// The stream closes when the turn ends, whether it ended in an answer, a
  /// request for confirmation, or a failure. Cancelling the subscription
  /// abandons the turn from the client's side; the server has already been
  /// paid for and finishes regardless.
  Stream<AssistantEvent> send({
    required String prompt,
    required List<ChatMessage> history,
  });

  /// Approves tool calls the assistant paused on, and resumes the turn.
  ///
  /// Unsupported by an assistant with no write tools, which is why it has a
  /// default: overriding it is opting in to being able to change data.
  Stream<AssistantEvent> confirm({
    required String turnId,
    required List<String> callIds,
    required String prompt,
    required List<ChatMessage> history,
  }) => const Stream.empty();
}
