import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';
import 'package:korkem_flow/features/team/domain/team_moves.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
import 'package:korkem_flow/features/team/presentation/team_actions.dart';
import 'package:korkem_flow/features/team/presentation/team_departments_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// His posts on his card: taken off with ×, another given with
/// «+ должность» — for those who run the team; read-only for the rest.
class PersonCardPosts extends ConsumerWidget {
  const PersonCardPosts({required this.card, super.key});

  final PersonCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final team = card.canEdit && !card.me && card.active
        ? ref.watch(teamPeopleProvider).value
        : null;
    final person = team?.people
        .where((p) => p.employee == card.row.employee)
        .firstOrNull;
    final edit = switch ((team, person)) {
      (final TeamPeople t, final TeamPerson p) when t.canEdit => (
        team: t,
        person: p,
      ),
      _ => null,
    };
    if (card.postKeys.isEmpty && edit == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final post in card.postKeys)
            InputChip(
              key: ValueKey('card:post:$post'),
              label: Text(teamPostLabel(post, l10n)),
              onDeleted: edit == null
                  ? null
                  : () => unawaited(
                      _take(context, edit.team, edit.person, post),
                    ),
            ),
          if (edit != null)
            ActionChip(
              key: const ValueKey('card:givePost'),
              avatar: const Icon(AppIcons.add),
              label: Text(l10n.tmAddPost),
              onPressed: () async {
                final c = ProviderScope.containerOf(context, listen: false);
                final post = await pickTeamPost(
                  context,
                  edit.team,
                  edit.person,
                );
                if (post != null && context.mounted) {
                  await teamGivePost(context, edit.person, post);
                  c.invalidate(personCardProvider);
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _take(
    BuildContext context,
    TeamPeople team,
    TeamPerson person,
    String post,
  ) async {
    final c = ProviderScope.containerOf(context, listen: false);
    await teamTakePost(context, team, person, post);
    c.invalidate(personCardProvider);
  }
}

/// The card's end: what happened to him on the team, and «Уволен» or
/// «Вернуть в команду».
class PersonCardHistory extends ConsumerWidget {
  const PersonCardHistory({required this.card, super.key});

  final PersonCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final team = card.canEdit && !card.me
        ? ref.watch(teamPeopleProvider).value
        : null;
    final person = team?.people
        .where((p) => p.employee == card.row.employee)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.tmHistory),
          for (final (i, e) in card.history.indexed)
            ListTile(
              key: ValueKey('card:event:$i'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_event(e, l10n)),
              subtitle: Text(
                [mdfDay(e.on), ?e.by].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        if (team != null && person != null && team.canEdit) ...[
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: card.active
                ? OutlinedButton(
                    key: const ValueKey('card:dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => unawaited(_dismiss(context, team, person)),
                    child: Text(l10n.teamPersonLeft),
                  )
                : OutlinedButton(
                    key: const ValueKey('card:back'),
                    onPressed: () => unawaited(_back(context, person)),
                    child: Text(l10n.teamPersonBack),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _dismiss(
    BuildContext context,
    TeamPeople team,
    TeamPerson person,
  ) async {
    final c = ProviderScope.containerOf(context, listen: false);
    if (await teamDismiss(context, team, person)) {
      c.invalidate(personCardProvider);
    }
  }

  Future<void> _back(BuildContext context, TeamPerson person) async {
    final c = ProviderScope.containerOf(context, listen: false);
    await teamBringBack(context, person);
    c.invalidate(personCardProvider);
  }
}

String _event(TeamEvent e, AppLocalizations l10n) {
  final post = e.post == null ? '' : teamPostLabel(e.post!, l10n);
  return switch (e.kind) {
    TeamEventKind.added => l10n.tmEvAdded,
    TeamEventKind.postOn => l10n.tmEvPostOn(post),
    TeamEventKind.postOff => l10n.tmEvPostOff(post),
    TeamEventKind.left => l10n.tmEvLeft,
    TeamEventKind.back => l10n.tmEvBack,
  };
}
