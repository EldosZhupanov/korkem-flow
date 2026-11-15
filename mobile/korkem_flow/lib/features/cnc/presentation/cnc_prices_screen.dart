import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/cnc/data/cnc_repository.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_receipt_terms.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// «Прайс услуг ЧПУ» (owner, 15.11.2026): each service in its own unit, a
/// furniture maker's price beside it, the machine minutes a unit takes; the
/// urgency percentage, the minimum order and the machine's working day.
class CncPricesScreen extends ConsumerWidget {
  const CncPricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = mdfMoney(context);
    final services = ref.watch(cncServicesProvider);
    final settings = ref.watch(cncSettingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cncPricesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('cncServiceAdd'),
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(AppIcons.add),
        label: Text(l10n.cncServiceAdd),
      ),
      body: switch (services) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (settings != null)
              ReadableWidth(
                child: ListTile(
                  key: const ValueKey('cncSettings'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.settings),
                  title: Text(l10n.cncSettingsTitle),
                  subtitle: Text(
                    [
                      l10n.cncUrgentPct(filmMetres(settings.urgentPct)),
                      l10n.cncMinOrder(money.format(settings.minOrder)),
                      l10n.cncDayMinutes(filmMetres(settings.dayMinutes)),
                    ].join(' · '),
                  ),
                  onTap: () => _settings(context, ref, settings),
                ),
              ),
            for (final g in {for (final s in value) s.group ?? ''}) ...[
              const SizedBox(height: AppSpacing.sm),
              ReadableWidth(
                child: SectionLabel(g.isEmpty ? l10n.cncNoGroup : g),
              ),
              for (final s in value.where((s) => (s.group ?? '') == g))
                ReadableWidth(
                  child: ListTile(
                    key: ValueKey('cncServiceRow:${s.title}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      s.title,
                      style: TextStyle(
                        color: s.enabled ? null : theme.disabledColor,
                      ),
                    ),
                    subtitle: Text(
                      [
                        s.unit,
                        if (s.minutes > 0)
                          l10n.cncPerUnitMinutes(filmMetres(s.minutes)),
                        if (s.priceTrade case final t?)
                          l10n.cncTradePrice(money.format(t)),
                        if (!s.enabled) l10n.cncServiceOff,
                      ].join(' · '),
                    ),
                    trailing: Text(
                      s.byAgreement
                          ? l10n.cncByAgreement
                          : money.format(s.price),
                      style: theme.textTheme.titleSmall,
                    ),
                    onTap: () => _edit(context, ref, s),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xxxl * 2),
          ],
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(cncServicesProvider),
        ),
        _ => const LinearProgressIndicator(),
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CncService? service,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ServiceDialog(service: service),
    );
    if (saved ?? false) {
      ref.invalidate(cncServicesProvider);
      messenger.showDone(l10n.cncSaved);
    }
  }

  Future<void> _settings(
    BuildContext context,
    WidgetRef ref,
    CncSettings now,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SettingsDialog(now: now),
    );
    if (saved ?? false) ref.invalidate(cncSettingsProvider);
  }
}

Widget _number(
  TextEditingController c,
  String label,
  String key,
  VoidCallback onChanged,
) => TextField(
  key: ValueKey(key),
  controller: c,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
  onChanged: (_) => onChanged(),
  decoration: InputDecoration(labelText: label, isDense: true),
);

class _ServiceDialog extends ConsumerStatefulWidget {
  const _ServiceDialog({this.service});

  final CncService? service;

  @override
  ConsumerState<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends ConsumerState<_ServiceDialog> {
  late final _title = TextEditingController(text: widget.service?.title);
  late final _group = TextEditingController(text: widget.service?.group);
  late final _price = TextEditingController(
    text: (widget.service?.price ?? 0) > 0 ? filmMetres(widget.service!.price) : '',
  );
  late final _trade = TextEditingController(
    text: widget.service?.priceTrade == null ? '' : filmMetres(widget.service!.priceTrade!),
  );
  late final _minutes = TextEditingController(
    text: (widget.service?.minutes ?? 0) > 0 ? filmMetres(widget.service!.minutes) : '',
  );
  late String _unit = widget.service?.unit ?? cncUnits.first;
  late bool _enabled = widget.service?.enabled ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _group, _price, _trade, _minutes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(cncRepositoryProvider).saveService(
        title: _title.text.trim(),
        unit: _unit,
        group: _group.text.trim().isEmpty ? null : _group.text.trim(),
        price: filmNumber(_price.text) ?? 0,
        priceTrade: filmNumber(_trade.text) ?? 0,
        minutes: filmNumber(_minutes.text) ?? 0,
        id: widget.service?.id,
        enabled: _enabled,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessageOf(e, AppLocalizations.of(context));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.service == null ? l10n.cncServiceAdd : l10n.cncServiceEdit),
      content: SizedBox(
        width: AppSpacing.xxxl * 8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('cncServiceTitle'),
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.cncServiceTitle),
              ),
              TextField(
                key: const ValueKey('cncServiceGroup'),
                controller: _group,
                decoration: InputDecoration(labelText: l10n.cncServiceGroup),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final u in cncUnits)
                    ChoiceChip(
                      key: ValueKey('cncServiceUnit:$u'),
                      label: Text(u),
                      selected: _unit == u,
                      onSelected: (_) => setState(() => _unit = u),
                    ),
                ],
              ),
              if (_unit != cncByAgreement) ...[
                _number(_price, l10n.cncServicePrice, 'cncServicePrice', () {}),
                _number(_trade, l10n.cncServiceTrade, 'cncServiceTrade', () {}),
              ],
              _number(
                _minutes,
                l10n.cncServiceMinutes,
                'cncServiceMinutes',
                () {},
              ),
              SwitchListTile(
                key: const ValueKey('cncServiceEnabled'),
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: Text(l10n.cncServiceOn),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('cncServiceSave'),
          onPressed: _busy || _title.text.trim().isEmpty ? null : _save,
          child: Text(l10n.cncOk),
        ),
      ],
    );
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({required this.now});

  final CncSettings now;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late final _urgent = TextEditingController(text: filmMetres(widget.now.urgentPct));
  late final _min = TextEditingController(text: filmMetres(widget.now.minOrder));
  late final _day = TextEditingController(text: filmMetres(widget.now.dayMinutes));
  String? _error;

  @override
  void dispose() {
    for (final c in [_urgent, _min, _day]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.cncSettingsTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _number(_urgent, l10n.cncUrgentPctLabel, 'cncSetUrgent', () {}),
          _number(_min, l10n.cncMinOrderLabel, 'cncSetMin', () {}),
          _number(_day, l10n.cncDayMinutesLabel, 'cncSetDay', () {}),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('cncSettingsSave'),
          onPressed: () async {
            try {
              await ref.read(cncRepositoryProvider).setSettings(
                urgentPct: filmNumber(_urgent.text),
                minOrder: filmNumber(_min.text),
                dayMinutes: filmNumber(_day.text),
              );
              if (context.mounted) Navigator.of(context).pop(true);
            } on Object catch (e) {
              if (context.mounted) {
                setState(() => _error = errorMessageOf(e, l10n));
              }
            }
          },
          child: Text(l10n.cncOk),
        ),
      ],
    );
  }
}
