import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
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
        Routes.orders,
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
        'logistics',
        AppIcons.delivery,
        l10n.logisticsTitle,
        l10n.mdfLogisticsHint,
        Routes.logistics,
      ),
      _MdfRow(
        'prices',
        AppIcons.payroll,
        l10n.facadePricesTitle,
        l10n.mdfPricesHint,
        Routes.facadePrices,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMdf)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final row in rows)
            ReadableWidth(
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
            ),
        ],
      ),
    );
  }
}

class _MdfRow {
  const _MdfRow(this.id, this.icon, this.title, this.hint, this.path);

  final String id;
  final IconData icon;
  final String title;
  final String hint;
  final String path;
}
