import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One selectable option in a filter sheet.
@immutable
class FilterOption<T> {
  const FilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Result of a filter sheet.
///
/// A wrapper rather than a bare nullable value, so "dismissed the sheet"
/// (`null`) stays distinguishable from "chose All" (a choice holding `null`).
/// Using a real option as a sentinel would make that option unselectable — a
/// bug this type exists to prevent.
@immutable
class FilterChoice<T> {
  const FilterChoice(this.value);

  final T? value;
}

/// Generic single-select filter, presented as a bottom sheet.
///
/// A sheet rather than a dialog: filters are a routine, reversible choice, and
/// sheets stay in the thumb zone on a phone.
Future<FilterChoice<T>?> showFilterSheet<T>({
  required BuildContext context,
  required String title,
  required List<FilterOption<T>> options,
  T? current,
}) {
  return showModalBottomSheet<FilterChoice<T>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FilterSheet<T>(
      title: title,
      options: options,
      current: current,
    ),
  );
}

class _FilterSheet<T> extends StatelessWidget {
  const _FilterSheet({
    required this.title,
    required this.options,
    this.current,
  });

  final String title;
  final List<FilterOption<T>> options;
  final T? current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                  // A visible way out, not only a drag. `docs/design_system.md`
                  // §8 has required this of every sheet from the start and
                  // this one never had it: the drag handle is the affordance
                  // only for someone who already knows sheets drag, and the
                  // Android back gesture is the same bet. Someone who opened
                  // this by accident had nothing to aim at.
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    tooltip: l10n.actionClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _Tile(
                    label: l10n.actionSelectAll,
                    selected: current == null,
                    onTap: () =>
                        Navigator.of(context).pop(FilterChoice<T>(null)),
                  ),
                  for (final option in options)
                    _Tile(
                      label: option.label,
                      selected: option.value == current,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(FilterChoice<T>(option.value)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      selected: selected,
      minTileHeight: AppTouchTarget.min,
      trailing: selected
          ? Icon(AppIcons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
