import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:meta/meta.dart';

/// One conversation.
@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.messages,
    required this.updatedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messages: [
      for (final raw in (json['messages'] as List? ?? const []))
        ChatMessage.fromJson(Map<String, dynamic>.from(raw as Map)),
    ],
  );

  final String id;
  final List<ChatMessage> messages;
  final DateTime updatedAt;

  bool get isEmpty => messages.isEmpty;

  /// What the sidebar calls this conversation: the first thing the user said.
  ///
  /// Derived rather than stored, and taken from the *user's* words rather than
  /// the assistant's — a list of replies would read as a list of the same
  /// canned sentence, while a list of questions is a record of what someone
  /// was trying to find out.
  String get title {
    for (final message in messages) {
      if (message.role == ChatRole.user && message.body.trim().isNotEmpty) {
        return message.body.trim();
      }
    }
    return '';
  }

  ChatThread copyWith({List<ChatMessage>? messages, DateTime? updatedAt}) =>
      ChatThread(
        id: id,
        messages: messages ?? this.messages,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': [for (final message in messages) message.toJson()],
  };
}
