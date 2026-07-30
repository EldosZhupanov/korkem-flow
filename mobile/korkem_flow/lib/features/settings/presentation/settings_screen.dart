import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Display preferences and connection details.
///
/// Split from Profile so that "who am I / sign out" stays one tap from the tab
/// bar while the rarely-touched knobs sit one level down.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider).value;

    return AppScreen(
      title: l10n.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SectionLabel(l10n.profileAppearance),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (value) => value == null
                  ? null
                  : ref
                        .read(settingsControllerProvider.notifier)
                        .setThemeMode(value),
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(switch (mode) {
                        ThemeMode.system => l10n.themeSystem,
                        ThemeMode.light => l10n.themeLight,
                        ThemeMode.dark => l10n.themeDark,
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionLabel(l10n.profileLanguage),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            // Nullable, and the null entry is listed first — mirroring the
            // theme group above. Without it the default state (follow the
            // device) matched no option, so the group opened with nothing
            // selected and there was no way back to it once a language had
            // been picked.
            child: RadioGroup<Locale?>(
              groupValue: settings.locale,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setLocale(value),
              child: Column(
                children: [
                  RadioListTile<Locale?>(
                    value: null,
                    title: Text(l10n.languageSystem),
                  ),
                  for (final locale in AppLocalizations.supportedLocales)
                    RadioListTile<Locale?>(
                      value: locale,
                      title: Text(languageEndonym(locale.languageCode)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionLabel(l10n.settingsConnection),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow(
                  icon: AppIcons.settings,
                  label: l10n.profileServer,
                  value: session?.serverUrl ?? config.baseUrl,
                ),
                const SizedBox(height: AppSpacing.md),
                InfoRow(
                  icon: AppIcons.info,
                  label: l10n.profileVersion,
                  value: '${config.flavor} · 0.1.0',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Endonyms: a language is easiest to find written in itself.
String languageEndonym(String code) => switch (code) {
  'ru' => 'Русский',
  'kk' => 'Қазақша',
  _ => 'English',
};
