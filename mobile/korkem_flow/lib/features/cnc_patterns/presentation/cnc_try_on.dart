import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/loopback.dart';
import 'package:korkem_flow/core/api/server_image.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/features/cnc_patterns/data/cnc_patterns_repository.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_relief.dart';
import 'package:korkem_flow/features/cnc_patterns/presentation/cnc_relief_view.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_decors_screen.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_order_screen.dart'
    show mdfGlossLabel;
import 'package:korkem_flow/features/paint_catalogue/data/paint_catalogue_repository.dart';
import 'package:korkem_flow/features/paint_catalogue/domain/paint_catalogue.dart';
import 'package:korkem_flow/features/paint_catalogue/presentation/paint_catalogue_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What a facade is dressed in: a film's decor or a paint's colour.
@immutable
class CncFinish {
  const CncFinish({
    required this.title,
    required this.argb,
    this.image,
    this.paint = false,
  });

  final String title;

  /// The colour — a paint's own, a decor's average.
  final int argb;

  /// A decor's picture, a server path.
  final String? image;
  final bool paint;
}

/// One look put aside to compare.
typedef _Compared = ({CncFinish finish, MdfGloss gloss, bool across});

/// The most cards shown at once; a search narrows the rest.
const int _shown = 80;

/// The facade dressed in the shop's own catalogues — its PVC films and its
/// paints — so the customer sees it before it is made, up to four looks side
/// by side, and the picture saved to send (owner, 20.11.2026: «надевали свои
/// родные каталоги… чтобы клиент мог его представить»).
Future<void> showCncTryOn(
  BuildContext context, {
  required CncRelief relief,
  required double thickness,
  String? customer,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      CncTryOn(relief: relief, thickness: thickness, customer: customer),
);

class CncTryOn extends ConsumerStatefulWidget {
  const CncTryOn({
    required this.relief,
    required this.thickness,
    this.customer,
    super.key,
  });

  final CncRelief relief;
  final double thickness;

  /// Whose order: his colours first among the paints.
  final String? customer;

  @override
  ConsumerState<CncTryOn> createState() => _CncTryOnState();
}

class _CncTryOnState extends ConsumerState<CncTryOn> {
  bool _paints = false;
  String _search = '';
  String? _maker;
  CncFinish? _finish;
  MdfGloss _gloss = MdfGloss.matt;
  bool _across = false;
  final _textures = <String, ui.Image?>{};
  final _compared = <_Compared>[];
  final GlobalKey _shot = GlobalKey();

  @override
  void dispose() {
    for (final t in _textures.values) {
      t?.dispose();
    }
    super.dispose();
  }

  /// A decor's picture as the 3D view needs it; null offline or when the
  /// server has none — the decor's average colour stands in.
  Future<ui.Image?> _load(String path) {
    final endpoint = fastLoopback(ref.read(serverBaseUrlProvider));
    final url = ServerImage.urlOf(endpoint.url, path);
    final done = Completer<ui.Image?>();
    final stream = NetworkImage(
      url,
      headers: endpoint.headers,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!done.isCompleted) done.complete(info.image.clone());
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!done.isCompleted) done.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return done.future;
  }

  Future<void> _wear(CncFinish f) async {
    setState(() => _finish = f);
    final path = f.image;
    if (path == null || _textures.containsKey(path)) return;
    _textures[path] = null;
    final image = await _load(path);
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() => _textures[path] = image);
  }

  ui.Image? _textureOf(CncFinish? f) =>
      f?.image == null ? null : _textures[f!.image];

  static double _shine(MdfGloss g) => switch (g) {
    MdfGloss.matt => 0,
    MdfGloss.semi => 0.4,
    _ => 1,
  };

  Widget _facade(
    CncFinish? f,
    MdfGloss gloss,
    bool across, {
    bool interactive = true,
    Key? key,
  }) => CncFacade3d(
    key: key,
    relief: widget.relief,
    thickness: widget.thickness,
    colour: f == null ? AppColors.facadeBare : Color(f.argb),
    texture: _textureOf(f),
    across: across,
    gloss: _shine(gloss),
    interactive: interactive,
  );

  void _compare() {
    final l10n = AppLocalizations.of(context);
    final f = _finish;
    if (f == null) return;
    if (_compared.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ctoCompareFull)),
      );
      return;
    }
    setState(
      () => _compared.add((finish: f, gloss: _gloss, across: _across)),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saver = ref.read(cncFileSaverProvider);
    final boundary =
        _shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      final name = '${_finish?.title ?? l10n.ctoBare}.png';
      final dir = await saver.saveBytes(
        l10n.ctoFolder,
        name,
        data.buffer.asUint8List(),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.ctoSavedTo(dir)),
          // A bar with a button stays until pressed unless told
          // otherwise (Flutter 3.32+): it is told — it goes.
          persist: false,
          action: SnackBarAction(
            label: l10n.cncpOpenFolder,
            onPressed: () => unawaited(saver.open(dir)),
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Dialog(
      key: const ValueKey('cncTryOnDialog'),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSpacing.xxxl * 24,
          maxHeight: AppSpacing.xxxl * 15,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _stage(l10n, theme)),
              const VerticalDivider(width: AppSpacing.lg),
              SizedBox(
                width: AppSpacing.xxxl * 7,
                child: _catalogue(l10n, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage(AppLocalizations l10n, ThemeData theme) {
    final f = _finish;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final worn = [
      f?.title ?? l10n.ctoBare,
      mdfGlossLabel(_gloss, l10n),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.ctoTitle, style: theme.textTheme.titleLarge),
            ),
            IconButton(
              key: const ValueKey('ctoClose'),
              tooltip: l10n.actionClose,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(AppIcons.close),
            ),
          ],
        ),
        Expanded(
          // What is saved for the customer: the facade, what it is dressed
          // in, the looks beside it, and the honest note.
          child: RepaintBoundary(
            key: _shot,
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _facade(
                      f,
                      _gloss,
                      _across,
                      key: const ValueKey('ctoFacade'),
                    ),
                  ),
                  Text(
                    worn,
                    key: const ValueKey('ctoWorn'),
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_compared.isNotEmpty)
                    SizedBox(
                      height: AppSpacing.xxxl * 3,
                      child: Row(
                        children: [
                          for (final (i, c) in _compared.indexed)
                            Expanded(
                              child: InkWell(
                                key: ValueKey('ctoCompared:$i'),
                                onTap: () => setState(() {
                                  _finish = c.finish;
                                  _gloss = c.gloss;
                                  _across = c.across;
                                }),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: _facade(
                                        c.finish,
                                        c.gloss,
                                        c.across,
                                        interactive: false,
                                      ),
                                    ),
                                    Text(
                                      c.finish.title,
                                      style: muted,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Text(l10n.ctoNote, style: muted, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final g in const [
              MdfGloss.matt,
              MdfGloss.semi,
              MdfGloss.gloss,
            ])
              ChoiceChip(
                key: ValueKey('ctoGloss:${g.wire}'),
                label: Text(mdfGlossLabel(g, l10n)),
                selected: _gloss == g,
                onSelected: (_) => setState(() => _gloss = g),
              ),
            if (f?.image != null)
              FilterChip(
                key: const ValueKey('ctoAcross'),
                label: Text(l10n.ctoAcross),
                selected: _across,
                onSelected: (on) => setState(() => _across = on),
              ),
            OutlinedButton.icon(
              key: const ValueKey('ctoCompare'),
              onPressed: f == null ? null : _compare,
              icon: const Icon(AppIcons.add),
              label: Text(l10n.ctoCompare),
            ),
            if (_compared.isNotEmpty)
              TextButton(
                key: const ValueKey('ctoCompareClear'),
                onPressed: () => setState(_compared.clear),
                child: Text(l10n.ctoCompareClear),
              ),
            FilledButton.icon(
              key: const ValueKey('ctoSave'),
              onPressed: () => unawaited(_save()),
              icon: const Icon(AppIcons.moveOut),
              label: Text(l10n.ctoSave),
            ),
          ],
        ),
      ],
    );
  }

  Widget _catalogue(AppLocalizations l10n, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: AppSpacing.xs,
        children: [
          ChoiceChip(
            key: const ValueKey('ctoFilms'),
            label: Text(l10n.ctoFilms),
            selected: !_paints,
            onSelected: (_) => setState(() => _paints = false),
          ),
          ChoiceChip(
            key: const ValueKey('ctoPaints'),
            label: Text(l10n.ctoPaints),
            selected: _paints,
            onSelected: (_) => setState(() => _paints = true),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      TextField(
        key: const ValueKey('ctoSearch'),
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          prefixIcon: const Icon(AppIcons.search),
          hintText: l10n.ctoSearch,
          isDense: true,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Expanded(child: _paints ? _paintGrid(l10n) : _filmGrid(l10n)),
    ],
  );

  Widget _grid(List<Widget> cards, int more, AppLocalizations l10n) => ListView(
    children: [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 0.8,
        children: cards,
      ),
      if (more > 0)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(l10n.ctoMore(more)),
        ),
    ],
  );

  Widget _card({
    required Key key,
    required Widget swatch,
    required String title,
    required bool on,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: on
              ? Border.all(
                  color: theme.colorScheme.primary,
                  width: AppSpacing.xxs,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: swatch,
              ),
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filmGrid(AppLocalizations l10n) => ref
      .watch(filmDecorsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.ctoNoCatalogue)),
        data: (c) {
          final all = [
            for (final d in c.decors)
              if ((_maker == null || d.maker == _maker) && d.matches(_search))
                d,
          ];
          final bare = AppColors.facadeBare.toARGB32();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    key: const ValueKey('ctoMaker:all'),
                    label: Text(l10n.ctoAllMakers),
                    selected: _maker == null,
                    onSelected: (_) => setState(() => _maker = null),
                  ),
                  for (final m in c.makers)
                    ChoiceChip(
                      key: ValueKey('ctoMaker:${m.maker}'),
                      label: Text(m.maker),
                      selected: _maker == m.maker,
                      onSelected: (on) =>
                          setState(() => _maker = on ? m.maker : null),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: _grid(
                  [
                    for (final d in all.take(_shown))
                      _card(
                        key: ValueKey('ctoFilm:${d.decor}'),
                        swatch: DecorPicture(decor: d),
                        title: d.name,
                        on:
                            _finish?.image != null &&
                            _finish?.title == '${d.maker} · ${d.name}',
                        onTap: () => unawaited(
                          _wear(
                            CncFinish(
                              title: '${d.maker} · ${d.name}',
                              argb: d.argb ?? bare,
                              image: d.image,
                            ),
                          ),
                        ),
                      ),
                  ],
                  all.length - _shown,
                  l10n,
                ),
              ),
            ],
          );
        },
      );

  Widget _paintGrid(AppLocalizations l10n) => ref
      .watch(paintCatalogueForProvider(widget.customer))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.ctoNoCatalogue)),
        data: (c) {
          final bare = AppColors.facadeBare.toARGB32();
          final keep = [
            for (final x in c.colours)
              if (!x.hidden && x.matches(_search)) x,
          ];
          // His colours first, then ours, then the whole of RAL.
          final theirs = {for (final (i, k) in c.customer.indexed) k: i};
          int rank(PaintColour x) => theirs.containsKey(x.key)
              ? theirs[x.key]!
              : x.popular
              ? theirs.length
              : theirs.length + 1;
          final all = [...keep]
            ..sort((a, b) {
              final r = rank(a).compareTo(rank(b));
              return r != 0 ? r : b.areaM2.compareTo(a.areaM2);
            });
          return _grid(
            [
              for (final x in all.take(_shown))
                _card(
                  key: ValueKey('ctoPaint:${x.key}'),
                  swatch: PaintSwatch(colour: x),
                  title: x.title,
                  on: (_finish?.paint ?? false) && _finish?.title == x.title,
                  onTap: () => unawaited(
                    _wear(
                      CncFinish(
                        title: x.title,
                        argb: x.argb ?? bare,
                        paint: true,
                      ),
                    ),
                  ),
                ),
            ],
            all.length - _shown,
            l10n,
          );
        },
      );
}
