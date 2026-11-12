import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Which film — with a search (owner, 12.11.2026: «туда включить поиск»):
/// by maker, colour or code, each with what is free of it.
Future<Film?> showFilmChoice(
  BuildContext context,
  List<Film> films, {
  required String title,
  Set<String> skip = const {},
}) => showDialog<Film>(
  context: context,
  builder: (_) => _FilmPicker(
    title: title,
    films: [
      for (final f in films)
        if (f.enabled && !skip.contains(f.item)) f,
    ],
  ),
);

/// Whether [f] answers what was typed: every word somewhere in its name,
/// its maker, its code or its type.
bool filmMatches(Film f, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  final text = [
    filmName(f),
    f.maker,
    f.colour,
    ?f.code,
    ?f.type,
  ].join(' ').toLowerCase();
  return words.every(text.contains);
}

class _FilmPicker extends StatefulWidget {
  const _FilmPicker({required this.title, required this.films});

  final String title;
  final List<Film> films;

  @override
  State<_FilmPicker> createState() => _FilmPickerState();
}

class _FilmPickerState extends State<_FilmPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final shown = [
      for (final f in widget.films)
        if (filmMatches(f, _query.text)) f,
    ];
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        height: AppSpacing.xxxl * 8,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('filmPick:search'),
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search),
                hintText: l10n.filmPickSearch,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text(l10n.filmPickNone))
                  : ListView(
                      children: [
                        for (final f in shown)
                          ListTile(
                            key: ValueKey('filmReceivePick:${f.item}'),
                            dense: true,
                            title: Text(filmName(f)),
                            subtitle: Text(
                              [?f.code, ?f.type].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Text(
                              f.free > 0
                                  ? l10n.filmPickFree(filmMetres(f.free))
                                  : f.reorder != null
                                  ? l10n.filmPickReorder
                                  : l10n.filmPickFree(filmMetres(0)),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: f.free > 0 ? null : status.danger,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(f),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
      ],
    );
  }
}
