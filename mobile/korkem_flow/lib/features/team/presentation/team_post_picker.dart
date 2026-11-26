import 'dart:async';

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
import 'package:korkem_flow/features/team/presentation/team_actions.dart';
import 'package:korkem_flow/features/team/presentation/team_departments_view.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «+ Добавить» under a post: someone already here first — a second
/// «Владимир» is how a list rots — and a new person only below them.
///
/// The window stays open (owner, 26.11.2026: «из окошка не должен выходить
/// и закрываться»): a tap puts a person on the post and marks him ✓, a
/// second tap takes him off again; «Готово» closes. Who was on the post
/// before is shown ✓ and left alone — taking him off has its own questions
/// (his open stages), asked from his chip.
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

  /// Put on the post in this window — a second tap takes them off.
  final _added = <String>{};
  final _busy = <String>{};

  Future<void> _toggle(TeamPerson p) async {
    if (_busy.contains(p.id)) return;
    final on = !_added.contains(p.id);
    setState(() => _busy.add(p.id));
    final done = await teamSetPostInPlace(context, p, widget.post, on: on);
    if (!mounted) return;
    setState(() {
      _busy.remove(p.id);
      if (done) on ? _added.add(p.id) : _added.remove(p.id);
    });
  }

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
        if (p.active && (query.isEmpty || _key(p.name).contains(query))) p,
    ]..sort((a, b) {
        // Who is on the post before anyone else, then the rest by name.
        final on = (b.posts.contains(widget.post) ? 1 : 0) -
            (a.posts.contains(widget.post) ? 1 : 0);
        return on != 0 ? on : a.name.compareTo(b.name);
      });
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              _added.isEmpty ? l10n.tmPickHint : l10n.tmPickAdded(_added.length),
              key: const ValueKey('tm:pickCount'),
              style: muted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: people.isEmpty
                  ? Center(child: Text(l10n.tmNoOne))
                  : ListView(
                      children: [
                        for (final p in people)
                          _row(context, p, muted),
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
        FilledButton(
          key: const ValueKey('tm:pickDone'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tmPickDone),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, TeamPerson p, TextStyle? muted) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final before = p.posts.contains(widget.post) && !_added.contains(p.id);
    final added = _added.contains(p.id);
    final posts = [
      for (final x in p.posts)
        if (x != widget.post) teamPostLabel(x, l10n),
    ];
    return ListTile(
      key: ValueKey('tm:pickPerson:${p.id}'),
      contentPadding: EdgeInsets.zero,
      enabled: !before,
      title: Text(p.name),
      subtitle: Text(
        before
            ? l10n.tmOnPost
            : posts.isEmpty
            ? l10n.teamUnplaced
            : posts.join(', '),
        style: muted,
      ),
      trailing: _busy.contains(p.id)
          ? const SizedBox.square(
              dimension: AppSpacing.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              before || added ? AppIcons.check : AppIcons.add,
              color: before || added ? status.success : null,
            ),
      onTap: before ? null : () => unawaited(_toggle(p)),
    );
  }
}

String _key(String s) => s.toLowerCase().replaceAll('ё', 'е');
