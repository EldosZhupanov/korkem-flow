import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/search/recent_searches.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recent searches exist to save typing, and every rule here is about not
/// filling the list with things nobody would tap.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  RecentSearchesNotifier notifierFor(
    ProviderContainer container,
    String scope,
  ) => container.read(recentSearchesProvider(scope).notifier);

  List<String> historyOf(ProviderContainer container, String scope) =>
      container.read(recentSearchesProvider(scope));

  test('most recent first', () {
    final container = containerWith();
    notifierFor(container, SearchScope.deals)
      ..record('Korkem')
      ..record('Acme');

    expect(historyOf(container, SearchScope.deals), ['Acme', 'Korkem']);
  });

  test('re-searching moves a query up rather than duplicating it', () {
    final container = containerWith();
    notifierFor(container, SearchScope.deals)
      ..record('Korkem')
      ..record('Acme')
      ..record('Korkem');

    expect(historyOf(container, SearchScope.deals), ['Korkem', 'Acme']);
  });

  test('de-dupe ignores case, but the newest spelling is the one kept', () {
    final container = containerWith();
    notifierFor(container, SearchScope.deals)
      ..record('korkem')
      ..record('KORKEM');

    // One entry, spelled the way the user last typed it — that is the one they
    // will recognise in the list.
    expect(historyOf(container, SearchScope.deals), ['KORKEM']);
  });

  test('a single character is not worth remembering', () {
    final container = containerWith();
    notifierFor(container, SearchScope.deals)
      ..record('K')
      ..record('  ')
      ..record('')
      ..record('Ko');

    // Otherwise every prefix typed on the way to a real query lands in the
    // list, and pushes the real query out of it.
    expect(historyOf(container, SearchScope.deals), ['Ko']);
  });

  test('holds five, and the sixth pushes out the oldest', () {
    final container = containerWith();
    [
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
    ].forEach(notifierFor(container, SearchScope.deals).record);

    expect(historyOf(container, SearchScope.deals), [
      'six',
      'five',
      'four',
      'three',
      'two',
    ]);
  });

  test('scopes do not see each other', () {
    final container = containerWith();
    notifierFor(container, SearchScope.deals).record('Korkem');
    notifierFor(container, SearchScope.warehouse).record('Plywood 18mm');

    // A customer name surfacing in the parts warehouse would be noise, and a
    // shared key is how that happens.
    expect(historyOf(container, SearchScope.deals), ['Korkem']);
    expect(historyOf(container, SearchScope.warehouse), ['Plywood 18mm']);
  });

  test('history outlives the process', () {
    notifierFor(containerWith(), SearchScope.deals).record('Korkem');

    // A fresh container over the same store is what a relaunch looks like.
    expect(historyOf(containerWith(), SearchScope.deals), ['Korkem']);
  });

  test('clearing empties the store, not just the state', () {
    final container = containerWith();
    notifierFor(container, SearchScope.deals)
      ..record('Korkem')
      ..clear();

    expect(historyOf(container, SearchScope.deals), isEmpty);
    expect(historyOf(containerWith(), SearchScope.deals), isEmpty);
  });
}
