import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/film_where_view.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The films a press layout's decor names (owner, 27.11.2026, as the
/// server's `film_catalog.named`): «Adilet · Белое дерево» — that maker's
/// colour in every thickness, «… · 0,25» that one thickness, a plain
/// «Белое дерево» the colour of any maker.
List<Film> filmsForDecor(List<Film> films, String decor) {
  String norm(String s) => s.trim().toLowerCase().replaceAll('ё', 'е');
  final parts = decor.split(' · ').map((p) => p.trim()).toList();
  if (parts.length < 2) {
    return [
      for (final f in films)
        if (norm(f.colour) == norm(decor)) f,
    ];
  }
  final maker = norm(parts[0]);
  final colour = norm(parts[1]);
  final thickness = parts.length > 2
      ? double.tryParse(parts[2].replaceAll(',', '.'))
      : null;
  return [
    for (final f in films)
      if (norm(f.maker) == maker &&
          norm(f.colour) == colour &&
          (thickness == null || f.thicknessMm == thickness))
        f,
  ];
}

/// What the order needs of the film against what there is (owner,
/// 28.11.2026): before the press is launched, the free metres decide;
/// once launched, the film was held for it and the server says what it
/// still lacked.
typedef PressFilmStock = ({double need, double free, double lack, bool held});

PressFilmStock pressFilmStock(
  FilmLayout film,
  OrderPressLayout layout,
  List<Film> group,
) {
  final need = film.filmM;
  final free = group.fold<double>(0, (s, f) => s + math.max(0, f.free));
  final held = layout.approvedBy != null;
  final lack = held
      ? layout.short
            .where((s) => s.decor == film.decor)
            .fold<double>(0, (s, x) => s + x.metres)
      : math.max(0, need - free).toDouble();
  return (need: need, free: free, lack: lack, held: held);
}

/// The film's card beside the press layout, the layout staying where it is
/// (owner, 28.11.2026: «чтобы не выходить или обратно возвращаться»): from
/// the right on a wide window, from below on a phone.
Future<void> showPressFilmPeek(
  BuildContext context, {
  required FilmLayout film,
  required OrderPressLayout layout,
}) {
  final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;
  final peek = PressFilmPeek(film: film, layout: layout);
  if (!wide) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: peek,
        ),
      ),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: AppDuration.standard,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        key: const ValueKey('pressFilmPeek'),
        shape: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: SizedBox(
          width: AppSpacing.xxxl * 8,
          height: double.infinity,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: peek,
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: AppCurves.enter),
      ),
      child: child,
    ),
  );
}

class PressFilmPeek extends ConsumerWidget {
  const PressFilmPeek({required this.film, required this.layout, super.key});

  final FilmLayout film;
  final OrderPressLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(filmCatalogProvider);
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(filmCatalogProvider),
      ),
      data: (c) {
        final group = filmsForDecor(c.films, film.decor);
        final stock = pressFilmStock(film, layout, group);
        final where = stock.lack > 0
            ? FilledButton(
                key: const ValueKey('pressPeekWhere'),
                onPressed: () => _where(context),
                child: Text(l10n.pressPeekWhere),
              )
            : OutlinedButton(
                key: const ValueKey('pressPeekWhere'),
                onPressed: () => _where(context),
                child: Text(l10n.pressPeekWhere),
              );
        final header = _ForThisOrder(
          stock: stock,
          rollMm: group.map((f) => f.widthMm).nonNulls.firstOrNull,
          pressMm: layout.press.widthMm,
        );
        if (group.isEmpty) {
          return Column(
            key: const ValueKey('pressPeekUnknown'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      film.decor,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.mdfCancel,
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              header,
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.pressPeekUnknown),
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerLeft, child: where),
            ],
          );
        }
        return FilmSide(
          key: ValueKey('pressPeek:${film.decor}'),
          group: group,
          catalog: c,
          picks: false,
          header: header,
          actions: [where],
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  Future<void> _where(BuildContext context) => showFilmWhere(
    context,
    order: layout.salesOrder,
    film: film.decor,
  );
}

/// «Для этого заказа»: the verdict first, then the roll against the table.
class _ForThisOrder extends StatelessWidget {
  const _ForThisOrder({
    required this.stock,
    required this.rollMm,
    required this.pressMm,
  });

  final PressFilmStock stock;
  final double? rollMm;
  final double pressMm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    String m(double v) => NumberFormat(
      '0.##',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(v);
    final short = stock.lack > 0;
    final colour = short ? status.danger : status.success;
    final text = switch ((stock.held, short)) {
      (true, true) => l10n.pressPeekShortHeld(m(stock.lack)),
      (true, false) => l10n.pressPeekHeld(m(stock.need)),
      (false, true) => l10n.pressPeekShort(
        m(stock.need),
        m(stock.free),
        m(stock.lack),
      ),
      (false, false) => l10n.pressPeekEnough(m(stock.need), m(stock.free)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.pressPeekOrder,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DecoratedBox(
          key: ValueKey(short ? 'pressPeekShort' : 'pressPeekEnough'),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: AppTint.surface),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  short ? AppIcons.danger : AppIcons.check,
                  size: AppIconSize.small,
                  color: colour,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(text, style: TextStyle(color: colour)),
                ),
              ],
            ),
          ),
        ),
        if (rollMm case final roll?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.pressPeekRoll(m(roll), m(pressMm)),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
