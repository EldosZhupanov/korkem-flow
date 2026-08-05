import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_logo.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/navigation/app_destinations.dart';
import 'package:korkem_flow/core/navigation/app_router.dart';
import 'package:korkem_flow/core/navigation/sidebar_entries.dart';
import 'package:korkem_flow/features/assistant/application/threads_controller.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The app's navigation, as a panel rather than a bar.
///
/// It replaced a bottom `NavigationBar`, which `docs/design_system.md` used to
/// mandate and now does not. A bar is right when its destinations *are* the
/// product; here the product is a conversation and the sections are tools it
/// reaches, so spending a permanent band of a phone screen on five places
/// people visit occasionally was the wrong trade.
///
/// One widget serves both layouts — inside a `Drawer` on a phone, in a `Row` on
/// a wide screen — because two implementations of a navigation panel is how the
/// two drift apart.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    required this.shell,
    required this.onNavigate,
    super.key,
  });

  /// Passed in rather than looked up.
  ///
  /// `StatefulNavigationShell.of(context)` finds nothing here: a `Drawer` is
  /// its own route, mounted outside the shell's subtree, so the inherited
  /// lookup that works from a screen fails from the panel. The shell has the
  /// object already, and handing it over is both simpler and the only thing
  /// that works in both layouts.
  final StatefulNavigationShell shell;

  /// Called after any entry is chosen, so a phone can close the drawer. The
  /// wide layout passes a no-op: there is nothing to close.
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final threads = ref.watch(threadsControllerProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                const AppLogo(size: AppLogoSize.compact),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KORKEM', style: theme.textTheme.titleMedium),
                      Text(
                        l10n.navAssistant,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                for (final entry in sidebarEntries)
                  _EntryTile(
                    entry: entry,
                    selected: _isSelected(entry),
                    onTap: () => _go(context, ref, entry),
                  ),

                if (threads.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: SectionLabel(l10n.chatRecent),
                  ),
                  for (final thread in threads)
                    _ThreadTile(
                      title: thread.title,
                      onTap: () {
                        ref
                            .read(threadsControllerProvider.notifier)
                            .open(thread.id);
                        _toBranch(context, Routes.chat);
                        onNavigate();
                      },
                    ),
                ],
              ],
            ),
          ),

          const Divider(height: AppStroke.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                for (final entry in sidebarFooterEntries)
                  _EntryTile(
                    entry: entry,
                    selected: _isSelected(entry),
                    onTap: () => _go(context, ref, entry),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelected(SidebarEntry entry) =>
      entry is SidebarBranch && branchIndexOf(entry.path) == shell.currentIndex;

  void _go(BuildContext context, WidgetRef ref, SidebarEntry entry) {
    switch (entry) {
      case SidebarAction():
        ref.read(threadsControllerProvider.notifier).startNew();
        _toBranch(context, Routes.chat);
      case SidebarBranch(:final path):
        _toBranch(context, path);
      case SidebarLink(:final path):
        // `go` rather than `push`: it sets the owning branch *and* that
        // branch's stack in one move, so Production needs no branch of its own
        // and no second navigation to get to.
        context.go(path);
    }
    onNavigate();
  }

  void _toBranch(BuildContext context, String path) {
    final index = branchIndexOf(path);
    // initialLocation when it is already selected: choosing the section you are
    // in pops it back to its root, which is what every native app has taught
    // people that gesture does.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final SidebarEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Material(
        color: selected
            ? accent.withValues(alpha: AppTint.surface)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Selection rides the variable `fill` axis of one icon family
                // rather than swapping glyphs, so it animates.
                AppIcon(
                  entry.icon,
                  size: AppIconSize.small,
                  filled: selected,
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    entry.labelOf(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? accent : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
