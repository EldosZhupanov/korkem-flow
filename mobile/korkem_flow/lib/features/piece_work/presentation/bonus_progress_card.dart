import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/features/piece_work/domain/piece_work.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

NumberFormat _money(BuildContext context) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol: '₸',
  decimalDigits: 0,
);

/// A worker's way to today's and this month's bonus — on their own screen
/// and on the tablet. Nothing shown when the company pays no such bonus.
class BonusProgressCard extends ConsumerWidget {
  const BonusProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bonusProgressProvider).value;
    if (progress == null || progress.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final money = _money(context);
    Widget step(String label, BonusStep s, String key) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(key: ValueKey(key), value: s.fraction),
          const SizedBox(height: AppSpacing.xs),
          Text(
            s.reached
                ? l10n.bonusReached(money.format(s.bonus))
                : l10n.bonusLeft(money.format(s.left), money.format(s.bonus)),
          ),
        ],
      ),
    );
    return AppCard(
      key: const ValueKey('bonusProgress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.today case final today?)
            step(l10n.bonusToday, today, 'bonusToday'),
          if (progress.month case final month?)
            step(l10n.bonusMonth, month, 'bonusMonth'),
        ],
      ),
    );
  }
}
