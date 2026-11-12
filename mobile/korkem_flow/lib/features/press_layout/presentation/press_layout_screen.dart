import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/press_layout/data/press_layout_repository.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_editor.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_map.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_print.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

String _metres(BuildContext context, double value) => NumberFormat(
  '0.##',
  Localizations.localeOf(context).toLanguageTag(),
).format(value);

/// The foot of every printed map: who checked the layout, and where the
/// operator and the foreman sign.
String pressPrintFooter(AppLocalizations l10n, OrderPressLayout layout) => [
  if (layout.approvedBy != null)
    l10n.pressPrintApproved(layout.approvedBy!, layout.approvedAt ?? ''),
  l10n.pressPrintSigns,
].join('     ');

/// The films on paper, through the system print dialog.
/// The printed map's words in the reader's language.
PressPrintWords pressPrintWordsOf(AppLocalizations l10n) => (
  textured: l10n.pressTextured,
  plain: l10n.pressPlain,
  total: l10n.pressFilmTotal,
  sheet: l10n.pressPrintSheet,
  copies: l10n.pressPrintCopies,
  size: l10n.pressPrintSize,
  section: l10n.pressPrintSection,
  area: l10n.pressPrintArea,
  parts: l10n.pressPrintParts,
  waste: l10n.pressPrintWaste,
  count: l10n.pressPrintCount,
  perimeter: l10n.pressPrintPerimeter,
  gap: l10n.pressPrintGap,
  details: l10n.pressPrintDetails,
  tooBig: l10n.pressTooBig,
  page: l10n.pressPrintPage,
);

Future<void> _print(
  BuildContext context,
  String salesOrder,
  List<FilmLayout> films,
  PressSettings press, {
  String? footer,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final words = pressPrintWordsOf(l10n);
  try {
    await printPressLayout(
      name: salesOrder,
      build: () => buildPressPdf(
        films,
        press,
        words,
        locale: locale,
        footer: footer,
      ),
    );
  } on Object catch (error) {
    messenger.showFailure(error, l10n);
  }
}

/// An order on the membrane-vacuum press: per film, the title the operator
/// reads first, whether it may be turned, the metres, and each load drawn.
class PressLayoutScreen extends ConsumerWidget {
  const PressLayoutScreen({required this.salesOrder, super.key});

  final String salesOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(orderPressLayoutProvider(salesOrder));
    final films = layout.value?.films ?? const <FilmLayout>[];
    return AppScreen(
      title: l10n.pressLayoutTitle,
      actions: [
        IconButton(
          key: const ValueKey('pressPrintAll'),
          tooltip: l10n.pressPrint,
          icon: const Icon(AppIcons.print),
          onPressed: films.isEmpty
              ? null
              : () => _print(
                  context,
                  salesOrder,
                  films,
                  layout.requireValue.press,
                  footer: pressPrintFooter(l10n, layout.requireValue),
                ),
        ),
      ],
      body: layout.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(orderPressLayoutProvider(salesOrder)),
        ),
        data: (data) => data.films.isEmpty
            ? EmptyView(
                icon: AppIcons.pressLayout,
                title: l10n.pressLayoutTitle,
                message: l10n.pressNoFilm,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  ReadableWidth(
                    child: _Approval(layout: data, salesOrder: salesOrder),
                  ),
                  for (final film in data.films)
                    ReadableWidth(
                      child: _FilmCard(
                        film: film,
                        press: data.press,
                        salesOrder: salesOrder,
                        canCorrect: data.canCorrect,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _FilmCard extends ConsumerWidget {
  const _FilmCard({
    required this.film,
    required this.press,
    required this.salesOrder,
    required this.canCorrect,
  });

  final FilmLayout film;
  final PressSettings press;
  final String salesOrder;
  final bool canCorrect;

  Future<void> _correct(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_Correction>(
      context: context,
      builder: (_) => _CorrectDialog(film: film),
    );
    if (result == null) return;
    try {
      await ref
          .read(pressLayoutRepositoryProvider)
          .setFilmMetres(
            salesOrder,
            film.decor,
            metres: result.metres,
            reason: result.reason,
          );
      ref.invalidate(orderPressLayoutProvider(salesOrder));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warning = context.statusColors.warning;
    return Card(
      key: ValueKey('pressFilm:${film.decor}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              film.title,
              key: ValueKey('pressTitle:${film.decor}'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (film.textured)
              DecoratedBox(
                key: ValueKey('pressTextured:${film.decor}'),
                decoration: BoxDecoration(
                  color: warning.withValues(alpha: AppTint.warningBand),
                  border: Border.all(color: warning, width: AppStroke.focus),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(AppIcons.textured, color: warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.pressTextured,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(AppIcons.direction, color: warning),
                    ],
                  ),
                ),
              )
            else
              Text(
                l10n.pressPlain,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.pressFilmTotal(_metres(context, film.filmM)),
                    key: ValueKey('pressMetres:${film.decor}'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('pressPrint:${film.decor}'),
                  tooltip: l10n.pressPrint,
                  icon: const Icon(AppIcons.print),
                  onPressed: () => _print(context, salesOrder, [film], press),
                ),
                if (canCorrect && film.loads.isNotEmpty)
                  IconButton(
                    key: ValueKey('pressEdit:${film.decor}'),
                    tooltip: l10n.pressEdit,
                    icon: const Icon(AppIcons.edit),
                    onPressed: () async {
                      final kept = await showPressEditor(
                        context,
                        salesOrder: salesOrder,
                        film: film,
                        press: press,
                      );
                      if (kept) {
                        ref.invalidate(orderPressLayoutProvider(salesOrder));
                      }
                    },
                  ),
                if (canCorrect)
                  TextButton.icon(
                    key: ValueKey('pressCorrect:${film.decor}'),
                    onPressed: () => _correct(context, ref),
                    icon: const Icon(AppIcons.edit, size: AppIconSize.dense),
                    label: Text(l10n.pressCorrect),
                  ),
              ],
            ),
            if (film.saved > 0)
              Text(
                l10n.pressSmartSaved(
                  _metres(context, film.plainM!),
                  _metres(context, film.saved),
                ),
                key: ValueKey('pressSaved:${film.decor}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.statusColors.success,
                ),
              ),
            if (film.manual)
              Text(
                l10n.pressManual,
                key: ValueKey('pressManual:${film.decor}'),
                style: theme.textTheme.bodySmall?.copyWith(color: warning),
              )
            else if (film.corrected)
              Text(
                l10n.pressCorrected(
                  film.reason ?? '',
                  _metres(context, film.layoutM),
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: warning),
              ),
            if (film.tooBig.isNotEmpty)
              Text(
                l10n.pressTooBig(film.tooBig.toSet().join(', ')),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            for (final (i, load) in film.loads.indexed) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.pressLoad(i + 1, _metres(context, load.filmM)),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              PressMap(
                key: ValueKey('pressMap:${film.decor}:$i'),
                load: load,
                widthMm: press.widthMm,
                textured: film.textured,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Раскрой проверен — запустить»: the manager looked at the maps and the
/// metres. What the shelf lacks goes on «К заказу» with the mark.
class _Approval extends ConsumerWidget {
  const _Approval({required this.layout, required this.salesOrder});

  final OrderPressLayout layout;
  final String salesOrder;

  Future<void> _set(
    BuildContext context,
    WidgetRef ref, {
    required bool approved,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final number = NumberFormat(
      '0.##',
      Localizations.localeOf(context).toLanguageTag(),
    );
    try {
      final result = await ref
          .read(pressLayoutRepositoryProvider)
          .approve(salesOrder, approved: approved);
      ref.invalidate(orderPressLayoutProvider(salesOrder));
      if (result.short.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.pressShortAdded(
                [
                  for (final s in result.short)
                    '${s.decor} — ${number.format(s.metres)}',
                ].join('; '),
              ),
            ),
          ),
        );
      }
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final by = layout.approvedBy;
    if (by == null && !layout.canCorrect) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: by == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('pressApprove'),
                onPressed: () => _set(context, ref, approved: true),
                icon: const Icon(AppIcons.check),
                label: Text(l10n.pressApprove),
              ),
            )
          : Row(
              children: [
                Icon(AppIcons.success, color: context.statusColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.pressApproved(by, layout.approvedAt ?? ''),
                    key: const ValueKey('pressApproved'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (layout.canCorrect)
                  TextButton(
                    key: const ValueKey('pressUnapprove'),
                    onPressed: () => _set(context, ref, approved: false),
                    child: Text(l10n.pressUnapprove),
                  ),
              ],
            ),
    );
  }
}

typedef _Correction = ({double? metres, String? reason});

class _CorrectDialog extends StatefulWidget {
  const _CorrectDialog({required this.film});

  final FilmLayout film;

  @override
  State<_CorrectDialog> createState() => _CorrectDialogState();
}

class _CorrectDialogState extends State<_CorrectDialog> {
  late final _metres = TextEditingController(
    text: widget.film.corrected ? '${widget.film.filmM}' : '',
  );
  late final _reason = TextEditingController(text: widget.film.reason ?? '');

  @override
  void dispose() {
    _metres.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.pressCorrect),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('pressCorrectMetres'),
            controller: _metres,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
            decoration: InputDecoration(labelText: l10n.pressMetres),
          ),
          TextField(
            key: const ValueKey('pressCorrectReason'),
            controller: _reason,
            decoration: InputDecoration(labelText: l10n.pressReason),
          ),
        ],
      ),
      actions: [
        if (widget.film.corrected)
          TextButton(
            key: const ValueKey('pressBackToLayout'),
            onPressed: () => Navigator.of(
              context,
            ).pop<_Correction>((metres: null, reason: null)),
            child: Text(l10n.pressBackToLayout),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('pressCorrectSave'),
          onPressed: () {
            final metres = double.tryParse(_metres.text.replaceAll(',', '.'));
            if (metres == null || metres <= 0) return;
            Navigator.of(context).pop<_Correction>((
              metres: metres,
              reason: _reason.text.trim(),
            ));
          },
          child: Text(l10n.facadePricesSave),
        ),
      ],
    );
  }
}
