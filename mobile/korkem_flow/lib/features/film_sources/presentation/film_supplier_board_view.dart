import 'package:flutter/material.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_sources/domain/film_source.dart';
import 'package:korkem_flow/features/film_sources/domain/film_supplier_board.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

const _medals = ['🥇', '🥈', '🥉'];

/// The board's figures at the top: sold, on the shelf, on its way, to order.
class FilmSupplierSummary extends StatelessWidget {
  const FilmSupplierSummary({required this.board, super.key});

  final FilmSupplierBoard board;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final b = board;

    Widget fact(
      String key,
      String label,
      String value,
      String? note,
      Color? c,
    ) => SizedBox(
      width: AppSpacing.xxxl * 4,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                key: ValueKey('filmSup:$key'),
                style: theme.textTheme.titleLarge?.copyWith(color: c),
              ),
              Text(note ?? '', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        fact(
          'sold',
          b.allTime ? l10n.filmSupSoldAll : l10n.filmSupSoldMonth,
          l10n.filmSupM(filmMetres(b.soldM)),
          b.amount == null ? null : money.format(b.amount),
          null,
        ),
        fact(
          'onHand',
          l10n.filmSupOnHand,
          l10n.filmSupM(filmMetres(b.onHandM)),
          null,
          null,
        ),
        fact(
          'coming',
          l10n.filmSupComing,
          l10n.filmSupM(filmMetres(b.comingM)),
          b.comingCount > 0 ? l10n.filmSupComingRolls(b.comingCount) : null,
          b.comingM > 0 ? status.info : null,
        ),
        // What we owe for film taken on credit (owner, 14.11.2026).
        if (b.owed != null)
          fact(
            'owed',
            l10n.filmSupOwed,
            money.format(b.owed),
            b.owedSuppliers > 0
                ? l10n.filmSupOwedTo(b.owedSuppliers)
                : null,
            (b.owed ?? 0) > 0 ? status.danger : null,
          ),
        fact(
          'reorder',
          l10n.filmSupReorder,
          l10n.filmSupReorderFilms(b.reorderFilms),
          null,
          b.reorderFilms > 0 ? status.danger : status.success,
        ),
      ],
    );
  }
}

/// One source on the board: its place, its name and whom to ring; a bar
/// for what its film sold; and what to do about it — order, wait, ring.
class FilmSupplierTile extends StatelessWidget {
  const FilmSupplierTile({
    required this.row,
    required this.place,
    required this.topM,
    this.source,
    this.onTap,
    super.key,
  });

  final FilmSupplierRow row;

  /// Its place by metres sold, from zero; null when it sold nothing.
  final int? place;

  /// The best seller's metres: a full bar.
  final double topM;

  /// Its card — city, person, telephone, whose films it sells.
  final FilmSource? source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final r = row;
    final coming = r.coming;
    final src = source;
    final behind = r.lateDays > 0 || (coming?.lateDays ?? 0) > 0;
    final bar = topM <= 0
        ? 0.0
        : r.soldM >= topM
        ? 1.0
        : r.soldM / topM;
    // To order red, late or lying idle amber, selling green, else grey.
    final stripe = r.reorder.isNotEmpty
        ? status.danger
        : behind || r.idleFilms > 0
        ? status.warning
        : r.soldM > 0
        ? status.success
        : status.neutral;
    final lines = [
      if (src != null && src.line.isNotEmpty) src.line,
      if (src != null && src.makers.isNotEmpty) src.makers.join(', '),
    ];
    final facts = [
      if (r.amount != null) l10n.filmSupRevenue(money.format(r.amount)),
      l10n.filmSupShelf(filmMetres(r.onHandM)),
      if (r.leadDays != null)
        l10n.filmSupLead(r.leadDays!, r.promisedDays ?? r.leadDays!),
    ];
    final order = [
      for (final o in r.reorder)
        l10n.filmSupOrderLine(o.title, filmMetres(o.metres)),
    ].join('\n');

    Widget chip(String key, String text, Color color) => DecoratedBox(
      key: ValueKey('filmSup:$key:${r.id}'),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTint.surface),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: InkWell(
          key: ValueKey('filmSource:${r.id}'),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: stripe, width: AppSpacing.xs),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: AppSpacing.xl,
                        child: Text(
                          place == null
                              ? ''
                              : place! < _medals.length
                              ? _medals[place!]
                              : '${place! + 1}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (lines.isNotEmpty)
                              Text(
                                lines.join('\n'),
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.filmSupM(filmMetres(r.soldM)),
                            key: ValueKey('filmSup:sold:${r.id}'),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            l10n.filmSupShare(filmMetres(r.share)),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      if (r.phone != null)
                        IconButton(
                          key: ValueKey('filmSup:call:${r.id}'),
                          tooltip: l10n.filmCall,
                          icon: const Icon(AppIcons.call),
                          onPressed: () => ContactActions.call(r.phone),
                        ),
                      if (r.writeTo != null)
                        IconButton(
                          key: ValueKey('filmSup:write:${r.id}'),
                          tooltip: r.reorder.isEmpty
                              ? l10n.filmWrite
                              : l10n.filmSupOrder,
                          icon: const Icon(AppIcons.whatsApp),
                          // What ran low goes into the message, ready to send.
                          onPressed: () => r.reorder.isEmpty
                              ? ContactActions.whatsApp(r.writeTo)
                              : ContactActions.whatsAppMessage(
                                  r.writeTo,
                                  l10n.filmSupOrderText(order),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: bar,
                    color: stripe,
                    minHeight: AppSpacing.xs,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(facts.join(' · '), style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (r.reorder.isNotEmpty)
                        chip(
                          'reorder',
                          l10n.filmSupChipReorder(r.reorder.length),
                          status.danger,
                        ),
                      if (coming != null)
                        chip(
                          'coming',
                          coming.lateDays > 0
                              ? l10n.filmSupChipComingLate(
                                  filmMetres(coming.metres),
                                  coming.lateDays,
                                )
                              : l10n.filmSupChipComing(
                                  filmMetres(coming.metres),
                                  mdfDay(coming.due, year: false),
                                ),
                          coming.lateDays > 0 ? status.warning : status.info,
                        ),
                      // The money side (owner, 14.11.2026): what we owe
                      // it, how it keeps its word, how its price moved.
                      if ((r.owed ?? 0) > 0)
                        chip(
                          'owed',
                          l10n.filmSupChipOwed(money.format(r.owed)),
                          status.danger,
                        ),
                      if (r.onTime != null && r.rolls > 0)
                        chip(
                          'onTime',
                          l10n.filmSupChipOnTime(r.onTime!, r.rolls),
                          r.onTime! >= r.rolls * FilmSupplierRow.reliable
                              ? status.success
                              : status.warning,
                        ),
                      if (r.priceChange != null && r.priceChange!.abs() >= 1)
                        chip(
                          'price',
                          l10n.filmSupChipPrice(
                            '${r.priceChange! > 0 ? '▲' : '▼'} '
                            '${r.priceChange!.abs().round()}',
                          ),
                          r.priceChange! > 0 ? status.warning : status.success,
                        ),
                      if (r.lateDays > 0)
                        chip(
                          'late',
                          l10n.filmSupChipLate(r.lateDays),
                          status.warning,
                        ),
                      if (r.idleFilms > 0)
                        chip(
                          'idle',
                          l10n.filmSupChipIdle(
                            r.idleFilms,
                            filmMetres(r.idleM),
                          ),
                          status.warning,
                        ),
                      if (r.fine && r.soldM > 0)
                        chip('ok', l10n.filmSupChipOk, status.success),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
