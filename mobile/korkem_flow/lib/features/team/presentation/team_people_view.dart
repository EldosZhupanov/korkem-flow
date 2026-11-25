import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
import 'package:korkem_flow/features/team/presentation/team_actions.dart';
import 'package:korkem_flow/features/team/presentation/team_departments_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Which people «Люди» shows.
enum TeamFilter { all, unplaced, noLogin, left }

String _key(String s) => s.toLowerCase().replaceAll('ё', 'е');

/// «По отделам» — who is on each post; «Люди» — what each person does
/// (owner, 26.11.2026). One list underneath, two questions.
class TeamViews extends StatefulWidget {
  const TeamViews({super.key, this.canManageLogins = false});

  final bool canManageLogins;

  @override
  State<TeamViews> createState() => _TeamViewsState();
}

class _TeamViewsState extends State<TeamViews> {
  bool _people = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            key: const ValueKey('tm:view'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.tmViewDepartments),
              ),
              ButtonSegment(value: true, label: Text(l10n.tmViewPeople)),
            ],
            selected: {_people},
            onSelectionChanged: (s) => setState(() => _people = s.first),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_people)
          TeamPeopleView(canManageLogins: widget.canManageLogins)
        else
          TeamDepartmentsView(canManageLogins: widget.canManageLogins),
      ],
    );
  }
}

/// Everyone, a line each: his posts — taken off with ×, another given with
/// «+ должность» — and, from the menu, his card, his details, «Уволен».
class TeamPeopleView extends ConsumerStatefulWidget {
  const TeamPeopleView({super.key, this.canManageLogins = false});

  final bool canManageLogins;

  @override
  ConsumerState<TeamPeopleView> createState() => _TeamPeopleViewState();
}

class _TeamPeopleViewState extends ConsumerState<TeamPeopleView> {
  final _search = TextEditingController();
  TeamFilter _filter = TeamFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _shown(TeamPerson p) {
    final query = _key(_search.text.trim());
    if (query.isNotEmpty && !_key(p.name).contains(query)) return false;
    return switch (_filter) {
      TeamFilter.all => p.active,
      TeamFilter.unplaced => p.active && p.posts.isEmpty,
      TeamFilter.noLogin => p.active && p.user == null,
      TeamFilter.left => !p.active,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(teamPeopleProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(teamPeopleProvider),
          ),
          data: (team) {
            final people = team.people.where(_shown).toList();
            return Column(
              key: const ValueKey('tm:people'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('tm:search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(AppIcons.search),
                    hintText: l10n.tmSearch,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final (f, label) in [
                      (TeamFilter.all, l10n.tmFilterAll),
                      (TeamFilter.unplaced, l10n.teamUnplaced),
                      (TeamFilter.noLogin, l10n.tmFilterNoLogin),
                      (TeamFilter.left, l10n.tmFilterLeft),
                    ])
                      ChoiceChip(
                        key: ValueKey('tm:filter:${f.name}'),
                        label: Text(label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (people.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(l10n.tmNoOne, textAlign: TextAlign.center),
                  ),
                for (final p in people)
                  _PersonLine(
                    team: team,
                    person: p,
                    canManageLogins: widget.canManageLogins,
                  ),
              ],
            );
          },
        );
  }
}

enum _LineAction { card, edit, dismiss, back }

class _PersonLine extends StatelessWidget {
  const _PersonLine({
    required this.team,
    required this.person,
    required this.canManageLogins,
  });

  final TeamPeople team;
  final TeamPerson person;
  final bool canManageLogins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final edit = team.canEdit && person.active;
    final employee = person.employee;
    return Container(
      key: ValueKey('tm:line:${person.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: employee == null
                      ? null
                      : () => context.push(Routes.person(employee)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        // A phone: he ticks his own stages.
                        Icon(
                          person.user == null
                              ? AppIcons.profile
                              : AppIcons.call,
                          size: AppIconSize.small,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            person.name,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (!person.active) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.tmLeftMark,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final post in person.posts)
                      InputChip(
                        key: ValueKey('tm:post:${person.id}:$post'),
                        label: Text(teamPostLabel(post, l10n)),
                        onDeleted: edit
                            ? () => unawaited(
                                teamTakePost(context, team, person, post),
                              )
                            : null,
                      ),
                    if (person.active && person.posts.isEmpty)
                      Chip(
                        label: Text(l10n.teamUnplaced),
                        labelStyle: TextStyle(
                          color: context.statusColors.warning,
                        ),
                      ),
                    if (edit)
                      ActionChip(
                        key: ValueKey('tm:give:${person.id}'),
                        avatar: const Icon(AppIcons.add),
                        label: Text(l10n.tmAddPost),
                        onPressed: () async {
                          final post = await pickTeamPost(
                            context,
                            team,
                            person,
                          );
                          if (post != null && context.mounted) {
                            await teamGivePost(context, person, post);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<_LineAction>(
            key: ValueKey('tm:menu:${person.id}'),
            tooltip: l10n.tmMenu,
            onSelected: (a) => unawaited(_act(context, a)),
            itemBuilder: (_) => [
              if (employee != null)
                PopupMenuItem(
                  value: _LineAction.card,
                  child: Text(l10n.pplOpenCard),
                ),
              if (team.canEdit || canManageLogins)
                PopupMenuItem(
                  value: _LineAction.edit,
                  child: Text(l10n.tmEdit),
                ),
              if (team.canEdit && person.active)
                PopupMenuItem(
                  key: ValueKey('tm:dismiss:${person.id}'),
                  value: _LineAction.dismiss,
                  child: Text(
                    l10n.teamPersonLeft,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (team.canEdit && !person.active)
                PopupMenuItem(
                  value: _LineAction.back,
                  child: Text(l10n.teamPersonBack),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, _LineAction a) => switch (a) {
    _LineAction.card => context.push(Routes.person(person.employee)),
    _LineAction.edit => showTeamPersonDialog(
      context,
      team,
      person: person,
      canManageLogins: canManageLogins,
    ),
    _LineAction.dismiss => teamDismiss(context, team, person),
    _LineAction.back => teamBringBack(context, person),
  };
}

/// «+ Добавить» under a post: someone already here first — a second
/// «Владимир» is how a list rots — and a new person only below them.
Future<void> showTeamPostPicker(
  BuildContext context,
  TeamPeople team,
  String post, {
  bool canManageLogins = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PostPicker(
    team: team,
    post: post,
    canManageLogins: canManageLogins,
  ),
);

class _PostPicker extends StatefulWidget {
  const _PostPicker({
    required this.team,
    required this.post,
    required this.canManageLogins,
  });

  final TeamPeople team;
  final String post;
  final bool canManageLogins;

  @override
  State<_PostPicker> createState() => _PostPickerState();
}

class _PostPickerState extends State<_PostPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _key(_search.text.trim());
    final people = [
      for (final p in widget.team.people)
        if (p.active &&
            !p.posts.contains(widget.post) &&
            (query.isEmpty || _key(p.name).contains(query)))
          p,
    ];
    final title = teamPostLabel(widget.post, l10n);
    return AlertDialog(
      title: Text(l10n.tmPickTitle(title)),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        height: AppSpacing.xxxl * 8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('tm:pickSearch'),
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search),
                hintText: l10n.tmSearch,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: people.isEmpty
                  ? Center(child: Text(l10n.tmNoOne))
                  : ListView(
                      children: [
                        for (final p in people)
                          ListTile(
                            key: ValueKey('tm:pickPerson:${p.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(p.name),
                            subtitle: Text(
                              p.posts.isEmpty
                                  ? l10n.teamUnplaced
                                  : [
                                      for (final x in p.posts)
                                        teamPostLabel(x, l10n),
                                    ].join(', '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: const Icon(AppIcons.add),
                            onTap: () async {
                              await teamGivePost(context, p, widget.post);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('tm:pickNew'),
          icon: const Icon(AppIcons.add),
          label: Text(l10n.tmNewPerson),
          onPressed: () {
            final host = Navigator.of(context).context;
            Navigator.of(context).pop();
            unawaited(
              showTeamPersonDialog(
                host,
                widget.team,
                post: widget.post,
                canManageLogins: widget.canManageLogins,
              ),
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
      ],
    );
  }
}
