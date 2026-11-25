import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/charts/bar_rows.dart';
import 'package:korkem_flow/core/design/widgets/charts/flow_bars.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/features/team/presentation/people_period.dart';
import 'package:korkem_flow/features/team/presentation/people_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// One person's card: what he did and when, what he earned, what he took
/// as an advance, what he was fined, what was paid out. [employee] null —
/// the one looking, his own («Мой заработок»).
class PersonCardScreen extends ConsumerStatefulWidget {
  const PersonCardScreen({
    this.employee,
    this.span = PeopleSpan.month,
    this.day,
    this.today,
    super.key,
  });

  final String? employee;
  final PeopleSpan span;
  final DateTime? day;
  final DateTime? today;

  @override
  ConsumerState<PersonCardScreen> createState() => _PersonCardScreenState();
}

class _PersonCardScreenState extends ConsumerState<PersonCardScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late PeopleSpan _span = widget.span;
  late DateTime _day = widget.day ?? _today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = (
      employee: widget.employee,
      span: _span,
      day: peopleIso(_day),
    );
    final card = ref.watch(personCardProvider(query));
    final row = card.value?.row;
    return AppScreen(
      title: row?.name ?? (widget.employee == null ? l10n.pplMine : ''),
      subtitle: row == null || row.posts.isEmpty ? null : row.posts.join(', '),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: PeoplePeriodBar(
              span: _span,
              day: _day,
              today: _today,
              onChanged: (span, day) => setState(() {
                _span = span;
                _day = day;
              }),
            ),
          ),
          Expanded(
            child: card.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(personCardProvider(query)),
              ),
              data: (c) => RefreshIndicator(
                onRefresh: () => ref.refresh(personCardProvider(query).future),
                child: _CardBody(card: c, span: _span),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBody extends StatefulWidget {
  const _CardBody({required this.card, required this.span});

  final PersonCard card;
  final PeopleSpan span;

  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  int? _day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = peopleMoney(context);
    final c = widget.card;
    final row = c.row;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final day = _day != null && _day! < c.days.length ? c.days[_day!] : null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        FigureRow(
          tiles: [
            FigureTile(
              id: 'card:m2',
              title: l10n.pplM2,
              value: peopleM2(context, row.m2),
              note: '${l10n.pplStages}: ${row.stagesDone}',
            ),
            FigureTile(
              id: 'card:days',
              title: l10n.pplDays,
              value: '${row.days}',
              note: '${l10n.pplOrders}: ${row.orders}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.pplMoney),
        if (row.money case final m?) ...[
          FigureRow(
            tiles: [
              FigureTile(
                id: 'card:earned',
                title: l10n.pplEarned,
                value: money.format(m.earned),
                note: m.pending > 0
                    ? '${l10n.pplPending}: ${money.format(m.pending)}'
                    : null,
              ),
              FigureTile(
                id: 'card:advance',
                title: l10n.pplAdvance,
                value: money.format(m.advance),
                note: m.fine > 0
                    ? '${l10n.pplFine}: ${money.format(m.fine)}'
                    : null,
              ),
              FigureTile(
                id: 'card:paid',
                title: l10n.pplPaid,
                value: money.format(m.paid),
              ),
              FigureTile(
                id: 'card:left',
                title: l10n.pplLeft,
                value: money.format(m.left),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${l10n.pplPiece} ${money.format(m.piece)}   ·   '
            '${l10n.pplBonus} ${money.format(m.bonus)}',
            key: const ValueKey('card:split'),
            style: muted,
          ),
        ] else
          Text(
            l10n.pplNoLogin,
            key: const ValueKey('card:noLogin'),
            style: muted,
          ),
        if (widget.span != PeopleSpan.day && c.days.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.pplByDay),
          FlowBars(
            key: const ValueKey('card:days'),
            bars: [
              for (final d in c.days)
                FlowBar(
                  label: widget.span == PeopleSpan.week
                      ? DateFormat.E(locale).format(DateTime.parse(d.day))
                      : '${DateTime.parse(d.day).day}',
                  up: d.m2,
                ),
            ],
            selected: _day,
            onSelect: (i) => setState(() => _day = i),
            semanticLabel: l10n.pplByDay,
          ),
          Text(
            day == null
                ? l10n.pplDayHint
                : [
                    mdfDay(day.day),
                    peopleM2(context, day.m2),
                    if (row.money != null) money.format(day.earned),
                  ].join(' · '),
            key: const ValueKey('card:day'),
            style: muted,
          ),
        ],
        if (row.stages.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.pplByStage),
          BarRows(
            key: const ValueKey('card:stages'),
            rows: [
              for (final s in row.stages)
                BarRow(
                  id: 'stage:${s.stage}',
                  label: peopleStageLabel(s.stage, l10n),
                  value: s.m2,
                  note: '${s.orders} · ${peopleM2(context, s.m2)}',
                ),
            ],
          ),
        ],
        if (c.adjustments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.pplAdjustments),
          for (final (i, a) in c.adjustments.indexed)
            _Line(
              key: ValueKey('card:adj:$i'),
              title: [
                switch (a.kind) {
                  PersonAdjustmentKind.advance => l10n.pplAdvance,
                  PersonAdjustmentKind.fine => l10n.pplFineOne,
                  PersonAdjustmentKind.bonus => l10n.pplBonusOne,
                },
                ?a.reason,
              ].join(' — '),
              subtitle: [
                mdfDay(a.on),
                if (!a.approved) l10n.pplNotApproved,
              ].join(' · '),
              trailing: money.format(a.amount),
              colour: switch (a.kind) {
                PersonAdjustmentKind.fine => context.statusColors.danger,
                PersonAdjustmentKind.bonus => context.statusColors.success,
                PersonAdjustmentKind.advance => null,
              },
            ),
        ],
        if (c.payouts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.pplPayouts),
          for (final (i, p) in c.payouts.indexed)
            _Line(
              key: ValueKey('card:payout:$i'),
              title: money.format(p.amount),
              subtitle: mdfDay(p.on),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.pplWorks),
        if (c.works.isEmpty)
          Text(
            l10n.pplNothing,
            key: const ValueKey('card:noWorks'),
            style: muted,
          )
        else
          for (final (i, w) in c.works.indexed)
            _Line(
              key: ValueKey('card:work:$i'),
              title: [
                if (w.number != null) '№${w.number}',
                ?w.customer,
              ].join(' · '),
              subtitle:
                  '${peopleStageLabel(w.stage, l10n)} · '
                  '${mdfDay(w.on, year: false)}',
              trailing: peopleM2(context, w.m2),
              // A worker sees his own work; the order card is the office's.
              onTap: c.me ? null : () => context.push(Routes.mdfOrder(w.order)),
            ),
        if (c.entries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.pplEntries),
          for (final (i, e) in c.entries.indexed)
            _Line(
              key: ValueKey('card:entry:$i'),
              title: e.operation,
              subtitle: [
                [
                  NumberFormat('0.##', locale).format(e.quantity),
                  ?e.unit,
                ].join(' '),
                mdfDay(e.on, year: false),
                if (e.pending) l10n.pplNotApproved,
              ].join(' · '),
              trailing: money.format(e.amount),
            ),
        ],
      ],
    );
  }
}

/// A plain row of a list: what, when, how much.
class _Line extends StatelessWidget {
  const _Line({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.colour,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final Color? colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: theme.textTheme.titleSmall?.copyWith(color: colour),
            ),
      onTap: onTap,
    );
  }
}
