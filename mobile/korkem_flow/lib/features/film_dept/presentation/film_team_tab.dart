import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _shift(String month, int by) {
  final parts = month.split('-');
  final y = int.tryParse(parts.first) ?? DateTime.now().year;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  final d = DateTime(y, m + by);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

String _n(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// «Команда» (owner, 11.11.2026: «командный бонус в конце месяца»): the
/// month by seller — metres, what was paid, the margin it carried — the
/// plan, the pot and each one's part. The owner sets the plan and shares.
class FilmTeamTab extends ConsumerStatefulWidget {
  const FilmTeamTab({super.key});

  @override
  ConsumerState<FilmTeamTab> createState() => _FilmTeamTabState();
}

class _FilmTeamTabState extends ConsumerState<FilmTeamTab> {
  String? _month;

  Future<void> _settings(FilmTeam t) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SettingsDialog(team: t),
    );
    if (saved ?? false) ref.invalidate(filmTeamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final async = ref.watch(filmTeamProvider(_month));
    final status = context.statusColors;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(filmTeamProvider(_month)),
      ),
      data: (t) {
        // Against last month, when last month sold anything.
        final before = ref
            .watch(filmTeamProvider(_shift(t.month, -1)))
            .value
            ?.metres;
        final change = before == null || before <= 0
            ? null
            : (t.metres - before) / before * 100;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('filmTeam:prev'),
                  onPressed: () => setState(() => _month = _shift(t.month, -1)),
                  icon: const Icon(AppIcons.previous),
                ),
                Text(
                  // «Ноябрь 2026», not «2026-11» (owner, 27.11.2026).
                  _monthName(context, t.month),
                  key: const ValueKey('filmTeam:month'),
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  key: const ValueKey('filmTeam:next'),
                  onPressed: () => setState(() => _month = _shift(t.month, 1)),
                  icon: const Icon(AppIcons.forward),
                ),
                const Spacer(),
                if (t.canSet)
                  TextButton.icon(
                    key: const ValueKey('filmTeam:settings'),
                    onPressed: () => _settings(t),
                    icon: const Icon(AppIcons.edit),
                    label: Text(l10n.filmTeamSettings),
                  ),
              ],
            ),
            // At a glance (owner, 12.11.2026, 27.11.2026): four figures,
            // the plan and where its pace leads, sellers and their share.
            Wrap(
              key: const ValueKey('filmTeam:totals'),
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Metric(
                  label: l10n.filmTeamSold,
                  value: '${_n(t.metres)} м',
                  note: change == null
                      ? null
                      : '${change >= 0 ? '▲' : '▼'} ${_n(change.abs())}% '
                            '${l10n.filmTeamVsLastMonth}',
                  noteColor: change == null
                      ? null
                      : change >= 0
                      ? status.success
                      : status.danger,
                ),
                _Metric(
                  label: l10n.filmTeamPaid,
                  value: money.format(t.paid),
                  // Sold, not yet paid: the bonus waits for it.
                  note: t.owed > 0.5
                      ? l10n.filmTeamUnpaid(money.format(t.owed))
                      : null,
                  noteColor: status.danger,
                ),
                _Metric(
                  label: l10n.filmTeamMargin,
                  value: money.format(t.margin),
                  valueColor: t.margin >= 0 ? status.success : status.danger,
                  note: [
                    if (t.paid > 0)
                      l10n.filmTeamMarginShare(_n(t.margin / t.paid * 100)),
                    if (t.metres > 0)
                      l10n.filmTeamMarginM(money.format(t.margin / t.metres)),
                  ].join(' · '),
                ),
                _Metric(
                  key: const ValueKey('filmTeam:pot'),
                  label: l10n.filmTeamPotLabel,
                  value: money.format(t.pot),
                  // 0 % is a share nobody set: said where it is set.
                  note: t.pctSet
                      ? l10n.filmTeamPotNote(_n(t.pct))
                      : l10n.filmTeamPotUnset,
                  noteColor: t.pctSet ? null : status.warning,
                  valueColor: status.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (t.planM > 0) ...[
              Text(
                [
                  l10n.filmTeamPlan(_n(t.done ?? 0), _n(t.planM)),
                  // What it still takes (owner, 14.11.2026).
                  if (t.needPerDay != null && t.daysLeft != null)
                    l10n.filmTeamPlanNeed(t.daysLeft!, _n(t.needPerDay!)),
                ].join(' · '),
                key: const ValueKey('filmTeam:plan'),
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: LinearProgressIndicator(
                  minHeight: AppSpacing.sm,
                  value: ((t.done ?? 0) / 100).clamp(0, 1).toDouble(),
                  // Red under half, amber on the way, green when made.
                  color: (t.done ?? 0) >= 100
                      ? status.success
                      : (t.done ?? 0) >= 50
                      ? status.warning
                      : status.danger,
                ),
              ),
              // Where its own pace leads, and where the plan wants it today
              // (owner, 27.11.2026).
              if (t.forecastM != null && t.paceMDay != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    l10n.filmTeamForecast(
                      _n(t.paceMDay!),
                      _n(t.forecastM!),
                      _n(t.forecastM! / t.planM * 100),
                    ),
                    if (t.targetM != null) l10n.filmTeamTarget(_n(t.targetM!)),
                  ].join(' · '),
                  key: const ValueKey('filmTeam:forecast'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.forecastM! >= t.planM
                        ? status.success
                        : status.danger,
                  ),
                ),
                if (t.needPerDay != null &&
                    t.paceMDay! > 0 &&
                    t.needPerDay! > t.paceMDay! * 2)
                  Text(
                    l10n.filmTeamFarBehind(
                      (t.needPerDay! / t.paceMDay!).round(),
                    ),
                    key: const ValueKey('filmTeam:behind'),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ] else if (t.canSet)
              // No plan, no bonus worth the name: say so where it is set.
              Card(
                key: const ValueKey('filmTeam:noPlan'),
                color: theme.colorScheme.tertiaryContainer,
                child: ListTile(
                  title: Text(l10n.filmTeamNoPlan),
                  subtitle: Text(l10n.filmTeamNoPlanHint),
                  trailing: FilledButton(
                    key: const ValueKey('filmTeam:setPlan'),
                    onPressed: () => _settings(t),
                    child: Text(l10n.filmTeamSetPlan),
                  ),
                ),
              )
            else
              Text(l10n.filmTeamNoPlan),
            Text(l10n.filmTeamHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            if (t.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(l10n.filmTeamEmpty),
              ),
            if (t.rows.isNotEmpty)
              Text(l10n.filmTeamSellers, style: theme.textTheme.titleMedium),
            for (final r in t.rows)
              Card(
                key: ValueKey('filmTeam:row:${r.seller}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.filmTeamSellerLine(
                                    r.name,
                                    '${r.sales}',
                                    _n(r.metres),
                                  ),
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (r.sales > 0 && r.amount > 0)
                                  Text(
                                    l10n.filmTeamAvgSale(
                                      money.format(r.amount / r.sales),
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l10n.filmTeamBonus(money.format(r.bonus)),
                                style: theme.textTheme.titleSmall,
                              ),
                              // What a hundred metres more would bring him,
                              // at his margin and this month's share.
                              if (t.pct > 0 && r.metres > 0 && r.margin > 0)
                                Text(
                                  l10n.filmTeamBonusMore(
                                    money.format(
                                      100 * r.margin / r.metres * t.pct / 100,
                                    ),
                                  ),
                                  key: ValueKey('filmTeam:more:${r.seller}'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: status.success,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        child: LinearProgressIndicator(
                          minHeight: AppSpacing.xs,
                          value: (r.share / 100).clamp(0, 1).toDouble(),
                          color: status.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          l10n.filmTeamShareLine(
                            _n(r.share),
                            money.format(r.margin),
                            money.format(r.paid),
                          ),
                          if (r.metres > 0)
                            l10n.filmTeamMarginM(
                              money.format(r.margin / r.metres),
                            ),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                      // Sold on credit is his to collect (owner, 14.11.2026).
                      if (r.owed > 0.5)
                        Text(
                          r.owedSales > 0
                              ? l10n.filmTeamOwedSales(
                                  money.format(r.owed),
                                  r.owedSales,
                                )
                              : l10n.filmTeamOwed(money.format(r.owed)),
                          key: ValueKey('filmTeam:owed:${r.seller}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: status.danger,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // The month on one page (owner, 11.11.2026).
            _ReportSection(month: t.month),
          ],
        );
      },
    );
  }
}

/// «2026-11» as a month and year in words.
String _monthName(BuildContext context, String month) {
  final day = DateTime.tryParse('$month-01');
  if (day == null) return month;
  final text = DateFormat(
    'LLLL y',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(day);
  return text.isEmpty ? month : text[0].toUpperCase() + text.substring(1);
}

/// One figure of the month on a card of its own.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.note,
    this.valueColor,
    this.noteColor,
    super.key,
  });

  final String label;
  final String value;
  final String? note;
  final Color? valueColor;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
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
                style: theme.textTheme.titleLarge?.copyWith(color: valueColor),
              ),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: noteColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What sold most this month and what each film earned over its cost;
/// what lies on the shelf unmoved.
class _ReportSection extends ConsumerWidget {
  const _ReportSection({required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final report = ref.watch(filmReportProvider(month)).value;
    if (report == null) return const SizedBox.shrink();
    final status = context.statusColors;
    final maxM = report.top.fold<double>(
      0,
      (m, r) => r.metres > m ? r.metres : m,
    );
    // Green — a good margin; amber — too little; red — sold under cost.
    Color marginColor(double? m) => m == null
        ? theme.colorScheme.outline
        : m < 0
        ? status.danger
        : m < filmThinMarginM
        ? status.warning
        : status.success;
    return Column(
      key: const ValueKey('filmReport'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        // Its totals are the figures at the top: not said twice.
        Text(l10n.filmReportTop, style: theme.textTheme.titleMedium),
        if (report.top.isEmpty) Text(l10n.filmTeamEmpty),
        for (final (i, r) in report.top.indexed)
          Padding(
            key: ValueKey('filmReport:top:${r.item}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.xxxl * 5,
                  child: Text(
                    '${i + 1}. ${r.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Metres as a bar, against the best seller of the month.
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      minHeight: AppSpacing.sm,
                      value: maxM <= 0 ? 0 : r.metres / maxM,
                      color: marginColor(r.marginM),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: AppSpacing.xxxl * 4,
                  child: Text(
                    [
                      '${_n(r.metres)} м',
                      if (r.marginM != null)
                        l10n.filmReportMarginM(money.format(r.marginM)),
                    ].join(' · '),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: marginColor(r.marginM)),
                  ),
                ),
              ],
            ),
          ),
        if (report.top.isNotEmpty)
          Text(l10n.filmReportMarginLegend, style: theme.textTheme.bodySmall),
        // A film sold for too little over its cost (owner, 27.11.2026).
        for (final r in report.top)
          if (r.marginM != null &&
              r.marginM! >= 0 &&
              r.marginM! < filmThinMarginM)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                key: ValueKey('filmReport:thin:${r.item}'),
                children: [
                  Icon(
                    AppIcons.danger,
                    size: AppIconSize.small,
                    color: status.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.filmReportThin(
                        r.title,
                        money.format(r.marginM),
                        money.format(filmThinMarginM),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (report.idle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.filmReportIdle(report.idleDays),
            style: theme.textTheme.titleMedium,
          ),
          for (final r in report.idle)
            ListTile(
              key: ValueKey('filmReport:idle:${r.item}'),
              dense: true,
              leading: Icon(
                AppIcons.schedule,
                color: context.statusColors.warning,
              ),
              title: Text(r.title),
              subtitle: Text(
                [
                  '${_n(r.onHand)} м',
                  l10n.filmReportIdleDays(r.days),
                  if (r.value != null)
                    l10n.filmReportFrozen(money.format(r.value)),
                ].join(' · '),
              ),
            ),
        ],
      ],
    );
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({required this.team});

  final FilmTeam team;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late final _plan = TextEditingController(
    text: _n(widget.team.settings?.planM ?? 0),
  );
  late final _pct = TextEditingController(
    text: _n(widget.team.settings?.pct ?? 10),
  );
  late final _below = TextEditingController(
    text: _n(widget.team.settings?.pctBelow ?? 5),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _plan.dispose();
    _pct.dispose();
    _below.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Widget _field(String key, TextEditingController c, String label) => TextField(
    key: ValueKey('filmTeam:$key'),
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
    decoration: InputDecoration(labelText: label),
  );

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(filmDeptRepositoryProvider)
          .setTeamSettings(
            planM: _v(_plan),
            pct: _v(_pct),
            pctBelow: _v(_below),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.filmTeamSettings),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('planM', _plan, l10n.filmTeamPlanM),
            _field('pct', _pct, l10n.filmTeamPct),
            _field('pctBelow', _below, l10n.filmTeamPctBelow),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('filmTeam:save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.filmTeamSave),
        ),
      ],
    );
  }
}
