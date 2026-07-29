import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/search/recent_searches.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Debounced search input, with the last few queries one tap away.
///
/// Debouncing lives here rather than in every screen: without it each keystroke
/// becomes a backend round-trip, which is the fastest way to make a list feel
/// slow and to get rate-limited.
class AppSearchField extends ConsumerStatefulWidget {
  const AppSearchField({
    required this.onChanged,
    this.hintText,
    this.initialValue,
    this.recentScope,
    this.debounce = AppDebounce.search,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? initialValue;

  /// Which list's history to offer, from `SearchScope`. Null keeps no history —
  /// correct for a field whose queries are not worth returning to.
  final String? recentScope;

  final Duration debounce;

  @override
  ConsumerState<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends ConsumerState<AppSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final _focus = FocusNode();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Leaving the field is what marks a query as finished. Recording on every
    // keystroke would store every prefix — "K", "Ko", "Kor" — and bury the one
    // query worth keeping.
    if (!_focus.hasFocus) _remember(_controller.text);
    setState(() {});
  }

  void _remember(String query) {
    final scope = widget.recentScope;
    if (scope == null) return;
    ref.read(recentSearchesProvider(scope).notifier).record(query);
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {});
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  void _apply(String query) {
    _timer?.cancel();
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    widget.onChanged(query);
    _remember(query);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = widget.recentScope;

    // Only while the field is focused *and* empty. A recents strip under a
    // field with text in it competes with the results the text just produced.
    final recent =
        (scope == null || !_focus.hasFocus || _controller.text.isNotEmpty)
        ? const <String>[]
        : ref.watch(recentSearchesProvider(scope));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          onSubmitted: _remember,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.hintText ?? l10n.searchHint,
            prefixIcon: const Icon(AppIcons.search, size: AppIconSize.small),
            // Cross-faded rather than inserted. Swapping `null` for a button
            // changes the field's content width, so the caret and every
            // character in the field jumped sideways the instant the first key
            // was pressed.
            suffixIcon: AnimatedSwitcher(
              duration: motionOf(context, AppDuration.quick),
              switchInCurve: AppCurves.enter,
              switchOutCurve: AppCurves.exit,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              // The idle box occupies the same width as the button, so the
              // field's content width never changes.
              child: _controller.text.isEmpty
                  ? const SizedBox.square(dimension: AppTouchTarget.min)
                  : IconButton(
                      icon: const Icon(AppIcons.close, size: AppIconSize.small),
                      onPressed: _clear,
                      tooltip: l10n.actionClearSearch,
                    ),
            ),
          ),
        ),
        // Animates its own height so the list below slides rather than jumps.
        AnimatedSize(
          duration: motionOf(context, AppDuration.quick),
          curve: AppCurves.standard,
          alignment: Alignment.topCenter,
          child: recent.isEmpty
              ? const SizedBox(width: double.infinity)
              : _RecentStrip(
                  queries: recent,
                  onSelected: _apply,
                  onClear: () =>
                      ref.read(recentSearchesProvider(scope!).notifier).clear(),
                ),
        ),
      ],
    );
  }
}

class _RecentStrip extends StatelessWidget {
  const _RecentStrip({
    required this.queries,
    required this.onSelected,
    required this.onClear,
  });

  final List<String> queries;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final query in queries)
            ActionChip(
              avatar: const Icon(AppIcons.schedule, size: AppIconSize.inline),
              label: Text(query),
              // Tapping must beat retyping, so the whole chip runs the search
              // rather than only filling the field.
              onPressed: () => onSelected(query),
            ),
          TextButton(onPressed: onClear, child: Text(l10n.actionClearHistory)),
        ],
      ),
    );
  }
}
