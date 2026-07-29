import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing display preferences.
///
/// Kept out of the feature layer because the shell, the theme and the locale
/// delegate all read it before any feature is built.
@immutable
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system, this.locale});

  final ThemeMode themeMode;

  /// `null` follows the device locale.
  final Locale? locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
  );
}

/// The store, loaded before the first frame and injected at bootstrap.
///
/// Resolved eagerly in `main` rather than awaited inside the controller so the
/// app never renders one theme or language and then swaps to another a frame
/// later. Overridden in tests.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider'),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'settings.themeMode';
  static const _localeKey = 'settings.locale';

  /// Preferences outlive the process.
  ///
  /// They used to be in-memory only, so every launch reset them: someone who
  /// chose Russian on a Kazakh-locale phone had to choose it again, every time.
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    return AppSettings(
      themeMode: _readThemeMode(prefs.getString(_themeKey)),
      locale: switch (prefs.getString(_localeKey)) {
        final String code when code.isNotEmpty => Locale(code),
        _ => null,
      },
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    // Fire-and-forget: the state is already live, and the only cost of a failed
    // write is that this preference is not remembered next launch. Making the
    // setter async would push a Future onto every caller for no benefit.
    unawaited(
      ref.read(sharedPreferencesProvider).setString(_themeKey, mode.name),
    );
  }

  /// `null` restores "follow the device locale".
  ///
  /// Constructed rather than `copyWith`-ed: `copyWith` resolves a null argument
  /// to the existing value, so it can set a locale but never clear one — the
  /// user could pick a language and then had no way back.
  void setLocale(Locale? locale) {
    state = AppSettings(themeMode: state.themeMode, locale: locale);

    final prefs = ref.read(sharedPreferencesProvider);
    unawaited(
      locale == null
          ? prefs.remove(_localeKey)
          : prefs.setString(_localeKey, locale.languageCode),
    );
  }

  /// Unknown or absent values fall back to following the system, which is the
  /// same default a fresh install gets.
  static ThemeMode _readThemeMode(String? name) =>
      ThemeMode.values.where((mode) => mode.name == name).firstOrNull ??
      ThemeMode.system;
}
