import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/company_details/data/company_details_repository.dart';
import 'package:korkem_flow/features/company_details/domain/company_details.dart';
import 'package:korkem_flow/features/company_details/presentation/company_details_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeCompanyDetailsRepository extends CompanyDetailsRepository {
  _FakeCompanyDetailsRepository({
    required this.fetchHandler,
    this.saveHandler,
  }) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());

  final Future<CompanyDetails> Function() fetchHandler;
  final Future<CompanyDetails> Function(CompanyDetails details)? saveHandler;

  @override
  Future<CompanyDetails> fetch() => fetchHandler();

  @override
  Future<CompanyDetails> save(CompanyDetails details) {
    if (saveHandler != null) {
      return saveHandler!(details);
    }
    return Future.value(details);
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required CompanyDetailsRepository repository,
  }) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        companyDetailsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CompanyDetailsScreen(),
      ),
    );
  }

  testWidgets('renders loaded company details in form fields', (tester) async {
    final repo = _FakeCompanyDetailsRepository(
      fetchHandler: () async => const CompanyDetails(
        company: 'eldos (Demo)',
        name: 'ТОО Фабрика Көркем',
        bin: '123456789012',
        city: 'г. Шымкент',
        address: 'пр. Республики, 25',
        phone: '+7 701 555 0199',
        email: 'sales@korkem-mebel.kz',
        website: 'https://korkem-mebel.kz',
        bankName: 'АО Halyk Bank',
        bankAccount: 'KZ123456789012345678',
        bik: 'HLBKKZKZ',
      ),
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Реквизиты компании'), findsOneWidget);
    expect(find.text('ТОО Фабрика Көркем'), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);
    expect(find.text('г. Шымкент'), findsOneWidget);
    expect(find.text('пр. Республики, 25'), findsOneWidget);
    expect(find.text('+7 701 555 0199'), findsOneWidget);
    expect(find.text('sales@korkem-mebel.kz'), findsOneWidget);
    expect(find.text('https://korkem-mebel.kz'), findsOneWidget);
    expect(find.text('АО Halyk Bank'), findsOneWidget);
    expect(find.text('KZ123456789012345678'), findsOneWidget);
    expect(find.text('HLBKKZKZ'), findsOneWidget);
    expect(
      find.text(
        'Название компании задаётся при создании и меняется в профиле компании',
      ),
      findsOneWidget,
    );
  });

  testWidgets('rejects invalid BIN with less than 12 digits or non-digits', (
    tester,
  ) async {
    final repo = _FakeCompanyDetailsRepository(
      fetchHandler: () async => const CompanyDetails(),
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    // Enter invalid short BIN
    await tester.enterText(
      find.widgetWithText(TextFormField, 'БИН'),
      '12345',
    );

    await tester.tap(find.text('Сохранить реквизиты'));
    await tester.pumpAndSettle();

    expect(
      find.text('БИН должен содержать ровно 12 цифр'),
      findsOneWidget,
    );

    // Enter non-digit characters
    await tester.enterText(
      find.widgetWithText(TextFormField, 'БИН'),
      '12345678901A',
    );

    await tester.tap(find.text('Сохранить реквизиты'));
    await tester.pumpAndSettle();

    expect(
      find.text('БИН должен содержать ровно 12 цифр'),
      findsOneWidget,
    );
  });

  testWidgets('rejects invalid Kazakhstan IBAN', (tester) async {
    final repo = _FakeCompanyDetailsRepository(
      fetchHandler: () async => const CompanyDetails(),
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    // Enter IBAN that does not start with KZ
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Расчётный счёт (IBAN)'),
      'RU123456789012345678',
    );

    await tester.tap(find.text('Сохранить реквизиты'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'IBAN Казахстана должен начинаться с KZ и содержать 20 символов',
      ),
      findsOneWidget,
    );

    // Enter IBAN with incorrect length
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Расчётный счёт (IBAN)'),
      'KZ12345',
    );

    await tester.tap(find.text('Сохранить реквизиты'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'IBAN Казахстана должен начинаться с KZ и содержать 20 символов',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'saving incomplete form succeeds when blank fields are omitted',
    (tester) async {
      CompanyDetails? savedPayload;

      final repo = _FakeCompanyDetailsRepository(
        fetchHandler: () async => const CompanyDetails(),
        saveHandler: (details) async {
          savedPayload = details;
          return details;
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // Only fill city and phone, leave BIN, bank, etc. blank
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Город'),
        'г. Шымкент',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Телефон'),
        '+7 701 555 0199',
      );

      await tester.tap(find.text('Сохранить реквизиты'));
      await tester.pumpAndSettle();

      // Validation passes, save is invoked, success SnackBar is shown
      expect(savedPayload, isNotNull);
      expect(savedPayload!.city, 'г. Шымкент');
      expect(savedPayload!.phone, '+7 701 555 0199');
      expect(savedPayload!.bin, isEmpty);
      expect(savedPayload!.bankAccount, isEmpty);

      expect(find.text('Реквизиты успешно сохранены'), findsOneWidget);
    },
  );

  testWidgets('displays error state on network failure and retries', (
    tester,
  ) async {
    var fail = true;
    final repo = _FakeCompanyDetailsRepository(
      fetchHandler: () async {
        if (fail) throw const NetworkFailure('Connection failed');
        return const CompanyDetails(name: 'ТОО Фабрика Көркем');
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Нет связи с сервером.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('ТОО Фабрика Көркем'), findsOneWidget);
  });

  testWidgets('displays exact server refusal message when save fails', (
    tester,
  ) async {
    final repo = _FakeCompanyDetailsRepository(
      fetchHandler: () async => const CompanyDetails(),
      saveHandler: (details) async {
        throw const ValidationFailure(
          'БИН — это 12 цифр. Неверный БИН в договоре означает '
          'переподписание, а не опечатку.',
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'БИН'),
      '123456789012',
    );

    await tester.tap(find.text('Сохранить реквизиты'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'БИН — это 12 цифр. Неверный БИН в договоре означает '
        'переподписание, а не опечатку.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('displays permission refusal when non-owner saves', (
    tester,
  ) async {
    final repo = _FakeCompanyDetailsRepository(
      fetchHandler: () async => const CompanyDetails(),
      saveHandler: (details) async {
        throw const PermissionFailure(
          '403 Forbidden: Only System Manager can change company '
          'details.',
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'БИН'),
      '123456789012',
    );

    await tester.tap(find.text('Сохранить реквизиты'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '403 Forbidden: Only System Manager can change company '
        'details.',
      ),
      findsOneWidget,
    );
  });
}
