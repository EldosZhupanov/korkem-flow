import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/film_dept/data/film_orders_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_orders_page.dart';
import 'package:korkem_flow/features/film_sources/domain/film_source.dart';
import 'package:korkem_flow/features/film_sources/domain/film_supplier_board.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What to do first (owner, 27.11.2026): the rolls past their day, whom to
/// ring — and the films that ran low, by whom to order them from.
class FilmSupplierAlerts extends ConsumerWidget {
  const FilmSupplierAlerts({
    required this.board,
    this.canOrder = false,
    super.key,
  });

  final FilmSupplierBoard board;

  /// The list «К заказу» may be filled from here.
  final bool canOrder;

  Future<void> _want(
    BuildContext context,
    WidgetRef ref,
    FilmSupplierRow r,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final repo = ref.read(filmOrdersRepositoryProvider);
      for (final o in r.reorder) {
        await repo.add(item: o.item, metres: o.metres, supplier: r.id);
      }
      ref.invalidate(filmWantedProvider);
      messenger.showDone(l10n.filmSupWanted(r.reorder.length));
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => const FilmOrdersPage()),
      );
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final late = board.late;
    final toOrder = board.toOrder;
    if (late.isEmpty && toOrder.isEmpty) return const SizedBox.shrink();

    Widget block({
      required String key,
      required Color colour,
      required IconData icon,
      required String title,
      required List<Widget> rows,
    }) => Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: AppTint.surface),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colour, width: AppStroke.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colour, size: AppIconSize.small),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: colour),
                ),
              ),
            ],
          ),
          ...rows,
        ],
      ),
    );

    Widget line(String key, String text, List<Widget> actions) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        key: ValueKey(key),
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [Text(text), ...actions],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (late.isNotEmpty)
          block(
            key: 'filmSup:late',
            colour: status.danger,
            icon: AppIcons.delivery,
            title: l10n.filmSupLateTitle(
              board.lateCount,
              filmMetres(board.lateM),
            ),
            rows: [
              for (final r in late)
                line(
                  'filmSup:lateRow:${r.id}',
                  l10n.filmSupLateRow(
                    r.name,
                    filmMetres(r.coming!.lateM),
                    mdfDay(r.coming!.lateDue ?? r.coming!.due, year: false),
                    r.coming!.lateDays,
                  ),
                  [
                    if (r.phone != null)
                      OutlinedButton.icon(
                        key: ValueKey('filmSup:lateCall:${r.id}'),
                        onPressed: () => ContactActions.call(r.phone),
                        icon: const Icon(AppIcons.call),
                        label: Text(l10n.filmCall),
                      ),
                  ],
                ),
            ],
          ),
        if (toOrder.isNotEmpty)
          block(
            key: 'filmSup:toOrder',
            colour: status.warning,
            icon: AppIcons.toOrder,
            title: l10n.filmSupToOrderTitle(board.reorderFilms),
            rows: [
              for (final r in toOrder)
                line(
                  'filmSup:toOrder:${r.id}',
                  '${r.name}: ${[
                    for (final o in r.reorder) '${o.title} ${l10n.filmSupM(filmMetres(o.metres))}',
                  ].join(' · ')}',
                  [
                    if (canOrder)
                      OutlinedButton.icon(
                        key: ValueKey('filmSup:want:${r.id}'),
                        onPressed: () => _want(context, ref, r),
                        icon: const Icon(AppIcons.toOrder),
                        label: Text(l10n.filmSupWant),
                      ),
                    if (r.writeTo != null)
                      OutlinedButton.icon(
                        key: ValueKey('filmSup:write:${r.id}'),
                        // What ran low goes into the message, ready to send.
                        onPressed: () => ContactActions.whatsAppMessage(
                          r.writeTo,
                          l10n.filmSupOrderText(
                            [
                              for (final o in r.reorder)
                                l10n.filmSupOrderLine(
                                  o.title,
                                  filmMetres(o.metres),
                                ),
                            ].join('\n'),
                          ),
                        ),
                        icon: const Icon(AppIcons.whatsApp),
                        label: Text(l10n.filmSupOrder),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

/// The board's figures: sold, on the shelf and for how long, on its way and
/// how much of it late, what we owe — and one source too many relied on.
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
      String? note, {
      Color? noteColour,
    }) => SizedBox(
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
                style: theme.textTheme.titleLarge,
              ),
              Text(
                note ?? '',
                style: theme.textTheme.labelSmall?.copyWith(color: noteColour),
              ),
            ],
          ),
        ),
      ),
    );

    final dependence = b.dependence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            fact(
              'sold',
              b.allTime ? l10n.filmSupSoldAll : l10n.filmSupSoldMonth,
              l10n.filmSupM(filmMetres(b.soldM)),
              b.amount == null ? null : money.format(b.amount),
            ),
            fact(
              'onHand',
              l10n.filmSupOnHand,
              l10n.filmSupM(filmMetres(b.onHandM)),
              b.daysLeft == null ? null : l10n.filmSupDaysLeft(b.daysLeft!),
            ),
            fact(
              'coming',
              l10n.filmSupComing,
              l10n.filmSupM(filmMetres(b.comingM)),
              b.lateM > 0
                  ? l10n.filmSupLateNote(filmMetres(b.lateM))
                  : b.comingCount > 0
                  ? l10n.filmSupComingRolls(b.comingCount)
                  : null,
              noteColour: b.lateM > 0 ? status.danger : null,
            ),
            // What we owe for film taken on credit (owner, 14.11.2026).
            if (b.owed != null)
              fact(
                'owed',
                l10n.filmSupOwed,
                money.format(b.owed),
                b.owedSuppliers > 0
                    ? l10n.filmSupOwedTo(b.owedSuppliers)
                    : l10n.filmSupOwedNone,
                noteColour: (b.owed ?? 0) > 0 ? status.danger : null,
              ),
          ],
        ),
        // Half the film from one source (owner, 27.11.2026): if it fails a
        // delivery, the press stops.
        if (dependence != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  AppIcons.danger,
                  size: AppIconSize.small,
                  color: status.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.filmSupDependence(
                      dependence.name,
                      dependence.share.round(),
                    ),
                    key: const ValueKey('filmSup:dependence'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The table is a table only where it fits; on a phone each source is a
/// card with the same figures.
const double _tableWidth = AppSpacing.xxxl * 15;

/// The columns' shares of the row, after the source's name.
const _flex = (name: 14, sold: 13, onTime: 8, lead: 11, price: 6);

/// The table's head: what each column is (owner, 27.11.2026).
class FilmSupplierHeader extends StatelessWidget {
  const FilmSupplierHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < _tableWidth
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: _flex.name,
                    child: Text(l10n.filmSupColSupplier, style: style),
                  ),
                  Expanded(
                    flex: _flex.sold,
                    child: Text(l10n.filmSupColSold, style: style),
                  ),
                  Expanded(
                    flex: _flex.onTime,
                    child: Text(l10n.filmSupColOnTime, style: style),
                  ),
                  Expanded(
                    flex: _flex.lead,
                    child: Text(l10n.filmSupColLead, style: style),
                  ),
                  Expanded(
                    flex: _flex.price,
                    child: Text(l10n.filmSupColPrice, style: style),
                  ),
                  const SizedBox(width: AppSpacing.xxxl * 2),
                ],
              ),
            ),
    );
  }
}

/// One source: whom to ring, what its film sold, whether it keeps its
/// word — what it promised against what it took — and its price.
class FilmSupplierTile extends StatelessWidget {
  const FilmSupplierTile({
    required this.row,
    required this.topM,
    this.source,
    this.onTap,
    super.key,
  });

  final FilmSupplierRow row;

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
    final src = source;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final idle = r.soldM <= 0 && (r.coming == null);
    final bar = topM <= 0
        ? 0.0
        : r.soldM >= topM
        ? 1.0
        : r.soldM / topM;
    // Its makers only when they say more than its own name.
    final makers = src == null
        ? const <String>[]
        : [
            for (final m in src.makers)
              if (m.toLowerCase() != r.name.toLowerCase()) m,
          ];
    final about = [
      if (src != null && src.line.isNotEmpty) src.line,
      if (makers.isNotEmpty) makers.join(', '),
    ];
    final notes = [
      if ((r.owed ?? 0) > 0)
        (
          'owed',
          l10n.filmSupChipOwed(money.format(r.owed)),
          status.danger,
        ),
      if (r.idleFilms > 0)
        (
          'idle',
          l10n.filmSupChipIdle(r.idleFilms, filmMetres(r.idleM)),
          status.warning,
        ),
      if (r.coming case final c? when c.lateM <= 0)
        (
          'coming',
          l10n.filmSupChipComing(
            filmMetres(c.metres),
            mdfDay(c.due, year: false),
          ),
          status.info,
        ),
    ];

    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          r.name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: idle ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        if (about.isNotEmpty) Text(about.join('\n'), style: muted),
        if (idle) Text(l10n.filmSupNoSales, style: muted),
        for (final (key, text, colour) in notes)
          Text(
            text,
            key: ValueKey('filmSup:$key:${r.id}'),
            style: theme.textTheme.labelSmall?.copyWith(color: colour),
          ),
      ],
    );
    final sold = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: LinearProgressIndicator(
            value: bar,
            minHeight: AppSpacing.xs,
            color: theme.colorScheme.onSurfaceVariant,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.filmSupM(filmMetres(r.soldM)),
          key: ValueKey('filmSup:sold:${r.id}'),
          style: theme.textTheme.bodyMedium,
        ),
        Text(l10n.filmSupShare(filmMetres(r.share)), style: muted),
      ],
    );
    final onTime = r.onTime == null || r.rolls == 0
        ? Text('—', style: muted)
        : Text(
            l10n.filmSupChipOnTime(r.onTime!, r.rolls),
            key: ValueKey('filmSup:onTime:${r.id}'),
            style: TextStyle(
              color: r.onTime! >= r.rolls * FilmSupplierRow.reliable
                  ? status.success
                  : status.warning,
            ),
          );
    // What it promised against what it took (owner, 27.11.2026).
    final lead = r.leadDays == null
        ? Text('—', style: muted)
        : Text(
            l10n.filmSupLeadCell(r.promisedDays ?? r.leadDays!, r.leadDays!),
            key: ValueKey('filmSup:lead:${r.id}'),
            style: TextStyle(
              color: r.leadDays! > (r.promisedDays ?? r.leadDays!)
                  ? status.danger
                  : null,
            ),
          );
    final change = r.priceChange;
    final price = change == null || change.abs() < 1
        ? Text('—', style: muted)
        : Text(
            l10n.filmSupChipPrice(
              '${change > 0 ? '▲' : '▼'} ${change.abs().round()}',
            ),
            key: ValueKey('filmSup:price:${r.id}'),
            style: TextStyle(
              color: change > 0 ? status.warning : status.success,
            ),
          );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r.phone != null)
          IconButton(
            key: ValueKey('filmSup:call:${r.id}'),
            tooltip: l10n.filmCall,
            icon: const Icon(AppIcons.call),
            onPressed: () => ContactActions.call(r.phone),
          ),
        if (r.writeTo != null)
          IconButton(
            key: ValueKey('filmSup:chat:${r.id}'),
            tooltip: l10n.filmWrite,
            icon: const Icon(AppIcons.whatsApp),
            onPressed: () => ContactActions.whatsApp(r.writeTo),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        key: ValueKey('filmSource:${r.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth < _tableWidth
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: name),
                          actions,
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      sold,
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xxs,
                        children: [onTime, lead, price],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: _flex.name, child: name),
                      Expanded(
                        flex: _flex.sold,
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: sold,
                        ),
                      ),
                      Expanded(flex: _flex.onTime, child: onTime),
                      Expanded(flex: _flex.lead, child: lead),
                      Expanded(flex: _flex.price, child: price),
                      SizedBox(width: AppSpacing.xxxl * 2, child: actions),
                    ],
                  ),
          ),
        ),
      ),
      ),
    );
  }
}
