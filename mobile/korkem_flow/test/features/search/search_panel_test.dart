import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/search/application/search_controller.dart';
import 'package:korkem_flow/features/search/data/smart_search_repository.dart';
import 'package:korkem_flow/features/search/domain/search_text.dart';
import 'package:korkem_flow/features/search/domain/smart_search.dart';
import 'package:korkem_flow/features/search/presentation/search_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/widget_harness.dart';

const _allowed = {
  'facades': true,
  'cnc': true,
  'film': true,
  'film_edit': true,
};

/// What the server answers for «ерлан» typed in the English layout.
final _erlan = SmartSearch.fromJson(const {
  'query': 'thkfy',
  'kind': 'text',
  'allowed': _allowed,
  'parts': {
    'customers': [
      {
        'customer': 'CUST-1',
        'name': 'Ерлан Абенов',
        'phone': '8 701 555 12 34',
        'orders': 2,
        'debt': 145000,
      },
    ],
    'facade_orders': [
      {
        'name': 'SAL-ORD-2026-00245',
        'number': 245,
        'customer': 'CUST-1',
        'customer_name': 'Ерлан Абенов',
        'status': 'in_shop',
        'decor': 'Белое дерево',
        'due': '2026-11-21',
        'total': 68000,
        'debt': 18000,
      },
    ],
    'payments': [
      {
        'date': '2026-11-14',
        'order': 'SAL-ORD-2026-00245',
        'customer_name': 'Ерлан Абенов',
        'amount': 50000,
        'method': 'Наличные',
      },
    ],
  },
});

class _FakeSearch implements SmartSearchRepository {
  _FakeSearch({this.film = true});

  final bool film;
  final asked = <String>[];

  @override
  Future<SmartSearch> find(String query) async {
    asked.add(query);
    if (query == 'thkfy') return _erlan;
    return SmartSearch.fromJson({
      'query': query,
      'allowed': {..._allowed, 'film': film, 'film_edit': film},
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SearchText', () {
    test('the wrong layout is read too', () {
      expect(SearchText.readings('thkfy'), contains('ерлан'));
      expect(SearchText.readings('ДЦ 611'), contains('lw 611'));
    });

    test('Kazakh letters and «ё» are their Russian neighbours', () {
      expect(SearchText.fold('Айгүл  Қасенова'), 'аигул касенова');
      expect(SearchText.matches('приход клёя', ['Приход клея']), isTrue);
    });

    test('every word must start a word of the text, a letter off at most', () {
      expect(SearchText.matches('прод клей', ['Продать клей']), isTrue);
      expect(SearchText.matches('продать клеи', ['Продать клей']), isTrue);
      expect(SearchText.matches('продать плёнку', ['Продать клей']), isFalse);
      expect(SearchText.matches('rfccf', ['Касса']), isTrue);
    });
  });

  group('SearchPanel', () {
    late SharedPreferences prefs;
    late _FakeSearch repo;
    late List<SearchChoice> chosen;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = _FakeSearch();
      chosen = [];
    });

    Future<ProviderContainer> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            smartSearchRepositoryProvider.overrideWithValue(repo),
          ],
          child: harness(SearchPanel(onChoose: chosen.add)),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(SearchPanel)),
      );
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('searchField')), text);
      await tester.pump(AppDebounce.search);
      await tester.pumpAndSettle();
    }

    testWidgets('one line finds the customer, his order and his payment', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'thkfy');

      expect(repo.asked, contains('thkfy'));
      expect(
        find.byKey(const ValueKey('searchRow:customer:CUST-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('searchRow:facade:SAL-ORD-2026-00245')),
        findsOneWidget,
      );
      expect(find.text('№ 245 · Ерлан Абенов'), findsOneWidget);
      expect(find.textContaining('Наличные'), findsOneWidget);
    });

    testWidgets('a tab narrows the results to its kind', (tester) async {
      await pump(tester);
      await type(tester, 'thkfy');

      await tester.tap(find.byKey(const ValueKey('searchTab:orders')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('searchRow:customer:CUST-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('searchRow:facade:SAL-ORD-2026-00245')),
        findsOneWidget,
      );
    });

    testWidgets('arrows choose a row, Enter opens it, and it is remembered', (
      tester,
    ) async {
      final container = await pump(tester);
      await type(tester, 'thkfy');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(chosen, hasLength(1));
      final recent = container.read(searchRecentsProvider).first;
      expect((recent.kind, recent.id), ('facadeOrder', 'SAL-ORD-2026-00245'));
      final stored = prefs.getStringList('search.global.recent')!;
      expect(jsonDecode(stored.first), containsPair('kind', 'facadeOrder'));
    });

    testWidgets('the customer in focus offers his orders and a new one', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'thkfy');

      expect(
        find.byKey(const ValueKey('searchExtra:customer:CUST-1:New order')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('searchExtra:customer:CUST-1:New order')),
      );
      await tester.pumpAndSettle();
      expect(chosen, hasLength(1));
    });

    testWidgets('an action is found by its words, as far as allowed', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'sell glue');
      expect(
        find.byKey(const ValueKey('searchRow:action:sellGlue')),
        findsOneWidget,
      );

      repo = _FakeSearch(film: false);
      await pump(tester);
      await type(tester, 'sell glue');
      expect(
        find.byKey(const ValueKey('searchRow:action:sellGlue')),
        findsNothing,
      );
    });

    testWidgets('a menu section is found by name, even in the wrong layout', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'rfccf');

      expect(
        find.byKey(const ValueKey('searchRow:section:/mdf/cash')),
        findsOneWidget,
      );
    });

    testWidgets('before typing: what was opened lately, and the actions', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'search.global.recent': [
          jsonEncode({
            'kind': 'facadeOrder',
            'id': 'SAL-ORD-2026-00245',
            'title': '№ 245 · Ерлан Абенов',
          }),
        ],
      });
      prefs = await SharedPreferences.getInstance();
      await pump(tester);

      expect(find.text('№ 245 · Ерлан Абенов'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('searchRow:action:newFacadeOrder')),
        findsOneWidget,
      );
      expect(repo.asked, isNot(contains('thkfy')));
    });
  });
}
