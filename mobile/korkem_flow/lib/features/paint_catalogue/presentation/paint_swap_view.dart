import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/mdf/data/mdf_order_repository.dart';
import 'package:korkem_flow/features/mdf/data/mdf_paint_repository.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_catalogue_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The paint colours of an order, as its positions name them.
List<String> mdfPaintColours(MdfOrder o) => {
  for (final l in o.lines)
    if (l.coating == MdfCoating.paint) ...[
      if ((l.film ?? '').trim().isNotEmpty) l.film!.trim(),
      if ((l.filmBack ?? '').trim().isNotEmpty) l.filmBack!.trim(),
    ],
}.toList();

/// «Замена цвета» on the order's card (owner, 19.11.2026: «клиент выбирает
/// краску, но её нет у поставщиков — мы заменили более похожим»): each
/// colour swapped — asked of the customer, or agreed and by whom — and the
/// button that starts it for a colour no supplier has.
class MdfPaintSwapView extends ConsumerWidget {
  const MdfPaintSwapView({required this.order, super.key});

  final MdfOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final colours = mdfPaintColours(o);
    if (o.status == MdfStatus.draft ||
        (colours.isEmpty && o.paintSwaps.isEmpty)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final open =
        o.status != MdfStatus.handedOver && o.status != MdfStatus.cancelled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in o.paintSwaps)
            InkWell(
              key: ValueKey('mdfSwap:${s.key}'),
              onTap: s.agreed || !open
                  ? null
                  : () => unawaited(showPaintSwap(context, o, s.from)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: s.from,
                        style: s.agreed && s.way == PaintSwapWay.replace
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      TextSpan(text: ' → ${paintSwapTarget(l10n, s)}'),
                      TextSpan(
                        text: ' · ${paintSwapState(l10n, s)}',
                        style: TextStyle(
                          color: s.agreed ? status.success : status.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          if (open && colours.isNotEmpty)
            TextButton.icon(
              key: const ValueKey('mdfSwapStart'),
              onPressed: () async {
                final colour = colours.length == 1
                    ? colours.single
                    : await showDialog<String>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text(l10n.pswWhich),
                          children: [
                            for (final c in colours)
                              SimpleDialogOption(
                                key: ValueKey('mdfSwapPick:$c'),
                                onPressed: () => Navigator.of(context).pop(c),
                                child: Text(c),
                              ),
                          ],
                        ),
                      );
                if (colour != null && context.mounted) {
                  await showPaintSwap(context, o, colour);
                }
              },
              icon: const Icon(AppIcons.colour),
              label: Text(l10n.pswStart),
            ),
        ],
      ),
    );
  }
}

/// «RAL 6011», «колеровка», «ждём родной до 27.11».
String paintSwapTarget(AppLocalizations l10n, PaintSwap s) => switch (s.way) {
  PaintSwapWay.replace => s.to ?? '—',
  PaintSwapWay.tint => l10n.pswWayTint,
  PaintSwapWay.wait =>
    s.waitUntil == null
        ? l10n.pswWayWait
        : l10n.pswWaitUntil(_day(s.waitUntil!)),
};

/// «ждём согласия» or «согласовал Ерлан 19.11 по телефону».
String paintSwapState(AppLocalizations l10n, PaintSwap s) {
  if (!s.agreed) return l10n.pswAsked;
  final via = switch (s.agreedVia) {
    'whatsapp' => l10n.pswViaWhatsApp,
    'in_person' => l10n.pswViaInPerson,
    _ => l10n.pswViaPhone,
  };
  return l10n.pswAgreed(
    s.agreedBy ?? '—',
    s.agreedAt == null ? '' : _day(s.agreedAt!),
    via,
  );
}

String _day(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}';
}

/// The swap window for one colour of an order.
Future<void> showPaintSwap(BuildContext context, MdfOrder order, String colour) =>
    showDialog<void>(
      context: context,
      builder: (_) => _SwapDialog(order: order, colour: colour),
    );

class _SwapDialog extends ConsumerStatefulWidget {
  const _SwapDialog({required this.order, required this.colour});

  final MdfOrder order;
  final String colour;

  @override
  ConsumerState<_SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends ConsumerState<_SwapDialog> {
  late final Future<PaintSwapOptions> _options = ref
      .read(paintCatalogueRepositoryProvider)
      .swapOptions(widget.order.name, widget.colour);
  PaintSwapWay _way = PaintSwapWay.replace;
  PaintColour? _to;
  DateTime? _waitUntil;
  bool _busy = false;
  String? _error;

  PaintSwap? get _asked => widget.order.paintSwaps
      .where((s) => !s.agreed && s.from == widget.colour)
      .firstOrNull;

  void _refresh() {
    ref
      ..invalidate(mdfOrderProvider(widget.order.name))
      ..invalidate(mdfPaintBoardProvider);
  }

  Future<void> _step(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _refresh();
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  /// Asked of the customer: the window closes, WhatsApp opens with the
  /// words typed.
  Future<void> _ask() async {
    final phone = widget.order.phone;
    PaintSwapAsked? asked;
    await _step(() async {
      asked = await ref
          .read(paintCatalogueRepositoryProvider)
          .proposeSwap(
          widget.order.name,
          widget.colour,
          _way,
          to: _to?.value,
          waitUntil: _waitUntil == null
              ? null
              : '${_waitUntil!.year}-'
                    '${_waitUntil!.month.toString().padLeft(2, '0')}-'
                    '${_waitUntil!.day.toString().padLeft(2, '0')}',
        );
    });
    if (asked case final a?) {
      unawaited(ContactActions.whatsAppMessage(a.phone ?? phone, a.message));
    }
  }

  Future<void> _agree(String via) => _step(
    () => ref
        .read(paintCatalogueRepositoryProvider)
        .agreeSwap(widget.order.name, widget.colour, via: via),
  );

  Future<void> _cancel() => _step(
    () => ref
        .read(paintCatalogueRepositoryProvider)
        .cancelSwap(widget.order.name, widget.colour),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asked = _asked;
    return AlertDialog(
      key: const ValueKey('pswDialog'),
      title: Text(l10n.pswTitle(widget.order.name)),
      content: SizedBox(
        width: AppSpacing.xxxl * 10,
        child: FutureBuilder<PaintSwapOptions>(
          future: _options,
          builder: (context, snap) {
            if (snap.hasError) return Text('${snap.error}');
            final options = snap.data;
            if (options == null) {
              return const Center(
                heightFactor: 3,
                child: CircularProgressIndicator(),
              );
            }
            final from = PaintColour(
              key: '',
              code: '',
              name: widget.colour,
              value: widget.colour,
              hex: options.hex,
            );
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Compare(from: from, to: _way == PaintSwapWay.replace ? _to : null),
                  if (asked != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.pswAskedLine(paintSwapTarget(l10n, asked)),
                      key: const ValueKey('pswAsked'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.pswHow, style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<PaintSwapWay>(
                      key: const ValueKey('pswWay'),
                      segments: [
                        ButtonSegment(
                          value: PaintSwapWay.replace,
                          icon: const Icon(AppIcons.refresh),
                          label: Text(l10n.pswReplace),
                        ),
                        ButtonSegment(
                          value: PaintSwapWay.tint,
                          icon: const Icon(AppIcons.colour),
                          label: Text(l10n.pswTint),
                        ),
                        ButtonSegment(
                          value: PaintSwapWay.wait,
                          icon: const Icon(AppIcons.schedule),
                          label: Text(l10n.pswWait),
                        ),
                      ],
                      selected: {_way},
                      onSelectionChanged: (s) =>
                          setState(() => _way = s.first),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    switch (_way) {
                      PaintSwapWay.replace => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.pswNearest, style: theme.textTheme.labelLarge),
                          SimilarList(
                            colours: options.similar,
                            selected: _to?.key,
                            onTap: (x) => setState(() => _to = x),
                          ),
                        ],
                      ),
                      PaintSwapWay.tint => Text(l10n.pswTintHint),
                      PaintSwapWay.wait => OutlinedButton.icon(
                        key: const ValueKey('pswWaitDate'),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: now,
                            lastDate: DateTime(now.year, now.month + 4),
                            initialDate: DateTime(
                              now.year,
                              now.month,
                              now.day + 7,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _waitUntil = picked);
                          }
                        },
                        icon: const Icon(AppIcons.calendar),
                        label: Text(
                          _waitUntil == null
                              ? l10n.pswWaitPick
                              : l10n.pswWaitUntil(
                                  _day(_waitUntil!.toIso8601String()),
                                ),
                        ),
                      ),
                    },
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.pswRule,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        if (asked != null) ...[
          TextButton(
            key: const ValueKey('pswCancel'),
            onPressed: _busy ? null : _cancel,
            child: Text(l10n.pswCancel),
          ),
          OutlinedButton(
            key: const ValueKey('pswAgreeWhatsApp'),
            onPressed: _busy ? null : () => _agree('whatsapp'),
            child: Text(l10n.pswAgreeWhatsApp),
          ),
          FilledButton(
            key: const ValueKey('pswAgreePhone'),
            onPressed: _busy ? null : () => _agree('phone'),
            child: Text(l10n.pswAgreePhone),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.mdfCancel),
          ),
          FilledButton.icon(
            key: const ValueKey('pswAsk'),
            onPressed: _busy || (_way == PaintSwapWay.replace && _to == null)
                ? null
                : _ask,
            icon: const Icon(AppIcons.whatsApp),
            label: Text(l10n.pswAsk),
          ),
        ],
      ],
    );
  }
}

/// The customer's colour beside the one offered.
class _Compare extends StatelessWidget {
  const _Compare({required this.from, this.to});

  final PaintColour from;
  final PaintColour? to;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget side(PaintColour? x, String label, String key) => Expanded(
      child: Column(
        children: [
          SizedBox(
            height: AppSpacing.xxxl * 1.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: x == null
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    )
                  : PaintSwatch(colour: x),
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            x?.title ?? '—',
            key: ValueKey(key),
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        side(from, l10n.pswChosen, 'pswFrom'),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Icon(AppIcons.forward),
        ),
        side(to, l10n.pswOffered, 'pswTo'),
      ],
    );
  }
}
