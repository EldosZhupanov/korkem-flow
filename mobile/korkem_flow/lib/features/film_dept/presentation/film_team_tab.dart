import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final async = ref.watch(filmTeamProvider(_month));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(filmTeamProvider(_month)),
      ),
      data: (t) => ListView(
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
                t.month,
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
                  onPressed: () async {
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (_) => _SettingsDialog(team: t),
                    );
                    if (saved ?? false) ref.invalidate(filmTeamProvider);
                  },
                  icon: const Icon(AppIcons.edit),
                  label: Text(l10n.filmTeamSettings),
                ),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.filmTeamTotals(
                      _n(t.metres),
                      '${t.sales}',
                      money.format(t.paid),
                      money.format(t.margin),
                    ),
                    key: const ValueKey('filmTeam:totals'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (t.planM > 0) ...[
                    Text(
                      l10n.filmTeamPlan(_n(t.done ?? 0), _n(t.planM)),
                      key: const ValueKey('filmTeam:plan'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressIndicator(
                      value: ((t.done ?? 0) / 100).clamp(0, 1).toDouble(),
                    ),
                  ] else
                    Text(l10n.filmTeamNoPlan),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.filmTeamPot(_n(t.pct), money.format(t.pot)),
                    key: const ValueKey('filmTeam:pot'),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(l10n.filmTeamHint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (t.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.filmTeamEmpty),
            ),
          for (final r in t.rows)
            ListTile(
              key: ValueKey('filmTeam:row:${r.seller}'),
              leading: const Icon(AppIcons.profile),
              title: Text(r.name),
              subtitle: Text(
                l10n.filmTeamTotals(
                  _n(r.metres),
                  '${r.sales}',
                  money.format(r.paid),
                  money.format(r.margin),
                ),
              ),
              trailing: Text(
                l10n.filmTeamShare(_n(r.share), money.format(r.bonus)),
                style: theme.textTheme.titleSmall,
              ),
            ),
        ],
      ),
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
