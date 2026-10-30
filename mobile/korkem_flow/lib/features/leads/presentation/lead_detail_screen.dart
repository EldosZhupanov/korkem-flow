import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/crm/crm_status.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_filter_sheet.dart';
import 'package:korkem_flow/core/design/widgets/detail_view.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/leads/application/leads_controller.dart';
import 'package:korkem_flow/features/leads/domain/lead.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// ignore: specify_nonobvious_property_types — the generics are right there.
final leadDetailProvider = FutureProvider.family<Lead, String>(
  (ref, id) => ref.watch(leadRepositoryProvider).fetchOne(id),
);

class LeadDetailScreen extends ConsumerWidget {
  const LeadDetailScreen({required this.id, super.key});

  final String id;

  Future<void> _changeStage(
    BuildContext context,
    WidgetRef ref,
    Lead lead,
  ) async {
    final l10n = AppLocalizations.of(context);
    final catalog =
        ref.read(leadStatusCatalogProvider).value ?? StatusCatalog.empty;

    // Captured before the first await: the sheet is an async gap, and the
    // element may be gone by the time it closes.
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showFilterSheet<String>(
      context: context,
      title: l10n.fieldStage,
      current: lead.status,
      options: [
        for (final status in catalog.statuses)
          FilterOption(value: status.name, label: status.name),
      ],
    );

    final next = choice?.value;
    if (next == null || next == lead.status) return;

    try {
      await ref.read(leadRepositoryProvider).updateStatus(lead.id, next);
      ref
        ..invalidate(leadDetailProvider(lead.id))
        ..invalidate(leadsControllerProvider);
    } on Exception catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final catalog =
        ref.watch(leadStatusCatalogProvider).value ?? StatusCatalog.empty;

    return DetailScaffold<Lead>(
      state: ref.watch(leadDetailProvider(id)),
      onRefresh: () async => ref.invalidate(leadDetailProvider(id)),
      builder: (context, lead) {
        final status = catalog.resolve(lead.status);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailHeader(
              heroTag: Routes.heroTag(Routes.lead(id)),
              title: lead.displayName,
              subtitle: lead.jobTitle ?? lead.id,
              // A converted lead is done, whatever stage it stopped in — that
              // outranks the stage for anyone scanning the screen.
              statusLabel: lead.converted
                  ? l10n.leadConverted
                  : (status.name.isEmpty ? null : status.name),
              statusIntent: lead.converted
                  ? StatusIntent.success
                  : status.intent,
            ),

            DetailActions(
              children: [
                ContactAction(
                  icon: AppIcons.call,
                  label: l10n.actionCall,
                  onPressed: lead.mobileNo == null
                      ? null
                      : () => ContactActions.call(lead.mobileNo),
                ),
                ContactAction(
                  icon: AppIcons.whatsApp,
                  label: l10n.actionWhatsApp,
                  onPressed: lead.mobileNo == null
                      ? null
                      : () => ContactActions.whatsApp(lead.mobileNo),
                ),
                ContactAction(
                  icon: AppIcons.email,
                  label: l10n.actionEmail,
                  onPressed: lead.email == null
                      ? null
                      : () => ContactActions.email(lead.email),
                ),
              ],
            ),

            DetailSection(
              label: l10n.detailPipeline,
              fields: [
                DetailField(
                  icon: AppIcons.lead,
                  label: l10n.fieldStage,
                  value: status.name.isEmpty ? null : status.name,
                  // A converted lead's stage is history; changing it would
                  // rewrite the record of how it closed.
                  onTap: lead.converted
                      ? null
                      : () => _changeStage(context, ref, lead),
                ),
                DetailField(
                  icon: AppIcons.conversation,
                  label: l10n.fieldSource,
                  value: lead.source,
                ),
              ],
            ),

            DetailSection(
              label: l10n.detailCompany,
              fields: [
                DetailField(
                  icon: AppIcons.customer,
                  label: l10n.navCustomers,
                  value: lead.organization,
                ),
                DetailField(
                  icon: AppIcons.item,
                  label: l10n.fieldIndustry,
                  value: lead.industry,
                ),
                DetailField(
                  icon: AppIcons.warehouse,
                  label: l10n.fieldTerritory,
                  value: lead.territory,
                ),
                DetailField(
                  icon: AppIcons.info,
                  label: l10n.fieldWebsite,
                  value: lead.website,
                ),
              ],
            ),

            DetailSection(
              label: l10n.detailOwnership,
              fields: [
                DetailField(
                  icon: AppIcons.profile,
                  label: l10n.fieldOwner,
                  value: lead.leadOwner,
                ),
                DetailField(
                  icon: AppIcons.refresh,
                  label: l10n.fieldUpdated,
                  value: lead.modified == null
                      ? null
                      : DateFormat.yMMMd(
                          locale,
                        ).add_Hm().format(lead.modified!),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
