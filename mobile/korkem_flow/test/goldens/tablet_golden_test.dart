import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/app_screen.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';

import '../support/widget_harness.dart';

/// What a tablet gets, which until now was whatever a phone layout did when
/// nothing stopped it.
///
/// At 1024dp a deal card ran the full width: title at the left edge, status
/// chip at the right, roughly 600dp apart. Far enough that the eye cannot take
/// in both, so a list whose entire job is to be glanced at stopped being
/// glanceable — and no test noticed, because every golden in the suite is a
/// 390dp phone.
void main() {
  const tablet = Size(1024, 768);

  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(child));
    await tester.pumpAndSettle();
  }

  Widget list() => AppScreen(
    title: 'Продажи',
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final (name, status) in const [
          ('Астана Мебель Групп', 'Negotiation'),
          ('ЖК «Есиль Парк»', 'Proposal'),
          ('Қарағанды Интерьер', 'Won'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: EntityCard(
              title: name,
              subtitle: 'Согласовать смету по фасадам МДФ',
              statusLabel: status,
              statusIntent: StatusIntent.info,
              onTap: () {},
            ),
          ),
      ],
    ),
  );

  testWidgets('a list is capped and centred, not stretched', (tester) async {
    await pumpAt(tester, tablet, list());

    final width = tester.getSize(find.byType(EntityCard).first).width;

    // Card width comes out at the readable cap minus the list's own padding.
    expect(width, lessThanOrEqualTo(AppBreakpoints.readable));

    // And centred, so it does not hug the rail on one side.
    final card = tester.getRect(find.byType(EntityCard).first);
    final screen = tester.getRect(find.byType(AppScreen));
    expect(
      card.center.dx,
      closeTo(screen.center.dx, 1),
      reason: 'the column should sit in the middle of the extra space',
    );
  });

  testWidgets('a phone is untouched by the cap', (tester) async {
    await pumpAt(tester, const Size(390, 844), list());

    final width = tester.getSize(find.byType(EntityCard).first).width;

    // 390 minus the list's 16dp padding either side. The cap must never bind
    // on the device the app is actually used on.
    expect(width, closeTo(390 - AppSpacing.lg * 2, 0.5));
  });

  testWidgets('golden: tablet list', (tester) async {
    await pumpAt(tester, tablet, list());

    await expectLater(
      find.byType(ReadableWidth),
      matchesGoldenFile('tablet_list.png'),
    );
  });
}
