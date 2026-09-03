import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/bazis/data/bazis_repository.dart';
import 'package:korkem_flow/features/bazis/domain/bazis_models.dart';
import 'package:korkem_flow/features/bazis/presentation/bazis_import_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeBazisRepository extends BazisRepository {
  _FakeBazisRepository({
    this.inspectHandler,
    this.importHandler,
  }) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());

  final Future<BazisInspectResult> Function({
    required String filename,
    required List<int> bytes,
  })?
  inspectHandler;

  final Future<BazisImportResult> Function({
    required String filename,
    required List<int> bytes,
    String? salesOrder,
  })?
  importHandler;

  @override
  Future<BazisInspectResult> inspectSpecification({
    required String filename,
    required List<int> bytes,
  }) {
    if (inspectHandler != null) {
      return inspectHandler!(filename: filename, bytes: bytes);
    }
    return Future.value(
      const BazisInspectResult(
        products: [],
        totals: BazisTotals(
          products: 0,
          parts: 0,
          materials: 0,
          operations: 0,
        ),
      ),
    );
  }

  @override
  Future<BazisImportResult> importSpecification({
    required String filename,
    required List<int> bytes,
    String? salesOrder,
  }) {
    if (importHandler != null) {
      return importHandler!(
        filename: filename,
        bytes: bytes,
        salesOrder: salesOrder,
      );
    }
    return Future.value(
      const BazisImportResult(
        totals: BazisTotals(
          products: 0,
          parts: 0,
          materials: 0,
          operations: 0,
        ),
        products: [],
      ),
    );
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required BazisRepository repository,
    String? salesOrder,
    Future<BazisPickedFile?> Function()? onPickFileForTesting,
  }) {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        bazisRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BazisImportScreen(
          salesOrder: salesOrder,
          onPickFileForTesting: onPickFileForTesting,
        ),
      ),
    );
  }

  testWidgets(
    'Flow: read (inspect) -> display inspected data -> create specification',
    (tester) async {
      var inspectCalled = false;
      var importCalled = false;
      String? passedSalesOrder;

      final repo = _FakeBazisRepository(
        inspectHandler: ({required filename, required bytes}) async {
          inspectCalled = true;
          return const BazisInspectResult(
            totals: BazisTotals(
              products: 1,
              parts: 1,
              materials: 1,
              operations: 1,
            ),
            products: [
              BazisProduct(
                name: 'Кухонный гарнитур «Астана»',
                article: 'KG-001',
                order: 'SO-2026-0042',
                qty: 1,
                price: 780000,
                parts: [
                  BazisPart(
                    block: '3 / Шариковые',
                    name: 'Боковина левая',
                    code: 'D-101',
                    kind: 'Панель',
                    length: 2100,
                    width: 560,
                    thickness: 16,
                    qty: 2,
                    edges: ['Кромка ПВХ 2мм дуб'],
                  ),
                ],
                materials: [
                  BazisMaterial(
                    syncId: 'MAT-LDSP-DUB-16',
                    name: 'ЛДСП Дуб Сонома 16мм',
                    unit: 'м2',
                    qty: 2.352,
                  ),
                ],
                operations: [
                  BazisOperation(
                    syncId: 'OP-CUT',
                    name: 'Раскрой',
                    qty: 6,
                    minutes: 12.5,
                  ),
                ],
              ),
            ],
          );
        },
        importHandler:
            ({
              required filename,
              required bytes,
              salesOrder,
            }) async {
              importCalled = true;
              passedSalesOrder = salesOrder;
              return const BazisImportResult(
                company: 'ТОО «Көркем»',
                totals: BazisTotals(
                  products: 1,
                  parts: 1,
                  materials: 1,
                  operations: 1,
                ),
                products: [
                  BazisImportedProduct(
                    product: 'Кухонный гарнитур «Астана»',
                    item: 'KG-001',
                    bom: 'BOM-KG-001-001',
                    bomStatus: 'created',
                    materials: ['БАЗИС-MAT-LDSP-DUB-16'],
                    materialsWithoutQuantity: ['Кромка без расчёта'],
                    operations: ['Раскрой'],
                    operationsAwaitingWorkstation: ['Кромление на ЧПУ'],
                    salesOrder: 'SO-2026-0042',
                  ),
                ],
              );
            },
      );

      const fakeFile = BazisPickedFile(
        name: 'specification_kitchen.xml',
        bytes: [60, 80, 114, 111, 106, 101, 99, 116, 47, 62],
      );

      await tester.pumpWidget(
        buildHarness(
          tester,
          repository: repo,
          salesOrder: 'SO-2026-0042',
          onPickFileForTesting: () async => fakeFile,
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Initial screen with prompt to pick file
      expect(find.text('Спецификация из БАЗИС'), findsWidgets);
      expect(find.text('Выбрать файл БАЗИС'), findsOneWidget);

      // Tap pick file
      await tester.tap(find.text('Выбрать файл БАЗИС'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Step 2: Inspected file preview is displayed
      expect(inspectCalled, isTrue);
      expect(find.text('specification_kitchen.xml'), findsOneWidget);
      expect(find.text('Кухонный гарнитур «Астана»'), findsOneWidget);
      expect(find.text('Артикул: KG-001'), findsOneWidget);
      expect(find.text('Заказ: SO-2026-0042'), findsOneWidget);

      // Check part with block (workshop address)
      expect(find.text('Боковина левая'), findsOneWidget);
      expect(find.text('3 / Шариковые'), findsOneWidget);
      expect(find.text('2100 × 560 × 16 мм'), findsOneWidget);
      expect(find.text('Кромка: Кромка ПВХ 2мм дуб'), findsOneWidget);

      // Switch to materials tab
      await tester.tap(find.text('Материалы (1)'));
      await tester.pumpAndSettle();
      expect(find.text('ЛДСП Дуб Сонома 16мм'), findsOneWidget);
      expect(find.text('2.352 м2'), findsOneWidget);

      // Switch to operations tab
      await tester.tap(find.text('Операции (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Раскрой'), findsOneWidget);
      expect(find.text('12.5 мин.'), findsOneWidget);

      // Verify "Создать спецификацию" button is visible
      expect(find.text('Создать спецификацию'), findsOneWidget);

      // Step 3: Tap create specification
      await tester.tap(find.text('Создать спецификацию'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(importCalled, isTrue);
      expect(passedSalesOrder, 'SO-2026-0042');

      // Step 4: Verify import results and 3 critical points:
      // 1. bom_status badge
      expect(find.text('Спецификация создана'), findsOneWidget);
      expect(find.text('Спецификация BOM: BOM-KG-001-001'), findsOneWidget);
      expect(find.text('Номенклатура: KG-001'), findsOneWidget);

      // 2. materials_without_quantity alert
      expect(
        find.text(
          'Материалы без расчёта количества (не вошли в спецификацию):',
        ),
        findsOneWidget,
      );
      expect(find.text('• Кромка без расчёта'), findsOneWidget);

      // 3. operations_awaiting_workstation alert
      expect(
        find.text(
          'Операции без назначенного рабочего места '
          '(внесены в справочник, но не включены в маршрут):',
        ),
        findsOneWidget,
      );
      expect(find.text('• Кромление на ЧПУ'), findsOneWidget);

      // Test "Загрузить другую выгрузку" resets state
      await tester.tap(find.text('Загрузить другую выгрузку'));
      await tester.pumpAndSettle();
      expect(find.text('Выбрать файл БАЗИС'), findsOneWidget);
    },
  );

  testWidgets(
    'displays updated bom_status badge when an existing draft is updated',
    (tester) async {
      final repo = _FakeBazisRepository(
        inspectHandler: ({required filename, required bytes}) async {
          return const BazisInspectResult(
            totals: BazisTotals(
              products: 1,
              parts: 0,
              materials: 1,
              operations: 0,
            ),
            products: [
              BazisProduct(
                name: 'Шкаф-купе',
                materials: [
                  BazisMaterial(name: 'ЛДСП 16мм', unit: 'м2', qty: 5),
                ],
              ),
            ],
          );
        },
        importHandler:
            ({
              required filename,
              required bytes,
              salesOrder,
            }) async {
              return const BazisImportResult(
                totals: BazisTotals(
                  products: 1,
                  parts: 0,
                  materials: 1,
                  operations: 0,
                ),
                products: [
                  BazisImportedProduct(
                    product: 'Шкаф-купе',
                    item: 'SHK-001',
                    bom: 'BOM-SHK-001-001',
                    bomStatus: 'updated',
                    materials: ['БАЗИС-MAT-1'],
                  ),
                ],
              );
            },
      );

      const fakeFile = BazisPickedFile(
        name: 'shkaf.xml',
        bytes: [60, 80, 114, 111, 106, 101, 99, 116, 47, 62],
      );

      await tester.pumpWidget(
        buildHarness(
          tester,
          repository: repo,
          onPickFileForTesting: () async => fakeFile,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Выбрать файл БАЗИС'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Создать спецификацию'));
      await tester.pumpAndSettle();

      // Check bom_status badge for updated draft
      expect(find.text('Черновик спецификации обновлён'), findsOneWidget);
    },
  );

  testWidgets('displays verbatim server refusal on unknown units', (
    tester,
  ) async {
    const refusalText =
        'Не понимаю единицы измерения: «рулон». Подставить вместо них штуки '
        'нельзя — единица печатается в накладной, и её читает клиент. Ничего '
        'не записано.';

    final repo = _FakeBazisRepository(
      inspectHandler: ({required filename, required bytes}) async {
        return const BazisInspectResult(
          totals: BazisTotals(
            products: 1,
            parts: 0,
            materials: 1,
            operations: 0,
          ),
          products: [
            BazisProduct(
              name: 'Стол',
              materials: [
                BazisMaterial(name: 'Плёнка', unit: 'рулон', qty: 1),
              ],
            ),
          ],
        );
      },
      importHandler:
          ({
            required filename,
            required bytes,
            salesOrder,
          }) async {
            throw const ValidationFailure(refusalText);
          },
    );

    const fakeFile = BazisPickedFile(
      name: 'table.xml',
      bytes: [60, 80, 114, 111, 106, 101, 99, 116, 47, 62],
    );

    await tester.pumpWidget(
      buildHarness(
        tester,
        repository: repo,
        onPickFileForTesting: () async => fakeFile,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выбрать файл БАЗИС'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать спецификацию'));
    await tester.pumpAndSettle();

    // Verify refusal text is displayed verbatim in the alert box
    expect(find.text(refusalText), findsOneWidget);
  });

  testWidgets('displays verbatim server error on inspect failure', (
    tester,
  ) async {
    const errorText =
        'В файле нет ни одного изделия. Возможно, это выгрузка раскроя, '
        'а не спецификация: нужна та, что содержит элемент «Изделие».';

    final repo = _FakeBazisRepository(
      inspectHandler: ({required filename, required bytes}) async {
        throw const ValidationFailure(errorText);
      },
    );

    const fakeFile = BazisPickedFile(
      name: 'wrong.xml',
      bytes: [60, 82, 97, 115, 107, 114, 111, 121, 47, 62],
    );

    await tester.pumpWidget(
      buildHarness(
        tester,
        repository: repo,
        onPickFileForTesting: () async => fakeFile,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выбрать файл БАЗИС'));
    await tester.pumpAndSettle();

    expect(find.text(errorText), findsOneWidget);
  });
}
