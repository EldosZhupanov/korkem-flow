import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';

/// Renders a paginated list through its five states: loading, error, empty,
/// content, and appending.
///
/// Every list screen in the app needs the same scroll listener, the same
/// prefetch distance and the same rules about which state wins. Written per
/// screen, those drift — and the drift is invisible until a list quietly stops
/// loading page four.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    required this.state,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
    required this.emptyView,
    super.key,
  });

  final AsyncValue<PagedList<T>> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  /// Built lazily: an empty state usually needs to say *why* it is empty, which
  /// depends on whether a filter is active.
  final Widget Function(BuildContext context) emptyView;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Prefetches roughly one viewport ahead, so the next page is usually already
  /// there by the time the user reaches the bottom.
  void _onScroll() {
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(widget.onLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: switch (widget.state) {
        AsyncLoading() => const ListSkeleton(),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: widget.onRefresh,
        ),
        AsyncData(:final value) when value.isEmpty => LayoutBuilder(
          // Must still scroll, or pull-to-refresh cannot reach an empty list —
          // the one state where a user most wants to retry.
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: widget.emptyView(context),
            ),
          ),
        ),
        AsyncData(:final value) => ListView.separated(
          controller: _controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: value.items.length + (value.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (index >= value.items.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return widget.itemBuilder(context, value.items[index]);
          },
        ),
      },
    );
  }
}
