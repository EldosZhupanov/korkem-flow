import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/price_visibility/application/price_visibility_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Settings row: may the shop floor see prices.
///
/// Drawn only for the administrator. Everybody else gets nothing — not a
/// disabled switch — because a setting you cannot change is noise, and the
/// server refuses the change anyway.
class PriceVisibilityTile extends ConsumerWidget {
  const PriceVisibilityTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final visibility = ref.watch(priceVisibilityControllerProvider).value;
    if (visibility == null || !visibility.canChange) {
      return const SizedBox.shrink();
    }

    return Card(
      child: SwitchListTile(
        key: const ValueKey('floorSeesPrices'),
        secondary: const Icon(AppIcons.quote),
        title: Text(l10n.priceVisibilityTitle),
        subtitle: Text(l10n.priceVisibilitySubtitle),
        value: visibility.floorSeesPrices,
        onChanged: (value) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref
                .read(priceVisibilityControllerProvider.notifier)
                .setFloorSeesPrices(value: value);
          } on Object catch (_) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.priceVisibilitySaveFailed)),
            );
          }
        },
      ),
    );
  }
}
