import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/features/team/presentation/people_money_actions.dart';
import 'package:korkem_flow/features/team/presentation/people_money_view.dart';
import 'package:korkem_flow/features/team/presentation/people_period.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «раскрой 3 · 4,25 м²» for each stage a person did.
String peopleStagesLine(
  BuildContext context,
  List<PersonStage> stages,
  AppLocalizations l10n,
) => [
  for (final s in stages)
    [
      peopleStageLabel(s.stage, l10n),
      '${s.orders}',
      '·',
      peopleM2(context, s.m2),
    ].join(' '),
].join('   ');

/// The work that is not a facade stage: orders taken in, film sold,
/// deliveries received.
List<String> peopleOtherWork(
  BuildContext context,
  PersonRow person,
  AppLocalizations l10n,
) {
  final metres = NumberFormat(
    '0.#',
    Localizations.localeOf(context).toLanguageTag(),
  );
  return [
    if (person.intake case final i?)
      l10n.pplIntake(i.orders, peopleM2(context, i.m2)),
    if (person.sales case final v?)
      l10n.pplSold(metres.format(v.metres), v.sales),
    if (person.received case final n?) l10n.pplReceived(n),
  ];
}

/// «Раскрой» for `cut`; a stage this app does not know, as the server said it.
String peopleStageLabel(String stage, AppLocalizations l10n) {
  final known = MdfStage.values.asNameMap()[stage];
  return known == null ? stage : mdfStageLabel(known, l10n);
}

/// «Сотрудники» (owner, 25.11.2026): everyone for a day, a week or a month —
/// post, what he did, days with work, what he earned, took and is owed.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key, this.today, this.money = false});

  final DateTime? today;

  /// Open on «Деньги» — where «Ведомость» used to lead.
  final bool money;

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  PeopleSpan _span = PeopleSpan.month;
  late DateTime _day = _today;
  late bool _money = widget.money;

  /// Whether «Деньги» is offered: the last answer said this one sees pay.
  bool _seesPay = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Money is the month's: the tab shows the month the day is in.
    final span = _money ? PeopleSpan.month : _span;
    final query = (span: span, day: peopleIso(_day));
    final report = ref.watch(peopleReportProvider(query));
    if (report.value case final r?) _seesPay = r.seesPay;
    return AppScreen(
      title: l10n.pplTitle,
      subtitle: l10n.pplSubtitle,
      actions: [
        if (_money && _seesPay)
          IconButton(
            key: const ValueKey('ppl:excel'),
            tooltip: l10n.pplExcel,
            icon: const Icon(AppIcons.share),
            onPressed: () => unawaited(copyMonthForExcel(context, _day)),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              children: [
                if (_seesPay || _money) ...[
                  SegmentedButton<bool>(
                    key: const ValueKey('ppl:tab'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(l10n.pplWorkTab)),
                      ButtonSegment(value: true, label: Text(l10n.pplMoneyTab)),
                    ],
                    selected: {_money},
                    onSelectionChanged: (s) => setState(() => _money = s.first),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                PeoplePeriodBar(
                  span: span,
                  day: _day,
                  today: _today,
                  monthOnly: _money,
                  onChanged: (span, day) => setState(() {
                    _span = span;
                    _day = day;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(peopleReportProvider(query)),
              ),
              data: (r) => r.people.isEmpty
                  ? EmptyView(message: l10n.pplEmpty)
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(peopleReportProvider(query).future),
                      child: _money
                          ? PeopleMoneyView(report: r, day: _day, today: _today)
                          : _Body(report: r, query: query),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report, required this.query});

  final PeopleReport report;
  final PeopleQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = peopleMoney(context);
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
              id: 'ppl:total:m2',
              title: l10n.pplM2,
              value: peopleM2(context, report.m2),
              note: '${l10n.pplStages}: ${report.stagesDone}',
            ),
            if (report.seesPay) ...[
              FigureTile(
                id: 'ppl:total:earned',
                title: l10n.pplEarned,
                value: money.format(report.earned),
              ),
              FigureTile(
                id: 'ppl:total:advance',
                title: l10n.pplAdvance,
                value: money.format(report.advance),
              ),
              FigureTile(
                id: 'ppl:total:left',
                title: l10n.pplLeft,
                value: money.format(report.left),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final p in report.people) _PersonTile(person: p, query: query),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.query});

  final PersonRow person;
  final PeopleQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final money = person.money;
    final other = peopleOtherWork(context, person, l10n);
    final work = person.stages.isEmpty
        ? (other.isEmpty ? l10n.pplNothing : other.join('   ·   '))
        : [
            peopleStagesLine(context, person.stages, l10n),
            '${l10n.pplDays}: ${person.days}',
            ...other,
          ].join('   ·   ');
    return ListTile(
      key: ValueKey('ppl:person:${person.employee}'),
      contentPadding: EdgeInsets.zero,
      title: Text(person.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (person.posts.isNotEmpty) Text(person.posts.join(', ')),
          Text(work, style: muted),
        ],
      ),
      isThreeLine: person.posts.isNotEmpty,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            peopleM2(context, person.m2),
            style: theme.textTheme.titleSmall,
          ),
          if (money != null)
            Text(peopleMoney(context).format(money.earned), style: muted),
        ],
      ),
      onTap: () => context.push(
        Routes.person(person.employee, span: query.span, day: query.day),
      ),
    );
  }
}
