import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
import 'package:korkem_flow/features/team/presentation/team_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A department's name in the reader's language; the server's own word for
/// one this app does not know.
String teamDepartmentLabel(TeamDepartment d, AppLocalizations l10n) =>
    switch (d.key) {
      'intake' => l10n.teamDeptIntake,
      'cut' => l10n.teamDeptCut,
      'cnc' => l10n.teamDeptCnc,
      'pvc' => l10n.teamDeptPvc,
      'paint' => l10n.teamDeptPaint,
      'pack' => l10n.teamDeptPack,
      'film_sales' => l10n.teamDeptFilmSales,
      'warehouse' => l10n.teamDeptWarehouse,
      _ => d.title,
    };

/// A post's name: «Шкурщик» is one word in two departments.
String teamPostLabel(String key, AppLocalizations l10n, [String? fallback]) =>
    switch (key.split('.').last) {
      'manager' => l10n.teamPostManager,
      'cutter' => l10n.teamPostCutter,
      'operator' => l10n.teamPostCncOperator,
      'sander' => l10n.teamPostSander,
      'vacuum' => l10n.teamPostVacuum,
      'painter' => l10n.teamPostPainter,
      'packer' => l10n.teamPostPacker,
      'seller' => l10n.teamPostSeller,
      'loader' => l10n.teamPostLoader,
      'storekeeper' => l10n.teamPostStorekeeper,
      'driver' => l10n.teamPostDriver,
      _ => fallback ?? key,
    };

/// «Отделы и люди» (owner, 17.11.2026): every department with its posts and
/// the people on each — with or without a login. An order's stage goes to
/// the people of its post. It is the whole team: a login is opened from its
/// person ([canManageLogins] — the owner), not kept in a list of its own.
class TeamDepartmentsView extends ConsumerWidget {
  const TeamDepartmentsView({super.key, this.canManageLogins = false});

  final bool canManageLogins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
          data: (team) => Column(
            key: const ValueKey('teamDepartments'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionLabel(l10n.teamDepartmentsSection),
                  if (team.canEdit)
                    TextButton.icon(
                      key: const ValueKey('teamAddPerson'),
                      onPressed: () => showTeamPersonDialog(
                        context,
                        team,
                        canManageLogins: canManageLogins,
                      ),
                      icon: const Icon(AppIcons.add, size: AppIconSize.small),
                      label: Text(l10n.teamAddPerson),
                    ),
                ],
              ),
              Text(
                l10n.teamDepartmentsHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final d in team.departments) ...[
                _DepartmentCard(
                  team: team,
                  department: d,
                  canManageLogins: canManageLogins,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (final (title, people) in [
                (l10n.teamUnplaced, team.unplaced),
                (l10n.teamLeft, team.left),
              ])
                if (people.isNotEmpty) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final p in people)
                              _PersonChip(
                                team: team,
                                person: p,
                                canManageLogins: canManageLogins,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.team,
    required this.department,
    required this.canManageLogins,
  });

  final TeamPeople team;
  final TeamDepartment department;
  final bool canManageLogins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AppCard(
      key: ValueKey('teamDept:${department.key}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamDepartmentLabel(department, l10n),
            style: theme.textTheme.titleSmall,
          ),
          for (final post in department.posts) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              teamPostLabel(post.key, l10n, post.title),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final p in team.on(post.key))
                  _PersonChip(
                    team: team,
                    person: p,
                    canManageLogins: canManageLogins,
                  ),
                if (team.on(post.key).isEmpty && !team.canEdit)
                  Text(l10n.teamPostEmpty, style: theme.textTheme.bodySmall),
                if (team.canEdit)
                  ActionChip(
                    key: ValueKey('teamAddTo:${post.key}'),
                    avatar: const Icon(AppIcons.add),
                    label: Text(
                      team.on(post.key).isEmpty
                          ? l10n.teamPostEmptyAdd
                          : l10n.teamAddPersonShort,
                    ),
                    onPressed: () => showTeamPersonDialog(
                      context,
                      team,
                      post: post.key,
                      canManageLogins: canManageLogins,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.team,
    required this.person,
    required this.canManageLogins,
  });

  final TeamPeople team;
  final TeamPerson person;
  final bool canManageLogins;

  @override
  Widget build(BuildContext context) => InputChip(
    key: ValueKey('teamPerson:${person.id}'),
    // A phone icon: he ticks his own stages; none: the manager ticks for him.
    avatar: Icon(person.user == null ? AppIcons.profile : AppIcons.call),
    label: Text(person.name),
    onPressed: team.canEdit || canManageLogins
        ? () => showTeamPersonDialog(
            context,
            team,
            person: person,
            canManageLogins: canManageLogins,
          )
        : null,
  );
}

/// A person: new ([person] null, on [post] if given) or changed.
Future<void> showTeamPersonDialog(
  BuildContext context,
  TeamPeople team, {
  TeamPerson? person,
  String? post,
  bool canManageLogins = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PersonDialog(
    team: team,
    person: person,
    post: post,
    canManageLogins: canManageLogins,
  ),
);

class _PersonDialog extends ConsumerStatefulWidget {
  const _PersonDialog({
    required this.team,
    this.person,
    this.post,
    this.canManageLogins = false,
  });

  final TeamPeople team;
  final TeamPerson? person;
  final String? post;
  final bool canManageLogins;

  @override
  ConsumerState<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends ConsumerState<_PersonDialog> {
  late final _name = TextEditingController(text: widget.person?.name);
  late final _phone = TextEditingController(
    text: Phone.prettyOrNull(widget.person?.phone),
  );
  late final Set<String> _posts = {
    ...?widget.person?.posts,
    ?widget.post,
  };
  late String? _user = widget.person?.user;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// The posts in the structure's order, as the server keeps them.
  List<String> get _ordered => [
    for (final d in widget.team.departments)
      for (final p in d.posts)
        if (_posts.contains(p.key)) p.key,
  ];

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(teamStructureRepositoryProvider);
    final name = _name.text.trim();
    if (name.length < 2) return;
    setState(() => _busy = true);
    try {
      final person = widget.person;
      if (person == null) {
        await repo.add(
          name: name,
          posts: _ordered,
          phone: _phone.text.trim(),
        );
      } else {
        final saved = await repo.change(
          person,
          name: name,
          posts: _ordered,
          phone: _phone.text.trim(),
        );
        // A login with no person yet is one now; find him to link.
        final employee =
            person.employee ??
            saved.people
                .where((p) => p.user == person.user)
                .map((p) => p.employee)
                .nonNulls
                .firstOrNull;
        if (_user != person.user && employee != null) {
          await repo.linkUser(employee, _user);
        }
      }
      ref.invalidate(teamPeopleProvider);
      navigator.pop();
      messenger.showDone(l10n.teamPersonSaved(name));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back at the company — and his login with him, when the owner asks.
  Future<void> _return() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(teamStructureRepositoryProvider)
          .setActive(widget.person!, active: true);
      ref
        ..invalidate(teamPeopleProvider)
        ..invalidate(teamMembersProvider);
      navigator.pop();
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The login's own dialogs (invite, access, trades, close, open) — this
  /// one shut first, the lists read again after.
  Future<void> _login(TeamLoginAction? action) async {
    final navigator = Navigator.of(context);
    final host = navigator.context;
    final container = ProviderScope.containerOf(context);
    final person = widget.person!;
    final login = person.login;
    final members = ref.read(teamMembersProvider).value ?? const [];
    navigator.pop();
    if (action == null || login == null) {
      await showTeamInviteDialog(host);
    } else {
      final member =
          members.where((m) => m.email == login.user).firstOrNull ??
          TeamMember(
            email: login.user,
            firstName: person.name.split(' ').first,
            fullName: person.name,
            position: EmployeePosition.fromId(login.position),
            roles: const [],
            enabled: login.enabled,
            ownerByServer: login.isOwner,
          );
      await showTeamLoginAction(host, member, action);
    }
    container
      ..invalidate(teamPeopleProvider)
      ..invalidate(teamMembersProvider);
  }

  Future<void> _dismiss() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final person = widget.person!;
    final sure = await showConfirmDialog(
      context: context,
      title: l10n.teamPersonLeftTitle(person.name),
      message: l10n.teamPersonLeftMessage,
      confirmLabel: l10n.teamPersonLeft,
      isDestructive: true,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(teamStructureRepositoryProvider)
          .setActive(person, active: false);
      ref
        ..invalidate(teamPeopleProvider)
        ..invalidate(teamMembersProvider);
      navigator.pop();
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final logins = ref.watch(teamMembersProvider).value ?? const [];
    final person = widget.person;
    final login = person?.login;
    final self = ref.watch(sessionProvider).value?.user?.trim().toLowerCase();
    final isSelf = login != null && login.user.toLowerCase() == self;
    final taken = {
      for (final p in widget.team.people)
        if (p.user != null && p.id != person?.id) p.user!,
    };
    final free = [
      for (final m in logins)
        if (m.enabled && !taken.contains(m.email)) m,
    ];
    return AlertDialog(
      title: Text(
        widget.person == null ? l10n.teamAddPerson : widget.person!.name,
      ),
      content: SizedBox(
        width: AppSpacing.xxxl * 9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('teamPersonName'),
                controller: _name,
                autofocus: widget.person == null,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.teamPersonName),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('teamPersonPhone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [PhoneMaskFormatter()],
                decoration: InputDecoration(labelText: l10n.teamPersonPhone),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.teamPersonPosts, style: theme.textTheme.labelLarge),
              for (final d in widget.team.departments) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  teamDepartmentLabel(d, l10n),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final p in d.posts)
                      FilterChip(
                        key: ValueKey('teamPost:${p.key}'),
                        label: Text(teamPostLabel(p.key, l10n, p.title)),
                        selected: _posts.contains(p.key),
                        onSelected: (on) => setState(
                          () => on ? _posts.add(p.key) : _posts.remove(p.key),
                        ),
                      ),
                  ],
                ),
              ],
              if (person != null && widget.canManageLogins) ...[
                const SizedBox(height: AppSpacing.md),
                _LoginBlock(
                  login: login,
                  isSelf: isSelf,
                  busy: _busy,
                  onAction: (action) => unawaited(_login(action)),
                ),
              ],
              // Tie an existing login to him — the owner sees the login above.
              if (person != null &&
                  person.employee != null &&
                  widget.team.canEdit &&
                  (person.user == null
                      ? free.isNotEmpty
                      : !widget.canManageLogins)) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: const ValueKey('teamPersonLogin'),
                  initialValue: _user,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.teamPersonLogin,
                    helperText: l10n.teamPersonLoginHint,
                    helperMaxLines: 3,
                  ),
                  items: [
                    DropdownMenuItem(child: Text(l10n.teamPersonNoLogin)),
                    for (final m in free)
                      DropdownMenuItem(
                        value: m.email,
                        child: Text(
                          m.fullName.isEmpty
                              ? m.email
                              : '${m.fullName} · ${m.email}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_user != null && !free.any((m) => m.email == _user))
                      DropdownMenuItem(value: _user, child: Text(_user!)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _user = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (person != null && widget.team.canEdit && !isSelf)
          if (person.active)
            TextButton(
              key: const ValueKey('teamPersonLeft'),
              onPressed: _busy ? null : _dismiss,
              child: Text(
                l10n.teamPersonLeft,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            )
          else
            TextButton(
              key: const ValueKey('teamPersonBack'),
              onPressed: _busy ? null : _return,
              child: Text(l10n.teamPersonBack),
            ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        if (widget.team.canEdit)
          FilledButton(
            key: const ValueKey('teamPersonSave'),
            onPressed: _busy ? null : _save,
            child: Text(l10n.teamPersonSave),
          ),
      ],
    );
  }
}

/// A person's login inside his card: what it allows and what can be done
/// with it — or, with none, an invitation into the program.
class _LoginBlock extends StatelessWidget {
  const _LoginBlock({
    required this.login,
    required this.isSelf,
    required this.busy,
    required this.onAction,
  });

  final TeamLogin? login;
  final bool isSelf;
  final bool busy;

  /// Null invites.
  final ValueChanged<TeamLoginAction?> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final login = this.login;
    return Column(
      key: const ValueKey('teamPersonLoginBlock'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.teamLoginsSection, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        if (login == null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey('teamPersonInvite'),
              onPressed: busy ? null : () => onAction(null),
              icon: const Icon(AppIcons.add, size: AppIconSize.small),
              label: Text(l10n.teamInviteButton),
            ),
          )
        else ...[
          Text(
            login.enabled
                ? EmployeePosition.fromId(login.position).localizedName(l10n)
                : l10n.teamStatusDisabled,
            key: const ValueKey('teamPersonAccess'),
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            login.user,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!isSelf) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: login.enabled
                  ? [
                      ActionChip(
                        key: const ValueKey('teamLoginPosition'),
                        avatar: const Icon(AppIcons.edit),
                        label: Text(l10n.teamChangePositionAction),
                        onPressed: busy
                            ? null
                            : () => onAction(TeamLoginAction.position),
                      ),
                      ActionChip(
                        key: const ValueKey('teamLoginTrades'),
                        avatar: const Icon(AppIcons.team),
                        label: Text(l10n.tradesAction),
                        onPressed: busy
                            ? null
                            : () => onAction(TeamLoginAction.trades),
                      ),
                      ActionChip(
                        key: const ValueKey('teamLoginClose'),
                        avatar: Icon(
                          AppIcons.noAccess,
                          color: theme.colorScheme.error,
                        ),
                        label: Text(l10n.teamDeactivateAction),
                        onPressed: busy
                            ? null
                            : () => onAction(TeamLoginAction.close),
                      ),
                    ]
                  : [
                      ActionChip(
                        key: const ValueKey('teamLoginOpen'),
                        avatar: const Icon(AppIcons.refresh),
                        label: Text(l10n.teamReactivateAction),
                        onPressed: busy
                            ? null
                            : () => onAction(TeamLoginAction.open),
                      ),
                    ],
            ),
          ],
        ],
      ],
    );
  }
}
