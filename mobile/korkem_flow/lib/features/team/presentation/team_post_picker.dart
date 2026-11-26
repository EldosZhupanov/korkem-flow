import 'dart:async';

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
import 'package:korkem_flow/features/team/presentation/team_actions.dart';
import 'package:korkem_flow/features/team/presentation/team_departments_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

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

String _key(String s) => s.toLowerCase().replaceAll('ё', 'е');
