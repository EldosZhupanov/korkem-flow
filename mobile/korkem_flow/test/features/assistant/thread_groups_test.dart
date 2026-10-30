import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';
import 'package:korkem_flow/features/assistant/domain/chat_thread.dart';
import 'package:korkem_flow/features/assistant/domain/thread_groups.dart';

/// Grouping is calendar arithmetic, which is where date bugs live. Kept as a
/// pure function precisely so it can be tested at the boundaries rather than
/// inferred from a screenshot of a sidebar.
void main() {
  // Late enough in the day that "two hours ago" is still today and "sixteen
  // hours ago" is not — the case a 24-hour window gets wrong.
  final now = DateTime(2026, 7, 28, 11);

  ChatThread at(String id, DateTime when) => ChatThread(
    id: id,
    updatedAt: when,
    messages: [
      ChatMessage(id: '$id-m', role: ChatRole.user, body: id, sentAt: when),
    ],
  );

  test('splits by calendar day, not by elapsed hours', () {
    final groups = groupThreads([
      at('two-hours-ago', now.subtract(const Duration(hours: 2))),
      // 19:00 the previous evening: sixteen hours back, so inside any 24-hour
      // window, and still unambiguously yesterday to the person who wrote it.
      at('last-evening', DateTime(2026, 7, 27, 19)),
      at('last-week', now.subtract(const Duration(days: 7))),
    ], now);

    expect(groups.map((g) => g.band), [
      ThreadBand.today,
      ThreadBand.yesterday,
      ThreadBand.earlier,
    ]);
    expect(groups[1].threads.single.id, 'last-evening');
  });

  test('a minute past midnight is today, not yesterday', () {
    final justAfterMidnight = DateTime(2026, 7, 28, 0, 1);
    final groups = groupThreads([at('early', justAfterMidnight)], now);

    expect(groups.single.band, ThreadBand.today);
  });

  test('the last moment of yesterday is yesterday', () {
    final groups = groupThreads([
      at('late', DateTime(2026, 7, 27, 23, 59, 59)),
    ], now);

    expect(groups.single.band, ThreadBand.yesterday);
  });

  test('newest first within a band', () {
    final groups = groupThreads([
      at('older', now.subtract(const Duration(hours: 5))),
      at('newer', now.subtract(const Duration(hours: 1))),
    ], now);

    expect(groups.single.threads.map((t) => t.id), ['newer', 'older']);
  });

  test('a future timestamp sorts to the top rather than into earlier', () {
    // A device clock nudged backwards, or a record edited on a server in
    // another timezone. It must not vanish to the bottom of the list.
    final groups = groupThreads([
      at('now-ish', now),
      at('ahead', now.add(const Duration(hours: 3))),
    ], now);

    expect(groups.single.band, ThreadBand.today);
    expect(groups.single.threads.first.id, 'ahead');
  });

  test('empty bands produce no heading', () {
    final groups = groupThreads([
      at('old', now.subtract(const Duration(days: 30))),
    ], now);

    expect(groups.map((g) => g.band), [ThreadBand.earlier]);
  });

  test('no threads, no groups', () {
    expect(groupThreads(const [], now), isEmpty);
  });
}
