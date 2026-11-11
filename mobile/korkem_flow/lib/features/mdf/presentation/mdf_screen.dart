import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One door in the sidebar for everything the facade shop does.
///
/// The owner runs MDF orders from one window in OnayBaza. Here the same work
/// was spread across settings, the workstations and buttons inside other
/// screens, so nobody found it (31.10.2026: «что касается МДФ — перенести
/// туда в отдельный блок»). This screen moves nothing: every row opens the
/// screen that already exists, at the route it already has, and the old
/// entry points keep working.
class MdfScreen extends StatelessWidget {
  const MdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <_MdfRow>[
      _MdfRow(
        'orders',
        AppIcons.deal,
        l10n.mdfOrders,
        l10n.mdfOrdersHint,
        Routes.mdfOrders,
      ),
      // «Отдел плёнки» — a department of its own (owner, 10.11.2026): it buys
      // film from wholesalers and sells it by the metre.
      _MdfRow(
        'filmDept',
        AppIcons.warehouse,
        l10n.filmDeptTitle,
        l10n.filmDeptHint,
        Routes.filmDept,
      ),
      _MdfRow(
        'quote',
        AppIcons.quote,
        l10n.facadeQuoteTitle,
        l10n.mdfQuoteHint,
        Routes.facadeQuote,
      ),
      _MdfRow(
        'jobs',
        AppIcons.task,
        l10n.facadeJobsTitle,
        l10n.mdfJobsHint,
        Routes.facadeJobs,
      ),
      _MdfRow(
        'press',
        AppIcons.pressLayout,
        l10n.mdfPress,
        l10n.mdfPressHint,
        Routes.pressSettings,
      ),
      _MdfRow(
        'stock',
        AppIcons.material,
        l10n.materialStockTitle,
        l10n.mdfStockHint,
        Routes.materialStock,
      ),
      _MdfRow(
        'plan',
        AppIcons.task,
        l10n.mdfPlanTitle,
        l10n.mdfPlanHint,
        Routes.mdfPlan,
      ),
      _MdfRow(
        'tv',
        AppIcons.tv,
        l10n.mdfTvTitle,
        l10n.mdfTvHint,
        Routes.mdfTv,
      ),
      _MdfRow(
        'batch',
        AppIcons.pressLayout,
        l10n.mdfBatchTitle,
        l10n.mdfBatchHint,
        Routes.mdfBatch,
      ),
      _MdfRow(
        'cash',
        AppIcons.payroll,
        l10n.mdfCashTitle,
        l10n.mdfCashHint,
        Routes.mdfCash,
      ),
      _MdfRow(
        'report',
        AppIcons.report,
        l10n.mdfReportTitle,
        l10n.mdfReportHint,
        Routes.mdfReport,
      ),
      _MdfRow(
        'volume',
        AppIcons.team,
        l10n.mdfVolumeTitle,
        l10n.mdfVolumeHint,
        Routes.mdfVolume,
      ),
      _MdfRow(
        'debts',
        AppIcons.payroll,
        l10n.mdfDebtsTitle,
        l10n.mdfDebtsHint,
        Routes.mdfDebts,
      ),
      _MdfRow(
        'film',
        AppIcons.material,
        l10n.filmShortageTitle,
        l10n.mdfFilmHint,
        Routes.mdfFilm,
      ),
      _MdfRow(
        'logistics',
        AppIcons.delivery,
        l10n.logisticsTitle,
        l10n.mdfLogisticsHint,
        Routes.logistics,
      ),
      _MdfRow(
        'dictionaries',
        AppIcons.dictionary,
        l10n.mdfDictTitle,
        l10n.mdfDictHint,
        Routes.mdfDictionaries,
      ),
      _MdfRow(
        'prices',
        AppIcons.payroll,
        l10n.facadePricesTitle,
        l10n.mdfPricesHint,
        Routes.facadePrices,
      ),
    ];
    // In groups (owner, 12.11.2026): seventeen rows in one list were too
    // long to find anything in.
    const groups = {
      'orders': 0,
      'quote': 0,
      'filmDept': 0,
      'cash': 0,
      'debts': 0,
      'report': 0,
      'volume': 0,
      'jobs': 1,
      'plan': 1,
      'press': 1,
      'tv': 1,
      'batch': 1,
      'stock': 2,
      'film': 2,
      'logistics': 2,
      'dictionaries': 3,
      'prices': 3,
    };
    final titles = [
      l10n.mdfGroupSales,
      l10n.mdfGroupShop,
      l10n.mdfGroupStock,
      l10n.mdfGroupSettings,
    ];
    final children = <Widget>[];
    for (var g = 0; g < titles.length; g++) {
      final inGroup = [
        for (final row in rows)
          if ((groups[row.id] ?? 3) == g) row,
      ];
      if (inGroup.isEmpty) continue;
      children.add(
        ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: SectionLabel(titles[g]),
          ),
        ),
      );
      for (final row in inGroup) {
        children.add(_tile(context, row));
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMdf)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: children,
      ),
    );
  }

  Widget _tile(BuildContext context, _MdfRow row) => ReadableWidth(
    child: Card(
      child: ListTile(
        key: ValueKey('mdf:${row.id}'),
        leading: Icon(row.icon),
        title: Text(row.title),
        subtitle: Text(row.hint),
        trailing: const Icon(AppIcons.forward),
        onTap: () => context.push(row.path),
      ),
    ),
  );
}

class _MdfRow {
  const _MdfRow(this.id, this.icon, this.title, this.hint, this.path);

  final String id;
  final IconData icon;
  final String title;
  final String hint;
  final String path;
}
