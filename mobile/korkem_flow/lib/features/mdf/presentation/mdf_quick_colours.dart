import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_catalogue_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// How many of each kind are offered in one press.
const int _quick = 3;

/// The paints offered in one press: the customer's own first, then the
/// shop's most painted. A catalogue that would not load offers none — the
/// three buttons still work.
// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final mdfQuickPaintsProvider = FutureProvider.autoDispose
    .family<List<PaintColour>, String?>((ref, customer) async {
      try {
        final c = await ref
            .watch(paintCatalogueRepositoryProvider)
            .catalogue(customer: customer);
        final ours = [
          for (final x in c.colours)
            if (x.popular && !x.hidden) x,
        ]..sort((a, b) => b.areaM2.compareTo(a.areaM2));
        final seen = <String>{};
        return [
          for (final x in [
            for (final k in c.customer) ?c.byKey(k),
            ...ours,
          ])
            if (!x.hidden && seen.add(x.key)) x,
        ].take(_quick).toList();
      } on Object {
        return const [];
      }
    });

/// «Или сразу цвет» beside the three coating buttons (owner, 20.11.2026):
/// the customer's films of late and the paints he and the shop paint most —
/// a group in one press, its colour already chosen.
class MdfQuickColours extends ConsumerWidget {
  const MdfQuickColours({
    required this.customer,
    required this.onFilm,
    required this.onPaint,
    super.key,
  });

  final String? customer;
  final ValueChanged<String> onFilm;
  final ValueChanged<PaintColour> onPaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final films =
        ref
            .watch(filmPickExtrasProvider(customer))
            .value
            ?.recent
            .take(_quick) ??
        const <String>[];
    final paints =
        ref.watch(mdfQuickPaintsProvider(customer)).value ?? const [];
    if (films.isEmpty && paints.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n.mdfQuickColours,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final f in films)
          ActionChip(
            key: ValueKey('mdfQuickFilm:$f'),
            avatar: const Icon(AppIcons.colour),
            label: Text(f),
            onPressed: () => onFilm(f),
          ),
        for (final p in paints)
          ActionChip(
            key: ValueKey('mdfQuickPaint:${p.key}'),
            avatar: SizedBox.square(
              dimension: AppSpacing.md,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: PaintSwatch(colour: p),
              ),
            ),
            label: Text(p.title),
            onPressed: () => onPaint(p),
          ),
      ],
    );
  }
}
