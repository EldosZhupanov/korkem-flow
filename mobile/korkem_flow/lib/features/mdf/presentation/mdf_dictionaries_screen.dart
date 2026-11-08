import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_customers_dialog.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dictionary_dialog.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The name of one list, as the order form labels its drop-down.
String mdfDictLabel(MdfDictKind kind, AppLocalizations l10n) => switch (kind) {
  MdfDictKind.material => l10n.mdfMaterial,
  MdfDictKind.thickness => l10n.mdfThicknessShort,
  MdfDictKind.finish => l10n.mdfFinish,
  MdfDictKind.decor => l10n.mdfDictDecor,
  MdfDictKind.patina => l10n.mdfPatina,
  MdfDictKind.milling => l10n.mdfMilling,
  MdfDictKind.edge => l10n.mdfColEdge,
  MdfDictKind.bank => l10n.mdfDictBank,
};

/// «Справочники»: every list of the order form in one place.
class MdfDictionariesScreen extends ConsumerWidget {
  const MdfDictionariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dicts =
        ref.watch(mdfDictionariesProvider).value ?? MdfDictionaries.empty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mdfDictTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ReadableWidth(
            child: ListTile(
              key: const ValueKey('dictList:customer'),
              leading: const Icon(AppIcons.dictionary),
              title: Text(l10n.mdfCustomers),
              onTap: () => showMdfCustomers(context),
            ),
          ),
          // Thickness has its own list again (09.11.2026), banks too.
          for (final kind in MdfDictKind.values)
            ReadableWidth(
              child: ListTile(
                key: ValueKey('dictList:${kind.name}'),
                leading: const Icon(AppIcons.dictionary),
                title: Text(mdfDictLabel(kind, l10n)),
                subtitle: Text(
                  dicts.values(kind).take(4).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${dicts.entries(kind).length}'),
                onTap: () => showMdfDictionary(
                  context,
                  kind,
                  title: mdfDictLabel(kind, l10n),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
