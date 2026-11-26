import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_orders_page.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_today.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Сегодня» on the home screen (owner, 27.11.2026: «открыл программу —
/// сразу видно, что горит и что делать»): four figures, the shop's load in
/// days, what to decide — the worst first — and what was just done. Each
/// leads where it is decided. Hidden for whoever may not see the facade
/// shop's figures: the server says no, and the home is as before.
class TodaySection extends ConsumerWidget {
  const TodaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(mdfTodayProvider);
    if (today.value case final value?) return _Today(t: value);
    // No access, or no server: the home as before, no spinner left behind.
    if (today.hasError) return const SizedBox.shrink();
    return const SizedBox(
      height: AppSpacing.xxxl * 3,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.t});

  final MdfToday t;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final day = DateTime.tryParse(t.day);
    void go(String route) => unawaited(context.push(route));
    Widget tile(
      String key,
      String label,
      String value,
      String note,
      Color? colour,
      VoidCallback onTap,
    ) => Expanded(
      child: Card(
        key: ValueKey('today:$key'),
        margin: const EdgeInsets.all(AppSpacing.xxs),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                Text(
                  value,
                  key: ValueKey('today:$key:value'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colour,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final tiles = [
      tile(
        'overdue',
        l10n.shopTodayOverdue,
        '${t.overdue}',
        t.decide.firstOrNull?.kind == 'jam'
            ? l10n.shopTodayOverdueAt(
                '${t.decide.first.data['title'] ?? ''}',
              )
            : l10n.shopTodayOpenList,
        t.overdue > 0 ? status.danger : null,
        () => go(Routes.mdfOrders),
      ),
      tile(
        'atRisk',
        l10n.shopTodayAtRisk,
        '${t.atRisk}',
        l10n.shopTodayAtRiskNote,
        t.atRisk > 0 ? status.warning : null,
        () => go(Routes.mdfPlan),
      ),
      tile(
        'ready',
        l10n.shopTodayReady,
        money.format(t.readyMoney),
        l10n.shopTodayReadyNote(t.ready),
        t.ready > 0 ? status.success : null,
        () => go(Routes.mdfOrders),
      ),
      tile(
        'debt',
        l10n.shopTodayDebt,
        money.format(t.debt),
        l10n.shopTodayDebtors(t.debtors),
        t.debt > 0 ? status.danger : null,
        () => go(Routes.mdfDebts),
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
    return Column(
      key: const ValueKey('today'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          day == null
              ? l10n.shopTodayTitle
              : '${l10n.shopTodayTitle} · '
                    '${DateFormat('EEEE, d MMMM', locale).format(day)}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (wide)
          Row(children: tiles)
        else ...[
          Row(children: tiles.sublist(0, 2)),
          Row(children: tiles.sublist(2)),
        ],
        const SizedBox(height: AppSpacing.sm),
        Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _wrap(wide, 3, _Decide(t: t)),
            if (wide) const SizedBox(width: AppSpacing.sm),
            _wrap(wide, 2, _Load(t: t)),
          ],
        ),
        if (t.recent.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Recent(t: t),
        ],
        // Its own room below: hidden, it takes none (the home as before).
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  static Widget _wrap(bool wide, int flex, Widget child) =>
      wide ? Expanded(flex: flex, child: child) : child;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(AppSpacing.xxs),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    ),
  );
}

/// «Нужно решить» — the worst first, each where it is decided.
class _Decide extends StatelessWidget {
  const _Decide({required this.t});

  final MdfToday t;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    String m(Object? v) =>
        (v is num ? v.toDouble() : 0.0).toStringAsFixed(1).replaceAll('.', ',');
    (IconData, Color?, String, String, VoidCallback)? row(TodayDecision d) {
      void go(String route) => unawaited(context.push(route));
      return switch (d.kind) {
        'jam' => (
          AppIcons.danger,
          status.danger,
          l10n.shopTodayDecideJam(
            '${d.data['title']}',
            m(d.data['days']),
            m(d.data['waiting_m2']),
          ),
          l10n.shopTodayGoPlan,
          () => go(Routes.mdfPlan),
        ),
        'at_risk' => (
          AppIcons.warning,
          status.warning,
          l10n.shopTodayDecideAtRisk(d.count),
          l10n.shopTodayGoPlan,
          () => go(Routes.mdfPlan),
        ),
        'film' => (
          AppIcons.textured,
          null,
          l10n.shopTodayDecideFilm(
            [
              for (final f in d.data['films'] as List? ?? const [])
                if (f is Map) '${f['decor']} ${m(f['to_buy'])} м',
            ].join(', '),
          ),
          l10n.shopTodayGoFilm,
          () => unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FilmOrdersPage()),
            ),
          ),
        ),
        'post_empty' => (
          AppIcons.team,
          status.danger,
          l10n.shopTodayDecidePostEmpty(
            '${d.data['title']}',
            (d.data['orders'] as num?)?.toInt() ?? 0,
          ),
          l10n.shopTodayGoTeam,
          () => go(Routes.team),
        ),
        'unassigned' => (
          AppIcons.team,
          null,
          l10n.shopTodayDecideUnassigned(
            d.count,
            [
              for (final s in d.data['stages'] as List? ?? const [])
                if (s is Map) '${s['title']} ${s['orders']}',
            ].join(', '),
          ),
          l10n.shopTodayGoPlan,
          () => go(Routes.mdfPlan),
        ),
        'no_prepay' => (
          AppIcons.payment,
          null,
          l10n.shopTodayDecideNoPrepay(d.count),
          l10n.shopTodayGoList,
          () => go(Routes.mdfOrders),
        ),
        _ => null,
      };
    }

    final rows = [for (final d in t.decide) ?row(d)];
    return _Panel(
      key: const ValueKey('today:decide'),
      title: l10n.shopTodayDecideTitle(rows.length),
      children: [
        if (rows.isEmpty)
          Row(
            children: [
              Icon(AppIcons.check, color: status.success),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.shopTodayAllCalm, style: theme.textTheme.bodyMedium),
            ],
          ),
        for (final (i, (icon, colour, text, go, onTap)) in rows.indexed)
          InkWell(
            key: ValueKey('today:decide:$i'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(icon, size: AppIconSize.small, color: colour),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${i + 1}. $text',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colour,
                      ),
                    ),
                  ),
                  Text(
                    '$go →',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The shop's load in days of work, stage by stage; the jam in red.
class _Load extends StatelessWidget {
  const _Load({required this.t});

  final MdfToday t;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final longest = t.load.fold<double>(
      1,
      (m, l) => (l.days ?? 0) > m ? l.days! : m,
    );
    return _Panel(
      key: const ValueKey('today:load'),
      title: l10n.shopTodayLoadTitle,
      children: [
        for (final l in t.load)
          Padding(
            key: ValueKey('today:load:${l.stage.name}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.xxxl * 2,
                  child: Text(
                    mdfStageLabel(l.stage, l10n),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: ((l.days ?? 0) / longest).clamp(0.02, 1.0),
                      minHeight: AppSpacing.sm,
                      color: l.jam
                          ? status.danger
                          : (l.days ?? 0) >= 1
                          ? status.warning
                          : status.success,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: AppSpacing.xxxl * 2.5,
                  child: Text(
                    l.nobody
                        ? l10n.shopTodayLoadNobody
                        : l10n.shopTodayLoadDays(
                            (l.days ?? 0)
                                .toStringAsFixed(1)
                                .replaceAll('.', ','),
                            l.waitingM2.round(),
                          ),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: l.nobody || l.jam ? status.danger : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          l10n.shopTodayLoadNote,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// «Только что» — the last things done, each its order a tap away.
class _Recent extends StatelessWidget {
  const _Recent({required this.t});

  final MdfToday t;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    String what(TodayRecent r) => switch (r.action) {
      'mdf.stage' when r.stage != null =>
        r.done
            ? l10n.shopTodayRecentStage(mdfStageLabel(r.stage!, l10n))
            : l10n.shopTodayRecentStageOff(mdfStageLabel(r.stage!, l10n)),
      'mdf.order_accepted' => l10n.shopTodayRecentAccepted(
        money.format(r.amount),
      ),
      'mdf.handed_over' => l10n.shopTodayRecentHandedOver,
      'mdf.order_cancelled' => l10n.shopTodayRecentCancelled,
      _ => l10n.shopTodayRecentPaid(money.format(r.amount)),
    };
    return _Panel(
      key: const ValueKey('today:recent'),
      title: l10n.mdfJustNow,
      children: [
        for (final r in t.recent)
          InkWell(
            onTap: () => unawaited(context.push(Routes.mdfOrder(r.order))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Text(
                '${r.at.length >= 16 ? r.at.substring(11, 16) : r.at} · '
                '${r.order.split('-').last} · ${what(r)} · ${r.by}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}
