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
/// One method, deliberately: everything the UI needs from an assistant is "here
/// is what the user said, give me a reply". A network implementation satisfies
/// this without the chat screen changing, which is the point of writing it down
/// now rather than after there is something to connect.
///
/// A class rather than a typedef'd function, despite the single method: a real
/// implementation will hold a client, a base URL and a cancellation token, and
/// none of that fits in a closure without becoming a closure over hidden state.
// ignore: one_member_abstracts
abstract class AssistantRepository {
  const AssistantRepository();

  /// [history] is the conversation so far, oldest first — unused by the local
  /// implementation and present because any real model needs it.
  Future<AssistantReply> reply({
    required String prompt,
    required List<ChatMessage> history,
  });
}
