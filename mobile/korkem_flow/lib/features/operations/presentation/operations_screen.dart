import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/features/material_stock/presentation/material_stock_screen.dart';
import 'package:korkem_flow/features/production/presentation/production_screen.dart';
import 'package:korkem_flow/features/warehouse/presentation/warehouse_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Production and the warehouse under one destination.
///
/// They are read together: the question "can we make this by Friday" is a
/// question about a work order *and* about whether the panels are in stock.
/// Products and the facade materials (MDF, film) are two tabs of one
/// warehouse, both counted by ERPNext; receipts and lists stay on the full
/// materials screen, opened from the workstations.
class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScreen.tabbed(
      title: l10n.navOperations,
      fullWidth: true,
      tabs: [
        AppTab(label: l10n.navProduction, view: const ProductionScreen()),
        AppTab(label: l10n.navWarehouse, view: const WarehouseScreen()),
        AppTab(
          label: l10n.materialStockOpen,
          view: const MaterialStockOnHand(),
        ),
      ],
    );
  }
}
