import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sections a person folded away, kept between openings of a window
/// (owner, 21.11.2026: «я хочу где Каталоги фирм мы могли свернуть… здесь
/// тоже»). A key names one section: `rcv.catalogs`, `pp.shelf`. Where no
/// store is to hand — a test — they are kept for the session only.
final foldsProvider = NotifierProvider<Folds, Set<String>>(Folds.new);

class Folds extends Notifier<Set<String>> {
  static const _key = 'ui.folds.shut';

  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      return null;
    }
  }

  @override
  Set<String> build() => {...?_prefs?.getStringList(_key)};

  /// Whether [key] was folded away.
  bool shut(String key) => state.contains(key);

  void set(String key, {required bool shut}) {
    if (shut == state.contains(key)) return;
    final next = {...state};
    if (shut) {
      next.add(key);
    } else {
      next.remove(key);
    }
    state = next;
    final prefs = _prefs;
    if (prefs != null) unawaited(prefs.setStringList(_key, next.toList()));
  }
}
