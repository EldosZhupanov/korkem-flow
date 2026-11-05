import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _m(double v) => v.toStringAsFixed(1);

/// «Плёнка: что докупить» — OnayBaza's «Пленка» form: what each open order
/// needs, and, summed by film, how many metres to order from the supplier.
class FilmShortageScreen extends ConsumerWidget {
  const FilmShortageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final report = ref.watch(filmShortageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.filmShortageTitle)),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(filmShortageProvider),
        ),
        data: (r) => r.films.isEmpty
            ? EmptyView(
                title: l10n.filmShortageEmpty,
                message: l10n.filmShortageEmptyHint,
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(filmShortageProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    ReadableWidth(
                      child: Text(
                        l10n.filmShortageTotals(
                          _m(r.neededTotal),
                          _m(r.toBuyTotal),
                        ),
                        key: const ValueKey('filmTotals'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReadableWidth(child: SectionLabel(l10n.filmShortageByFilm)),
                    for (final f in r.films)
                      ReadableWidth(
                        child: AppCard(
                          key: ValueKey('film:${f.decor}'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.title,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Text(
                                      l10n.filmShortageLine(
                                        '${f.orders}',
                                        _m(f.needed),
                                        _m(f.held),
                                        _m(f.free),
                                        f.unit,
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (!f.onBooks)
                                      Text(
                                        l10n.filmShortageNotOnBooks,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              StatusChip(
                                key: ValueKey('filmBuy:${f.decor}'),
                                label: f.toBuy > 0
                                    ? l10n.filmShortageBuy(_m(f.toBuy), f.unit)
                                    : l10n.filmShortageEnough,
                                intent: f.toBuy > 0
                                    ? StatusIntent.danger
                                    : StatusIntent.success,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    ReadableWidth(
                      child: SectionLabel(l10n.filmShortageByOrder),
                    ),
                    for (final o in r.orders)
                      ReadableWidth(
                        child: ListTile(
                          key: ValueKey('filmOrder:${o.order}:${o.decor}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('${o.order} · ${o.customerName}'),
                          subtitle: Text(
                            [
                              o.decor,
                              '${_m(o.needed)} м',
                              o.deliveryDate,
                            ].join(' · '),
                          ),
                          trailing: o.short > 0
                              ? StatusChip(
                                  label: l10n.filmShortageShort(_m(o.short)),
                                  intent: StatusIntent.warning,
                                  compact: true,
                                )
                              : null,
                          onTap: () => context.push(Routes.mdfOrder(o.order)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
