import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_dialog.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
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
/// the people of its post.
class TeamDepartmentsView extends ConsumerWidget {
  const TeamDepartmentsView({super.key});

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
                      onPressed: () => showTeamPersonDialog(context, team),
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
                _DepartmentCard(team: team, department: d),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (team.unplaced.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.teamUnplaced,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final p in team.unplaced)
                            _PersonChip(team: team, person: p),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.team, required this.department});

  final TeamPeople team;
  final TeamDepartment department;

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
                  _PersonChip(team: team, person: p),
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
                    onPressed: () =>
                        showTeamPersonDialog(context, team, post: post.key),
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
  const _PersonChip({required this.team, required this.person});

  final TeamPeople team;
  final TeamPerson person;

  @override
  Widget build(BuildContext context) => InputChip(
    key: ValueKey('teamPerson:${person.employee}'),
    // A phone icon: he ticks his own stages; none: the manager ticks for him.
    avatar: Icon(person.user == null ? AppIcons.profile : AppIcons.call),
    label: Text(person.name),
    onPressed: team.canEdit
        ? () => showTeamPersonDialog(context, team, person: person)
        : null,
  );
}

/// A person: new ([person] null, on [post] if given) or changed.
Future<void> showTeamPersonDialog(
  BuildContext context,
  TeamPeople team, {
  TeamPerson? person,
  String? post,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PersonDialog(team: team, person: person, post: post),
);

class _PersonDialog extends ConsumerStatefulWidget {
  const _PersonDialog({required this.team, this.person, this.post});

  final TeamPeople team;
  final TeamPerson? person;
  final String? post;

  @override
  ConsumerState<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends ConsumerState<_PersonDialog> {
  late final _name = TextEditingController(text: widget.person?.name);
  late final _phone = TextEditingController(text: widget.person?.phone);
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
        await repo.change(
          person.employee,
          name: name,
          posts: _ordered,
          phone: _phone.text.trim(),
        );
        if (_user != person.user) await repo.linkUser(person.employee, _user);
      }
      ref.invalidate(teamPeopleProvider);
      navigator.pop();
      messenger.showDone(l10n.teamPersonSaved(name));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
      if (mounted) setState(() => _busy = false);
    }
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
          .setActive(person.employee, active: false);
      ref.invalidate(teamPeopleProvider);
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
    final taken = {
      for (final p in widget.team.people)
        if (p.user != null && p.employee != widget.person?.employee) p.user!,
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
              if (widget.person != null) ...[
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
        if (widget.person != null)
          TextButton(
            key: const ValueKey('teamPersonLeft'),
            onPressed: _busy ? null : _dismiss,
            child: Text(
              l10n.teamPersonLeft,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('teamPersonSave'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.teamPersonSave),
        ),
      ],
    );
  }
}
