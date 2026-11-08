import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String mdfCoatingLabel(MdfCoating coating, AppLocalizations l10n) =>
    switch (coating) {
      MdfCoating.pvc => l10n.mdfCoatingPvc,
      MdfCoating.paint => l10n.mdfCoatingPaint,
      MdfCoating.raw => l10n.mdfCoatingRaw,
    };

/// The list a coating's colours come from; a raw facade has none.
MdfDictKind? mdfCoatingList(MdfCoating coating) => switch (coating) {
  MdfCoating.pvc => MdfDictKind.decor,
  MdfCoating.paint => MdfDictKind.paint,
  MdfCoating.raw => null,
};

/// «ПВХ · Графит», «Краска · RAL 9010», «Черновой» — a group by name.
String mdfGroupName(
  MdfCoating? coating,
  String? film,
  AppLocalizations l10n,
) => [
  if (coating != null) mdfCoatingLabel(coating, l10n),
  ?film,
].join(' · ');
