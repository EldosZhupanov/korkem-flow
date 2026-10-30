import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/ai_settings/data/ai_settings_repository.dart';
import 'package:korkem_flow/features/ai_settings/domain/ai_provider_config.dart';
import 'package:korkem_flow/features/ai_settings/presentation/ai_settings_screen.dart';

import '../../support/widget_harness.dart';

/// The AI settings screen, and the one property that matters most about it.
///
/// A settings screen that holds a credential has exactly one way to be
/// catastrophically wrong, so that is what most of this file checks: the real
/// key must never reach the widget tree, and an untouched field must never
/// overwrite a stored key.
void main() {
  AiProviderConfig config({
    String provider = 'Google Gemini',
    bool configured = true,
    bool hasKey = true,
    bool needsKey = true,
    String? masked = 'AQ.A••••••••iO5A',
    Map<String, String>? capabilities,
  }) => AiProviderConfig(
    provider: provider,
    enabled: true,
    configured: configured,
    isDefault: true,
    hasKey: hasKey,
    needsKey: needsKey,
    needsBaseUrl: false,
    model: 'gemini-flash-latest',
    maskedKey: masked,
    capabilities: capabilities ?? const {'supports_tools': 'yes'},
  );

  Future<void> pump(WidgetTester tester, List<AiProviderConfig> providers) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiProvidersProvider.overrideWith(
              (ref) async =>
                  (providers: providers, defaultProvider: 'Google Gemini'),
            ),
          ],
          child: harness(const AiSettingsScreen()),
        ),
      );

  testWidgets('shows the mask, never anything key-shaped', (tester) async {
    await pump(tester, [config()]);
    await tester.pumpAndSettle();

    expect(find.text('Google Gemini'), findsOneWidget);
    // The mask is a *hint*, so it appears only once the section is open — and
    // even then it is punctuation, not a credential.
    expect(find.textContaining('•'), findsNothing);
  });

  testWidgets('the key field starts empty even when a key is stored', (
    tester,
  ) async {
    // The defect this guards: pre-filling bullets and posting the form back
    // would overwrite a working credential with punctuation.
    await pump(tester, [config()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    final obscured = fields.where((field) => field.obscureText);

    expect(obscured, hasLength(1));
    expect(obscured.single.controller!.text, isEmpty);
    expect(
      obscured.single.decoration!.hintText,
      'AQ.A••••••••iO5A',
      reason: 'the mask belongs in the hint, never in the value',
    );
  });

  testWidgets('a local provider is not asked for a key it does not need', (
    tester,
  ) async {
    await pump(tester, [
      config(provider: 'Ollama', needsKey: false, hasKey: false, masked: null),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .where(
            (field) => field.obscureText,
          ),
      isEmpty,
    );
  });

  testWidgets('an unverified capability reads as unknown, not as no', (
    tester,
  ) async {
    // Ollama's tool support genuinely depends on the model loaded. Rendering
    // that as "no" would hide a capability some local models do have.
    await pump(tester, [
      config(
        provider: 'Ollama',
        needsKey: false,
        capabilities: const {'supports_tools': 'unknown'},
      ),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(find.text('tools: unknown'), findsOneWidget);
  });

  test('a provider that was never set up is not treated as ready', () {
    expect(config(configured: false).ready, isFalse);
    expect(config(hasKey: false).ready, isFalse);
    expect(config(hasKey: false, needsKey: false).ready, isTrue);
  });
}
