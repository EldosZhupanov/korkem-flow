import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/reason_dialog.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/mdf/data/film_where_repository.dart';
import 'package:korkem_flow/features/mdf/domain/film_where.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_dates.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The film the shelf cannot give — where to get it (owner, 19.11.2026).
///
/// From the draft's «нет на складе» chip: the sources, their prices with
/// the bringing, and when each would come. On an accepted order the same
/// list orders («Есть — заказать») and offers a look-alike.
Future<void> showFilmWhere(
  BuildContext context, {
  required String order,
  required String film,
  String? phone,
  VoidCallback? onChanged,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final screen = MediaQuery.sizeOf(context);
    return AlertDialog(
      key: const ValueKey('filmWhereDialog'),
      title: Text(l10n.fwTitle),
      content: SizedBox(
        width: AppSpacing.xxxl * 14 < screen.width * 0.9
            ? AppSpacing.xxxl * 14
            : screen.width * 0.9,
        child: SingleChildScrollView(
          child: FilmWhereView(
            order: order,
            only: film,
            phone: phone,
            onChanged: onChanged,
            titled: false,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
      ],
    );
  },
);

class FilmWhereView extends ConsumerWidget {
  const FilmWhereView({
    required this.order,
    this.only,
    this.phone,
    this.onChanged,
    this.titled = true,
    super.key,
  });

  final String order;

  /// One film of the order, by its name; every lacking film when null.
  final String? only;

  /// The customer's phone, for offering a look-alike on WhatsApp.
  final String? phone;

  /// The order itself changed — its film was replaced.
  final VoidCallback? onChanged;
  final bool titled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ref
        .watch(filmWhereProvider(order))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (w) {
            final films = [
              for (final f in w.films)
                if (only == null || f.film == only) f,
            ];
            if (films.isEmpty) {
              return only == null
                  ? const SizedBox.shrink()
                  : Text(l10n.fwNothingShort);
            }
            return Column(
              key: const ValueKey('filmWhere'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (titled) SectionLabel(l10n.fwTitle),
                Text(
                  [
                    l10n.fwNeedBy(mdfDay(w.needBy, year: false)),
                    if (w.urgent) l10n.fwUrgent,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: w.urgent
                        ? context.statusColors.danger
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final f in films)
                  _LackCard(
                    where: w,
                    lack: f,
                    phone: phone,
                    onChanged: onChanged,
                  ),
              ],
            );
          },
        );
  }
}

class _LackCard extends ConsumerStatefulWidget {
  const _LackCard({
    required this.where,
    required this.lack,
    this.phone,
    this.onChanged,
  });

  final FilmWhere where;
  final FilmLack lack;
  final String? phone;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_LackCard> createState() => _LackCardState();
}

class _LackCardState extends ConsumerState<_LackCard> {
  bool _busy = false;

  String get _order => widget.where.order;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(filmWhereProvider(_order));
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _orderFrom(FilmSourceOffer s) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final asked = await showDialog<_Ask>(
      context: context,
      builder: (_) => _OrderDialog(lack: widget.lack, source: s),
    );
    if (asked == null || !mounted) return;
    await _run(() async {
      await ref
          .read(filmWhereRepositoryProvider)
          .order(
            order: _order,
            item: widget.lack.item,
            supplier: s.supplier,
            metres: asked.metres,
            priceM: asked.priceM,
            comesOn: asked.comesOn,
            saidBy: asked.saidBy,
          );
      messenger.showDone(l10n.fwOrderedDone);
    });
  }

  Future<void> _replace(String label) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showReasonDialog(
      context,
      title: l10n.fwReplaceTitle(widget.lack.film, label),
      label: l10n.fwReplaceReason,
      confirm: l10n.fwReplace,
      cancel: l10n.mdfCancel,
      fieldKey: const ValueKey('fwReplaceReason'),
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      await ref
          .read(filmWhereRepositoryProvider)
          .replace(
            order: _order,
            from: widget.lack.film,
            to: label,
            reason: reason,
          );
      widget.onChanged?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final f = widget.lack;
    final accepted = widget.where.accepted;
    return Card(
      key: ValueKey('fwFilm:${f.item}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(f.film, style: theme.textTheme.titleSmall),
                ),
                Text(
                  l10n.fwShort(filmMetres(f.short)),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: status.warning,
                  ),
                ),
              ],
            ),
            for (final o in f.ordered)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  [
                    l10n.fwOrdered(filmMetres(o.metres), o.supplier),
                    ?o.note,
                  ].join(' · '),
                  style: TextStyle(color: status.success),
                ),
              ),
            if (f.nowhere case final day?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.fwNowhere(mdfDay(day, year: false)),
                  style: TextStyle(color: status.danger),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            if (f.sources.isEmpty)
              Text(l10n.fwNoSources(f.maker ?? f.film), style: muted),
            for (final s in f.sources)
              _SourceRow(
                item: f.item,
                source: s,
                onOrder: _busy || !accepted ? null : () => _orderFrom(s),
              ),
            if (!accepted && f.sources.isNotEmpty)
              Text(l10n.fwAcceptFirst, style: muted),
            if (accepted && f.nowhere == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: ValueKey('fwNowhere:${f.item}'),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref
                              .read(filmWhereRepositoryProvider)
                              .nowhere(_order, f.item),
                        ),
                  child: Text(l10n.fwNowhereButton),
                ),
              ),
            if (f.lookalikes.isNotEmpty) ...[
              const Divider(),
              Text(l10n.fwLookalikes, style: theme.textTheme.labelMedium),
              for (final m in f.lookalikes)
                _LookalikeRow(
                  item: f.item,
                  match: m,
                  onOffer: () => ContactActions.whatsAppMessage(
                    widget.phone,
                    l10n.fwOfferText(f.film, '${m.maker} · ${m.name}'),
                  ),
                  onReplace: !accepted || _busy
                      ? null
                      : _replace,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.item, required this.source, this.onOrder});

  final String item;
  final FilmSourceOffer source;
  final VoidCallback? onOrder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final money = mdfMoney(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final s = source;
    final name = [
      s.name,
      if (s.city != null && !s.name.contains(s.city!)) s.city!,
    ].join(' · ');
    final price = switch ((s.priceM, s.deliveryM, s.landedM)) {
      (final p?, final d?, final l?) when d > 0 => l10n.fwPrice(
        money.format(p),
        money.format(d),
        money.format(l),
      ),
      (final p?, _, _) => l10n.fwPriceOnly(money.format(p)),
      _ => null,
    };
    final (arrives, colour) = switch ((s.days, s.comesOn, s.inTime)) {
      (final d?, final day?, final ok) => (
        [
          l10n.fwComes('$d', mdfDay(day, year: false)),
          if (ok ?? false) l10n.fwInTime else l10n.fwLate,
        ].join(' · '),
        (ok ?? false) ? status.success : status.danger,
      ),
      _ => (l10n.fwLeadUnknown, theme.colorScheme.onSurfaceVariant),
    };
    return Container(
      key: ValueKey('fwSource:$item:${s.supplier}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: s.advised
            ? status.success.withValues(alpha: AppTint.surface)
            : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (s.advised) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.fwAdvised,
                        key: ValueKey('fwAdvised:$item:${s.supplier}'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: status.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(arrives, style: TextStyle(color: colour)),
                Text(
                  [
                    ?price,
                    if (price != null && !s.priceKnown) l10n.fwCardPrice,
                    if (s.times > 0) l10n.fwTimes('${s.times}'),
                    ?s.contact,
                  ].join(' · '),
                  style: muted,
                ),
              ],
            ),
          ),
          if (s.phone != null)
            IconButton(
              tooltip: s.phone,
              icon: const Icon(AppIcons.call),
              onPressed: () => ContactActions.call(s.phone),
            ),
          if (s.whatsapp ?? s.phone case final wa?)
            IconButton(
              tooltip: wa,
              icon: const Icon(AppIcons.whatsApp),
              onPressed: () => ContactActions.whatsApp(wa),
            ),
          FilledButton.tonal(
            key: ValueKey('fwOrder:$item:${s.supplier}'),
            onPressed: onOrder,
            child: Text(l10n.fwOrderButton),
          ),
        ],
      ),
    );
  }
}

class _LookalikeRow extends StatelessWidget {
  const _LookalikeRow({
    required this.item,
    required this.match,
    required this.onOffer,
    this.onReplace,
  });

  final String item;
  final DecorMatch match;
  final VoidCallback onOffer;

  /// Given the look-alike's film name; only a film on our books can be put
  /// in the order.
  final ValueChanged<String>? onReplace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final m = match;
    final films = [
      for (final f in m.films)
        if (f.label.isNotEmpty) f,
    ]..sort((a, b) => b.free.compareTo(a.free));
    final label = films.firstOrNull?.label;
    return ListTile(
      key: ValueKey('fwLike:$item:${m.decor}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: FilmSample(argb: m.argb, image: m.image),
      title: Text(filmTitle(m.name, m.code)),
      subtitle: Text(
        [
          m.maker,
          if (m.onShelf > 0) l10n.fwOnShelf(filmMetres(m.onShelf)),
        ].join(' · '),
        style: m.onShelf > 0 ? TextStyle(color: status.success) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('fwOffer:$item:${m.decor}'),
            tooltip: l10n.fwOffer,
            icon: const Icon(AppIcons.whatsApp),
            onPressed: onOffer,
          ),
          if (label != null)
            OutlinedButton(
              key: ValueKey('fwReplace:$item:${m.decor}'),
              onPressed: onReplace == null ? null : () => onReplace!(label),
              child: Text(l10n.fwReplace),
            ),
        ],
      ),
    );
  }
}

typedef _Ask = ({
  double metres,
  double? priceM,
  String? comesOn,
  String? saidBy,
});

/// «Есть — заказать»: how many metres, the price the manager named, when
/// it comes and who said so.
class _OrderDialog extends StatefulWidget {
  const _OrderDialog({required this.lack, required this.source});

  final FilmLack lack;
  final FilmSourceOffer source;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  late final _metres = TextEditingController(
    text: widget.lack.short.ceil().toString(),
  );
  late final _price = TextEditingController(
    text: widget.source.priceM?.toStringAsFixed(0) ?? '',
  );
  final _said = TextEditingController();
  late DateTime? _comes = widget.source.comesOn == null
      ? null
      : DateTime.tryParse(widget.source.comesOn!);

  @override
  void dispose() {
    for (final c in [_metres, _price, _said]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _num(String v) =>
      double.tryParse(v.trim().replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _comes ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 120)),
    );
    if (picked != null) setState(() => _comes = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metres = _num(_metres.text);
    return AlertDialog(
      key: const ValueKey('fwOrderDialog'),
      title: Text(l10n.fwOrderTitle(widget.lack.film, widget.source.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('fwMetres'),
            controller: _metres,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.fwMetres),
          ),
          TextField(
            key: const ValueKey('fwPrice'),
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.fwPriceField),
          ),
          TextField(
            key: const ValueKey('fwSaid'),
            controller: _said,
            decoration: InputDecoration(labelText: l10n.fwSaidBy),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('fwComes'),
              onPressed: _pickDay,
              icon: const Icon(AppIcons.calendar),
              label: Text(
                [
                  l10n.fwComesOn,
                  if (_comes case final d?) mdfDayOf(d),
                ].join(': '),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mdfCancel),
        ),
        FilledButton(
          key: const ValueKey('fwOrderConfirm'),
          onPressed: metres == null || metres <= 0
              ? null
              : () => Navigator.of(context).pop((
                  metres: metres,
                  priceM: _num(_price.text),
                  comesOn: _comes == null ? null : mdfIso(_comes!),
                  saidBy: _said.text.trim().isEmpty ? null : _said.text.trim(),
                )),
          child: Text(l10n.fwOrderConfirm),
        ),
      ],
    );
  }
}
