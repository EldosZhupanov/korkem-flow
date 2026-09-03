import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/memory/data/memory_repository.dart';
import 'package:korkem_flow/features/memory/domain/memory_fact.dart';
import 'package:korkem_flow/features/memory/presentation/memory_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeMemoryRepository extends MemoryRepository {
  _FakeMemoryRepository({
    this.fetchAllHandler,
    this.updateFactHandler,
    this.confirmFactHandler,
    this.deleteFactHandler,
  }) : super(dummyClient);

  static final FrappeClient dummyClient = FrappeClient(Dio());

  final Future<List<MemoryFact>> Function()? fetchAllHandler;
  final Future<MemoryFact> Function(String id, {required String text})?
  updateFactHandler;
  final Future<MemoryFact> Function(String id)? confirmFactHandler;
  final Future<void> Function(String id)? deleteFactHandler;

  @override
  Future<List<MemoryFact>> fetchAll() async {
    if (fetchAllHandler != null) {
      return fetchAllHandler!();
    }
    return const [];
  }

  @override
  Future<MemoryFact> updateFact(String id, {required String text}) async {
    if (updateFactHandler != null) {
      return updateFactHandler!(id, text: text);
    }
    return MemoryFact(
      id: id,
      text: text,
      scope: MemoryScope.company,
      sourceLabel: 'тест',
      isConfirmed: true,
    );
  }

  @override
  Future<MemoryFact> confirmFact(String id) async {
    if (confirmFactHandler != null) {
      return confirmFactHandler!(id);
    }
    return MemoryFact(
      id: id,
      text: 'тест',
      scope: MemoryScope.company,
      sourceLabel: 'тест',
      isConfirmed: true,
    );
  }

  @override
  Future<void> deleteFact(String id) async {
    if (deleteFactHandler != null) {
      return deleteFactHandler!(id);
    }
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required MemoryRepository repository,
  }) {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        memoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MemoryScreen(),
      ),
    );
  }

  const companyFact = MemoryFact(
    id: 'MEM-COMP-1',
    text: 'ЛДСП считаем в квадратных метрах',
    scope: MemoryScope.company,
    sourceLabel: 'из разговора 2 сентября',
  );

  const userFact = MemoryFact(
    id: 'MEM-USER-1',
    text: 'Основной рабочий язык — казахский',
    scope: MemoryScope.user,
    sourceLabel: 'указано вами',
    isConfirmed: true,
  );

  testWidgets(
    'пустое состояние показывает объяснение, а не белый экран',
    (tester) async {
      final repo = _FakeMemoryRepository(
        fetchAllHandler: () async => const [],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Что KORKEM знает'), findsOneWidget);
      expect(find.text('KORKEM пока ничего о вас не запомнил'), findsOneWidget);
      expect(
        find.textContaining('Здесь появятся знания о цехе'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'показывает два раздела: «О компании» и «Обо мне» со статусами и '
    'источниками',
    (tester) async {
      final repo = _FakeMemoryRepository(
        fetchAllHandler: () async => [companyFact, userFact],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Sections
      expect(find.text('О компании'.toUpperCase()), findsOneWidget);
      expect(find.text('Обо мне'.toUpperCase()), findsOneWidget);

      // Facts
      expect(find.text('ЛДСП считаем в квадратных метрах'), findsOneWidget);
      expect(find.text('из разговора 2 сентября'), findsOneWidget);
      expect(find.text('Выведено системой'), findsOneWidget);

      expect(find.text('Основной рабочий язык — казахский'), findsOneWidget);
      expect(find.text('указано вами'), findsOneWidget);
      expect(find.text('Подтверждено'), findsOneWidget);
    },
  );

  testWidgets(
    'факт можно исправить, и правка уходит на сервер дословно',
    (tester) async {
      String? updatedId;
      String? updatedText;

      final repo = _FakeMemoryRepository(
        fetchAllHandler: () async => [companyFact],
        updateFactHandler: (id, {required text}) async {
          updatedId = id;
          updatedText = text;
          return companyFact.copyWith(text: text, isConfirmed: true);
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Open menu on fact
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      // Tap Edit
      await tester.tap(find.text('Исправить'));
      await tester.pumpAndSettle();

      expect(find.text('Исправить факт'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Change text
      const newText = 'ЛДСП считаем в листах 2750x1830';
      await tester.enterText(find.byType(TextField), newText);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      // Verified server called
      expect(updatedId, 'MEM-COMP-1');
      expect(updatedText, newText);

      // Verified screen shows updated text and confirmation
      expect(find.text(newText), findsOneWidget);
      expect(find.text('Факт обновлён'), findsOneWidget);
    },
  );

  testWidgets(
    'удаление спрашивает подтверждение — '
    'отмена оставляет факт, подтверждение удаляет',
    (tester) async {
      var deleteCalled = false;
      String? deletedId;

      final repo = _FakeMemoryRepository(
        fetchAllHandler: () async => [companyFact],
        deleteFactHandler: (id) async {
          deleteCalled = true;
          deletedId = id;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('ЛДСП считаем в квадратных метрах'), findsOneWidget);

      // Open menu -> Delete
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      // Dialog asks confirmation with warning
      expect(find.text('Удалить факт?'), findsOneWidget);
      expect(
        find.textContaining('Удалить память легко, вернуть нельзя'),
        findsOneWidget,
      );

      // Cancel first
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isFalse);
      expect(find.text('ЛДСП считаем в квадратных метрах'), findsOneWidget);

      // Open menu -> Delete again -> Confirm
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      // Confirm delete in dialog
      final confirmDelete = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Удалить'),
      );
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(deletedId, 'MEM-COMP-1');
      expect(find.text('Факт удалён'), findsOneWidget);
      // Fact is gone from list, shows empty state
      expect(find.text('ЛДСП считаем в квадратных метрах'), findsNothing);
      expect(find.text('KORKEM пока ничего о вас не запомнил'), findsOneWidget);
    },
  );

  testWidgets(
    'подтверждение факта вызывает сервер и обновляет статус до «Подтверждено»',
    (tester) async {
      String? confirmedId;

      final repo = _FakeMemoryRepository(
        fetchAllHandler: () async => [companyFact],
        confirmFactHandler: (id) async {
          confirmedId = id;
          return companyFact.copyWith(isConfirmed: true);
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Выведено системой'), findsOneWidget);
      expect(find.text('Подтвердить'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();

      expect(confirmedId, 'MEM-COMP-1');
      expect(find.text('Факт подтверждён'), findsOneWidget);
      expect(find.text('Подтверждено'), findsOneWidget);
      expect(find.text('Выведено системой'), findsNothing);
    },
  );

  testWidgets(
    'отказ сервера показан его словами при ошибке обновления или подтверждения',
    (tester) async {
      final repo = _FakeMemoryRepository(
        fetchAllHandler: () async => [companyFact],
        confirmFactHandler: (id) async {
          throw const ValidationFailure(
            'Факт устарел и был перезаписан в базе знаний',
          );
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();

      // Verbatim server refusal displayed in SnackBar
      expect(
        find.text('Факт устарел и был перезаписан в базе знаний'),
        findsOneWidget,
      );
      // Fact remains in list
      expect(find.text('ЛДСП считаем в квадратных метрах'), findsOneWidget);
    },
  );

  testWidgets(
    'тап по карточке открывает диалог просмотра с подробностями',
    (tester) async {
      final repo = _FakeMemoryRepository(
        fetchAllHandler: () async => [userFact],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Tap on card
      await tester.tap(find.text('Основной рабочий язык — казахский'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Источник: указано вами'), findsOneWidget);
      expect(find.text('Закрыть'), findsOneWidget);

      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
