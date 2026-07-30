import 'package:flutter/material.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/motion/app_pressable.dart';
import 'package:korkem_flow/core/design/motion/swipe_action.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/kpi_tile.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_illustration.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';

/// Every component in the design system, on one screen.
///
/// A design system nobody can look at drifts, because the only way to compare
/// two components is to open two features and remember. This puts them side by
/// side, in both themes, at whatever text scale the device is set to.
///
/// It also earns its keep as a test fixture: one golden over this screen
/// covers every component's appearance at once, so a change to a shared token
/// fails here — with everything visible in the diff — rather than in whichever
/// feature screen happened to be goldened.
///
/// Debug builds only. It is registered behind `kDebugMode` in the router, so
/// the tree-shaker drops it from a release binary.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScreen.tabbed(
      title: 'Design system',
      tabs: [
        AppTab(label: 'Foundations', view: _Foundations()),
        AppTab(label: 'Components', view: _Components()),
        AppTab(label: 'States', view: _States()),
      ],
    );
  }
}

class _Foundations extends StatelessWidget {
  const _Foundations();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Page(
      children: [
        const SectionLabel('Type scale'),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (name, style) in <(String, TextStyle?)>[
                ('displaySmall — a KPI number', theme.textTheme.displaySmall),
                ('headlineMedium — a title', theme.textTheme.headlineMedium),
                ('titleLarge — an empty state', theme.textTheme.titleLarge),
                ('titleMedium — a list row', theme.textTheme.titleMedium),
                ('bodyMedium — body copy', theme.textTheme.bodyMedium),
                ('labelSmall — chips, dates', theme.textTheme.labelSmall),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(name, style: style),
                ),
            ],
          ),
        ),

        const SectionLabel('Status intents'),
        _Panel(
          // Every one carries an icon and a word. Colour is never the only
          // signal — roughly 8% of male users cannot rely on it.
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final intent in StatusIntent.values)
                StatusChip(label: intent.name, intent: intent),
            ],
          ),
        ),

        const SectionLabel('Surface tints'),
        _Panel(
          child: Row(
            children: [
              for (final (label, alpha) in const <(String, double)>[
                ('surface', AppTint.surface),
                ('glow', AppTint.glow),
                ('faint', AppTint.surfaceFaint),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Column(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: alpha,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const SizedBox(
                            height: AppPlaceholder.metricHeight,
                            width: double.infinity,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(label, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SectionLabel('Spacing'),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (name, value) in const <(String, double)>[
                ('xs', AppSpacing.xs),
                ('sm', AppSpacing.sm),
                ('md', AppSpacing.md),
                ('lg', AppSpacing.lg),
                ('xl', AppSpacing.xl),
                ('xxl', AppSpacing.xxl),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: AppIllustration.plateDense,
                        child: Text(name, style: theme.textTheme.labelSmall),
                      ),
                      ColoredBox(
                        color: theme.colorScheme.primary,
                        child: SizedBox(height: AppSpacing.sm, width: value),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SectionLabel('Corner radius'),
        _Panel(
          child: Row(
            children: [
              for (final (name, value) in const <(String, double)>[
                ('sm', AppRadius.sm),
                ('md', AppRadius.md),
                ('lg', AppRadius.lg),
                ('xl', AppRadius.xl),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(value),
                        ),
                        child: const SizedBox.square(
                          dimension: AppIllustration.plateDense,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(name, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Components extends StatelessWidget {
  const _Components();

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        const SectionLabel('Buttons'),
        _Panel(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Primary')),
              FilledButton.tonal(
                onPressed: () {},
                child: const Text('Secondary'),
              ),
              OutlinedButton(onPressed: () {}, child: const Text('Tertiary')),
              TextButton(onPressed: () {}, child: const Text('Text')),
              const FilledButton(onPressed: null, child: Text('Disabled')),
            ],
          ),
        ),

        const SectionLabel('Entity card'),
        EntityCard(
          title: 'Фасад МДФ 716×396, белый глянец',
          subtitle: 'Кухня Ивановых — 8 шт.',
          statusLabel: 'In process',
          statusIntent: StatusIntent.info,
          statusPlacement: StatusPlacement.metadata,
          onTap: () {},
          metadata: const [
            EntityMeta(icon: AppIcons.schedule, label: '2 авг.'),
            EntityMeta(icon: AppIcons.workOrder, label: 'MFG-WO-2026-00019'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        const SectionLabel('Metric tile'),
        Row(
          children: [
            const Expanded(
              child: KpiTile(
                label: 'Открытые сделки',
                value: '266',
                icon: AppIcons.deal,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: KpiTile(
                label: 'Просрочено',
                value: '3',
                icon: AppIcons.schedule,
                intent: StatusIntent.danger,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Row(
          children: [
            Expanded(
              child: KpiTile(label: 'Loading', value: '—', isLoading: true),
            ),
          ],
        ),

        const SectionLabel('Press feedback'),
        _Panel(
          child: Row(
            children: [
              AppPressable(
                onTap: () {},
                child: const _Swatch(label: 'Press me'),
              ),
            ],
          ),
        ),

        const SectionLabel('Swipe action'),
        SizedBox(
          height: AppPlaceholder.rowHeight,
          child: SwipeActionBackground(
            icon: AppIcons.check,
            color: context.statusColors.success,
            // Shown mid-gesture, because at rest it is invisible by design.
            progress: 0.6,
          ),
        ),
      ],
    );
  }
}

class _States extends StatelessWidget {
  const _States();

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        const SectionLabel('Loading'),
        const ListSkeleton(rows: 2),

        const SectionLabel('Illustration'),
        _Panel(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const StateIllustration(icon: AppIcons.deal),
              StateIllustration(
                icon: AppIcons.success,
                color: context.statusColors.success,
                dense: true,
              ),
            ],
          ),
        ),

        const SectionLabel('Empty — filtered to nothing'),
        _Panel(
          child: EmptyView(
            icon: AppIcons.deal,
            title: 'Здесь пока пусто',
            message: 'Ничего не найдено по запросу «Kor»',
            actionLabel: 'Сбросить фильтр',
            onAction: () {},
            secondaryActionLabel: 'Обновить',
            onSecondaryAction: () {},
          ),
        ),

        const SectionLabel('Success'),
        const _Panel(
          child: SuccessView(
            title: 'Всё просмотрено',
            message: 'Назначения и оповещения появятся здесь.',
            dense: true,
          ),
        ),

        const SectionLabel('Error'),
        const _Panel(
          child: ErrorView(
            error: NetworkFailure('No connection to the server.'),
          ),
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: children,
  );
}

/// A neutral backdrop, so a component is judged on itself rather than on the
/// page behind it.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: AppCard(child: child),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(label, style: theme.textTheme.labelLarge),
      ),
    );
  }
}
