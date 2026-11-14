import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_tags.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String mdfOrderTagLabel(MdfOrderTag tag, AppLocalizations l10n) =>
    switch (tag) {
      MdfOrderTag.urgent => l10n.mdfTagUrgent,
      MdfOrderTag.rework => l10n.mdfTagRework,
      MdfOrderTag.warranty => l10n.mdfTagWarranty,
      MdfOrderTag.clientPaint => l10n.mdfTagClientPaint,
      MdfOrderTag.clientParts => l10n.mdfTagClientParts,
    };

String mdfCustomerTagLabel(MdfCustomerTag tag, AppLocalizations l10n) =>
    switch (tag) {
      MdfCustomerTag.vip => l10n.mdfTagVip,
      MdfCustomerTag.furnitureMaker => l10n.mdfTagFurnitureMaker,
      MdfCustomerTag.newcomer => l10n.mdfTagNew,
      MdfCustomerTag.prepayOnly => l10n.mdfTagPrepayOnly,
    };

StatusIntent _orderIntent(MdfOrderTag tag) => switch (tag) {
  MdfOrderTag.urgent => StatusIntent.danger,
  MdfOrderTag.rework || MdfOrderTag.warranty => StatusIntent.warning,
  MdfOrderTag.clientPaint || MdfOrderTag.clientParts => StatusIntent.info,
};

StatusIntent _customerIntent(MdfCustomerTag tag) => switch (tag) {
  MdfCustomerTag.vip => StatusIntent.success,
  MdfCustomerTag.prepayOnly => StatusIntent.warning,
  MdfCustomerTag.furnitureMaker || MdfCustomerTag.newcomer => StatusIntent.info,
};

/// An order's and its customer's tags, as small chips.
class MdfTagBadges extends StatelessWidget {
  const MdfTagBadges({
    this.orderTags = const [],
    this.customerTags = const [],
    super.key,
  });

  final List<MdfOrderTag> orderTags;
  final List<MdfCustomerTag> customerTags;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final t in orderTags)
          StatusChip(
            key: ValueKey('mdfTag:${t.wire}'),
            label: mdfOrderTagLabel(t, l10n),
            intent: _orderIntent(t),
            compact: true,
          ),
        for (final t in customerTags)
          StatusChip(
            key: ValueKey('mdfCustomerTag:${t.wire}'),
            label: mdfCustomerTagLabel(t, l10n),
            intent: _customerIntent(t),
            compact: true,
          ),
      ],
    );
  }
}
