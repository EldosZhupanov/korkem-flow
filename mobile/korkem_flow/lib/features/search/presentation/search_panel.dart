import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/server_image.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/app_feedback.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/navigation/sidebar_entries.dart';
import 'package:korkem_flow/features/cnc/domain/cnc.dart';
import 'package:korkem_flow/features/cnc/presentation/cnc_orders_screen.dart';
import 'package:korkem_flow/features/facade_prices/domain/facade_quote.dart';
import 'package:korkem_flow/features/film_catalog/data/film_decor_repository.dart';
import 'package:korkem_flow/features/film_catalog/domain/film.dart';
import 'package:korkem_flow/features/film_catalog/presentation/decor_match.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_catalog_screen.dart';
import 'package:korkem_flow/features/film_catalog/presentation/film_decors_screen.dart';
import 'package:korkem_flow/features/film_dept/data/film_dept_repository.dart';
import 'package:korkem_flow/features/film_dept/domain/film_dept.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_dialogs.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_dept_screen.dart';
import 'package:korkem_flow/features/film_dept/presentation/film_pick.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/glue_screen.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_orders_screen.dart';
import 'package:korkem_flow/features/search/application/search_controller.dart';
import 'package:korkem_flow/features/search/domain/search_text.dart';
import 'package:korkem_flow/features/search/domain/smart_search.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// What choosing a row does, run with a context that outlives the window.
typedef SearchChoice =
    Future<void> Function(BuildContext context, WidgetRef ref);

/// The window's share of the screen's height.
const double _paletteHeight = 0.72;

bool _paletteOpen = false;

/// The general search as a window over whatever is open (owner, 18.11.2026,
/// variant Б): Ctrl+K anywhere, or «Найти…» at the top of the menu.
///
/// The row chosen runs after the window closes, with [context] and [ref] —
/// the caller's, which are still there — so a dialog it opens (a sale, a
/// receipt) does not belong to a window that is already gone.
Future<void> showSearchPalette(BuildContext context, WidgetRef ref) async {
  if (_paletteOpen) return;
  _paletteOpen = true;
  SearchChoice? choice;
  try {
    choice = await showDialog<SearchChoice>(
      context: context,
      builder: (dialogContext) => Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxxl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.readable,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(dialogContext).height * _paletteHeight,
            child: SearchPanel(
              onChoose: (c) => Navigator.of(dialogContext).pop(c),
            ),
          ),
        ),
      ),
    );
  } finally {
    _paletteOpen = false;
  }
  if (choice != null && context.mounted) await choice(context, ref);
}

/// Ctrl+K (⌘K) opens the search from any screen, signed in.
///
/// A keyboard handler rather than a shortcut in the tree: it fires whatever
/// has the focus, or nothing at all, which is the state a desktop app is in
/// right after it starts.
class SearchHotkey extends ConsumerStatefulWidget {
  const SearchHotkey({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  /// The router's navigator — the window opens above whatever it shows.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<SearchHotkey> createState() => _SearchHotkeyState();
}

class _SearchHotkeyState extends ConsumerState<SearchHotkey> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyK ||
        !(keyboard.isControlPressed || keyboard.isMetaPressed)) {
      return false;
    }
    final signedIn = ref.read(sessionProvider).value?.isAuthenticated ?? false;
    final navigator = widget.navigatorKey.currentContext;
    if (!signedIn || navigator == null) return false;
    unawaited(showSearchPalette(navigator, ref));
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// «Найти… Ctrl+K» — the search's door at the top of the menu.
class SearchLauncher extends ConsumerWidget {
  const SearchLauncher({this.onOpened, super.key});

  /// Called before the window opens — a phone closes its drawer.
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        key: const ValueKey('searchLauncher'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () {
          // The root navigator's context outlives a phone's drawer, which
          // [onOpened] is about to close.
          final navigator = Navigator.of(context, rootNavigator: true).context;
          onOpened?.call();
          unawaited(showSearchPalette(navigator, ref));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(AppIcons.search, size: AppIconSize.small, color: muted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l10n.gsrFind,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
              Text(
                l10n.gsrHotkey,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tabs over the results.
enum _Tab { all, customers, orders, money, film, stock, go }

/// One row of the window.
class _Item {
  const _Item({
    required this.id,
    required this.icon,
    required this.title,
    required this.choose,
    this.subtitle,
    this.trailing,
    this.trailingColor,
    this.leading,
    this.recent,
    this.extras = const [],
  });

  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;
  final Widget? leading;
  final SearchChoice choose;

  /// Kept as «Недавние» when chosen.
  final SearchRecent? recent;

  /// What else the row can do, shown on the row in focus.
  final List<({IconData icon, String label, SearchChoice choose})> extras;
}

class _Group {
  const _Group(this.label, this.tabs, this.items);

  final String label;
  final Set<_Tab> tabs;
  final List<_Item> items;
}

/// The search itself: the line, the tabs, the results, the keyboard.
///
/// The same in the Ctrl+K window and on the search screen a phone opens.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({required this.onChoose, super.key});

  /// A row was chosen: the window closes and runs it; the screen runs it.
  final ValueChanged<SearchChoice> onChoose;

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _keys = <int, GlobalKey>{};
  Timer? _debounce;
  String _query = '';
  _Tab _tab = _Tab.all;
  int _selected = 0;

  /// The last answer, shown while the next one comes.
  SmartSearch? _last;
  List<_Item> _flat = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppDebounce.search, () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _selected = 0;
        _tab = _Tab.all;
      });
    });
    setState(() {});
  }

  void _move(int by) {
    if (_flat.isEmpty) return;
    setState(() => _selected = (_selected + by).clamp(0, _flat.length - 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[_selected]?.currentContext;
      if (target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: AppDuration.instant,
            alignmentPolicy: by > 0
                ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          ),
        );
      }
    });
  }

  void _choose(_Item item, [SearchChoice? choice]) {
    if (item.recent case final recent?) {
      ref.read(searchRecentsProvider.notifier).record(recent);
    }
    widget.onChoose(choice ?? item.choose);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit() {
    if (_flat.isEmpty) return;
    _choose(_flat[_selected.clamp(0, _flat.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final answer = _query.isEmpty
        ? null
        : ref.watch(smartSearchProvider(_query));
    if (answer?.value case final value?) _last = value;
    final result = _query.isEmpty ? null : (answer?.value ?? _last);
    final allowed =
        result?.allowed ??
        ref.watch(searchAllowedProvider).value ??
        const SearchAllowed();
    final groups = _groups(context, l10n, result, allowed);
    final tabs = {
      for (final g in groups)
        if (g.items.isNotEmpty) ...g.tabs,
    };
    final shown = [
      for (final g in groups)
        if (g.items.isNotEmpty && (_tab == _Tab.all || g.tabs.contains(_tab)))
          g,
    ];
    _flat = [for (final g in shown) ...g.items];
    if (_selected >= _flat.length) _selected = 0;

    final loading = answer?.isLoading ?? false;
    final failed = answer?.hasError ?? false;
    final typed = _controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Focus(
            onKeyEvent: _onKey,
            child: TextField(
              key: const ValueKey('searchField'),
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: l10n.gsrHint,
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: typed.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(AppIcons.close),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                          _focus.requestFocus();
                        },
                      ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: AppStroke.focus,
          child: loading ? const LinearProgressIndicator() : null,
        ),
        const Divider(height: AppStroke.hairline),
        if (_query.isNotEmpty && tabs.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                for (final t in _Tab.values)
                  if (t == _Tab.all || tabs.contains(t))
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        key: ValueKey('searchTab:${t.name}'),
                        label: Text(_tabLabel(t, l10n)),
                        selected: _tab == t,
                        onSelected: (_) => setState(() {
                          _tab = t;
                          _selected = 0;
                        }),
                      ),
                    ),
              ],
            ),
          ),
        if (result != null && result.kind != SearchKind.text)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              result.kind == SearchKind.phone
                  ? l10n.gsrByPhone
                  : l10n.gsrByNumber(
                      result.query.replaceAll(RegExp(r'\D'), ''),
                    ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: _flat.isEmpty
              ? _Empty(
                  text: failed
                      ? l10n.errorGeneric
                      : _query.isEmpty
                      ? l10n.gsrStart
                      : loading
                      ? ''
                      : l10n.gsrNothing(_query),
                )
              : _list(theme, shown),
        ),
        const Divider(height: AppStroke.hairline),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            l10n.gsrKeys,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(ThemeData theme, List<_Group> shown) {
    var index = 0;
    return ListView(
      key: const ValueKey('searchResults'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: [
        for (final g in shown) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: SectionLabel(g.label),
          ),
          for (final item in g.items) _row(theme, item, index++),
        ],
      ],
    );
  }

  Widget _row(ThemeData theme, _Item item, int index) {
    final selected = index == _selected;
    final key = _keys.putIfAbsent(index, GlobalKey.new);
    final accent = theme.colorScheme.primary;
    return MouseRegion(
      key: key,
      onEnter: (_) {
        if (_selected != index) setState(() => _selected = index);
      },
      child: Material(
        color: selected
            ? accent.withValues(alpha: AppTint.surface)
            : Colors.transparent,
        child: InkWell(
          key: ValueKey('searchRow:${item.id}'),
          onTap: () => _choose(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    item.leading ??
                        Icon(
                          item.icon,
                          size: AppIconSize.small,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.subtitle case final s? when s.isNotEmpty)
                            Text(
                              s,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (item.trailing case final t?) ...[
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        t,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              item.trailingColor ??
                              theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (selected && item.extras.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppIconSize.small + AppSpacing.md,
                      top: AppSpacing.xs,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final e in item.extras)
                          TextButton.icon(
                            key: ValueKey('searchExtra:${item.id}:${e.label}'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _choose(item, e.choose),
                            icon: Icon(e.icon, size: AppIconSize.inline),
                            label: Text(e.label),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tabLabel(_Tab t, AppLocalizations l10n) => switch (t) {
    _Tab.all => l10n.gsrTabAll,
    _Tab.customers => l10n.gsrTabCustomers,
    _Tab.orders => l10n.gsrTabOrders,
    _Tab.money => l10n.gsrTabMoney,
    _Tab.film => l10n.gsrTabFilm,
    _Tab.stock => l10n.gsrTabStock,
    _Tab.go => l10n.gsrTabGo,
  };

  List<_Group> _groups(
    BuildContext context,
    AppLocalizations l10n,
    SmartSearch? r,
    SearchAllowed allowed,
  ) {
    final rows = _Rows(context, l10n, allowed);
    final actions = searchActions(_query, allowed, labelOf: rows.actionLabel);
    if (_query.isEmpty) {
      final recents = ref.watch(searchRecentsProvider);
      return [
        _Group(
          l10n.gsrGroupRecent,
          const {_Tab.all},
          [
            for (final recent in recents) rows.recent(recent),
          ],
        ),
        _Group(
          l10n.gsrGroupActions,
          const {_Tab.go},
          [
            for (final a in actions) rows.action(a),
          ],
        ),
      ];
    }
    final sections = rows.sections(_query);
    if (r == null) {
      return [
        _Group(
          l10n.gsrGroupActions,
          const {_Tab.go},
          [
            for (final a in actions) rows.action(a),
          ],
        ),
        _Group(l10n.gsrGroupSections, const {_Tab.go}, sections),
      ];
    }
    return [
      _Group(
        l10n.gsrGroupActions,
        const {_Tab.go},
        [
          for (final a in actions) rows.action(a),
        ],
      ),
      _Group(
        l10n.gsrGroupCustomers,
        const {_Tab.customers, _Tab.money},
        [
          for (final c in r.customers) rows.customer(c),
        ],
      ),
      _Group(
        l10n.gsrGroupFacadeOrders,
        const {_Tab.orders},
        [
          for (final o in r.facadeOrders) rows.order(o),
        ],
      ),
      _Group(
        l10n.gsrGroupCncOrders,
        const {_Tab.orders},
        [
          for (final o in r.cncOrders) rows.order(o),
        ],
      ),
      _Group(
        l10n.gsrGroupPayments,
        const {_Tab.money},
        [
          for (final p in r.payments) rows.payment(p),
        ],
      ),
      _Group(
        l10n.gsrGroupFilms,
        const {_Tab.film},
        [
          for (final f in r.films) rows.film(f),
        ],
      ),
      _Group(
        l10n.gsrGroupDecors,
        const {_Tab.film},
        [
          for (final d in r.decors) rows.decor(d),
        ],
      ),
      _Group(
        l10n.gsrGroupOrders,
        const {_Tab.orders},
        [
          for (final o in r.orders)
            rows.plain(
              kind: 'order',
              id: o.name,
              icon: AppIcons.deal,
              title: '${o.name} · ${o.customer}',
              route: Routes.order(o.name),
            ),
        ],
      ),
      _Group(
        l10n.gsrGroupWorkOrders,
        const {_Tab.orders},
        [
          for (final w in r.workOrders)
            rows.plain(
              kind: 'workOrder',
              id: w.id,
              icon: AppIcons.workOrder,
              title: [w.id, ?w.itemName].join(' · '),
              route: Routes.workOrder(w.id),
            ),
        ],
      ),
      _Group(
        l10n.gsrGroupStock,
        const {_Tab.stock},
        [
          for (final s in r.stock)
            rows.plain(
              kind: 'stock',
              id: '${s.itemCode}@${s.warehouse}',
              icon: AppIcons.item,
              title: s.itemName ?? s.itemCode,
              subtitle:
                  '${s.warehouse} · ${_qty(s.actualQty)} ${s.stockUom ?? ''}'
                      .trim(),
              route: Routes.stockItem(s.itemCode),
            ),
        ],
      ),
      _Group(l10n.gsrGroupSections, const {_Tab.go}, sections),
    ];
  }
}

String _qty(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Builds the rows: what each kind of thing shows and what choosing it does.
class _Rows {
  _Rows(this.context, this.l10n, this.allowed)
    : money = mdfMoney(context),
      status = context.statusColors;

  final BuildContext context;
  final AppLocalizations l10n;
  final SearchAllowed allowed;
  final NumberFormat money;
  final StatusColors status;

  static final _day = DateFormat('dd.MM');

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? '' : _day.format(d);
  }

  // --- what choosing does -------------------------------------------------

  static SearchChoice _push(String route) =>
      (context, ref) async => unawaited(GoRouter.of(context).push(route));

  static SearchChoice _go(String route) => (context, ref) async {
    GoRouter.of(context).go(route);
  };

  static SearchChoice _page(Widget Function() page) =>
      (context, ref) async => unawaited(
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page())),
      );

  /// A sale or a receipt of the film department, from the shop's stock.
  static SearchChoice _film(
    Future<bool?> Function(BuildContext context, FilmCatalog stock) open,
  ) => (context, ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final FilmCatalog stock;
    try {
      stock = await ref.read(filmDeptRepositoryProvider).stock();
    } on Object catch (e) {
      messenger.showFailure(e, l10n);
      return;
    }
    if (!context.mounted) return;
    final done = await open(context, stock);
    if (done ?? false) {
      ref
        ..invalidate(filmStockProvider)
        ..invalidate(filmCustomersProvider);
    }
  };

  // --- rows ---------------------------------------------------------------

  String actionLabel(SearchAction a) => switch (a) {
    SearchAction.newFacadeOrder => l10n.gsrDoNewFacadeOrder,
    SearchAction.newCncOrder => l10n.gsrDoNewCncOrder,
    SearchAction.sellFilm => l10n.gsrDoSellFilm,
    SearchAction.sellGlue => l10n.gsrDoSellGlue,
    SearchAction.receiveFilm => l10n.gsrDoReceiveFilm,
    SearchAction.receiveGlue => l10n.gsrDoReceiveGlue,
  };

  _Item action(SearchAction a) => _Item(
    id: 'action:${a.name}',
    icon: switch (a) {
      SearchAction.newFacadeOrder || SearchAction.newCncOrder => AppIcons.add,
      SearchAction.sellFilm || SearchAction.sellGlue => AppIcons.moveOut,
      SearchAction.receiveFilm || SearchAction.receiveGlue => AppIcons.moveIn,
    },
    title: actionLabel(a),
    choose: switch (a) {
      SearchAction.newFacadeOrder => _push(Routes.mdfOrderNew),
      SearchAction.newCncOrder => _push(Routes.cncOrderNew),
      SearchAction.sellFilm => _film(showFilmSale),
      SearchAction.sellGlue => _film(
        (context, stock) => showFilmSale(context, stock, glue: true),
      ),
      SearchAction.receiveFilm => _film((context, stock) async {
        final l10n = AppLocalizations.of(context);
        final picked = await showFilmChoice(
          context,
          stock.films,
          title: l10n.filmReceivePick,
        );
        if (picked == null || !context.mounted) return false;
        return showFilmReceive(context, picked, stock);
      }),
      SearchAction.receiveGlue => openGlueReceipt,
    },
  );

  _Item customer(SearchCustomer c) {
    final film = c.film;
    final recent = SearchRecent(
      kind: 'customer',
      id: c.customer,
      title: c.name,
      subtitle: c.phone,
      data: {
        'phone': ?c.phone,
        'orders': c.orders,
        'film': film != null,
      },
    );
    return _Item(
      id: 'customer:${c.customer}',
      icon: AppIcons.customer,
      title: c.name,
      subtitle: [
        ?c.phone,
        ?c.organization,
        if (c.orders > 0) l10n.gsrOrders(c.orders),
        if (film != null) l10n.gsrFilmCustomer,
      ].join(' · '),
      trailing: c.debt > 0.5 ? l10n.gsrDebt(money.format(c.debt)) : null,
      trailingColor: status.danger,
      recent: recent,
      // The customer's card (owner, 18.11.2026): everything of his on one page.
      choose: _push(Routes.clientCard(c.customer)),
      extras: [
        if (allowed.facades) ...[
          (
            icon: AppIcons.board,
            label: l10n.gsrActOrders,
            choose: _push(Routes.mdfOrdersOf(c.name)),
          ),
          (
            icon: AppIcons.add,
            label: l10n.gsrActNewOrder,
            choose: (context, ref) async => unawaited(
              GoRouter.of(context).push(
                Routes.mdfOrderNew,
                extra: FacadeCustomer(
                  name: c.customer,
                  title: c.name,
                  phone: c.phone,
                ),
              ),
            ),
          ),
        ],
        if (film != null && allowed.film)
          (
            icon: AppIcons.moveOut,
            label: l10n.gsrActSell,
            choose: _film(
              (context, stock) =>
                  showFilmSale(context, stock, customer: c.customer),
            ),
          ),
        if (c.phone case final phone?)
          (
            icon: AppIcons.copy,
            label: l10n.gsrActCopyPhone,
            choose: (context, ref) async {
              final done = AppLocalizations.of(context).gsrPhoneCopied;
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: phone));
              messenger.showDone(done);
            },
          ),
      ],
    );
  }

  _Item order(SearchOrder o) {
    final label = o.cnc
        ? cncStatusLabel(CncStatus.parse(o.status), l10n)
        : mdfStatusChip(MdfStatus.parse(o.status), l10n).$1;
    final title = [
      if (o.number case final n?) '№ $n' else o.name,
      o.customerName,
    ].join(' · ');
    final subtitle = [
      label,
      ?o.decor,
      if (o.due != null) _date(o.due),
    ].where((s) => s.isNotEmpty).join(' · ');
    return _Item(
      id: '${o.cnc ? 'cnc' : 'facade'}:${o.name}',
      icon: o.cnc ? AppIcons.workOrder : AppIcons.board,
      title: title,
      subtitle: subtitle,
      trailing: o.debt > 0.5
          ? l10n.gsrDebt(money.format(o.debt))
          : money.format(o.total),
      trailingColor: o.debt > 0.5 || o.overdue ? status.danger : null,
      recent: SearchRecent(
        kind: o.cnc ? 'cncOrder' : 'facadeOrder',
        id: o.name,
        title: title,
        subtitle: subtitle,
      ),
      choose: _push(o.cnc ? Routes.cncOrder(o.name) : Routes.mdfOrder(o.name)),
    );
  }

  _Item payment(SearchPayment p) => _Item(
    id: 'payment:${p.order}:${p.date}:${p.amount}',
    icon: AppIcons.payroll,
    title: p.customerName,
    subtitle: [_date(p.date), ?p.method, p.order].join(' · '),
    trailing: l10n.gsrPaid(money.format(p.amount)),
    trailingColor: status.success,
    choose: _push(p.cnc ? Routes.cncOrder(p.order) : Routes.mdfOrder(p.order)),
  );

  _Item film(Film f) {
    final title = f.label ?? [f.maker, f.colour].join(' · ');
    final subtitle = [
      ?f.code,
      ?f.type,
      if (f.free > 0) '${filmMetres(f.free)} м',
    ].join(' · ');
    return _Item(
      id: 'film:${f.item}',
      icon: AppIcons.material,
      leading: FilmSample(argb: f.argb, image: f.image),
      title: title,
      subtitle: subtitle,
      recent: SearchRecent(
        kind: 'film',
        id: f.item,
        title: title,
        subtitle: subtitle,
      ),
      choose: _page(() => FilmPage(item: f.item)),
      extras: [
        (
          icon: AppIcons.colour,
          label: l10n.fdcAnalogues,
          choose: (context, ref) =>
              showAnalogues(context, ref, title: title, item: f.item),
        ),
        if (allowed.film)
          (
            icon: AppIcons.moveOut,
            label: l10n.gsrActSell,
            choose: _film(
              (context, stock) => showFilmSale(
                context,
                stock,
                film: stock.films.where((x) => x.item == f.item).firstOrNull,
              ),
            ),
          ),
      ],
    );
  }

  _Item decor(FilmDecor d) {
    final subtitle = [d.maker, ?d.collection, ?d.code].join(' · ');
    return _Item(
      id: 'decor:${d.decor}',
      icon: AppIcons.textured,
      leading: d.image == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: SizedBox.square(
                dimension: AppSpacing.xl,
                child: ServerImage(path: d.image!),
              ),
            ),
      title: d.name,
      subtitle: subtitle,
      recent: SearchRecent(
        kind: 'decor',
        id: d.decor,
        title: d.name,
        subtitle: subtitle,
        data: {'maker': d.maker},
      ),
      choose: _page(() => FilmDecorsScreen(maker: d.maker, search: d.name)),
    );
  }

  _Item plain({
    required String kind,
    required String id,
    required IconData icon,
    required String title,
    required String route,
    String? subtitle,
  }) => _Item(
    id: '$kind:$id',
    icon: icon,
    title: title,
    subtitle: subtitle,
    recent: SearchRecent(
      kind: kind,
      id: id,
      title: title,
      subtitle: subtitle,
      data: {'route': route},
    ),
    choose: _push(route),
  );

  /// The menu's own places — «касса», «долги» — and the glue's.
  List<_Item> sections(String query) {
    final entries = [...sidebarSectionEntries, ...sidebarFooterEntries];
    return [
      for (final e in entries)
        if (_target(e) case final target?)
          if (SearchText.matches(query, [
            e.labelOf(l10n),
            ..._keywords[target.$1] ?? const <String>[],
          ]))
            _Item(
              id: 'section:${target.$1}',
              icon: e.icon,
              title: e.labelOf(l10n),
              recent: SearchRecent(
                kind: 'section',
                id: target.$1,
                title: e.labelOf(l10n),
                data: {'go': target.$2},
              ),
              choose: target.$2 ? _go(target.$1) : _push(target.$1),
            ),
      if (SearchText.matches(query, [
        l10n.glueTitle,
        ..._keywords[Routes.glue]!,
      ]))
        _Item(
          id: 'section:${Routes.glue}',
          icon: AppIcons.material,
          title: l10n.glueTitle,
          recent: SearchRecent(
            kind: 'section',
            id: Routes.glue,
            title: l10n.glueTitle,
          ),
          choose: _push(Routes.glue),
        ),
      if (allowed.film &&
          SearchText.matches(query, [l10n.fdcTitle, ..._keywords['decors']!]))
        _Item(
          id: 'section:decors',
          icon: AppIcons.textured,
          title: l10n.fdcTitle,
          choose: _page(FilmDecorsScreen.new),
        ),
    ];
  }

  /// A menu row's path, and whether it is reached by `go` (inside the
  /// shell) rather than `push`; null for what is not a place.
  static (String, bool)? _target(SidebarEntry e) => switch (e) {
    SidebarBranch(:final path) || SidebarLink(:final path) => (path, true),
    SidebarPage(:final path) => (path, false),
    SidebarAction() => null,
  };

  /// Words that find a menu row besides its label, in every language.
  static const _keywords = <String, List<String>>{
    Routes.mdfCash: ['касса', 'деньги', 'оплаты', 'кассa', 'төлем', 'cash'],
    Routes.mdfDebts: ['долги', 'долг', 'должники', 'қарыз', 'debts'],
    Routes.facades: ['фасады', 'заказы', 'мдф', 'тапсырыс', 'orders'],
    Routes.filmDept: ['плёнка', 'пленка', 'пвх', 'үлдір', 'film'],
    Routes.cncOrders: ['чпу', 'фреза', 'станок', 'cnc'],
    Routes.mdfTv: ['экран', 'тв', 'телевизор', 'tv'],
    Routes.mdfPaint: ['краска', 'покраска', 'бояу', 'paint'],
    Routes.mdfReport: ['отчёт', 'отчет', 'итоги', 'есеп', 'report'],
    Routes.workshop: ['цех', 'производство', 'шеберхана', 'workshop'],
    Routes.team: ['команда', 'сотрудники', 'зарплата', 'қызметкерлер', 'team'],
    Routes.settings: ['настройки', 'баптаулар', 'settings'],
    Routes.glue: ['клей', 'желім', 'glue'],
    'decors': ['каталог', 'декор', 'greenwood', 'mc group', 'каталогтар'],
  };

  /// A recent row, opened again the way it was opened the first time.
  _Item recent(SearchRecent r) {
    final data = r.data ?? const {};
    final choose = switch (r.kind) {
      'customer' => _push(Routes.clientCard(r.id)),
      'facadeOrder' => _push(Routes.mdfOrder(r.id)),
      'cncOrder' => _push(Routes.cncOrder(r.id)),
      'film' => _page(() => FilmPage(item: r.id)),
      'decor' => _page(
        () =>
            FilmDecorsScreen(maker: data['maker'] as String?, search: r.title),
      ),
      'section' when data['go'] == true => _go(r.id),
      _ => _push(data['route'] as String? ?? r.id),
    };
    return _Item(
      id: 'recent:${r.kind}:${r.id}',
      icon: switch (r.kind) {
        'customer' => AppIcons.customer,
        'facadeOrder' => AppIcons.board,
        'cncOrder' || 'workOrder' => AppIcons.workOrder,
        'film' => AppIcons.material,
        'decor' => AppIcons.textured,
        'order' => AppIcons.deal,
        'stock' => AppIcons.item,
        _ => AppIcons.forward,
      },
      title: r.title,
      subtitle: r.subtitle,
      recent: r,
      choose: choose,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          text,
          key: const ValueKey('searchEmpty'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
