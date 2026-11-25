import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/team_moves.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
import 'package:korkem_flow/features/team/presentation/people_period.dart';
import 'package:korkem_flow/features/team/presentation/people_screen.dart';
import 'package:korkem_flow/features/team/presentation/team_departments_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

// One person at a time (owner, 26.11.2026): a post given or taken, his open
// stages passed on, «Уволен» with what is still owed. Shared by «Люди», the
// departments, the person's dialog and his card.

// Each takes what it needs from [context] before its first await: the line
// or the dialog it was started from may be gone when the server answers, so
// later dialogs open on the navigator's own context.

void _reload(ProviderContainer c) => c
  ..invalidate(teamPeopleProvider)
  ..invalidate(teamMembersProvider);

ProviderContainer _container(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false);

/// Give [person] [post].
Future<void> teamGivePost(
  BuildContext context,
  TeamPerson person,
  String post,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final c = _container(context);
  try {
    await c
        .read(teamStructureRepositoryProvider)
        .setPost(person, post, on: true);
    _reload(c);
    messenger.showDone(l10n.tmGiven(person.name, teamPostLabel(post, l10n)));
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// Take [post] off [person]. The stages of it already given to him are
/// shown, to pass on; a mistake is undone from the snackbar.
Future<void> teamTakePost(
  BuildContext context,
  TeamPeople team,
  TeamPerson person,
  String post,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final host = Navigator.of(context).context;
  final c = _container(context);
  final repo = c.read(teamStructureRepositoryProvider);
  try {
    await repo.setPost(person, post, on: false);
    _reload(c);
    final employee = person.employee;
    if (employee != null) {
      final work = await repo.openWork(employee, post: post);
      if (work.isNotEmpty && host.mounted) {
        await showTeamHandOver(host, team, person, work, post: post);
      }
    }
    messenger.showUndoable(
      message: l10n.tmTaken(person.name, teamPostLabel(post, l10n)),
      undoLabel: l10n.actionUndo,
      onUndo: () => unawaited(_undoTake(c, messenger, l10n, person, post)),
    );
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

Future<void> _undoTake(
  ProviderContainer c,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  TeamPerson person,
  String post,
) async {
  try {
    await c
        .read(teamStructureRepositoryProvider)
        .setPost(person, post, on: true);
    _reload(c);
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// Who could take over these stages: the active people whose posts do them.
List<TeamPerson> teamCandidates(
  TeamPeople team,
  TeamPerson person,
  Iterable<String> stages,
) {
  final wanted = stages.toSet();
  final posts = {
    for (final d in team.departments)
      for (final p in d.posts)
        if (p.stages.any(wanted.contains)) p.key,
  };
  return [
    for (final p in team.people)
      if (p.active &&
          p.employee != null &&
          p.id != person.id &&
          p.posts.any(posts.contains))
        p,
  ];
}

/// «На нём N незакрытых этапов» — to someone else, or to nobody.
Future<void> showTeamHandOver(
  BuildContext context,
  TeamPeople team,
  TeamPerson person,
  List<TeamOpenWork> work, {
  String? post,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final c = _container(context);
  final choice = await showDialog<_HandOverChoice>(
    context: context,
    builder: (_) => _HandOverDialog(
      title: l10n.tmOpenTitle(work.length),
      work: work,
      candidates: teamCandidates(team, person, work.map((w) => w.stage)),
      confirmLabel: l10n.tmHandOver,
      cancelLabel: l10n.tmKeep,
    ),
  );
  if (choice == null) return;
  try {
    final moved = await c
        .read(teamStructureRepositoryProvider)
        .handOver(person.employee!, to: choice.to, post: post);
    messenger.showDone(l10n.tmMoved(moved));
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// «Уволен», having seen what is still his: open stages are passed on (or
/// left for the manager to give out), and what is owed is said. True when
/// he was let go.
Future<bool> teamDismiss(
  BuildContext context,
  TeamPeople team,
  TeamPerson person,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final host = Navigator.of(context).context;
  final c = _container(context);
  final repo = c.read(teamStructureRepositoryProvider);
  final money = peopleMoney(context);
  try {
    final employee = person.employee;
    final check = employee == null
        ? const TeamDismissal()
        : await repo.dismissal(employee);
    if (!host.mounted) return false;
    final left = check.left ?? 0;
    final pending = check.pending ?? 0;
    final choice = await showDialog<_HandOverChoice>(
      context: host,
      builder: (_) => _HandOverDialog(
        title: l10n.teamPersonLeftTitle(person.name),
        message: l10n.teamPersonLeftMessage,
        notes: [
          if (left > 0) l10n.tmLeftToPay(money.format(left)),
          if (left < 0) l10n.tmAdvanceOver(money.format(-left)),
          if (pending > 0) l10n.tmPending(money.format(pending)),
        ],
        work: check.open,
        candidates: teamCandidates(
          team,
          person,
          check.open.map((w) => w.stage),
        ),
        confirmLabel: l10n.teamPersonLeft,
        cancelLabel: l10n.mdfCancel,
        destructive: true,
      ),
    );
    if (choice == null) return false;
    // Nobody chosen: his stages are freed for the manager to give out —
    // never left on someone who is gone.
    if (employee != null && check.open.isNotEmpty) {
      await repo.handOver(employee, to: choice.to);
    }
    await repo.setActive(person, active: false);
    _reload(c);
    return true;
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
    return false;
  }
}

/// Back at the company.
Future<void> teamBringBack(BuildContext context, TeamPerson person) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final c = _container(context);
  try {
    await c
        .read(teamStructureRepositoryProvider)
        .setActive(person, active: true);
    _reload(c);
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// A post [person] does not hold yet, chosen by department; null — none.
Future<String?> pickTeamPost(
  BuildContext context,
  TeamPeople team,
  TeamPerson person,
) {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return SimpleDialog(
        title: Text(person.name),
        children: [
          for (final d in team.departments)
            if (d.posts.any((p) => !person.posts.contains(p.key))) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  0,
                ),
                child: Text(
                  teamDepartmentLabel(d, l10n),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final p in d.posts)
                if (!person.posts.contains(p.key))
                  SimpleDialogOption(
                    key: ValueKey('tm:pick:${p.key}'),
                    onPressed: () => Navigator.of(context).pop(p.key),
                    child: Text(teamPostLabel(p.key, l10n, p.title)),
                  ),
            ],
        ],
      );
    },
  );
}

/// What the hand-over dialog answers: to whom; null — to nobody.
typedef _HandOverChoice = ({String? to});

class _HandOverDialog extends StatefulWidget {
  const _HandOverDialog({
    required this.title,
    required this.work,
    required this.candidates,
    required this.confirmLabel,
    required this.cancelLabel,
    this.message,
    this.notes = const [],
    this.destructive = false,
  });

  final String title;
  final String? message;
  final List<String> notes;
  final List<TeamOpenWork> work;
  final List<TeamPerson> candidates;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  State<_HandOverDialog> createState() => _HandOverDialogState();
}

class _HandOverDialogState extends State<_HandOverDialog> {
  // The one person who can take it all is offered first; several — chosen.
  late String? _to = widget.candidates.length == 1
      ? widget.candidates.single.employee
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final shown = widget.work.take(6).toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message case final m?) Text(m),
              for (final n in widget.notes) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  n,
                  key: ValueKey('tm:note:$n'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.statusColors.warning,
                  ),
                ),
              ],
              if (widget.work.isNotEmpty) ...[
                if (widget.message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.tmOpenTitle(widget.work.length),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                for (final w in shown)
                  Text(
                    [
                      [
                        if (w.number != null) '№${w.number}',
                        ?w.customer,
                      ].join(' · '),
                      peopleStageLabel(w.stage, l10n),
                    ].join(' — '),
                    style: muted,
                  ),
                if (widget.work.length > shown.length)
                  Text('…', style: muted),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('tm:handTo'),
                  initialValue: _to,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.tmHandTo),
                  items: [
                    DropdownMenuItem(child: Text(l10n.tmNobody)),
                    for (final p in widget.candidates)
                      DropdownMenuItem(value: p.employee, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _to = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('tm:cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          key: const ValueKey('tm:confirm'),
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop((to: _to)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
