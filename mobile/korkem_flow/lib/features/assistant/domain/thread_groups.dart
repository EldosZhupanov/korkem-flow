import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';
import 'package:meta/meta.dart';

/// Which band of the past a conversation falls into.
///
/// Three, not seven. A factory manager's conversations from this morning and
/// from last month need telling apart; the ones from Tuesday and Wednesday
/// three weeks ago do not, and a heading per day turns a short list into a
/// wall of headings.
enum ThreadBand { today, yesterday, earlier }

/// A heading and the conversations under it.
@immutable
class ThreadGroup {
  const ThreadGroup({required this.band, required this.threads});

  final ThreadBand band;
  final List<ChatThread> threads;
}

/// Groups [threads] by when they were last touched, newest first.
///
/// Calendar days, not elapsed hours: a conversation at 23:50 and one at 00:10
/// are eleven hours apart in the same sense that "yesterday" and "today" are,
/// and a 24-hour window would file the first under "today" the following
/// evening. `now` is passed in — every date decision in this app comes from
/// `clockProvider`, so tests are not at the mercy of the wall clock and a
/// golden does not change meaning at midnight.
List<ThreadGroup> groupThreads(List<ChatThread> threads, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  ThreadBand bandOf(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    // A clock skew or an edited record can date a conversation in the future;
    // it belongs at the top rather than in "earlier".
    if (!day.isBefore(today)) return ThreadBand.today;
    if (!day.isBefore(yesterday)) return ThreadBand.yesterday;
    return ThreadBand.earlier;
  }

  final sorted = [...threads]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final buckets = <ThreadBand, List<ChatThread>>{};
  for (final thread in sorted) {
    buckets.putIfAbsent(bandOf(thread.updatedAt), () => []).add(thread);
  }

  return [
    for (final band in ThreadBand.values)
      if (buckets[band] case final group? when group.isNotEmpty)
        ThreadGroup(band: band, threads: group),
  ];
}
