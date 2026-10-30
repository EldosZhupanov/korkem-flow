import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Чем занимается» — a person's shop trades, several at once, and a trade
/// of the company's own when the usual list lacks it. Trades give no rights;
/// the server keeps that apart (`services/shop_trades.py`).
Future<void> showTradesDialog(BuildContext context, TeamMember member) =>
    showDialog<void>(
      context: context,
      builder: (_) => _TradesDialog(member: member),
    );

class _TradesDialog extends ConsumerStatefulWidget {
  const _TradesDialog({required this.member});

  final TeamMember member;

  @override
  ConsumerState<_TradesDialog> createState() => _TradesDialogState();
}

class _TradesDialogState extends ConsumerState<_TradesDialog> {
  late final Set<String> _chosen = {...widget.member.trades};
  final _own = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() call) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await call();
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOwn() async {
    final title = _own.text.trim();
    if (title.isEmpty) return;
    await _run(() async {
      await ref.read(teamRepositoryProvider).addTrade(title);
      ref.invalidate(shopTradesProvider);
      _own.clear();
      setState(() => _chosen.add(title));
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    await _run(() async {
      await ref
          .read(teamRepositoryProvider)
          .setMemberTrades(widget.member.email, _chosen.toList());
      ref.invalidate(teamMembersProvider);
      messenger.showDone(l10n.tradesSaved);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trades = ref.watch(shopTradesProvider);
    return AlertDialog(
      title: Text('${l10n.tradesTitle}: ${widget.member.fullName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: trades.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(shopTradesProvider),
          ),
          data: (data) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.tradesHint),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final title in data.enabledTitles)
                      FilterChip(
                        key: ValueKey('trade:$title'),
                        label: Text(title),
                        selected: _chosen.contains(title),
                        onSelected: _busy
                            ? null
                            : (on) => setState(() {
                                if (on) {
                                  _chosen.add(title);
                                } else {
                                  _chosen.remove(title);
                                }
                              }),
                      ),
                  ],
                ),
                if (data.canEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('tradeOwn'),
                          controller: _own,
                          decoration: InputDecoration(
                            labelText: l10n.tradesOwn,
                          ),
                          onSubmitted: (_) => _addOwn(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        key: const ValueKey('tradeAdd'),
                        onPressed: _busy ? null : _addOwn,
                        child: Text(l10n.tradesAdd),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('tradesSave'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}
