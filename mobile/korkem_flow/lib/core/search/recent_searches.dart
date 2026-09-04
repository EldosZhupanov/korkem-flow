import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';

/// The last few things a user searched for, per list.
///
/// Keyed by scope — deals, leads, customers — because the lists ask different
/// questions. A salesperson looking up the same organisation across a week
/// should not have to retype it, but a customer name surfacing in the parts
/// warehouse would be noise.
///
/// Deliberately small and local: this is a typing shortcut, not history worth
/// syncing. Nothing leaves the device, and there is no server call to make.
// ignore: specify_nonobvious_property_types — the generics are right there.
final recentSearchesProvider =
    NotifierProvider.family<RecentSearchesNotifier, List<String>, String>(
      RecentSearchesNotifier.new,
    );

class RecentSearchesNotifier extends Notifier<List<String>> {
  RecentSearchesNotifier(this.scope);

  /// The list this history belongs to, from `SearchScope`.
  final String scope;

  /// Beyond about five this stops being a shortcut and becomes a list to read.
  static const _limit = 5;

  /// Too short to be worth remembering, and a one-character entry would push
  /// out a real query the user actually wants back.
  static const _minLength = 2;

  String get _key => 'search.recent.$scope';

  @override
  List<String> build() =>
      ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];

  /// Records a query, most recent first, without duplicating one already held.
  ///
  /// Called when a search *settles* rather than on every keystroke — otherwise
  /// every prefix of every word ends up stored, and the list fills with
  /// "K", "Ko", "Kor" instead of "Korkem".
  void record(String query) {
    final trimmed = query.trim();
    if (trimmed.length < _minLength) return;

    // Case-insensitive de-dupe, but the new spelling wins: the user just typed
    // it, so it is the one they will recognise.
    final next = [
      trimmed,
      ...state.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ].take(_limit).toList();

    if (_sameAs(next)) return;

    state = next;
    unawaited(
      ref.read(sharedPreferencesProvider).setStringList(_key, next),
    );
  }

  void clear() {
    if (state.isEmpty) return;
    state = const [];
    unawaited(ref.read(sharedPreferencesProvider).remove(_key));
  }

  bool _sameAs(List<String> other) {
    if (other.length != state.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i] != state[i]) return false;
    }
    return true;
  }
}

/// Scope names, spelled once.
///
/// A typo here does not fail — it silently gives that list its own private,
/// permanently empty history — which is exactly why they are not string
/// literals at the call sites.
abstract final class SearchScope {
  static const deals = 'deals';
  static const leads = 'leads';
  static const customers = 'customers';
  static const quotes = 'quotes';
  static const warehouse = 'warehouse';
  static const materials = 'materials';
}
