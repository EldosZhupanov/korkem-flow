import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';

/// Depth is the one part of the design system written as raw hex.
///
/// `const` cannot build a `BoxShadow` colour from `AppColors.forest` plus an
/// alpha, so the shadow tokens are literals — exactly the kind of hand-typed
/// value the token-discipline test exists to prevent everywhere else. These
/// assertions are what stands in for it.
void main() {
  const sets = {
    'resting': AppElevation.resting,
    'pressed': AppElevation.pressed,
    'overlay': AppElevation.overlay,
  };

  test('every shadow is the brand dark, never black', () {
    for (final MapEntry(key: name, value: shadows) in sets.entries) {
      for (final shadow in shadows) {
        // Black on warm cream goes muddy. A near-miss would be invisible in
        // review and obvious on a wall of cards.
        expect(
          shadow.color.withValues(alpha: 1),
          AppElevation.source.withValues(alpha: 1),
          reason: name,
        );
      }
    }
  });

  test('each level is two shadows: a contact edge and an ambient lift', () {
    for (final MapEntry(key: name, value: shadows) in sets.entries) {
      expect(shadows, hasLength(2), reason: name);

      final [contact, ambient] = shadows;
      // A single blurred drop reads as a sticker. The tight one anchors the
      // edge; the wide one lifts the shape. Collapsing to one loses the effect
      // entirely while still looking like "a shadow" in code review.
      expect(contact.blurRadius, lessThan(ambient.blurRadius), reason: name);
      expect(
        contact.offset.dy,
        lessThanOrEqualTo(ambient.offset.dy),
        reason: name,
      );
    }
  });

  test('pressing sinks a card rather than lifting it', () {
    final resting = AppElevation.resting.last;
    final pressed = AppElevation.pressed.last;

    // Pressing pushes an object toward the page. A card that grows a deeper
    // shadow under a finger is moving the wrong way — which looks fine in a
    // paused frame and wrong in the hand.
    expect(pressed.blurRadius, lessThan(resting.blurRadius));
    expect(pressed.offset.dy, lessThan(resting.offset.dy));
  });

  testWidgets('cards lift on light and stay flat on dark', (tester) async {
    Future<List<BoxShadow>?> shadowsUnder(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          // Keyed on the theme so the two pumps are not `identical` const
          // instances, which Flutter would skip rebuilding altogether.
          home: Scaffold(
            key: ValueKey(theme.brightness),
            body: const AppCard(child: Text('x')),
          ),
        ),
      );
      // Settled, not pumped once. MaterialApp wraps its theme in an
      // AnimatedTheme that interpolates over ~200ms, so one frame after
      // switching themes `Theme.of` still reports the *previous* brightness —
      // the light card survives into the dark assertion and the test passes on
      // a lie. Cost me a while; leaving the reason here.
      await tester.pumpAndSettle();
      final box = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      if (box.isEmpty) return null;
      return (box.first.decoration! as BoxDecoration).boxShadow;
    }

    expect(await shadowsUnder(AppTheme.light()), AppElevation.resting);
    // None on dark: a shadow is invisible against a forest field and costs a
    // raster pass to prove it. The card outline does the separating there.
    expect(await shadowsUnder(AppTheme.dark()), isNull);
  });
}
