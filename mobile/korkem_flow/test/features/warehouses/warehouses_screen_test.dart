import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/features/warehouses/data/warehouses_repository.dart';
import 'package:korkem_flow/features/warehouses/domain/warehouse_models.dart';
import 'package:korkem_flow/features/warehouses/presentation/warehouses_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeWarehousesRepository extends WarehousesRepository {
  _FakeWarehousesRepository({
    required this.fetchWarehousesHandler,
    this.createHandler,
    this.setShippingDefaultHandler,
    this.setDisabledHandler,
  }) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());

  final Future<List<WarehouseEntry>> Function() fetchWarehousesHandler;
  final Future<WarehouseEntry> Function(String name)? createHandler;
  final Future<WarehouseEntry> Function(String warehouse)?
  setShippingDefaultHandler;
  final Future<WarehouseEntry> Function({
    required String warehouse,
    required bool disabled,
  })?
  setDisabledHandler;

  @override
  Future<List<WarehouseEntry>> fetchWarehouses() => fetchWarehousesHandler();

  @override
  Future<WarehouseEntry> createWarehouse({required String name}) {
    if (createHandler != null) {
      return createHandler!(name);
    }
    return Future.value(
      WarehouseEntry(
        warehouse: '$name - ED',
        name: name,
        disabled: false,
        positions: 0,
        isShippingDefault: false,
      ),
    );
  }

  @override
  Future<WarehouseEntry> setShippingDefault({required String warehouse}) {
    if (setShippingDefaultHandler != null) {
      return setShippingDefaultHandler!(warehouse);
    }
    return Future.value(
      WarehouseEntry(
        warehouse: warehouse,
        name: warehouse.replaceAll(' - ED', ''),
        disabled: false,
        positions: 0,
        isShippingDefault: true,
      ),
    );
  }

  @override
  Future<WarehouseEntry> setDisabled({
    required String warehouse,
    required bool disabled,
  }) {
    if (setDisabledHandler != null) {
      return setDisabledHandler!(warehouse: warehouse, disabled: disabled);
    }
    return Future.value(
      WarehouseEntry(
        warehouse: warehouse,
        name: warehouse.replaceAll(' - ED', ''),
        disabled: disabled,
        positions: 0,
        isShippingDefault: false,
      ),
    );
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required WarehousesRepository repository,
  }) {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        warehousesRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WarehousesScreen(),
      ),
    );
  }

  testWidgets(
    'renders list of warehouses with shipping badge and zero positions count',
    (tester) async {
      final repo = _FakeWarehousesRepository(
        fetchWarehousesHandler: () async => const [
          WarehouseEntry(
            warehouse: 'Finished Goods - ED',
            name: 'Finished Goods',
            disabled: false,
            positions: 12,
            isShippingDefault: true,
          ),
          WarehouseEntry(
            warehouse: 'Stores - ED',
            name: 'Stores',
            disabled: false,
            positions: 0,
            isShippingDefault: false,
          ),
        ],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Склады'), findsWidgets);
      expect(find.text('Finished Goods'), findsOneWidget);
      expect(find.text('Склад отгрузки'), findsOneWidget);
      expect(find.text('12 позиций'), findsOneWidget);

      expect(find.text('Stores'), findsOneWidget);
      expect(find.text('0 позиций'), findsOneWidget);

      // Verify tip banner
      expect(find.text('Как сменить имя склада в документах'), findsOneWidget);
      expect(
        find.textContaining('заведите свой склад с нужным названием'),
        findsOneWidget,
      );
    },
  );

  testWidgets('displays empty state when no warehouses are returned', (
    tester,
  ) async {
    final repo = _FakeWarehousesRepository(
      fetchWarehousesHandler: () async => const [],
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Склады не найдены'), findsOneWidget);
    expect(find.text('Список складов компании пуст.'), findsOneWidget);
    expect(find.text('Новый склад'), findsWidgets);
  });

  testWidgets(
    'opens create warehouse dialog, validates, and creates warehouse',
    (
      tester,
    ) async {
      String? createdName;

      final repo = _FakeWarehousesRepository(
        fetchWarehousesHandler: () async => const [
          WarehouseEntry(
            warehouse: 'Finished Goods - ED',
            name: 'Finished Goods',
            disabled: false,
            positions: 1,
            isShippingDefault: true,
          ),
        ],
        createHandler: (name) async {
          createdName = name;
          return WarehouseEntry(
            warehouse: '$name - ED',
            name: name,
            disabled: false,
            positions: 0,
            isShippingDefault: false,
          );
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Tap + button in app bar
      await tester.tap(find.byIcon(AppIcons.add).first);
      await tester.pumpAndSettle();

      expect(find.text('Новый склад'), findsWidgets);
      expect(
        find.text('Второй цех, арендованное помещение, машина'),
        findsOneWidget,
      );

      // Try submit empty
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Новый склад'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Введите название склада'), findsOneWidget);

      // Enter warehouse name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название склада'),
        'Склад материалов',
      );

      // Submit
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Новый склад'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(createdName, 'Склад материалов');
      expect(find.text('Склад «Склад материалов» создан'), findsOneWidget);
    },
  );

  testWidgets('sets warehouse as shipping default via popup menu', (
    tester,
  ) async {
    String? defaultWarehouse;

    final repo = _FakeWarehousesRepository(
      fetchWarehousesHandler: () async => const [
        WarehouseEntry(
          warehouse: 'Finished Goods - ED',
          name: 'Finished Goods',
          disabled: false,
          positions: 1,
          isShippingDefault: true,
        ),
        WarehouseEntry(
          warehouse: 'Склад готовой продукции - ED',
          name: 'Склад готовой продукции',
          disabled: false,
          positions: 0,
          isShippingDefault: false,
        ),
      ],
      setShippingDefaultHandler: (warehouse) async {
        defaultWarehouse = warehouse;
        return WarehouseEntry(
          warehouse: warehouse,
          name: 'Склад готовой продукции',
          disabled: false,
          positions: 0,
          isShippingDefault: true,
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    // Tap menu button on second warehouse
    await tester.tap(find.byIcon(AppIcons.more));
    await tester.pumpAndSettle();

    // Tap "Сделать складом отгрузки"
    await tester.tap(find.text('Сделать складом отгрузки'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(defaultWarehouse, 'Склад готовой продукции - ED');
    expect(
      find.text(
        'Склад «Склад готовой продукции» назначен складом отгрузки',
      ),
      findsOneWidget,
    );
  });

  testWidgets('disables warehouse via confirmation dialog', (tester) async {
    String? disabledWarehouse;
    bool? isDisabled;

    final repo = _FakeWarehousesRepository(
      fetchWarehousesHandler: () async => const [
        WarehouseEntry(
          warehouse: 'Finished Goods - ED',
          name: 'Finished Goods',
          disabled: false,
          positions: 1,
          isShippingDefault: true,
        ),
        WarehouseEntry(
          warehouse: 'Stores - ED',
          name: 'Stores',
          disabled: false,
          positions: 0,
          isShippingDefault: false,
        ),
      ],
      setDisabledHandler:
          ({
            required warehouse,
            required disabled,
          }) async {
            disabledWarehouse = warehouse;
            isDisabled = disabled;
            return WarehouseEntry(
              warehouse: warehouse,
              name: 'Stores',
              disabled: disabled,
              positions: 0,
              isShippingDefault: false,
            );
          },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.more));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отключить склад'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog includes warehouse name
    expect(find.text('Отключить склад?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Stores'),
      ),
      findsOneWidget,
    );

    // Confirm disable
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Отключить склад'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(disabledWarehouse, 'Stores - ED');
    expect(isDisabled, isTrue);
    expect(find.text('Склад «Stores» отключён'), findsOneWidget);
  });

  testWidgets(
    'displays exact server refusal when disabling shipping default warehouse',
    (tester) async {
      final repo = _FakeWarehousesRepository(
        fetchWarehousesHandler: () async => const [
          WarehouseEntry(
            warehouse: 'Finished Goods - ED',
            name: 'Finished Goods',
            disabled: false,
            positions: 1,
            isShippingDefault: false,
          ),
        ],
        setDisabledHandler:
            ({
              required warehouse,
              required disabled,
            }) async {
              throw const ValidationFailure(
                'Это склад отгрузки: с него уходит готовая мебель. '
                'Сначала назначьте другой, иначе заказы будет '
                'некуда отгружать.',
              );
            },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Отключить склад'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Отключить склад'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify server's refusal message is shown verbatim in dialog
      expect(
        find.text(
          'Это склад отгрузки: с него уходит готовая мебель. '
          'Сначала назначьте другой, иначе заказы будет некуда отгружать.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'disabled warehouse is listed separately and can be re-enabled',
    (tester) async {
      String? enabledWarehouse;
      bool? isEnabled;

      final repo = _FakeWarehousesRepository(
        fetchWarehousesHandler: () async => const [
          WarehouseEntry(
            warehouse: 'Finished Goods - ED',
            name: 'Finished Goods',
            disabled: false,
            positions: 1,
            isShippingDefault: true,
          ),
          WarehouseEntry(
            warehouse: 'Старый склад - ED',
            name: 'Старый склад',
            disabled: true,
            positions: 0,
            isShippingDefault: false,
          ),
        ],
        setDisabledHandler:
            ({
              required warehouse,
              required disabled,
            }) async {
              enabledWarehouse = warehouse;
              isEnabled = !disabled;
              return WarehouseEntry(
                warehouse: warehouse,
                name: 'Старый склад',
                disabled: disabled,
                positions: 0,
                isShippingDefault: false,
              );
            },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Verify disabled section
      expect(
        find.widgetWithText(SectionLabel, 'ОТКЛЮЧЁННЫЕ СКЛАДЫ'),
        findsOneWidget,
      );
      expect(find.text('Старый склад'), findsOneWidget);
      expect(find.text('Отключён'), findsOneWidget);

      // Tap enable icon button
      await tester.tap(find.byTooltip('Включить склад'));
      await tester.pumpAndSettle();

      expect(find.text('Включить склад?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Старый склад'),
        ),
        findsOneWidget,
      );

      // Confirm enable
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Включить склад'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(enabledWarehouse, 'Старый склад - ED');
      expect(isEnabled, isTrue);
      expect(find.text('Склад «Старый склад» включён'), findsOneWidget);
    },
  );

  testWidgets('shows error state on network error and retries', (tester) async {
    var fail = true;
    final repo = _FakeWarehousesRepository(
      fetchWarehousesHandler: () async {
        if (fail) throw const NetworkFailure('Timeout');
        return const [
          WarehouseEntry(
            warehouse: 'Finished Goods - ED',
            name: 'Finished Goods',
            disabled: false,
            positions: 1,
            isShippingDefault: true,
          ),
        ];
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Нет связи с сервером.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Finished Goods'), findsOneWidget);
  });

  testWidgets('пустой склад показывает ноль позиций, а не пустоту', (
    tester,
  ) async {
    // Ноль — это факт: на складе ничего не лежит. Прочерк на его месте
    // читается как «данные не пришли», и владелец идёт проверять связь.
    final repo = _FakeWarehousesRepository(
      fetchWarehousesHandler: () async => const [
        WarehouseEntry(
          warehouse: 'Stores - ED',
          name: 'Stores',
          disabled: false,
          positions: 0,
          isShippingDefault: false,
        ),
      ],
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('0 позиций'), findsOneWidget);
  });

  testWidgets('склад отгрузки помечен и отключить его нечем', (tester) async {
    // Сервер откажется отключить склад отгрузки — но лучше не доводить до
    // отказа: экран не предлагает действия, которое всё равно не пройдёт.
    // Ошибка предотвращается, а не сообщается после нажатия.
    final repo = _FakeWarehousesRepository(
      fetchWarehousesHandler: () async => const [
        WarehouseEntry(
          warehouse: 'Finished Goods - ED',
          name: 'Finished Goods',
          disabled: false,
          positions: 3,
          isShippingDefault: true,
        ),
      ],
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.more), findsNothing);
  });
}
