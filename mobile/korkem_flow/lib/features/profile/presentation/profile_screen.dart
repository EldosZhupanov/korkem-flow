import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/config/app_config.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Profile and preferences.
///
/// Overflow lives here rather than in a drawer: a drawer hides navigation
/// behind an edge gesture and is poor one-handed.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SectionLabel(l10n.profileAppearance),
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

          _SectionLabel(l10n.profileLanguage),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: RadioGroup<Locale>(
              groupValue: settings.locale,
              onChanged: (value) => value == null
                  ? null
                  : ref
                        .read(settingsControllerProvider.notifier)
                        .setLocale(value),
              child: Column(
                children: [
                  for (final locale in AppLocalizations.supportedLocales)
                    RadioListTile<Locale>(
                      value: locale,
                      title: Text(_languageName(locale.languageCode)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          _SectionLabel(l10n.profileAbout),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: AppIcons.info,
                  label: l10n.profileVersion,
                  value: '${config.flavor} · 0.1.0',
                ),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(
                  icon: AppIcons.settings,
                  label: 'Server',
                  value: config.baseUrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Endonyms: a language is easiest to find written in itself.
  static String _languageName(String code) => switch (code) {
    'ru' => 'Русский',
    'kk' => 'Қазақша',
    _ => 'English',
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: AppIconSize.small, color: theme.colorScheme.outline),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
