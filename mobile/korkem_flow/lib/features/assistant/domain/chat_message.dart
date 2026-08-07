import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:meta/meta.dart';

/// What a message in a conversation is.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.body,
    required this.sentAt,
    this.card,
    this.unrecognised = false,
    this.failure,
    this.fromFallback = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    role: ChatRole.fromWire(json['role'] as String?),
    body: json['body'] as String? ?? '',
    sentAt: DateTime.parse(json['sentAt'] as String),
    card: ContextCardKind.fromWire(json['card'] as String?),
    unrecognised: json['unrecognised'] as bool? ?? false,
    failure: AssistantFailure.values
        .where((f) => f.name == json['failure'])
        .firstOrNull,
    fromFallback: json['fromFallback'] as bool? ?? false,
  );

  final String id;
  final ChatRole role;

  /// Markdown. The assistant's replies are authored as Markdown even though
  /// they are canned today, because that is the shape a real model returns —
  /// so connecting one changes who writes the string, not how it is rendered.
  final String body;

  final DateTime sentAt;

  /// A live view of KORKEM data attached to the reply.
  ///
  /// Only the *kind* is stored. The numbers are read from the app's existing
  /// providers when the card is built, so a conversation reopened tomorrow
  /// shows tomorrow's figures rather than a snapshot pretending to be current.
  final ContextCardKind? card;

  /// Why this turn failed, when it did.
  ///
  /// Stored as a reason rather than a sentence so the screen can word it in
  /// the user's language, and so a conversation reopened after the server was
  /// fixed still shows what went wrong at the time.
  final AssistantFailure? failure;

  /// The assistant could not answer, and said so.
  ///
  /// Stored rather than derived from an empty body, so reopening an old
  /// conversation still shows the admission instead of a blank turn that reads
  /// as a message that failed to load.
  final bool unrecognised;

  /// This reply came from the on-device keyword matcher, not a language model.
  ///
  /// Recorded on the message and shown on it, because the alternative — letting
  /// a card appear that looks exactly like an AI answer — is a claim the app
  /// cannot support. Persisted so a conversation reopened after a model *is*
  /// connected still says which of its turns were never answered by one.
  final bool fromFallback;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.wireValue,
    'body': body,
    'sentAt': sentAt.toIso8601String(),
    if (card != null) 'card': card!.wireValue,
    if (unrecognised) 'unrecognised': true,
    if (failure != null) 'failure': failure!.name,
    if (fromFallback) 'fromFallback': true,
  };
}

enum ChatRole {
  user('user'),
  assistant('assistant');

  const ChatRole(this.wireValue);

  final String wireValue;

  static ChatRole fromWire(String? value) =>
      value == 'user' ? ChatRole.user : ChatRole.assistant;
}

/// The kinds of KORKEM data the assistant can show.
///
/// Each maps to a screen that already exists and a provider that already feeds
/// it — the assistant is a way into the app, not a second copy of it.
enum ContextCardKind {
  attention('attention'),
  deals('deals'),
  tasks('tasks'),
  production('production');

  const ContextCardKind(this.wireValue);

  final String wireValue;

  static ContextCardKind? fromWire(String? value) {
    if (value == null) return null;
    for (final kind in ContextCardKind.values) {
      if (kind.wireValue == value) return kind;
    }
    return null;
  }
}
