import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/logistics/data/logistics_repository.dart';
import 'package:korkem_flow/features/logistics/domain/logistics.dart';
import 'package:korkem_flow/features/logistics/presentation/delivery_form.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

NumberFormat _money(BuildContext context) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol: '₸',
  decimalDigits: 0,
);

String _plain(BuildContext context, double value) => NumberFormat(
  '0.##',
  Localizations.localeOf(context).toLanguageTag(),
).format(value);

/// «Логистика»: what bringing material in cost, kept apart from the material.
/// A month at a time — its deliveries, and what they add up to.
class LogisticsScreen extends ConsumerStatefulWidget {
  const LogisticsScreen({super.key});

  @override
  ConsumerState<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends ConsumerState<LogisticsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _key => monthKey(_month);

  void _shift(int months) => setState(
    () => _month = DateTime(_month.year, _month.month + months),
  );

  void _refresh() {
    ref
      ..invalidate(deliveriesProvider(_key))
      ..invalidate(logisticsSummaryProvider(_key))
      ..invalidate(logisticsSuggestionsProvider);
  }

  Future<void> _add([DeliveryDraft? draft]) async {
    if (await showDeliveryForm(context, draft: draft)) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final month = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_month);
    final picker = Row(
      children: [
        IconButton(
          key: const ValueKey('logisticsPrev'),
          tooltip: l10n.payrollPrevMonth,
          icon: const Icon(AppIcons.back),
          onPressed: () => _shift(-1),
        ),
        Expanded(
          child: Text(
            month,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('logisticsNext'),
          tooltip: l10n.payrollNextMonth,
          icon: const Icon(AppIcons.forward),
          onPressed: () => _shift(1),
        ),
      ],
    );
    return AppScreen.tabbed(
      title: l10n.logisticsTitle,
      actions: [
        IconButton(
          key: const ValueKey('logisticsAdd'),
          tooltip: l10n.logisticsAdd,
          icon: const Icon(AppIcons.add),
          onPressed: _add,
        ),
      ],
      tabs: [
        AppTab(
          label: l10n.logisticsDeliveries,
          view: _Deliveries(month: _key, picker: picker, onChanged: _refresh),
        ),
        AppTab(
          label: l10n.logisticsSummary,
          view: _Summary(month: _key, picker: picker, onWrite: _add),
        ),
      ],
    );
  }
}

class _Deliveries extends ConsumerWidget {
  const _Deliveries({
    required this.month,
    required this.picker,
    required this.onChanged,
  });

  final String month;
  final Widget picker;
  final VoidCallback onChanged;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Delivery row,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref.read(logisticsRepositoryProvider).cancel(row.delivery, reason);
      onChanged();
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final theme = Theme.of(context);
    return ref
        .watch(deliveriesProvider(month))
        .when(
          loading: () => const ListSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(deliveriesProvider(month)),
          ),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              picker,
              if (rows.isEmpty)
                EmptyView(
                  icon: AppIcons.delivery,
                  title: l10n.logisticsEmpty,
                  message: l10n.logisticsEmptyMessage,
                ),
              for (final row in rows)
                Card(
                  key: ValueKey('delivery:${row.delivery}'),
                  child: ListTile(
                    leading: const Icon(AppIcons.delivery),
                    title: Text(
                      '${row.category} · ${row.fromCity} · ${row.transport}',
                    ),
                    subtitle: Text(
                      [
                        row.deliveredOn,
                        if (row.what != null) row.what!,
                        if (row.qty != null)
                          '${_plain(context, row.qty!)} ${row.unit ?? ''}',
                        if (row.salesOrder != null) '№${row.salesOrder}',
                        if (row.carrier != null) row.carrier!,
                        if (row.days != null) l10n.logisticsDays(row.days!),
                        if (row.urgent) l10n.logisticsUrgent,
                      ].join(' · '),
                    ),
                    trailing: Text(
                      money.format(row.amount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onLongPress: () => _cancel(context, ref, row),
                  ),
                ),
            ],
          ),
        );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({
    required this.month,
    required this.picker,
    required this.onWrite,
  });

  final String month;
  final Widget picker;
  final ValueChanged<DeliveryDraft> onWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    final theme = Theme.of(context);
    List<Widget> section(String title, List<LogisticsGroup> groups) => [
      if (groups.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(title),
        for (final g in groups)
          ListTile(
            key: ValueKey('logisticsGroup:$title:${g.name}'),
            dense: true,
            title: Text(g.name),
            subtitle: Text(
              [
                l10n.logisticsCount(g.count),
                if (g.averageDays != null)
                  l10n.logisticsAverageDays(_plain(context, g.averageDays!)),
              ].join(' · '),
            ),
            trailing: Text(money.format(g.amount)),
          ),
      ],
    ];
    return ref
        .watch(logisticsSummaryProvider(month))
        .when(
          loading: () => const ListSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(logisticsSummaryProvider(month)),
          ),
          data: (s) => ListView(
            key: const ValueKey('logisticsSummaryList'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              picker,
              Text(
                l10n.logisticsTotal(money.format(s.total)),
                key: const ValueKey('logisticsTotal'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.logisticsPrevious(money.format(s.previousTotal)),
                style: theme.textTheme.bodyMedium,
              ),
              if (s.urgentCount > 0)
                Text(
                  l10n.logisticsUrgentLine(
                    s.urgentCount,
                    money.format(s.urgentAmount),
                  ),
                ),
              ...section(l10n.logisticsByCategory, s.byCategory),
              if (s.perUnit.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                SectionLabel(l10n.logisticsPerUnit),
                for (final p in s.perUnit)
                  ListTile(
                    key: ValueKey('logisticsPerUnit:${p.category}:${p.unit}'),
                    dense: true,
                    title: Text(p.category),
                    subtitle: Text(
                      l10n.logisticsPerUnitLine(
                        money.format(p.perUnit),
                        p.unit,
                        _plain(context, p.qty),
                      ),
                    ),
                    trailing: Text(money.format(p.amount)),
                  ),
              ],
              ...section(l10n.logisticsByCity, s.byCity),
              ...section(l10n.logisticsByTransport, s.byTransport),
              ...section(l10n.logisticsByCarrier, s.byCarrier),
              if (s.unlinked.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                SectionLabel(l10n.logisticsUnlinked),
                Text(
                  l10n.logisticsUnlinkedHint,
                  style: theme.textTheme.bodySmall,
                ),
                for (final r in s.unlinked)
                  ListTile(
                    key: ValueKey('logisticsUnlinked:${r.receipt}'),
                    dense: true,
                    title: Text(r.title ?? r.receipt),
                    subtitle: Text(
                      [
                        r.date,
                        if (r.qty != null)
                          '${_plain(context, r.qty!)} ${r.unit ?? ''}',
                      ].join(' · '),
                    ),
                    trailing: TextButton(
                      key: ValueKey('logisticsWrite:${r.receipt}'),
                      onPressed: () => onWrite((
                        receipt: r.receipt,
                        category: null,
                        what: r.title,
                        qty: r.qty,
                        unit: r.unit,
                      )),
                      child: Text(l10n.logisticsWrite),
                    ),
                  ),
              ],
            ],
          ),
        );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.logisticsCancel),
      content: TextField(
        key: const ValueKey('deliveryCancelReason'),
        controller: _reason,
        decoration: InputDecoration(labelText: l10n.logisticsCancelReason),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('deliveryCancelConfirm'),
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: Text(l10n.logisticsCancel),
        ),
      ],
    );
  }
}

/// Settings row leading to «Логистика». Drawn only for the people the server
/// lets in — managers and accounting; for anybody else, nothing.
class LogisticsTile extends ConsumerWidget {
  const LogisticsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(logisticsSuggestionsProvider).value == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ListTile(
        key: const ValueKey('logisticsSettings'),
        leading: const Icon(AppIcons.delivery),
        title: Text(l10n.logisticsTitle),
        subtitle: Text(l10n.logisticsEmptyMessage),
        trailing: const Icon(AppIcons.forward),
        onTap: () => context.push(Routes.logistics),
      ),
    );
  }
}
