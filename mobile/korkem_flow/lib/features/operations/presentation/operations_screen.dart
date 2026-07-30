import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/features/production/presentation/production_screen.dart';
import 'package:korkem_flow/features/warehouse/presentation/warehouse_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Production and Warehouse under one destination.
///
/// They are read together: the question "can we make this by Friday" is a
/// question about a work order *and* about whether the panels are in stock.
class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScreen.tabbed(
      title: l10n.navOperations,
      tabs: [
        AppTab(label: l10n.navProduction, view: const ProductionScreen()),
        AppTab(label: l10n.navWarehouse, view: const WarehouseScreen()),
      ],
    );
  }
}
