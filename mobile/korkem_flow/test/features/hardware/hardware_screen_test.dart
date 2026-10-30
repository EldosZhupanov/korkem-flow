import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/hardware/data/hardware_repository.dart';
import 'package:korkem_flow/features/hardware/domain/hardware_item.dart';
import 'package:korkem_flow/features/hardware/presentation/hardware_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockHardwareRepository extends Mock implements HardwareRepository {}

void main() {
  late _MockHardwareRepository repository;

  setUp(() {
    repository = _MockHardwareRepository();
  });

  Widget buildHarness({
    required List<HardwareItem> hardware,
    Locale locale = const Locale('ru'),
  }) {
    when(
      () => repository.fetchHardware(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        query: any(named: 'query'),
        hardwareType: any(named: 'hardwareType'),
        overlay: any(named: 'overlay'),
      ),
    ).thenAnswer(
      (_) async => HardwarePage(
        hardware: hardware,
        total: hardware.length,
      ),
    );

    return ProviderScope(
      overrides: [
        hardwareRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HardwareScreen(),
      ),
    );
  }

  group('Экран «Фурнитура» (HardwareScreen)', () {
    testWidgets(
      '1. разные виды фурнитуры показываются по-разному '
      '(петля: наложение и угол; направляющая: длина и нагрузка; '
      'ручка: межцентровое расстояние и цвет)',
      (tester) async {
        const hinge = HardwareItem(
          id: 'HW-0001',
          hardwareType: HardwareType.hinge,
          brand: 'Boyard',
          model: 'H301',
          name: 'Петля накладная 110°',
          overlay: HingeOverlay.full,
          cupDiameterMm: 35,
          cupDepthMm: 11.3,
          mountingSystem: MountingSystem.german,
          openingAngleDeg: 110,
          softClose: true,
          colour: 'никель',
        );

        const runner = HardwareItem(
          id: 'HW-0020',
          hardwareType: HardwareType.runner,
          brand: 'Hettich',
          model: 'Quadro V6',
          name: 'Направляющие скрытого монтажа',
          lengthMm: 450,
          loadKg: 30,
          softClose: true,
        );

        const handle = HardwareItem(
          id: 'HW-0050',
          hardwareType: HardwareType.handle,
          brand: 'GTV',
          model: 'UA-HEXA',
          name: 'Ручка профильная',
          holeSpacingMm: 128,
          colour: 'черный матовый',
        );

        await tester.pumpWidget(
          buildHarness(hardware: [hinge, runner, handle]),
        );
        await tester.pumpAndSettle();

        // 1. Петля (Hinge):
        expect(find.text('Boyard H301 · Петля накладная 110°'), findsOneWidget);
        // Правило установки: фасад перекрывает торец
        expect(
          find.text('Фасад полностью перекрывает торец корпуса'),
          findsOneWidget,
        );
        expect(find.text('Накладная'), findsOneWidget);
        expect(find.text('110°'), findsOneWidget);
        expect(find.text('Чашка Ø35×11.3 мм'), findsOneWidget);
        expect(find.text('Немецкая (52 мм)'), findsOneWidget);
        expect(find.text('С доводчиком'), findsWidgets);
        expect(
          find.descendant(
            of: find.byType(HardwareCard),
            matching: find.byIcon(AppIcons.hinge),
          ),
          findsOneWidget,
        );

        // 2. Направляющая (Runner):
        expect(
          find.text('Hettich Quadro V6 · Направляющие скрытого монтажа'),
          findsOneWidget,
        );
        expect(find.text('450 мм'), findsOneWidget);
        expect(find.text('до 30 кг'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HardwareCard),
            matching: find.byIcon(AppIcons.runner),
          ),
          findsOneWidget,
        );

        // 3. Ручка (Handle):
        expect(find.text('GTV UA-HEXA · Ручка профильная'), findsOneWidget);
        expect(find.text('Межцентровое 128 мм'), findsOneWidget);
        expect(find.text('черный матовый'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HardwareCard),
            matching: find.byIcon(AppIcons.handle),
          ),
          findsOneWidget,
        );

        // Разные статусные чипы для каждого вида
        expect(
          find.descendant(
            of: find.byType(StatusChip),
            matching: find.text('Петля'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(StatusChip),
            matching: find.text('Направляющая'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(StatusChip),
            matching: find.text('Ручка'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. тип наложения назван словами (Накладная/Полунакладная/Вкладная), '
      'а не кодом full/half/inset, и объяснено правило установки',
      (tester) async {
        const fullHinge = HardwareItem(
          id: 'HW-1',
          hardwareType: HardwareType.hinge,
          name: 'Петля 1',
          overlay: HingeOverlay.full,
        );
        const halfHinge = HardwareItem(
          id: 'HW-2',
          hardwareType: HardwareType.hinge,
          name: 'Петля 2',
          overlay: HingeOverlay.half,
        );
        const insetHinge = HardwareItem(
          id: 'HW-3',
          hardwareType: HardwareType.hinge,
          name: 'Петля 3',
          overlay: HingeOverlay.inset,
        );

        await tester.pumpWidget(
          buildHarness(hardware: [fullHinge, halfHinge, insetHinge]),
        );
        await tester.pumpAndSettle();

        // Словесные наименования в карточках
        expect(find.text('Накладная'), findsOneWidget);
        expect(find.text('Полунакладная'), findsOneWidget);
        expect(find.text('Вкладная'), findsOneWidget);

        // Технические коды full/half/inset не торчат в интерфейсе
        expect(find.text('full'), findsNothing);
        expect(find.text('half'), findsNothing);
        expect(find.text('inset'), findsNothing);

        // Поясняющие правила установки видны мебельщику
        expect(
          find.text('Фасад полностью перекрывает торец корпуса'),
          findsOneWidget,
        );
        expect(
          find.text('Два фасада делят один торец корпуса'),
          findsOneWidget,
        );
        expect(find.text('Фасад утоплен внутрь корпуса'), findsOneWidget);
      },
    );

    testWidgets(
      '3. никогда не выдумывает данные — при отсутствии полей '
      'нет значений по умолчанию',
      (tester) async {
        // Минимальная запись с сервера: только id, name, hardware_type
        const minimalItem = HardwareItem(
          id: 'HW-9999',
          hardwareType: HardwareType.hinge,
          name: 'Петля без параметров',
        );

        await tester.pumpWidget(buildHarness(hardware: [minimalItem]));
        await tester.pumpAndSettle();

        expect(find.text('Петля без параметров'), findsOneWidget);

        // Никаких додуманных углов 110°, чашек 35 мм, наложений, доводчиков
        expect(find.text('110°'), findsNothing);
        expect(find.text('Ø35 мм'), findsNothing);
        expect(find.text('Чашка Ø35×11.3 мм'), findsNothing);
        expect(find.text('Накладная'), findsNothing);
        expect(find.text('С доводчиком'), findsNothing);
        expect(find.text('Без доводчика'), findsNothing);
      },
    );

    testWidgets(
      '4. фильтр по виду фурнитуры и подфильтр наложения петель '
      'отправляют точные параметры на сервер',
      (tester) async {
        await tester.pumpWidget(buildHarness(hardware: []));
        await tester.pumpAndSettle();

        // 1. Фильтр направляющих (runner)
        await tester.tap(find.byKey(const ValueKey('filter:type:runner')));
        await tester.pumpAndSettle();

        verify(
          () => repository.fetchHardware(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            hardwareType: 'runner',
            query: any(named: 'query'),
            overlay: any(named: 'overlay'),
          ),
        ).called(1);

        // 2. Переключаемся на петли (hinge) — появляются чипы наложений
        await tester.tap(find.byKey(const ValueKey('filter:type:hinge')));
        await tester.pumpAndSettle();

        verify(
          () => repository.fetchHardware(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            hardwareType: 'hinge',
            query: any(named: 'query'),
          ),
        ).called(1);

        // Подфильтр наложения появился
        expect(
          find.byKey(const ValueKey('filter:overlay:full')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('filter:overlay:half')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('filter:overlay:inset')),
          findsOneWidget,
        );

        // 3. Выбираем вкладную петлю (inset)
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter:overlay:inset')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('filter:overlay:inset')));
        await tester.pumpAndSettle();

        verify(
          () => repository.fetchHardware(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            hardwareType: 'hinge',
            overlay: 'inset',
            query: any(named: 'query'),
          ),
        ).called(1);

        // 4. Переключение обратно на ручки убирает подфильтр наложения
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter:type:handle')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('filter:type:handle')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('filter:overlay:inset')),
          findsNothing,
        );
      },
    );

    testWidgets('5. поиск с debounce отправляет query на сервер', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(hardware: []));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Boyard');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pump(AppDebounce.search + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      verify(
        () => repository.fetchHardware(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          query: 'Boyard',
          hardwareType: any(named: 'hardwareType'),
          overlay: any(named: 'overlay'),
        ),
      ).called(1);
    });

    testWidgets('5a. выбор всех типов очищает скрытый фильтр наложения', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(hardware: []));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('filter:type:hinge')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('filter:overlay:inset')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter:overlay:inset')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('filter:type:all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter:type:all')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('filter:overlay:inset')),
        findsNothing,
      );
      verify(
        () => repository.fetchHardware(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          query: any(named: 'query'),
        ),
      ).called(2); // Initial load and the unfiltered load after "All types".
    });

    testWidgets(
      '6. пустой каталог и пустой результат фильтрации с кнопкой сброса',
      (tester) async {
        await tester.pumpWidget(buildHarness(hardware: []));
        await tester.pumpAndSettle();

        // Каталог изначально пуст
        expect(find.text('Каталог фурнитуры пуст'), findsOneWidget);

        // Включаем фильтр ручек
        await tester.tap(find.byKey(const ValueKey('filter:type:handle')));
        await tester.pumpAndSettle();

        // Теперь пустое состояние с фильтром
        expect(find.text('Фурнитура не найдена'), findsOneWidget);
        expect(find.text('Сбросить фильтр'), findsOneWidget);

        // Сброс фильтра очищает параметры
        await tester.tap(find.text('Сбросить фильтр'));
        await tester.pumpAndSettle();

        expect(find.text('Каталог фурнитуры пуст'), findsOneWidget);
      },
    );

    testWidgets('7. экран полностью локализован на трёх языках (ru, kk, en)', (
      tester,
    ) async {
      const item = HardwareItem(
        id: 'HW-0001',
        hardwareType: HardwareType.hinge,
        brand: 'Blum',
        model: 'Clip Top',
        name: 'Петля 110°',
        overlay: HingeOverlay.full,
        cupDiameterMm: 35,
        openingAngleDeg: 110,
        softClose: true,
      );

      // Русский (ru)
      await tester.pumpWidget(buildHarness(hardware: [item]));
      await tester.pumpAndSettle();
      expect(find.text('Фурнитура'), findsWidgets);
      expect(find.text('Петли, направляющие и комплектующие'), findsOneWidget);
      expect(find.text('Накладная'), findsOneWidget);
      expect(
        find.text('Фасад полностью перекрывает торец корпуса'),
        findsOneWidget,
      );
      expect(find.text('С доводчиком'), findsOneWidget);
      expect(find.text('110°'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Петля'),
        ),
        findsOneWidget,
      );

      // Казахский (kk)
      await tester.pumpWidget(
        buildHarness(hardware: [item], locale: const Locale('kk')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Фурнитура'), findsWidgets);
      expect(
        find.text('Топсалар, бағыттауыштар және жиынтықтауыштар'),
        findsOneWidget,
      );
      expect(find.text('Үстіңгі жаппа'), findsOneWidget);
      expect(
        find.text('Фасад корпус қырын толығымен жабады'),
        findsOneWidget,
      );
      expect(find.text('Жұмсақ жапқышпен'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Топса'),
        ),
        findsOneWidget,
      );

      // Английский (en)
      await tester.pumpWidget(
        buildHarness(hardware: [item], locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hardware'), findsWidgets);
      expect(find.text('Hinges, runners and fittings'), findsOneWidget);
      expect(find.text('Full overlay'), findsOneWidget);
      expect(
        find.text('Door fully overlaps the cabinet edge'),
        findsOneWidget,
      );
      expect(find.text('Soft-close'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('Hinge'),
        ),
        findsOneWidget,
      );
    });
  });
}
