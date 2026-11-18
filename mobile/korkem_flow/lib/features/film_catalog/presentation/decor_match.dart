import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/server_image.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_decors_screen.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Подобрать по фото» (owner, 18.11.2026): a photo of the customer's sample
/// in, the closest decors of every catalogue out — what is on the shelf
/// marked, so a match from stock is a sale today.
Future<void> showPhotoMatch(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final List<PickedFile> files;
  try {
    files = await ref
        .read(filmFilePickerProvider)
        .pick(extensions: const ['jpg', 'jpeg', 'png', 'webp']);
  } on Object catch (e) {
    messenger.showFailure(e, l10n);
    return;
  }
  if (files.isEmpty || !context.mounted) return;
  final repo = ref.read(filmDecorRepositoryProvider);
  await showDialog<void>(
    context: context,
    builder: (_) => _MatchesDialog(
      title: l10n.fdcMatchTitle,
      hint: l10n.fdcMatchHint,
      matches: repo.matchPhoto(files.first.bytes),
    ),
  );
}

/// «Аналоги» — a decor's or a film's look-alikes at the other makers.
Future<void> showAnalogues(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  String? decor,
  String? item,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _MatchesDialog(
      title: l10n.fdcAnaloguesTitle(title),
      matches: ref
          .read(filmDecorRepositoryProvider)
          .analogues(decor: decor, item: item),
    ),
  );
}

class _MatchesDialog extends StatelessWidget {
  const _MatchesDialog({required this.title, required this.matches, this.hint});

  final String title;
  final String? hint;
  final Future<List<DecorMatch>> matches;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: AppBreakpoints.readable,
        child: FutureBuilder<List<DecorMatch>>(
          future: matches,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            final found = snap.data;
            if (found == null) {
              return const SizedBox(
                height: AppTouchTarget.comfortable,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (found.isEmpty) return Text(l10n.fdcNoMatches);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hint case final h?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      h,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Flexible(
                  child: GridView.extent(
                    shrinkWrap: true,
                    maxCrossAxisExtent: AppBreakpoints.minTileWidth,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.8,
                    children: [for (final m in found) _MatchTile(match: m)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});

  final DecorMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final m = match;
    final (likeness, colour) = switch (m.likeness) {
      DecorLikeness.close => (l10n.fdcLikeClose, status.success),
      DecorLikeness.near => (l10n.fdcLikeNear, status.warning),
      DecorLikeness.far => (l10n.fdcLikeFar, theme.colorScheme.onSurfaceVariant),
    };
    final shelf = m.films.where((f) => f.free > 0).firstOrNull;
    return Card(
      key: ValueKey('decorMatch:${m.decor}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final navigator = Navigator.of(context);
          unawaited(
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => shelf != null
                    ? FilmPage(item: shelf.item)
                    : FilmDecorsScreen(maker: m.maker, search: m.name),
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: m.image == null
                  ? Center(
                      child: FilmSample(argb: m.argb, size: AppSpacing.xxxl),
                    )
                  : ServerImage(
                      path: m.image!,
                      fallback: FilmSample(argb: m.argb),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [m.maker, ?m.collection].join(' · '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    likeness,
                    style: theme.textTheme.labelSmall?.copyWith(color: colour),
                  ),
                  Text(
                    m.onShelf > 0
                        ? l10n.fdcOnShelf(filmMetres(m.onShelf))
                        : l10n.fdcNotOnShelf,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: m.onShelf > 0
                          ? status.success
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The button that opens [showPhotoMatch] — in the decors and the film
/// department's bars.
class PhotoMatchButton extends ConsumerWidget {
  const PhotoMatchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const ValueKey('fdcMatchPhoto'),
    tooltip: AppLocalizations.of(context).fdcMatchPhoto,
    icon: const Icon(AppIcons.camera),
    onPressed: () => unawaited(showPhotoMatch(context, ref)),
  );
}
