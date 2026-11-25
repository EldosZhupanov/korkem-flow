import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/costs/data/costs_repository.dart';
import 'package:korkem_flow/features/costs/presentation/bills_tab.dart';
import 'package:korkem_flow/features/costs/presentation/consumables_tab.dart';
import 'package:korkem_flow/features/costs/presentation/cost_items_tab.dart';
import 'package:korkem_flow/features/costs/presentation/money_tab.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Money in tenge, whole.
NumberFormat costMoney(BuildContext context) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol: '₸',
  decimalDigits: 0,
);

/// A quantity or m²: no trailing zeros.
String costQty(double v) => NumberFormat('0.##').format(v).replaceAll('.', ',');

/// `yyyy-MM-01` of [month].
String costIso(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}-01';

/// The first day of this month.
DateTime costThisMonth([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTime(n.year, n.month);
}

/// «Расходы цеха» (owner, 25.11.2026: «куда деньги идут и тратятся»): where
/// the month's money went, the month's bills, the consumables on the shelf,
/// and the cost items he keeps. The floor sees only the consumables — to
/// take one, and to add one that is not in the list.
class CostsScreen extends ConsumerStatefulWidget {
  const CostsScreen({super.key, this.today});

  /// Fixed in tests; the device's date otherwise.
  final DateTime? today;

  @override
  ConsumerState<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends ConsumerState<CostsScreen> {
  late DateTime _month = costThisMonth(widget.today);

  void _shift(int months) => setState(
    () => _month = DateTime(_month.year, _month.month + months),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shelf = ref.watch(consumablesProvider);
    return shelf.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.cstTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.cstTitle)),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(consumablesProvider),
        ),
      ),
      data: (s) => s.canReceive
          ? _owner(context, l10n)
          : Scaffold(
              appBar: AppBar(title: Text(l10n.cstTabConsumables)),
              body: const ConsumablesTab(),
            ),
    );
  }

  Widget _owner(BuildContext context, AppLocalizations l10n) {
    final now = costThisMonth(widget.today);
    final month = _MonthBar(
      month: _month,
      onPrevious: () => _shift(-1),
      onNext: _month.isBefore(now) ? () => _shift(1) : null,
    );
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.cstTitle),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: const ValueKey('cst:tab:money'), text: l10n.cstTabMoney),
              Tab(key: const ValueKey('cst:tab:bills'), text: l10n.cstTabBills),
              Tab(
                key: const ValueKey('cst:tab:consumables'),
                text: l10n.cstTabConsumables,
              ),
              Tab(key: const ValueKey('cst:tab:items'), text: l10n.cstTabItems),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MoneyTab(month: costIso(_month), header: month),
            BillsTab(month: costIso(_month), header: month),
            const ConsumablesTab(),
            const CostItemsTab(),
          ],
        ),
      ),
    );
  }
}

/// ‹ ноябрь 2026 › — the month the first two tabs show.
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(month);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const ValueKey('cst:prevMonth'),
          tooltip: l10n.cstPrevMonth,
          onPressed: onPrevious,
          icon: const Icon(AppIcons.previous),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            label,
            key: const ValueKey('cst:month'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('cst:nextMonth'),
          tooltip: l10n.cstNextMonth,
          onPressed: onNext,
          icon: const Icon(AppIcons.forward),
        ),
      ],
    );
  }
}
