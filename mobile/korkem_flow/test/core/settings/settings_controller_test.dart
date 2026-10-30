import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences must outlive the process.
///
/// Regression on two counts. They were in-memory only, so every launch reset
/// them — someone who chose Russian on a Kazakh-locale phone chose it again
/// every time. And `setLocale` went through `copyWith`, which resolves a null
/// argument to the existing value: a language could be set but never cleared,
/// so "follow the device" was unreachable once anything else had been picked.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> container() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh install follows the device', () async {
    final settings = (await container()).read(settingsControllerProvider);

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.locale, isNull);
  });

  test('theme and language survive a restart', () async {
    final first = await container();
    first.read(settingsControllerProvider.notifier)
      ..setThemeMode(ThemeMode.dark)
      ..setLocale(const Locale('ru'));

    // A second container over the same store stands in for a relaunch.
    final restarted = (await container()).read(settingsControllerProvider);

    expect(restarted.themeMode, ThemeMode.dark);
    expect(restarted.locale, const Locale('ru'));
  });

  test('choosing a language can be undone', () async {
    final live = await container();
    final controller = live.read(settingsControllerProvider.notifier)
      ..setLocale(const Locale('kk'));

    expect(live.read(settingsControllerProvider).locale, const Locale('kk'));

    controller.setLocale(null);
    expect(live.read(settingsControllerProvider).locale, isNull);

    // And the reset is what a relaunch sees, not just this session.
    final restarted = (await container()).read(settingsControllerProvider);
    expect(restarted.locale, isNull);
  });

  test('a stored value it cannot parse falls back to the default', () async {
    SharedPreferences.setMockInitialValues({'settings.themeMode': 'neon'});

    final settings = (await container()).read(settingsControllerProvider);

    expect(settings.themeMode, ThemeMode.system);
  });
}
