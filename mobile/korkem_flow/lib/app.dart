import 'package:flutter/material.dart';
import 'package:korkem_flow/core/theme/app_theme.dart';
import 'package:korkem_flow/features/deals/presentation/deals_screen.dart';

class KorkemFlowApp extends StatelessWidget {
  const KorkemFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KORKEM Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // ThemeMode.system is the default; a manual override belongs in
      // Settings once that screen exists.
      builder: (context, child) {
        // Clamp text scaling so layouts survive accessibility settings without
        // clipping, while still honouring the user's preference.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 1,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const DealsScreen(),
    );
  }
}
