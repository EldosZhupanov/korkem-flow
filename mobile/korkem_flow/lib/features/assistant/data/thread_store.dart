import 'dart:convert';

import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where conversations live between launches.
///
/// On the device, in `shared_preferences` — there is no backend for chat
/// history and none is invented. The sidebar's "Recent" list is therefore the
/// user's own conversations and nothing else: empty until they have had one,
/// which is the honest state rather than a seeded list that suggests activity
/// that never happened.
///
/// A class rather than free functions so that a server-backed store can replace
/// it whole when there is an endpoint to talk to.
class ThreadStore {
  const ThreadStore(this._preferences);

  static const _key = 'assistant.threads';

  /// Enough to be useful in a sidebar, few enough that the whole list can be
  /// read and rewritten on every change without anyone noticing.
  static const int keep = 20;

  final SharedPreferences _preferences;

  List<ChatThread> read() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          ChatThread.fromJson(Map<String, dynamic>.from(entry as Map)),
      ];
    } on FormatException {
      // Corrupt or written by an older shape. Losing local chat history is a
      // far smaller harm than refusing to open the app, so it is discarded
      // rather than thrown.
      return const [];
    }
  }

  Future<void> write(List<ChatThread> threads) {
    final kept = threads.take(keep).toList();
    return _preferences.setString(
      _key,
      jsonEncode([for (final thread in kept) thread.toJson()]),
    );
  }
}
