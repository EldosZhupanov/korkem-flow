import 'dart:async';

import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Debounced search input.
///
/// Debouncing lives here rather than in every screen: without it each keystroke
/// becomes a backend round-trip, which is the fastest way to make a list feel
/// slow and to get rate-limited.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    required this.onChanged,
    this.hintText,
    this.initialValue,
    this.debounce = const Duration(milliseconds: 300),
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? initialValue;
  final Duration debounce;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText ?? l10n.searchHint,
        prefixIcon: const Icon(AppIcons.search, size: AppIconSize.small),
        // Cross-faded rather than inserted. Swapping `null` for a button
        // changes the field's content width, so the caret and every character
        // in the field jumped sideways the instant the first key was pressed.
        suffixIcon: AnimatedSwitcher(
          duration: motionOf(context, AppDuration.quick),
          switchInCurve: AppCurves.enter,
          switchOutCurve: AppCurves.exit,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _controller.text.isEmpty
              // Occupies the same box when idle, so the width never changes.
              ? const SizedBox.square(dimension: AppTouchTarget.min)
              : IconButton(
                  icon: const Icon(AppIcons.close, size: AppIconSize.small),
                  onPressed: _clear,
                  tooltip: l10n.actionClearSearch,
                ),
        ),
      ),
    );
  }
}
