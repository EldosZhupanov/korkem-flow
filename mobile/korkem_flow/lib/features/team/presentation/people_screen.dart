import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/figure_tile.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
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

/// «Раскрой» for `cut`; a stage this app does not know, as the server said it.
String peopleStageLabel(String stage, AppLocalizations l10n) {
  final known = MdfStage.values.asNameMap()[stage];
  return known == null ? stage : mdfStageLabel(known, l10n);
}

/// «Сотрудники» (owner, 25.11.2026): everyone for a day, a week or a month —
/// post, what he did, days with work, what he earned, took and is owed.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key, this.today});

  final DateTime? today;

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  PeopleSpan _span = PeopleSpan.month;
  late DateTime _day = _today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = (span: _span, day: peopleIso(_day));
    final report = ref.watch(peopleReportProvider(query));
    return AppScreen(
      title: l10n.pplTitle,
      subtitle: l10n.pplSubtitle,
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
                      child: _Body(report: r, query: query),
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
    final work = person.stages.isEmpty
        ? l10n.pplNothing
        : '${peopleStagesLine(context, person.stages, l10n)}'
              '   ·   ${l10n.pplDays}: ${person.days}';
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
