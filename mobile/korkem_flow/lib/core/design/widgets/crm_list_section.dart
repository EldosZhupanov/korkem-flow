import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_search_field.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// A searchable, optionally filterable list — as a *body*, not a screen.
///
/// Deliberately owns no `Scaffold` and no `AppBar`: Deals, Leads and Customers
/// live as tabs under one shared app bar, and a nested Scaffold per tab would
/// stack a second bar under the first.
class CrmListSection extends StatelessWidget {
  const CrmListSection({
    required this.onSearch,
    required this.child,
    this.searchValue,
    this.onFilter,
    this.isFiltered = false,
    super.key,
  });

  final String? searchValue;
  final ValueChanged<String> onSearch;
  final VoidCallback? onFilter;
  final bool isFiltered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppSearchField(
                  initialValue: searchValue,
                  onChanged: onSearch,
                ),
              ),
              if (onFilter != null)
                IconButton(
                  icon: Badge(
                    // A dot rather than a count: the point is "a filter is on",
                    // and a user who wants the detail opens the sheet.
                    isLabelVisible: isFiltered,
                    child: const Icon(AppIcons.filter),
                  ),
                  tooltip: l10n.actionFilter,
                  onPressed: onFilter,
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
