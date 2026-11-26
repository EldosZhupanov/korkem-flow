import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/features/team/presentation/people_money_actions.dart';
import 'package:korkem_flow/features/team/presentation/people_period.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Below this width a person's money is two lines, not six columns.
const double _tableWidth = 560;

String payKindLabel(PersonAdjustmentKind kind, AppLocalizations l10n) =>
    switch (kind) {
      PersonAdjustmentKind.advance => l10n.pplAdvance,
      PersonAdjustmentKind.fine => l10n.pplFineOne,
      PersonAdjustmentKind.bonus => l10n.pplBonusOne,
    };

/// «Деньги» (owner, 26.11.2026): everyone's month in one list — earned,
/// taken in advance, fined, still to give — with «Отдать» once the month is
/// over and «Да» / «Нет» for what waits. Replaces the separate «Ведомость».
class PeopleMoneyView extends StatelessWidget {
  const PeopleMoneyView({
    required this.report,
    required this.day,
    required this.today,
    super.key,
  });

  final PeopleReport report;

  /// A day in the month shown.
  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = peopleMoney(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final paid = [
      for (final p in report.people)
        if (p.money != null) p,
    ]..sort((a, b) => b.money!.left.compareTo(a.money!.left));
    final noLogin = [
      for (final p in report.people)
        if (p.money == null) p,
    ];
    final monthOver = DateTime(
      day.year,
      day.month + 1,
      0,
    ).isBefore(DateTime(today.year, today.month, today.day));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        if (report.canAdjust) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('ppl:addMoney'),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.pplAddMoney),
              onPressed: () => unawaited(
                showPayEntryDialog(context, people: report.people),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        FigureRow(
          tiles: [
            FigureTile(
              id: 'ppl:money:earned',
              title: l10n.pplEarnedAll,
              value: money.format(report.earned),
            ),
            FigureTile(
              id: 'ppl:money:advance',
              title: l10n.pplAdvanceAll,
              value: money.format(report.advance),
            ),
            FigureTile(
              id: 'ppl:money:left',
              title: l10n.pplLeftAll,
              value: money.format(report.left),
            ),
          ],
        ),
        if (report.pending.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Waiting(pending: report.pending),
        ],
        if (!monthOver) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.pplPayLater, key: const ValueKey('ppl:payLater'), style: muted),
        ],
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= _tableWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) const _Head(),
                for (final p in paid)
                  _MoneyRow(
                    person: p,
                    wide: wide,
                    canPay: report.canPay,
                    day: day,
                  ),
                for (final p in noLogin)
                  Padding(
                    key: ValueKey('ppl:money:none:${p.employee}'),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      '${p.name} — ${l10n.pplNoLoginMoney}',
                      style: muted,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.pending});

  final List<PayWaiting> pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = peopleMoney(context);
    final warning = context.statusColors.warning;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: warning),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.pplWaiting,
              style: theme.textTheme.titleSmall?.copyWith(color: warning),
            ),
            for (final w in pending)
              Padding(
                key: ValueKey('ppl:waiting:${w.adjustment}'),
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${payKindLabel(w.kind, l10n)} · ${w.name} · '
                            '${money.format(w.amount)}',
                          ),
                          Text(
                            [
                              ?w.reason,
                              if (w.by case final by?) l10n.pplWaitingBy(by),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (w.canApprove) ...[
                      TextButton(
                        key: ValueKey('ppl:no:${w.adjustment}'),
                        onPressed: () =>
                            unawaited(cancelPay(context, w.adjustment)),
                        child: Text(l10n.pplNo),
                      ),
                      FilledButton.tonal(
                        key: ValueKey('ppl:yes:${w.adjustment}'),
                        onPressed: () =>
                            unawaited(approvePay(context, w.adjustment)),
                        child: Text(l10n.pplYes),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget cell(String text) => Expanded(
      child: Text(text, textAlign: TextAlign.end, style: style),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(l10n.pplColWho, style: style)),
          cell(l10n.pplColEarned),
          cell(l10n.pplColAdvance),
          cell(l10n.pplColFine),
          cell(l10n.pplColGive),
          const SizedBox(width: AppSpacing.xxxl * 2),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.person,
    required this.wide,
    required this.canPay,
    required this.day,
  });

  final PersonRow person;
  final bool wide;
  final bool canPay;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = peopleMoney(context);
    final m = person.money!;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final owes = m.left < 0;
    final give = Text(
      money.format(m.left),
      key: ValueKey('ppl:give:${person.employee}'),
      textAlign: TextAlign.end,
      style: theme.textTheme.titleSmall?.copyWith(
        color: owes ? context.statusColors.danger : null,
      ),
    );
    final Widget action;
    if (canPay && m.left > 0) {
      action = OutlinedButton(
        key: ValueKey('ppl:pay:${person.employee}'),
        onPressed: () => unawaited(
          giveMonthPay(
            context,
            user: person.user!,
            name: person.name,
            amount: m.left,
            day: day,
          ),
        ),
        child: Text(l10n.pplGive),
      );
    } else if (owes) {
      action = Text(
        l10n.pplOwes,
        textAlign: TextAlign.center,
        style: muted?.copyWith(color: context.statusColors.danger),
      );
    } else if (m.paid > 0 && m.left == 0) {
      action = Text(
        l10n.pplGiven,
        textAlign: TextAlign.center,
        style: muted?.copyWith(color: context.statusColors.success),
      );
    } else {
      action = const SizedBox.shrink();
    }
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(person.name, style: theme.textTheme.titleSmall),
        if (person.posts.isNotEmpty)
          Text(person.posts.join(', '), style: muted),
      ],
    );
    String sum(double v) => v == 0 ? '—' : money.format(v);
    Widget cell(double v) =>
        Expanded(child: Text(sum(v), textAlign: TextAlign.end));
    return InkWell(
      key: ValueKey('ppl:money:${person.employee}'),
      onTap: () => context.push(Routes.person(person.employee)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: wide
            ? Row(
                children: [
                  Expanded(flex: 2, child: name),
                  cell(m.earned),
                  cell(m.advance),
                  cell(m.fine),
                  Expanded(child: give),
                  SizedBox(
                    width: AppSpacing.xxxl * 2,
                    child: Align(alignment: Alignment.centerRight, child: action),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        name,
                        Text(
                          [
                            '${l10n.pplColEarned} ${sum(m.earned)}',
                            '${l10n.pplColAdvance} ${sum(m.advance)}',
                            if (m.fine > 0)
                              '${l10n.pplColFine} ${sum(m.fine)}',
                          ].join(' · '),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [give, action],
                  ),
                ],
              ),
      ),
    );
  }
}
