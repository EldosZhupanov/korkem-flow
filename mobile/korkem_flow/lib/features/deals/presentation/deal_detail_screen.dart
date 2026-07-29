import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/detail_view.dart';
import 'package:korkem_flow/core/design/widgets/error_feedback.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One deal, in full.
// ignore: specify_nonobvious_property_types — the generics are right there.
final dealDetailProvider = FutureProvider.family<Deal, String>(
  (ref, id) => ref.watch(dealRepositoryProvider).fetchOne(id),
);

class DealDetailScreen extends ConsumerWidget {
  const DealDetailScreen({required this.id, super.key});

  final String id;

  Future<void> _changeStage(
    BuildContext context,
    WidgetRef ref,
    Deal deal,
  ) async {
    final l10n = AppLocalizations.of(context);
    final catalog =
        ref.read(dealStatusCatalogProvider).value ?? StatusCatalog.empty;

    // Captured before the first await: the sheet is an async gap, and the
    // element may be gone by the time it closes.
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showFilterSheet<String>(
      context: context,
      title: l10n.fieldStage,
      current: deal.status,
      options: [
        for (final status in catalog.statuses)
          FilterOption(value: status.name, label: status.name),
      ],
    );

    final next = choice?.value;
    if (next == null || next == deal.status) return;

    try {
      await ref.read(dealRepositoryProvider).updateStatus(deal.id, next);
      // The list holds a now-stale copy of this row.
      ref
        ..invalidate(dealDetailProvider(deal.id))
        ..invalidate(dealsControllerProvider);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageOf(error, l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final catalog =
        ref.watch(dealStatusCatalogProvider).value ?? StatusCatalog.empty;

    return DetailScaffold<Deal>(
      state: ref.watch(dealDetailProvider(id)),
      onRefresh: () async => ref.invalidate(dealDetailProvider(id)),
      builder: (context, deal) {
        final status = catalog.resolve(deal.status);
        final money = NumberFormat.simpleCurrency(
          locale: locale,
          name: deal.currency,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailHeader(
              heroTag: Routes.heroTag(Routes.deal(id)),
              title: deal.organization,
              subtitle: deal.id,
              statusLabel: status.name.isEmpty ? null : status.name,
              statusIntent: status.name.isEmpty ? null : status.intent,
            ),

            DetailActions(
              children: [
                ContactAction(
                  icon: AppIcons.call,
                  label: l10n.actionCall,
                  // Disabled rather than hidden: an absent phone number is
                  // itself information the salesperson needs.
                  onPressed: deal.mobileNo == null
                      ? null
                      : () => ContactActions.call(deal.mobileNo),
                ),
                ContactAction(
                  icon: AppIcons.whatsApp,
                  label: l10n.actionWhatsApp,
                  onPressed: deal.mobileNo == null
                      ? null
                      : () => ContactActions.whatsApp(deal.mobileNo),
                ),
                ContactAction(
                  icon: AppIcons.email,
                  label: l10n.actionEmail,
                  onPressed: deal.email == null
                      ? null
                      : () => ContactActions.email(deal.email),
                ),
              ],
            ),

            DetailSection(
              label: l10n.detailPipeline,
              fields: [
                DetailField(
                  icon: AppIcons.deal,
                  label: l10n.fieldStage,
                  value: status.name.isEmpty ? null : status.name,
                  onTap: () => _changeStage(context, ref, deal),
                ),
                DetailField(
                  icon: AppIcons.task,
                  label: l10n.fieldNextStep,
                  value: deal.nextStep,
                ),
                DetailField(
                  icon: AppIcons.schedule,
                  label: l10n.fieldExpectedClose,
                  value: deal.expectedClosureDate == null
                      ? null
                      : DateFormat.yMMMd(
                          locale,
                        ).format(deal.expectedClosureDate!),
                ),
                DetailField(
                  icon: AppIcons.info,
                  label: l10n.fieldProbability,
                  value: deal.probability == null
                      ? null
                      : '${deal.probability!.round()}%',
                ),
              ],
            ),

            DetailSection(
              label: l10n.detailCommercial,
              fields: [
                DetailField(
                  icon: AppIcons.quote,
                  label: l10n.fieldValue,
                  // Zero is a real value here — a deal with no amount agreed
                  // yet — so it is shown rather than suppressed.
                  value: deal.dealValue == null
                      ? null
                      : money.format(deal.dealValue),
                ),
                DetailField(
                  icon: AppIcons.lead,
                  label: l10n.fieldSource,
                  value: deal.source,
                ),
                DetailField(
                  icon: AppIcons.warehouse,
                  label: l10n.fieldTerritory,
                  value: deal.territory,
                ),
              ],
            ),

            DetailSection(
              label: l10n.detailOwnership,
              fields: [
                DetailField(
                  icon: AppIcons.profile,
                  label: l10n.fieldOwner,
                  value: deal.dealOwner,
                ),
                DetailField(
                  icon: AppIcons.lead,
                  label: l10n.fieldOriginLead,
                  value: deal.leadId,
                ),
                DetailField(
                  icon: AppIcons.refresh,
                  label: l10n.fieldUpdated,
                  value: deal.modified == null
                      ? null
                      : DateFormat.yMMMd(
                          locale,
                        ).add_Hm().format(deal.modified!),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
