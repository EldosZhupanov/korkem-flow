import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/glue_stock_repository.dart';
import 'package:korkem_flow/features/mdf/domain/glue_stock.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A fact this far from the norm, either way, is worth a look.
const _offPct = 10.0;

/// «Сверка за месяц» (owner, 17.11.2026): glue by glue, the m² through the
/// vacuum, what the norm took for them and what the storekeeper's weighing
/// found — so what a m² really took, what the difference cost, and the norm
/// put right to it in one tap.
class GlueMonthScreen extends ConsumerStatefulWidget {
  const GlueMonthScreen({super.key, this.today});

  /// For tests; the clock otherwise.
  final DateTime? today;

  @override
  ConsumerState<GlueMonthScreen> createState() => _GlueMonthScreenState();
}

class _GlueMonthScreenState extends ConsumerState<GlueMonthScreen> {
  late final DateTime _now = widget.today ?? DateTime.now();
  late DateTime _month = DateTime(_now.year, _now.month);

  String get _key => mdfIso(_month).substring(0, 7);

  bool get _isCurrent => _month.year == _now.year && _month.month == _now.month;

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(glueMonthProvider(_key));
    final title = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_month);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.glueMonthTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('glueMonthPrev'),
                      tooltip: l10n.payrollPrevMonth,
                      icon: const Icon(AppIcons.back),
                      onPressed: () => _shift(-1),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('glueMonthNext'),
                      tooltip: l10n.payrollNextMonth,
                      icon: const Icon(AppIcons.forward),
                      onPressed: _isCurrent ? null : () => _shift(1),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                month.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(glueMonthProvider(_key)),
                  ),
                  data: (m) => _Month(month: m),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _Month extends ConsumerWidget {
  const _Month({required this.month});

  final GlueMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final m = month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.glueMonthHint, style: muted),
        const SizedBox(height: AppSpacing.md),
        if (m.glues.isEmpty)
          Text(
            l10n.glueMonthEmpty,
            key: const ValueKey('glueMonthEmpty'),
            style: muted,
          )
        else ...[
          Card(
            key: const ValueKey('glueMonthTotal'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.glueMonthLine(
                      m.m2.toStringAsFixed(2),
                      filmMetres(m.kgByNorm),
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (m.kgCounted != 0)
                    Text(_counted(l10n, m.kgCounted, m.moneyCounted, money)),
                ],
              ),
            ),
          ),
          for (final g in m.glues) _GlueRow(row: g, canEdit: m.canEdit),
        ],
      ],
    );
  }
}

/// «Недостача 0,4 кг на 840 ₸» / «Излишек …» / «Сошлось».
String _counted(
  AppLocalizations l10n,
  double kg,
  double? cost,
  NumberFormat money,
) {
  final weight = filmMetres(kg.abs());
  final price = cost == null ? '—' : money.format(cost.abs());
  if (kg > 0) return l10n.glueMonthShort(weight, price);
  if (kg < 0) return l10n.glueMonthOver(weight, price);
  return l10n.glueMonthEven;
}

class _GlueRow extends ConsumerWidget {
  const _GlueRow({required this.row, required this.canEdit});

  final GlueMonthRow row;
  final bool canEdit;

  Future<void> _fixNorm(
    BuildContext context,
    WidgetRef ref,
    double fact,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(glueStockRepositoryProvider).setNorm(row.item, fact);
      ref
        ..invalidate(glueStockProvider)
        ..invalidate(glueMonthProvider);
      messenger.showDone(l10n.glueMonthNormSet(fact.round().toString()));
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final g = row;
    final fact = g.factGM2;
    final dev = g.deviationPct;
    final off = dev != null && dev.abs() > _offPct;
    return Card(
      key: ValueKey('glueMonth:${g.item}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.glueMonthLine(
                g.m2.toStringAsFixed(2),
                filmMetres(g.kgByNorm),
              ),
            ),
            if (!g.counted)
              Text(
                l10n.glueMonthNotCounted,
                key: ValueKey('glueMonthNotCounted:${g.item}'),
                style: TextStyle(color: status.warning),
              )
            else ...[
              Text(
                l10n.glueMonthWeighed(
                  '${g.counts}',
                  mdfDay(g.lastCount),
                ),
                style: muted,
              ),
              Text(_counted(l10n, g.kgCounted, g.moneyCounted, money)),
              if (fact != null)
                Text(
                  l10n.glueMonthFact(
                    fact.round().toString(),
                    g.normGM2.round().toString(),
                    dev == null
                        ? '—'
                        : '${dev > 0 ? '+' : ''}${dev.toStringAsFixed(1)}',
                  ),
                  key: ValueKey('glueMonthFact:${g.item}'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: off ? status.warning : status.success,
                  ),
                ),
              if (g.costM2Norm != null && g.costM2Fact != null)
                Text(
                  l10n.glueMonthCostM2(
                    money.format(g.costM2Norm),
                    money.format(g.costM2Fact),
                  ),
                  style: muted,
                ),
              if (canEdit && fact != null && fact.round() != g.normGM2.round())
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: FilledButton.tonalIcon(
                    key: ValueKey('glueMonthFixNorm:${g.item}'),
                    onPressed: () => _fixNorm(context, ref, fact),
                    icon: const Icon(AppIcons.edit),
                    label: Text(
                      l10n.glueMonthFixNorm(fact.round().toString()),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
