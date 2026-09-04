import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/materials/data/materials_repository.dart';
import 'package:korkem_flow/features/materials/domain/material_item.dart';
import 'package:korkem_flow/features/materials/presentation/materials_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockMaterialsRepository extends Mock implements MaterialsRepository {}

void main() {
  late _MockMaterialsRepository repository;

  setUp(() {
    repository = _MockMaterialsRepository();
  });

  Widget buildHarness({
    required List<MaterialItem> materials,
    Locale locale = const Locale('ru'),
  }) {
    when(
      () => repository.fetchMaterials(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        query: any(named: 'query'),
        thickness: any(named: 'thickness'),
        colorFamily: any(named: 'colorFamily'),
        kind: any(named: 'kind'),
      ),
    ).thenAnswer(
      (_) async => MaterialsPage(
        materials: materials,
        total: materials.length,
      ),
    );

    return ProviderScope(
      overrides: [
        materialsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MaterialsScreen(),
      ),
    );
  }

  group('Экран «Материалы» (MaterialsScreen)', () {
    testWidgets('1. код декора видно всегда и на первом месте в заголовке', (
      tester,
    ) async {
      const boardWithDecor = MaterialItem(
        id: 'MAT-0001',
        kind: MaterialKind.board,
        manufacturer: 'Egger',
        decorCode: 'W1000 ST9',
        name: 'Белый премиум',
        thicknessMm: 16,
        sheetWidthMm: 2800,
        sheetHeightMm: 2070,
        colorFamily: 'white',
      );
      const boardWithoutDecor = MaterialItem(
        id: 'MAT-0002',
        kind: MaterialKind.board,
        name: 'ЛДСП без артикула',
      );

      await tester.pumpWidget(
        buildHarness(materials: [boardWithDecor, boardWithoutDecor]),
      );
      await tester.pumpAndSettle();

      // Мебельщик сразу видит код декора: W1000 ST9 в заголовке карточки
      expect(find.text('W1000 ST9 · Белый премиум'), findsOneWidget);
      expect(find.text('Egger'), findsOneWidget);

      // Без кода декора отображается только название без разделителя
      expect(find.text('ЛДСП без артикула'), findsOneWidget);
    });

    testWidgets('2. кромка отличается от плиты визуально и семантически', (
      tester,
    ) async {
      const board = MaterialItem(
        id: 'MAT-0010',
        kind: MaterialKind.board,
        manufacturer: 'Egger',
        decorCode: 'H1277 ST9',
        name: 'Акация Лэйклэнд',
        thicknessMm: 16,
        sheetWidthMm: 2800,
        sheetHeightMm: 2070,
        colorFamily: 'wood',
      );
      const edge = MaterialItem(
        id: 'MAT-0020',
        kind: MaterialKind.edge,
        manufacturer: 'Rehau',
        decorCode: 'H1277 ST9',
        name: 'Кромка Акация Лэйклэнд',
        thicknessMm: 2,
        fitsThicknessMm: 16,
        colorFamily: 'wood',
      );

      await tester.pumpWidget(buildHarness(materials: [board, edge]));
      await tester.pumpAndSettle();

      // Разные чипы статуса: Плита и Кромка в карточках
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Плита'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Кромка'),
        ),
        findsOneWidget,
      );

      // Разные иконки в карточках: board (layers) и edge (border_style)
      expect(
        find.descendant(
          of: find.byType(MaterialCard),
          matching: find.byIcon(AppIcons.board),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MaterialCard),
          matching: find.byIcon(AppIcons.edge),
        ),
        findsOneWidget,
      );

      // У плиты отображается формат листа 2800×2070 мм
      expect(find.text('2800×2070 мм'), findsOneWidget);

      // У кромки толщина 2 мм и совместимость «под 16 мм», но формата листа нет
      expect(find.text('2 мм'), findsOneWidget);
      expect(find.text('под 16 мм'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaterialCard),
          matching: find.text('16 мм'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      '3. никогда не выдумывает данные — при отсутствии полей '
      'нет значений по умолчанию',
      (tester) async {
        // Запись только с обязательными полями (id, name, kind)
        const minimalItem = MaterialItem(
          id: 'MAT-0099',
          kind: MaterialKind.board,
          name: 'Неразмеченная плита',
        );

        await tester.pumpWidget(buildHarness(materials: [minimalItem]));
        await tester.pumpAndSettle();

        expect(find.text('Неразмеченная плита'), findsOneWidget);

        // Никаких выдуманных 16 мм, 18 мм, 2800×2070 в карточке
        expect(
          find.descendant(
            of: find.byType(MaterialCard),
            matching: find.text('16 мм'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(MaterialCard),
            matching: find.text('18 мм'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(MaterialCard),
            matching: find.text('2800×2070 мм'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(MaterialCard),
            matching: find.text('Egger'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      '4. фильтры толщины и семейства цвета отправляют '
      'точные параметры на сервер',
      (tester) async {
        await tester.pumpWidget(buildHarness(materials: []));
        await tester.pumpAndSettle();

        // 1. Фильтр толщины 16 мм
        await tester.tap(find.byKey(const ValueKey('filter:thickness:16')));
        await tester.pumpAndSettle();

        verify(
          () => repository.fetchMaterials(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            thickness: 16,
            query: any(named: 'query'),
            colorFamily: any(named: 'colorFamily'),
            kind: any(named: 'kind'),
          ),
        ).called(1);

        // 2. Фильтр цвета «Дерево» (wood)
        await tester.tap(find.byKey(const ValueKey('filter:color:wood')));
        await tester.pumpAndSettle();

        verify(
          () => repository.fetchMaterials(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            thickness: 16,
            colorFamily: 'wood',
            query: any(named: 'query'),
            kind: any(named: 'kind'),
          ),
        ).called(1);

        // 3. Фильтр типа «Плиты» (board)
        await tester.tap(find.byKey(const ValueKey('filter:board')));
        await tester.pumpAndSettle();

        verify(
          () => repository.fetchMaterials(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            thickness: 16,
            colorFamily: 'wood',
            kind: 'board',
            query: any(named: 'query'),
          ),
        ).called(1);
      },
    );

    testWidgets('5. поиск с debounce отправляет query на сервер', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(materials: []));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'W1000');
      // До истечения debounce запрос ещё не уходит
      await tester.pump(const Duration(milliseconds: 100));

      // Ждём завершения debounce поиска
      await tester.pump(AppDebounce.search + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      verify(
        () => repository.fetchMaterials(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          query: 'W1000',
          thickness: any(named: 'thickness'),
          colorFamily: any(named: 'colorFamily'),
          kind: any(named: 'kind'),
        ),
      ).called(1);
    });

    testWidgets(
      '6. пустой каталог и пустой результат фильтрации с кнопкой сброса',
      (tester) async {
        await tester.pumpWidget(buildHarness(materials: []));
        await tester.pumpAndSettle();

        // Каталог изначально пуст
        expect(find.text('Каталог материалов пуст'), findsOneWidget);

        // Включаем фильтр
        await tester.tap(find.byKey(const ValueKey('filter:thickness:18')));
        await tester.pumpAndSettle();

        // Теперь отображается пустое состояние фильтрации
        expect(find.text('Ничего не найдено'), findsOneWidget);
        expect(find.text('Сбросить фильтр'), findsOneWidget);

        // Нажатие «Сбросить фильтр» очищает выбор
        await tester.tap(find.text('Сбросить фильтр'));
        await tester.pumpAndSettle();

        expect(find.text('Каталог материалов пуст'), findsOneWidget);
      },
    );

    testWidgets('7. экран полностью локализован на трёх языках (ru, kk, en)', (
      tester,
    ) async {
      const item = MaterialItem(
        id: 'MAT-0001',
        kind: MaterialKind.board,
        name: 'Плита премиум',
        thicknessMm: 16,
      );

      // Русский (ru)
      await tester.pumpWidget(
        buildHarness(materials: [item]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Материалы'), findsWidgets);
      expect(find.text('Каталог плит и кромки'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaterialCard),
          matching: find.text('16 мм'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Плита'),
        ),
        findsOneWidget,
      );

      // Казахский (kk)
      await tester.pumpWidget(
        buildHarness(materials: [item], locale: const Locale('kk')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Материалдар'), findsWidgets);
      expect(find.text('Тақталар мен жиектер каталогы'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaterialCard),
          matching: find.text('16 мм'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Тақта'),
        ),
        findsOneWidget,
      );

      // Английский (en)
      await tester.pumpWidget(
        buildHarness(materials: [item], locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Materials'), findsWidgets);
      expect(find.text('Board and edge catalogue'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaterialCard),
          matching: find.text('16 mm'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Board'),
        ),
        findsOneWidget,
      );
    });
  });
}
