import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/facade_prices/application/facade_price_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Settings row leading to the facade price matrix.
///
/// Drawn only for the people who may edit it. The shop floor is refused the
/// matrix by the server, and the row stays absent rather than leading to an
/// error screen.
class FacadePricesTile extends ConsumerWidget {
  const FacadePricesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final table = ref.watch(facadePriceControllerProvider).value;
    if (table == null || !table.canEdit) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        key: const ValueKey('facadePricesSettings'),
        leading: const Icon(AppIcons.quote),
        title: Text(l10n.facadePricesTitle),
        subtitle: Text(l10n.facadePricesSubtitle),
        trailing: const Icon(AppIcons.forward),
        onTap: () => context.push(Routes.facadePrices),
      ),
    );
  }
}
