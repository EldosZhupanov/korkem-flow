import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/features/one_c/data/one_c_repository.dart';
import 'package:korkem_flow/features/piece_work/data/piece_work_repository.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Обмен с 1С»: a month, and each table to copy into 1C. The server builds
/// the text (`services/accounting_export.py`); nothing is assembled here.
class OneCScreen extends ConsumerStatefulWidget {
  const OneCScreen({super.key});

  @override
  ConsumerState<OneCScreen> createState() => _OneCScreenState();
}

class _OneCScreenState extends ConsumerState<OneCScreen> {
  late PayPeriod _period = monthOf(DateTime.now());
  bool _busy = false;

  void _shift(int months) => setState(
    () => _period = monthOf(
      DateTime(_period.from.year, _period.from.month + months),
    ),
  );

  Future<void> _copy(String table, String title) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(oneCRepositoryProvider)
          .export(table, _period);
      await Clipboard.setData(ClipboardData(text: result.csv));
      messenger.showDone(l10n.oneCCopied(title, result.rows));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switch({required bool enabled}) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(oneCRepositoryProvider).setEnabled(enabled: enabled);
      ref.invalidate(oneCSettingsProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(oneCSettingsProvider);
    final month = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_period.from);
    return AppScreen(
      title: l10n.oneCTitle,
      body: settings.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(oneCSettingsProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ReadableWidth(
              child: SwitchListTile(
                key: const ValueKey('oneCEnabled'),
                title: Text(l10n.oneCEnabled),
                value: data.enabled,
                onChanged: data.canEdit ? (on) => _switch(enabled: on) : null,
              ),
            ),
            if (!data.enabled)
              ReadableWidth(child: Text(l10n.oneCOffHint))
            else ...[
              ReadableWidth(
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('oneCPrev'),
                      tooltip: l10n.payrollPrevMonth,
                      icon: const Icon(AppIcons.back),
                      onPressed: () => _shift(-1),
                    ),
                    Expanded(
                      child: Text(
                        month,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('oneCNext'),
                      tooltip: l10n.payrollNextMonth,
                      icon: const Icon(AppIcons.forward),
                      onPressed: () => _shift(1),
                    ),
                  ],
                ),
              ),
              for (final t in data.tables)
                ReadableWidth(
                  child: Card(
                    child: ListTile(
                      key: ValueKey('oneCTable:${t.table}'),
                      title: Text(t.title),
                      trailing: TextButton.icon(
                        key: ValueKey('oneCCopy:${t.table}'),
                        onPressed: _busy ? null : () => _copy(t.table, t.title),
                        icon: const Icon(
                          AppIcons.share,
                          size: AppIconSize.dense,
                        ),
                        label: Text(l10n.oneCCopy),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              ReadableWidth(
                child: Text(
                  l10n.oneCHowTo,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Settings row leading to «Обмен с 1С». Drawn only for the people the server
/// lets in — the administrator and accounting; for anybody else, nothing.
class OneCTile extends ConsumerWidget {
  const OneCTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(oneCSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        key: const ValueKey('oneCSettings'),
        leading: const Icon(AppIcons.share),
        title: Text(l10n.oneCTitle),
        subtitle: Text(l10n.oneCSubtitle),
        trailing: const Icon(AppIcons.forward),
        onTap: () => context.push(Routes.oneC),
      ),
    );
  }
}
