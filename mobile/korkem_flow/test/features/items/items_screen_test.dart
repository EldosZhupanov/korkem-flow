import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/items/data/items_repository.dart';
import 'package:korkem_flow/features/items/domain/item.dart';
import 'package:korkem_flow/features/items/presentation/items_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeItemsRepository extends ItemsRepository {
  _FakeItemsRepository({
    this.listHandler,
    this.createHandler,
    this.setPriceHandler,
    this.fetchUnitsHandler,
  }) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());

  final Future<List<Item>> Function(String? query, int limit)? listHandler;
  final Future<Item> Function(Item item)? createHandler;
  final Future<Item> Function(String code, double price)? setPriceHandler;
  final Future<List<UnitOption>> Function()? fetchUnitsHandler;

  @override
  Future<List<Item>> list({String? query, int limit = 50}) {
    if (listHandler != null) return listHandler!(query, limit);
    return Future.value(const []);
  }

  @override
  Future<Item> create(Item item) {
    if (createHandler != null) return createHandler!(item);
    return Future.value(item);
  }

  @override
  Future<Item> setPrice(String code, double price) {
    if (setPriceHandler != null) return setPriceHandler!(code, price);
    return Future.value(
      Item(code: code, name: code, unit: 'Nos', salePrice: price),
    );
  }

  @override
  Future<List<UnitOption>> fetchUnits() {
    if (fetchUnitsHandler != null) return fetchUnitsHandler!();
    return Future.value(const [
      UnitOption(unit: 'Nos', label: 'шт'),
      UnitOption(unit: 'Set', label: 'комплект'),
      UnitOption(unit: 'Meter', label: 'м, погонный метр'),
    ]);
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required ItemsRepository repository,
  }) {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        itemsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ItemsScreen(),
      ),
    );
  }

  testWidgets('renders items catalog with price and unpriced items', (
    tester,
  ) async {
    final repo = _FakeItemsRepository(
      listHandler: (query, limit) async => const [
        Item(
          code: 'CAB-01',
          name: 'Шкаф распашной двухдверный',
          unit: 'Nos',
          description: 'МДФ белый глянец',
          salePrice: 150000,
        ),
        Item(
          code: 'CUSTOM-KIT',
          name: 'Кухня угловая заказная',
          unit: 'Set',
          description: 'По индивидуальным размерам',
        ),
      ],
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    final expectedPrice = NumberFormat.currency(
      locale: 'ru',
      symbol: '₸',
      decimalDigits: 0,
    ).format(150000);

    expect(find.text('Номенклатура и цены'), findsOneWidget);
    expect(find.text('Шкаф распашной двухдверный'), findsOneWidget);
    expect(find.text('CAB-01'), findsOneWidget);
    expect(find.text('МДФ белый глянец'), findsOneWidget);
    expect(find.text(expectedPrice), findsOneWidget);

    expect(find.text('Кухня угловая заказная'), findsOneWidget);
    expect(find.text('Цена по расчёту'), findsOneWidget);
    expect(find.text('Set'), findsOneWidget);
  });

  testWidgets('filters items by search query', (tester) async {
    String? capturedQuery;
    final repo = _FakeItemsRepository(
      listHandler: (query, limit) async {
        capturedQuery = query;
        if (query == 'Комод') {
          return const [
            Item(
              code: 'DRW-01',
              name: 'Комод',
              unit: 'Nos',
            ),
          ];
        }
        return const [
          Item(code: 'CAB-01', name: 'Шкаф', unit: 'Nos'),
          Item(code: 'DRW-01', name: 'Комод', unit: 'Nos'),
        ];
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Шкаф'), findsOneWidget);
    expect(find.text('Комод'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Комод',
    );
    await tester.pumpAndSettle();

    expect(capturedQuery, 'Комод');
    expect(find.text('Комод'), findsNWidgets(2));
    expect(find.text('Шкаф'), findsNothing);
  });

  testWidgets('displays empty state when catalog is empty', (tester) async {
    final repo = _FakeItemsRepository(
      listHandler: (_, _) async => const [],
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('В каталоге пока нет позиций'), findsOneWidget);
    expect(find.text('Добавьте первую позицию номенклатуры'), findsOneWidget);
  });

  testWidgets('opens create item dialog with dynamic units from server', (
    tester,
  ) async {
    Item? createdItem;
    final repo = _FakeItemsRepository(
      listHandler: (_, _) async => const [],
      fetchUnitsHandler: () async => const [
        UnitOption(unit: 'Nos', label: 'шт'),
        UnitOption(unit: 'Set', label: 'комплект'),
        UnitOption(unit: 'Meter', label: 'м, погонный метр'),
      ],
      createHandler: (item) async {
        createdItem = item;
        return item;
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Добавить позицию'));
    await tester.pumpAndSettle();

    expect(find.text('Новая позиция'), findsOneWidget);

    // Try submitting empty
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(FilledButton, 'Добавить позицию'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Введите название позиции'), findsOneWidget);
    expect(find.text('Единица измерения обязательна'), findsOneWidget);

    // Fill form without price (valid state for bespoke items)
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название позиции'),
      'Тумба прикроватная',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Код / артикул (необязательно)'),
      'BED-01',
    );

    // Select unit from dynamic dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('комплект').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(FilledButton, 'Добавить позицию'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(createdItem, isNotNull);
    expect(createdItem!.name, 'Тумба прикроватная');
    expect(createdItem!.code, 'BED-01');
    expect(createdItem!.unit, 'Set');
    expect(createdItem!.salePrice, isNull);
    expect(find.text('Позиция добавлена'), findsOneWidget);
  });

  testWidgets('displays server rejection in create dialog verbatim', (
    tester,
  ) async {
    final repo = _FakeItemsRepository(
      listHandler: (_, _) async => const [],
      fetchUnitsHandler: () async => const [
        UnitOption(unit: 'Nos', label: 'шт'),
      ],
      createHandler: (item) async {
        throw const ValidationFailure(
          'Позиция с таким артикулом уже существует в базе.',
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Добавить позицию'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название позиции'),
      'Стул офисный',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('шт').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(FilledButton, 'Добавить позицию'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Позиция с таким артикулом уже существует в базе.'),
      findsOneWidget,
    );
  });

  testWidgets('displays permission refusal when non-owner creates item', (
    tester,
  ) async {
    final repo = _FakeItemsRepository(
      listHandler: (_, _) async => const [],
      fetchUnitsHandler: () async => const [
        UnitOption(unit: 'Nos', label: 'шт'),
      ],
      createHandler: (item) async {
        throw const PermissionFailure(
          '403 Forbidden: Only System Manager can create items.',
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Добавить позицию'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название позиции'),
      'Стул',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('шт').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(FilledButton, 'Добавить позицию'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('403 Forbidden: Only System Manager can create items.'),
      findsOneWidget,
    );
  });

  testWidgets('updates item price via set price dialog', (tester) async {
    String? targetCode;
    double? targetPrice;

    final repo = _FakeItemsRepository(
      listHandler: (_, _) async => const [
        Item(
          code: 'CAB-01',
          name: 'Шкаф распашной',
          unit: 'Nos',
        ),
      ],
      setPriceHandler: (code, price) async {
        targetCode = code;
        targetPrice = price;
        return Item(
          code: code,
          name: 'Шкаф распашной',
          unit: 'Nos',
          salePrice: price,
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Цена по расчёту'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Изменить цену'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Шкаф распашной'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      '180000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Установить цену'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(targetCode, 'CAB-01');
    expect(targetPrice, 180000);
    expect(find.text('Цена обновлена'), findsOneWidget);
  });

  testWidgets('displays error view on failure and retries', (tester) async {
    var fail = true;
    final repo = _FakeItemsRepository(
      listHandler: (_, _) async {
        if (fail) throw const NetworkFailure('No connection');
        return const [
          Item(code: 'IT-1', name: 'Стол', unit: 'Nos'),
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

    expect(find.text('Стол'), findsOneWidget);
  });
}
