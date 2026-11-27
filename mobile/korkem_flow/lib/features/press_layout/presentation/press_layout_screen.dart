import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/film_catalog/data/film_catalog_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_orders_page.dart';
import 'package:korkem_flow/features/press_layout/data/press_layout_repository.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_editor.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_map.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_panel.dart';
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
  unchecked: l10n.pressGrainUncheckedPrint,
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
  dimension: l10n.pressTableDimension,
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
/// Beside it the press panel (owner, 13.11.2026: «как в Cutting»): the
/// table, the gap, the sections, how hard and which way — tried at once,
/// kept for this order alone or for the press.
class PressLayoutScreen extends ConsumerStatefulWidget {
  const PressLayoutScreen({required this.salesOrder, super.key});

  final String salesOrder;

  @override
  ConsumerState<PressLayoutScreen> createState() => _PressLayoutScreenState();
}

class _PressLayoutScreenState extends ConsumerState<PressLayoutScreen> {
  /// The panel's figures; null — the press's own, nothing tried.
  PressTune? _tune;

  /// The films laid out with them, by decor.
  Map<String, PressPreview> _tried = const {};
  bool _trying = false;
  bool _saving = false;
  Timer? _wait;
  int _round = 0;

  /// Bumped on a reset, so the panel's fields start again.
  int _resets = 0;

  String get _order => widget.salesOrder;

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  void _change(OrderPressLayout data, PressTune tune) {
    setState(() => _tune = tune);
    _wait?.cancel();
    if (!tune.differsFrom(data.press)) {
      setState(() => _tried = const {});
      return;
    }
    // A figure typed digit by digit is tried once it rests.
    _wait = Timer(AppDebounce.search, () => _try(data, tune));
  }

  Future<void> _try(OrderPressLayout data, PressTune tune) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final round = ++_round;
    setState(() => _trying = true);
    try {
      final repo = ref.read(pressLayoutRepositoryProvider);
      final tried = {
        for (final f in data.films)
          f.decor: await repo.preview(_order, f, tune),
      };
      if (!mounted || round != _round) return;
      setState(() => _tried = tried);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted && round == _round) setState(() => _trying = false);
    }
  }

  /// «Чуть-чуть не влезло — посмотреть»: the panel's gap set to the hint's;
  /// the films laid out with it, nothing kept until the manager says.
  void _tryGap(OrderPressLayout data, double gap) {
    final tune = (_tune ?? PressTune.of(data.press)).copyWith(gapMm: gap);
    setState(() => _resets++);
    _change(data, tune);
  }

  void _reset() {
    _wait?.cancel();
    _round++;
    setState(() {
      _tune = null;
      _tried = const {};
      _trying = false;
      _resets++;
    });
  }

  /// «Только для этого заказа»: each film's tried layout kept as the
  /// order's own, checked against the panel's figures.
  Future<void> _keepForOrder() async {
    final tune = _tune;
    if (tune == null || _tried.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final repo = ref.read(pressLayoutRepositoryProvider);
      for (final t in _tried.values) {
        await repo.saveLayout(
          _order,
          t.film.decor,
          t.film.loads,
          press: tune.press,
        );
      }
      ref.invalidate(orderPressLayoutProvider(_order));
      if (mounted) _reset();
      messenger.showSnackBar(SnackBar(content: Text(l10n.pressTuneKept)));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// «Сохранить для пресса»: the press's own figures — every new layout.
  Future<void> _keepForPress() async {
    final tune = _tune;
    if (tune == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(pressLayoutRepositoryProvider)
          .saveSettings(
            lengthMm: tune.lengthMm,
            widthMm: tune.widthMm,
            marginMm: tune.marginMm,
            gapMm: tune.gapMm,
            sections: tune.sections,
          );
      ref
        ..invalidate(orderPressLayoutProvider(_order))
        ..invalidate(pressSettingsProvider);
      if (mounted) _reset();
      messenger.showSnackBar(SnackBar(content: Text(l10n.pressTuneSaved)));
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(orderPressLayoutProvider(_order));
    final films = layout.value?.films ?? const <FilmLayout>[];
    return AppScreen(
      title: l10n.pressLayoutTitle,
      // The panel stands beside the maps; each card keeps a readable width.
      fullWidth: true,
      actions: [
        IconButton(
          key: const ValueKey('pressPrintAll'),
          tooltip: l10n.pressPrint,
          icon: const Icon(AppIcons.print),
          onPressed: films.isEmpty
              ? null
              : () => _print(
                  context,
                  _order,
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
          onRetry: () => ref.invalidate(orderPressLayoutProvider(_order)),
        ),
        data: (data) {
          if (data.films.isEmpty) {
            return EmptyView(
              icon: AppIcons.pressLayout,
              title: l10n.pressLayoutTitle,
              message: l10n.pressNoFilm,
            );
          }
          final tune = _tune ?? PressTune.of(data.press);
          final tried = _tried;
          final shownPress = tried.isEmpty
              ? data.press
              : PressSettings(
                  lengthMm: tune.lengthMm,
                  widthMm: tune.widthMm,
                  marginMm: tune.marginMm,
                  gapMm: tune.gapMm,
                  sections: tune.sections,
                  canEdit: data.press.canEdit,
                );
          final panel = data.canCorrect
              ? PressPanel(
                  key: ValueKey('pressPanel:$_resets'),
                  tune: tune,
                  tried: tried.isNotEmpty,
                  busy: _trying || _saving,
                  canSavePress: data.press.canEdit,
                  onChanged: (t) => _change(data, t),
                  onReset: _reset,
                  onKeepForOrder: _keepForOrder,
                  onKeepForPress: _keepForPress,
                )
              : null;
          final items = <Widget>[
            ReadableWidth(
              child: _Approval(layout: data, salesOrder: _order),
            ),
            if (tried.isNotEmpty)
              ReadableWidth(
                child: _Compare(
                  before: data.films.fold<double>(0, (s, f) => s + f.filmM),
                  after: tried.values.fold<double>(
                    0,
                    (s, t) => s + t.film.filmM,
                  ),
                ),
              ),
            for (final film in data.films)
              ReadableWidth(
                child: _FilmCard(
                  film: tried[film.decor]?.film ?? film,
                  press: shownPress,
                  salesOrder: _order,
                  canCorrect: data.canCorrect && tried.isEmpty,
                  onTryGap: data.canCorrect && tried.isEmpty
                      ? (gap) => _tryGap(data, gap)
                      : null,
                ),
              ),
          ];
          final list = ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: items,
          );
          if (panel == null) return list;
          return LayoutBuilder(
            builder: (context, box) => box.maxWidth >= AppBreakpoints.medium
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: list),
                      SizedBox(
                        width: AppBreakpoints.listPaneWidth * 0.85,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: panel,
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      ExpansionTile(
                        key: const ValueKey('pressPanelTile'),
                        leading: const Icon(AppIcons.settings),
                        title: Text(l10n.pressPanelTitle),
                        children: [panel],
                      ),
                      ...items,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// Was and will be: the metres the order takes now, and with the panel's
/// figures — and what that saves.
class _Compare extends StatelessWidget {
  const _Compare({required this.before, required this.after});

  final double before;
  final double after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final diff = before - after;
    final colour = diff > 0.005
        ? status.success
        : diff < -0.005
        ? status.danger
        : theme.colorScheme.onSurfaceVariant;
    return Card(
      key: const ValueKey('pressCompare'),
      color: colour.withValues(alpha: AppTint.surface),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.lg,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.pressWas(_metres(context, before))),
            const Icon(AppIcons.forward),
            Text(
              l10n.pressWillBe(_metres(context, after)),
              key: const ValueKey('pressWillBe'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colour,
              ),
            ),
            Text(
              diff > 0.005
                  ? l10n.pressSaves(_metres(context, diff))
                  : diff < -0.005
                  ? l10n.pressCostsMore(_metres(context, -diff))
                  : l10n.pressSame,
              style: TextStyle(color: colour),
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
    this.onTryGap,
  });

  final FilmLayout film;
  final PressSettings press;
  final String salesOrder;
  final bool canCorrect;

  /// Lay the films out with this gap on the panel; null — not offered.
  final ValueChanged<double>? onTryGap;

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
              pressShortTitle(film, salesOrder),
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
            // Nobody has looked at the roll (owner, 27.11.2026): laid
            // unturned already; whoever holds it says once, for every order.
            if (film.unchecked) _GrainAsk(film: film, salesOrder: salesOrder),
            // «Чуть-чуть не влезло» (owner, 26.11.2026): a gap a little
            // narrower saves a load — tried on the panel, kept by hand.
            if (film.hint case final hint? when onTryGap != null)
              Container(
                key: ValueKey('pressHint:${film.decor}'),
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: warning.withValues(alpha: AppTint.surface),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.idea,
                      color: warning,
                      size: AppIconSize.small,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.pressHint(
                          hint.gapMm.round(),
                          press.gapMm.round(),
                          _metres(context, hint.savesM),
                          _metres(context, hint.filmM),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      key: ValueKey('pressHintTry:${film.decor}'),
                      onPressed: () => onTryGap!(hint.gapMm),
                      child: Text(l10n.pressHintTry),
                    ),
                  ],
                ),
              ),
            if (film.manual) ...[
              Text(
                l10n.pressManual,
                key: ValueKey('pressManual:${film.decor}'),
                style: theme.textTheme.bodySmall?.copyWith(color: warning),
              ),
              // Laid nearer than the gap on purpose: who said why.
              if (film.loads.any((l) => l.placed.any((p) => p.forced)))
                Text(
                  film.reason ?? '',
                  key: ValueKey('pressForced:${film.decor}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.statusColors.danger,
                  ),
                ),
            ] else if (film.corrected)
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
            _LoadsView(film: film, press: press),
          ],
        ),
      ),
    );
  }
}

/// «Посмотрите на рулон»: a film nobody has looked at — the answer goes on
/// its card, for every order after this one.
class _GrainAsk extends ConsumerStatefulWidget {
  const _GrainAsk({required this.film, required this.salesOrder});

  final FilmLayout film;
  final String salesOrder;

  @override
  ConsumerState<_GrainAsk> createState() => _GrainAskState();
}

class _GrainAskState extends ConsumerState<_GrainAsk> {
  bool _busy = false;

  Future<void> _say(FilmGrain grain) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(filmCatalogRepositoryProvider)
          .setGrainAtPress(widget.film.decor, grain);
      ref
        ..invalidate(orderPressLayoutProvider(widget.salesOrder))
        ..invalidate(filmCatalogProvider);
    } on Object catch (error) {
      messenger.showFailure(error, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warning = context.statusColors.warning;
    final decor = widget.film.decor;
    return Container(
      key: ValueKey('pressGrainAsk:$decor'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: AppTint.surface),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pressGrainAsk(decor),
            style: theme.textTheme.titleSmall,
          ),
          Text(l10n.pressGrainAskHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                key: ValueKey('pressGrainTextured:$decor'),
                onPressed: _busy ? null : () => _say(FilmGrain.textured),
                icon: const Icon(AppIcons.textured),
                label: Text(l10n.pressGrainTextured),
              ),
              OutlinedButton(
                key: ValueKey('pressGrainPlain:$decor'),
                onPressed: _busy ? null : () => _say(FilmGrain.plain),
                child: Text(l10n.pressGrainPlain),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «№20 · Елдос Жупанов · Белый Матовый» — the order's own number, not
/// «SAL-ORD-2026-00020», so it reads at a glance (owner, 13.11.2026).
String pressShortTitle(FilmLayout film, String salesOrder) {
  final number = RegExp(r'(\d+)$').firstMatch(salesOrder)?.group(1);
  final short = number == null ? salesOrder : '${int.parse(number)}';
  var rest = film.title.startsWith('№$salesOrder ')
      ? film.title.substring('№$salesOrder '.length)
      : film.title;
  if (rest.endsWith(' ${film.decor}')) {
    rest = rest.substring(0, rest.length - film.decor.length - 1);
  }
  return [
    '№$short',
    if (rest.isNotEmpty && rest != film.decor) rest,
    film.decor,
  ].join(' · ');
}

/// A position of the film: its size as the order has it, how many, and
/// whether any of it lies turned.
typedef PressPosition = ({
  int pos,
  double width,
  double height,
  int count,
  bool turned,
});

/// The film's positions, from what lies on its loads.
List<PressPosition> pressPositions(FilmLayout film) {
  final found = <int, PressPosition>{};
  for (final load in film.loads) {
    for (final p in load.placed) {
      final seen = found[p.pos];
      found[p.pos] = (
        pos: p.pos,
        width: p.rotated ? p.height : p.width,
        height: p.rotated ? p.width : p.height,
        count: (seen?.count ?? 0) + 1,
        turned: (seen?.turned ?? false) || p.rotated,
      );
    }
  }
  return found.values.toList()..sort((a, b) => a.pos.compareTo(b.pos));
}

/// How full a load is: its parts' area over the table its section gives.
({double share, double wasteM2}) pressFill(PressLoad load, double widthMm) {
  final table = load.lengthMm * widthMm;
  final parts = load.placed.fold<double>(0, (s, p) => s + p.width * p.height);
  if (table <= 0) return (share: 0, wasteM2: 0);
  final share = (parts / table).clamp(0.0, 1.0);
  return (share: share, wasteM2: (table - parts).clamp(0, table) / 1e6);
}

/// A film's loads drawn, each with how full it is; its positions listed
/// below in their colours. A position tapped — on the map or the list —
/// lights up on every load; the pointer over a part names it.
class _LoadsView extends StatefulWidget {
  const _LoadsView({required this.film, required this.press});

  final FilmLayout film;
  final PressSettings press;

  @override
  State<_LoadsView> createState() => _LoadsViewState();
}

class _LoadsViewState extends State<_LoadsView> {
  int? _pinned;
  int? _hover;

  /// The loads, the same placement once: its first index, the load, and
  /// the numbers of every load laid so.
  static List<(int, PressLoad, List<int>)> _grouped(List<PressLoad> loads) {
    final out = <(int, PressLoad, List<int>)>[];
    final seen = <String, int>{};
    for (final (i, load) in loads.indexed) {
      final key = [
        load.lengthMm,
        for (final p in load.placed)
          '${p.pos}:${p.x}:${p.y}:${p.width}:${p.height}',
      ].join('|');
      final at = seen[key];
      if (at == null) {
        seen[key] = out.length;
        out.add((i, load, [i + 1]));
      } else {
        out[at].$3.add(i + 1);
      }
    }
    return out;
  }

  void _pin(int? pos) =>
      setState(() => _pinned = pos == null || pos == _pinned ? null : pos);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = context.statusColors;
    final film = widget.film;
    final positions = pressPositions(film);
    final money = NumberFormat.currency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      symbol: '₸',
      decimalDigits: 0,
    );
    final lit = _hover ?? _pinned;
    final shown = positions.where((p) => p.pos == lit).firstOrNull;
    String size(PressPosition p) => '${p.width.round()}×${p.height.round()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The same placement laid more than once: one map, «×2» (owner,
        // 26.11.2026) — the vacuum worker lays it so twice.
        for (final (i, load, numbers) in _grouped(film.loads)) ...[
          const SizedBox(height: AppSpacing.md),
          Builder(
            builder: (context) {
              final fill = pressFill(load, widget.press.widthMm);
              final percent = (fill.share * 100).round();
              final colour = percent >= 70
                  ? status.success
                  : percent >= 40
                  ? status.warning
                  : status.danger;
              return Wrap(
                spacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    numbers.length > 1
                        ? l10n.pressLoadsSame(
                            numbers.join(', '),
                            _metres(context, load.filmM),
                          )
                        : l10n.pressLoad(i + 1, _metres(context, load.filmM)),
                    key: ValueKey('pressLoadHead:${film.decor}:$i'),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (numbers.length > 1)
                    Container(
                      key: ValueKey('pressLoadTimes:${film.decor}:$i'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        l10n.pressLoadTimes(numbers.length),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: AppSpacing.xxxl * 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: fill.share,
                        minHeight: AppSpacing.xs,
                        color: colour,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  Text(
                    l10n.pressFill(
                      percent,
                      _metres(context, fill.wasteM2),
                    ),
                    key: ValueKey('pressFill:${film.decor}:$i'),
                    style: theme.textTheme.bodySmall?.copyWith(color: colour),
                  ),
                  // What the load costs, and its empty place — the
                  // managers' figures; the floor is not sent the price.
                  if (film.priceM case final price?)
                    Text(
                      l10n.pressLoadCost(
                        money.format(load.filmM * price * numbers.length),
                        money.format(
                          load.filmM *
                              price *
                              numbers.length *
                              (1 - fill.share),
                        ),
                      ),
                      key: ValueKey('pressCost:${film.decor}:$i'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (context, box) {
              final map = PressMap(
                key: ValueKey('pressMap:${film.decor}:$i'),
                load: load,
                widthMm: widget.press.widthMm,
                // One scale for every load (owner, 26.11.2026).
                tableMm: widget.press.lengthMm,
                marginMm: widget.press.marginMm,
                // As on a drawing (owner, 26.11.2026, variant В).
                lengthLabel: l10n.pressTableDimension(
                  math.max(widget.press.lengthMm, load.lengthMm).round(),
                  _metres(context, load.filmM),
                ),
                widthLabel: l10n.pressWidthDimension(
                  widget.press.widthMm.round(),
                ),
                textured: film.textured,
                highlight: lit,
                onHover: (pos) => setState(() => _hover = pos),
                onTap: _pin,
              );
              final list = _OnLoad(
                key: ValueKey('pressOnLoad:${film.decor}:$i'),
                load: load,
                onTap: _pin,
              );
              // What goes on this load, beside its map — under it on a phone.
              return box.maxWidth >= AppBreakpoints.compact
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: map),
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(width: _OnLoad.width, child: list),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        map,
                        const SizedBox(height: AppSpacing.xs),
                        list,
                      ],
                    );
            },
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          shown == null
              ? l10n.pressPositionsHint
              : l10n.pressPositionInfo(
                  shown.pos,
                  size(shown),
                  shown.count,
                  [
                    for (final (i, load) in film.loads.indexed)
                      if (load.placed.any((p) => p.pos == shown.pos)) i + 1,
                  ].join(', '),
                ),
          key: ValueKey('pressPositionInfo:${film.decor}'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final p in positions)
              FilterChip(
                key: ValueKey('pressPosition:${film.decor}:${p.pos}'),
                avatar: Container(
                  width: AppIconSize.dense,
                  height: AppIconSize.dense,
                  decoration: BoxDecoration(
                    color: PressMap.colourOf(p.pos),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                label: Text(
                  [
                    '${p.pos}',
                    size(p),
                    l10n.pressPositionCount(p.count),
                    if (p.turned) '↻',
                  ].join(' · '),
                ),
                selected: _pinned == p.pos,
                onSelected: (_) => _pin(p.pos),
              ),
          ],
        ),
      ],
    );
  }
}

/// What goes on one load, position by position, as it lies — the vacuum
/// worker counts the pieces against it (owner, 26.11.2026).
class _OnLoad extends StatelessWidget {
  const _OnLoad({required this.load, required this.onTap, super.key});

  final PressLoad load;
  final ValueChanged<int?> onTap;

  static const double width = AppSpacing.xxxl * 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = <int, ({String size, int count})>{};
    for (final p in load.placed) {
      final seen = rows[p.pos];
      rows[p.pos] = (
        size: '${p.width.round()}×${p.height.round()}',
        count: (seen?.count ?? 0) + 1,
      );
    }
    final area = load.placed.fold<double>(
      0,
      (sum, p) => sum + p.width * p.height / 1e6,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pressOnLoad,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final MapEntry(key: pos, value: row) in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => onTap(pos),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: PressMap.colourOf(
                    pos,
                  ).withValues(alpha: AppTint.surface),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  l10n.pressOnLoadRow(pos, row.size, row.count),
                  key: ValueKey('pressOnLoadRow:$pos'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
        Text(
          l10n.pressOnLoadTotal(
            load.placed.length,
            area.toStringAsFixed(2).replaceAll('.', ','),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
    final navigator = Navigator.of(context);
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
        // Where it went, one tap away (owner, 26.11.2026: «куда он уходит?
        // надо как ссылку»).
        messenger.showSnackBar(
          SnackBar(
            key: const ValueKey('pressShortAdded'),
            // With an action a snack bar stays until closed (Flutter 3.38+):
            // it would follow the person to every screen (owner, 27.11.2026).
            persist: false,
            duration: AppDuration.notice,
            action: SnackBarAction(
              key: const ValueKey('pressShortOpen'),
              label: l10n.pressShortOpen,
              onPressed: () => unawaited(
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FilmOrdersPage(),
                  ),
                ),
              ),
            ),
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
