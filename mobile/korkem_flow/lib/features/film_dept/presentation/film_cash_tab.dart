import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Касса» of the film department (owner, 11.11.2026): its own money — what
/// customers paid for film, what bringing film cost — apart from the MDF
/// cash book. Below, what is still owed back to employees and to carriers.
class FilmCashTab extends ConsumerStatefulWidget {
  const FilmCashTab({super.key});

  @override
  ConsumerState<FilmCashTab> createState() => _FilmCashTabState();
}

class _FilmCashTabState extends ConsumerState<FilmCashTab> {
  /// 0 today, 1 yesterday, 7 the week, 30 the month; a picked day wins
  /// (owner, 12.11.2026).
  int _span = 0;
  DateTime? _day;

  ({String? since, String? until}) get _period {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_day != null) return (since: mdfIso(_day!), until: mdfIso(_day!));
    return switch (_span) {
      1 => (
        since: mdfIso(today.subtract(const Duration(days: 1))),
        until: mdfIso(today.subtract(const Duration(days: 1))),
      ),
      7 => (
        since: mdfIso(today.subtract(const Duration(days: 6))),
        until: mdfIso(today),
      ),
      30 => (
        since: mdfIso(DateTime(now.year, now.month)),
        until: mdfIso(today),
      ),
      _ => (since: mdfIso(today), until: mdfIso(today)),
    };
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _settle(FilmOwed o, String method) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(filmDeptRepositoryProvider)
          .settleDelivery(o.receipt, method);
      ref.invalidate(filmCashProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final period = _period;
    final status = context.statusColors;
    return ref
        .watch(filmCashProvider(period))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(filmCashProvider(period)),
          ),
          data: (b) {
            Widget owedList(String title, List<FilmOwed> rows, String key) =>
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: theme.textTheme.titleMedium),
                    for (final o in rows)
                      ListTile(
                        key: ValueKey('filmCash:$key:${o.receipt}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          [o.who ?? '', money.format(o.amount)].join(' · '),
                        ),
                        subtitle: Text(
                          [mdfDay(o.date), ?o.supplier].join(' · '),
                        ),
                        // The carrier owed, a tap away (owner, 12.11.2026).
                        leading: o.phone == null || key != 'carrier'
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: ValueKey('filmCash:call:${o.receipt}'),
                                    icon: const Icon(AppIcons.call),
                                    onPressed: () =>
                                        ContactActions.call(o.phone),
                                  ),
                                  IconButton(
                                    key: ValueKey('filmCash:wa:${o.receipt}'),
                                    icon: const Icon(AppIcons.whatsApp),
                                    onPressed: () =>
                                        ContactActions.whatsApp(o.phone),
                                  ),
                                ],
                              ),
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('filmCash:settle:${o.receipt}'),
                          onSelected: (m) => _settle(o, m),
                          itemBuilder: (_) => [
                            for (final (m, label) in [
                              (filmCash, l10n.mdfPayCash),
                              (filmTransfer, l10n.mdfPayTransfer),
                              (filmCard, l10n.mdfPayCard),
                            ])
                              PopupMenuItem(
                                key: ValueKey('filmCash:settle:$m'),
                                value: m,
                                child: Text(l10n.filmSettleBy(label)),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              key == 'employee'
                                  ? l10n.filmGaveBack
                                  : l10n.filmPaidCarrier,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final (d, label) in [
                      (0, l10n.filmCashToday),
                      (1, l10n.filmYesterday),
                      (7, l10n.filmCashWeek),
                      (30, l10n.filmCashMonth),
                    ])
                      ChoiceChip(
                        key: ValueKey('filmCash:span:$d'),
                        label: Text(label),
                        selected: _day == null && _span == d,
                        onSelected: (_) => setState(() {
                          _day = null;
                          _span = d;
                        }),
                      ),
                    ActionChip(
                      key: const ValueKey('filmCash:day'),
                      avatar: const Icon(AppIcons.calendar),
                      label: Text(
                        _day == null ? l10n.filmArrivalPick : mdfDayOf(_day!),
                      ),
                      onPressed: _pickDay,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // In green, out in red, what is left (owner, 12.11.2026).
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CashCard(
                      key: const ValueKey('filmCash:in'),
                      label: l10n.filmCashIn,
                      value: '+${money.format(b.inTotal)}',
                      note: l10n.filmCashSales(b.sales),
                      color: status.success,
                    ),
                    _CashCard(
                      key: const ValueKey('filmCash:out'),
                      label: l10n.filmCashOut,
                      value: '−${money.format(b.outTotal)}',
                      note: l10n.filmCashSpent(b.spent),
                      color: status.danger,
                    ),
                    _CashCard(
                      key: const ValueKey('filmCash:balance'),
                      label: l10n.filmCashBalance,
                      value: money.format(b.balance),
                    ),
                  ],
                ),
                if (b.where.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.filmCashWhere, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final w in b.where)
                        _CashCard(
                          key: ValueKey('filmCash:where:${w.way}'),
                          label: w.way,
                          value: money.format(w.amount),
                          icon: w.way == filmCash
                              ? AppIcons.payroll
                              : AppIcons.bank,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(l10n.filmCashMoves, style: theme.textTheme.titleMedium),
                if (b.moves.isEmpty) Text(l10n.filmCashNothing),
                for (final m in b.moves)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      border: Border(
                        left: BorderSide(
                          color: m.incoming ? status.success : status.danger,
                          width: AppSpacing.xs,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              mdfDay(m.date, year: false),
                              ?m.at,
                              m.what,
                              ?m.way,
                            ].join(' · '),
                          ),
                        ),
                        Text(
                          '${m.incoming ? '+' : '−'}${money.format(m.amount)}',
                          style: TextStyle(
                            color: m.incoming ? status.success : status.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                // For the owner's eye: what logistics costs — not in the
                // bonus (owner, 11.11.2026).
                Text(
                  b.logisticsPerM == null
                      ? l10n.filmCashLogistics(money.format(b.logistics))
                      : l10n.filmCashLogisticsPerM(
                          money.format(b.logistics),
                          money.format(b.logisticsPerM),
                        ),
                  key: const ValueKey('filmCash:logistics'),
                  style: theme.textTheme.bodySmall,
                ),
                if (b.employees.isNotEmpty)
                  owedList(l10n.filmOwedEmployees, b.employees, 'employee'),
                if (b.carriers.isNotEmpty)
                  owedList(l10n.filmOwedCarriers, b.carriers, 'carrier'),
              ],
            );
          },
        );
  }
}

/// One figure of the cash on a card of its own — tinted when it is money
/// in or out.
class _CashCard extends StatelessWidget {
  const _CashCard({
    required this.label,
    required this.value,
    this.note,
    this.color,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final String? note;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: AppSpacing.xxxl * 4,
      child: Card(
        color: color?.withValues(alpha: AppTint.surface),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppIconSize.dense),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
