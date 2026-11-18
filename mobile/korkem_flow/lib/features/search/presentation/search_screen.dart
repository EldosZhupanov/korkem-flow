import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/features/search/presentation/search_panel.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// The general search on a screen of its own — what the magnifier buttons
/// of the sections open, and what a phone gets. The same panel as the
/// Ctrl+K window (owner, 18.11.2026, variant Б).
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScreen(
    title: AppLocalizations.of(context).searchTitle,
    body: SearchPanel(
      onChoose: (choice) => unawaited(choice(context, ref)),
    ),
  );
}
