import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/press_layout/data/press_layout_repository.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_layout_screen.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_map.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_settings_screen.dart';

import '../../support/widget_harness.dart';

const Map<String, Object> _press = {
  'press_length_mm': 2850,
  'press_width_mm': 1210,
  'press_margin_mm': 50,
  'press_gap_mm': 60,
  'press_sections': [
    {'film_m': 1.1, 'length_mm': 850},
    {'film_m': 2.1, 'length_mm': 1850},
    {'film_m': 3.1, 'length_mm': 2850},
  ],
  'can_edit': true,
};

Map<String, dynamic> _layout({bool corrected = false}) => {
  'sales_order': 'SO-1110',
  'press': _press,
  'can_correct': true,
  'films': [
    {
      'decor': 'ZB 852-2 Авори',
      'title': '№SO-1110 Дастан Жақсылықов ZB 852-2 Авори',
      'textured': false,
      'layout_m': 3.1,
      'film_m': corrected ? 2.1 : 3.1,
      'corrected': corrected,
      'reason': corrected ? 'плотнее вручную' : null,
      'loads': [
        {
          'film_m': 3.1,
          'length_mm': 2850,
          'placed': [
            {
              'pos': 1,
              'x': 50,
              'y': 50,
              'width': 598,
              'height': 298,
              'rotated': false,
            },
          ],
        },
      ],
      'too_big': <int>[],
    },
    {
      'decor': 'AS 1804-SFT Какао нубук',
      'title': '№SO-1110 Дастан Жақсылықов AS 1804-SFT Какао нубук',
      'textured': true,
      'layout_m': 2.1,
      'film_m': 2.1,
      'loads': [
        {
          'film_m': 2.1,
          'length_mm': 1850,
          'placed': [
            {'pos': 3, 'x': 50, 'y': 50, 'width': 598, 'height': 148},
            {'pos': 4, 'x': 708, 'y': 50, 'width': 598, 'height': 283},
          ],
        },
      ],
    },
  ],
};

class _FakeRepository implements PressLayoutRepository {
  final corrections = <(String, double?, String?)>[];
  final saved = <PressSettings>[];
  bool corrected = false;

  @override
  Future<OrderPressLayout> layout(String salesOrder) async =>
      OrderPressLayout.fromJson(_layout(corrected: corrected));

  @override
  Future<OrderPressLayout> setFilmMetres(
    String salesOrder,
    String decor, {
    double? metres,
    String? reason,
  }) async {
    corrections.add((decor, metres, reason));
    corrected = metres != null;
    return layout(salesOrder);
  }

  @override
  Future<PressSettings> settings() async => PressSettings.fromJson(_press);

  @override
  Future<PressSettings> saveSettings({
    required double lengthMm,
    required double widthMm,
    required double marginMm,
    required double gapMm,
    required List<({double filmM, double lengthMm})> sections,
  }) async {
    final result = PressSettings(
      lengthMm: lengthMm,
      widthMm: widthMm,
      marginMm: marginMm,
      gapMm: gapMm,
      sections: sections,
      canEdit: true,
    );
    saved.add(result);
    return result;
  }
}

void main() {
  Future<_FakeRepository> pump(WidgetTester tester, Widget screen) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pressLayoutRepositoryProvider.overrideWithValue(repo)],
        child: harness(screen),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test('reads the server layout', () {
    final layout = OrderPressLayout.fromJson(_layout());
    expect(layout.films, hasLength(2));
    expect(layout.films.last.textured, isTrue);
    expect(layout.films.first.loads.single.placed.single.pos, 1);
    expect(layout.press.sections.map((s) => s.filmM), [1.1, 2.1, 3.1]);
  });

  testWidgets('each film says its title, whether it turns, and its metres', (
    tester,
  ) async {
    await pump(tester, const PressLayoutScreen(salesOrder: 'SO-1110'));

    expect(
      find.text('№SO-1110 Дастан Жақсылықов ZB 852-2 Авори'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pressTextured:AS 1804-SFT Какао нубук')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pressTextured:ZB 852-2 Авори')),
      findsNothing,
    );
    expect(find.text('Film: 3.1 m'), findsOneWidget);
    expect(find.byType(PressMap), findsNWidgets(2));
  });

  testWidgets('a manager corrects the metres with a reason', (tester) async {
    final repo = await pump(
      tester,
      const PressLayoutScreen(salesOrder: 'SO-1110'),
    );
    await tester.tap(find.byKey(const ValueKey('pressCorrect:ZB 852-2 Авори')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pressCorrectMetres')),
      '2,1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pressCorrectReason')),
      'плотнее вручную',
    );
    await tester.tap(find.byKey(const ValueKey('pressCorrectSave')));
    await tester.pumpAndSettle();

    expect(repo.corrections.single.$2, 2.1);
    expect(repo.corrections.single.$3, 'плотнее вручную');
    expect(find.textContaining('плотнее вручную'), findsOneWidget);
  });

  testWidgets('the press settings are saved as typed', (tester) async {
    final repo = await pump(tester, const PressSettingsScreen());
    await tester.enterText(find.byKey(const ValueKey('pressGap')), '40');
    await tester.ensureVisible(find.byKey(const ValueKey('pressSave')));
    await tester.tap(find.byKey(const ValueKey('pressSave')));
    await tester.pumpAndSettle();

    expect(repo.saved.single.gapMm, 40);
    expect(repo.saved.single.sections, hasLength(3));
  });
}
