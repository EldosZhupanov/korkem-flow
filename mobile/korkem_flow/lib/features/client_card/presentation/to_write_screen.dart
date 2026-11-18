import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/phone/phone.dart';
import 'package:korkem_flow/features/client_card/data/client_card_repository.dart';
import 'package:korkem_flow/features/client_card/domain/client_card.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Кому написать» (owner, 18.11.2026): the orders ready whose customer does
/// not know yet, the debts due a reminder, the film department's debtors —
/// each with the words already written. The manager opens WhatsApp, reads,
/// sends, and marks it sent; then the row leaves. Above them, «Итоги дня».
class ToWriteScreen extends ConsumerWidget {
  const ToWriteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final todo = ref.watch(toWriteProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navToWrite),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton.icon(
              key: const ValueKey('tw:templates'),
              onPressed: () => unawaited(showMessageTemplates(context)),
              icon: const Icon(AppIcons.edit),
              label: Text(l10n.twTemplates),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(dailySummaryProvider);
          return ref.refresh(toWriteProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const ReadableWidth(child: _SummaryCard()),
            const SizedBox(height: AppSpacing.lg),
            ...todo.when(
              loading: () => [
                const Center(child: CircularProgressIndicator()),
              ],
              error: (error, _) => [
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(toWriteProvider),
                ),
              ],
              data: (t) => [
                if (t.count == 0)
                  ReadableWidth(
                    child: EmptyView(
                      title: l10n.twEmpty,
                      message: l10n.twEmptyHint,
                    ),
                  ),
                if (t.ready.isNotEmpty) ...[
                  ReadableWidth(
                    child: SectionLabel(l10n.twReady(t.ready.length)),
                  ),
                  for (final r in t.ready) _Row(row: r),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (t.debts.isNotEmpty) ...[
                  ReadableWidth(
                    child: SectionLabel(l10n.twDebts(t.debts.length)),
                  ),
                  for (final r in t.debts) _Row(row: r),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (t.film.isNotEmpty) ...[
                  ReadableWidth(
                    child: SectionLabel(l10n.twFilm(t.film.length)),
                  ),
                  for (final r in t.film) _Row(row: r),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.row});

  final ToWriteRow row;

  static final _day = DateFormat('dd.MM');

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? '' : _day.format(d);
  }

  Future<void> _mark(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(clientCardRepositoryProvider)
          .mark(row.kind, order: row.order, customer: row.customer);
      ref
        ..invalidate(toWriteProvider)
        ..invalidate(clientCardProvider(row.customer));
      if (row.order case final order?) ref.invalidate(mdfOrderProvider(order));
      messenger.showDone(l10n.twMarked);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (row.phone == null) {
      messenger.showFailureMessage(l10n.twNoPhone);
      return;
    }
    final opened = await ContactActions.whatsAppMessage(row.phone, row.text);
    if (!opened || !context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.twSentQ),
        action: SnackBarAction(
          label: l10n.twMark,
          onPressed: () => unawaited(_mark(context, ref)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final money = mdfMoney(context);
    final status = context.statusColors;
    final id = row.order ?? row.customer;
    final title = [
      if (row.number case final n?) '№ $n',
      row.customerName,
    ].join(' · ');
    final subtitle = [
      ?Phone.prettyOrNull(row.phone),
      if (row.kind == ToWriteKind.ready && row.readyOn != null)
        l10n.twReadyLine(_date(row.readyOn)),
      if (row.kind == ToWriteKind.debt && row.handedOverOn != null)
        l10n.twHandedLine(_date(row.handedOverOn)),
      if (row.kind == ToWriteKind.filmDebt && row.debtDays != null)
        l10n.twFilmDays(row.debtDays!),
      if (row.reminders > 0 && row.remindedOn != null)
        l10n.twRemindedLine(row.reminders, _date(row.remindedOn)),
    ].join(' · ');
    return ReadableWidth(
      child: Card(
        key: ValueKey('tw:${row.kind.wire}:$id'),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => unawaited(
            context.push(
              row.order == null
                  ? Routes.clientCard(row.customer)
                  : row.cnc
                  ? Routes.cncOrder(row.order!)
                  : Routes.mdfOrder(row.order!),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                    if (row.debt > 0.5)
                      Text(
                        l10n.twDebtLine(money.format(row.debt)),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: status.danger,
                        ),
                      ),
                  ],
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(row.text, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonalIcon(
                      key: ValueKey('tw:send:$id'),
                      onPressed: () => unawaited(_send(context, ref)),
                      icon: const Icon(AppIcons.whatsApp),
                      label: Text(l10n.twSend),
                    ),
                    OutlinedButton.icon(
                      key: ValueKey('tw:mark:$id'),
                      onPressed: () => unawaited(_mark(context, ref)),
                      icon: const Icon(AppIcons.check),
                      label: Text(l10n.twMark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Итоги дня»: the text the owner receives, sent by hand or each evening.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  static const _hours = [17, 18, 19, 20, 21, 22, 23];

  Future<void> _set(
    BuildContext context,
    WidgetRef ref, {
    bool? enabled,
    int? hour,
    bool? morning,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(clientCardRepositoryProvider)
          .setSummary(enabled: enabled, hour: hour, morning: morning);
      ref.invalidate(dailySummaryProvider);
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(dailySummaryProvider);
    final s = summary.value;
    return Card(
      key: const ValueKey('dsm:card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.dsmTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (summary.hasError)
              ErrorView(
                error: summary.error!,
                onRetry: () => ref.invalidate(dailySummaryProvider),
              )
            else if (s == null)
              const LinearProgressIndicator()
            else ...[
              SelectableText(
                s.text,
                key: const ValueKey('dsm:text'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      key: const ValueKey('dsm:enabled'),
                      contentPadding: EdgeInsets.zero,
                      value: s.enabled,
                      title: Text(l10n.dsmSwitch('${s.hour}')),
                      subtitle: Text(l10n.dsmHint),
                      onChanged: (v) =>
                          unawaited(_set(context, ref, enabled: v)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  DropdownButton<int>(
                    key: const ValueKey('dsm:hour'),
                    value: _hours.contains(s.hour) ? s.hour : null,
                    hint: Text(l10n.dsmHour),
                    items: [
                      for (final h in _hours)
                        DropdownMenuItem(value: h, child: Text('$h:00')),
                    ],
                    onChanged: (h) => unawaited(_set(context, ref, hour: h)),
                  ),
                ],
              ),
              SwitchListTile(
                key: const ValueKey('dsm:morning'),
                contentPadding: EdgeInsets.zero,
                value: s.morning,
                title: Text(l10n.dsmMorning),
                onChanged: (v) => unawaited(_set(context, ref, morning: v)),
              ),
              if (s.morningText case final morning?) ...[
                Text(l10n.dsmMorningTitle, style: theme.textTheme.labelLarge),
                SelectableText(
                  morning,
                  key: const ValueKey('dsm:morningText'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('dsm:copy'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: s.text));
                      messenger.showDone(l10n.dsmCopied);
                    },
                    icon: const Icon(AppIcons.copy),
                    label: Text(l10n.dsmCopy),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('dsm:whatsapp'),
                    onPressed: () =>
                        unawaited(ContactActions.whatsAppText(s.text)),
                    icon: const Icon(AppIcons.whatsApp),
                    label: Text(l10n.dsmSendMe),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The owner's own words for the three messages.
Future<void> showMessageTemplates(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _TemplatesDialog(),
);

class _TemplatesDialog extends ConsumerStatefulWidget {
  const _TemplatesDialog();

  @override
  ConsumerState<_TemplatesDialog> createState() => _TemplatesDialogState();
}

class _TemplatesDialogState extends ConsumerState<_TemplatesDialog> {
  /// What may be put in a text — the server fills them in.
  static const _tokens = '{имя} {номер} {сумма} {долг} {компания}';

  final _fields = <ToWriteKind, TextEditingController>{};
  Map<ToWriteKind, MessageTemplate>? _templates;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final got = await ref.read(clientCardRepositoryProvider).templates();
    if (!mounted) return;
    setState(() {
      _templates = got;
      for (final e in got.entries) {
        _fields[e.key] = TextEditingController(text: e.value.text);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(ToWriteKind kind, String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final got = await ref
          .read(clientCardRepositoryProvider)
          .setTemplate(kind, text);
      ref.invalidate(toWriteProvider);
      if (!mounted) return;
      setState(() {
        _templates = got;
        _fields[kind]?.text = got[kind]?.text ?? text;
      });
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(ToWriteKind kind, AppLocalizations l10n) => switch (kind) {
    ToWriteKind.ready => l10n.twTemplateReady,
    ToWriteKind.debt => l10n.twTemplateDebt,
    ToWriteKind.filmDebt => l10n.twTemplateFilm,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final templates = _templates;
    return AlertDialog(
      title: Text(l10n.twTemplates),
      content: SizedBox(
        width: AppBreakpoints.readable,
        child: templates == null
            ? const LinearProgressIndicator()
            : ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    '${l10n.twTemplateHint} $_tokens',
                    style: theme.textTheme.bodySmall,
                  ),
                  for (final kind in ToWriteKind.values)
                    if (_fields[kind] case final field?) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: ValueKey('tw:template:${kind.wire}'),
                        controller: field,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: _label(kind, l10n),
                        ),
                      ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          TextButton(
                            key: ValueKey('tw:template:${kind.wire}:save'),
                            onPressed: _busy
                                ? null
                                : () => unawaited(_save(kind, field.text)),
                            child: Text(l10n.twTemplateSave),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => unawaited(_save(kind, '')),
                            child: Text(l10n.twTemplateReset),
                          ),
                        ],
                      ),
                    ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}
