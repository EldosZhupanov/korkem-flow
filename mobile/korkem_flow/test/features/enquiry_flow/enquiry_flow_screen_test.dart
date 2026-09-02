import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/features/enquiry_flow/data/enquiry_flow_repository.dart';
import 'package:korkem_flow/features/enquiry_flow/domain/enquiry_flow_models.dart';
import 'package:korkem_flow/features/enquiry_flow/presentation/enquiry_flow_screen.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeEnquiryFlowRepository extends EnquiryFlowRepository {
  _FakeEnquiryFlowRepository({
    required this.captures,
    this.convertHandler,
  }) : super(dummyClient, dummyDio);

  static final dummyDio = Dio();
  static final dummyClient = FrappeClient(dummyDio);

  final List<CaptureSummary> captures;
  final Map<String, Map<String, dynamic>> quotations = {};
  final Map<String, Map<String, dynamic>> orders = {};
  final Map<String, MeasurementResult> measurements = {};

  final Future<ConvertResult> Function(
    String capture,
    String? customer,
    String? customerName,
    String? assignMeasurer,
    String? measureOn,
  )?
  convertHandler;

  @override
  Future<List<CaptureSummary>> fetchRecentCaptures({int limit = 20}) async =>
      captures;

  @override
  Future<CaptureSummary> fetchCapture(String id) async =>
      captures.firstWhere((c) => c.id == id);

  @override
  Future<Map<String, dynamic>> fetchEnquiry(String id) async => {
    'name': id,
    'party_name': 'Айгуль',
    'status': 'Open',
  };

  @override
  Future<MeasurementResult?> fetchMeasurementForEnquiry(
    String enquiryId,
  ) async => measurements[enquiryId];

  @override
  Future<Map<String, dynamic>?> fetchQuotationForEnquiry(
    String enquiryId,
  ) async => quotations[enquiryId];

  @override
  Future<Map<String, dynamic>?> fetchOrderForQuotation(
    String quotationId,
  ) async => orders[quotationId];

  @override
  Future<ConvertResult> convertCapture({
    required String capture,
    String? customer,
    String? customerName,
    String? assignMeasurer,
    String? measureOn,
  }) async {
    if (convertHandler != null) {
      return convertHandler!(
        capture,
        customer,
        customerName,
        assignMeasurer,
        measureOn,
      );
    }
    final idx = captures.indexWhere((c) => c.id == capture);
    if (idx != -1) {
      captures[idx] = CaptureSummary(
        id: capture,
        spokenText: captures[idx].spokenText,
        customerHint: customerName ?? captures[idx].customerHint,
        status: 'Converted',
        enquiry: 'OPP-001',
      );
    }
    return ConvertResult(
      capture: capture,
      customer: customer ?? 'CUST-001',
      customerCreated: true,
      enquiry: 'OPP-001',
    );
  }

  @override
  Future<MeasurementResult> recordMeasurement({
    required String enquiry,
    String? dimensions,
    String? notes,
    String? addressLine,
    String? city,
    String? measuredOn,
  }) async {
    final res = MeasurementResult(
      enquiry: enquiry,
      dimensions: dimensions,
      notes: notes,
      measuredOn: measuredOn ?? '2026-09-03',
    );
    measurements[enquiry] = res;
    return res;
  }

  @override
  Future<ProposalResult> draftProposal({
    required String enquiry,
    required List<ProposalItem> items,
    int validDays = 14,
  }) async {
    quotations[enquiry] = {
      'name': 'SAL-QTN-2026-0001',
      'status': 'Draft',
      'valid_till': '2026-09-17',
      'grand_total': 450000,
    };
    return ProposalResult(
      quotation: 'SAL-QTN-2026-0001',
      status: 'drafted',
      itemsCount: items.length,
      customer: 'Айгуль',
      validTill: '2026-09-17',
      items: items,
    );
  }

  @override
  Future<OrderAcceptResult> acceptQuotation({
    required String quotation,
    required String deliverOn,
  }) async {
    orders[quotation] = {
      'parent': 'SAL-ORD-2026-0001',
      'delivery_date': deliverOn,
    };
    return OrderAcceptResult(
      quotation: quotation,
      salesOrder: 'SAL-ORD-2026-0001',
      status: 'accepted',
      total: 450000,
      deliverOn: deliverOn,
    );
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required EnquiryFlowRepository repository,
    String? initialCaptureId,
  }) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        enquiryFlowRepositoryProvider.overrideWithValue(repository),
        teamMembersProvider.overrideWith(
          (ref) async => const [
            TeamMember(
              email: 'measurer@korkem.kz',
              firstName: 'Кайрат',
              fullName: 'Кайрат Замерщик',
              position: EmployeePosition.shopFloor,
              roles: ['Stock User'],
              enabled: true,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EnquiryFlowScreen(initialCaptureId: initialCaptureId),
      ),
    );
  }

  testWidgets('renders 4 pipeline steps and converts capture on step 1', (
    tester,
  ) async {
    const capture = CaptureSummary(
      id: 'CAP-001',
      spokenText: 'Нужна кухня 3 метра белая',
      customerHint: 'Айгуль',
      productHint: 'Кухня',
      status: 'Recorded',
    );

    final repo = _FakeEnquiryFlowRepository(captures: [capture]);

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Проводка заявки'), findsOneWidget);
    expect(find.text('Заявка'), findsWidgets);
    expect(find.text('Замер'), findsWidgets);
    expect(find.text('КП'), findsWidgets);
    expect(find.text('Заказ'), findsWidgets);

    expect(find.text('«Нужна кухня 3 метра белая»'), findsOneWidget);
    expect(find.text('Создать заявку'), findsOneWidget);

    await tester.tap(find.text('Создать заявку'));
    await tester.pumpAndSettle();

    expect(find.text('Записать результат замера'), findsOneWidget);
  });

  testWidgets('handles ambiguous customer by rendering candidate selection', (
    tester,
  ) async {
    const capture = CaptureSummary(
      id: 'CAP-001',
      spokenText: 'Нужна кухня для Айгуль',
      customerHint: 'Айгуль',
      status: 'Recorded',
    );

    var convertCalls = 0;
    String? selectedCustomer;

    final repo = _FakeEnquiryFlowRepository(
      captures: [capture],
      convertHandler: (cap, cust, name, measurer, date) async {
        convertCalls++;
        if (cust == null) {
          throw const AmbiguousCustomerException(
            message: 'More than one customer matches «Айгуль»',
            candidates: [
              CustomerCandidate(
                name: 'CUST-001',
                customerName: 'Айгуль Серикова',
                mobileNo: '+77011112233',
              ),
              CustomerCandidate(
                name: 'CUST-002',
                customerName: 'Айгуль Мухтарова',
                mobileNo: '+77023334455',
              ),
            ],
          );
        }
        selectedCustomer = cust;
        return ConvertResult(
          capture: cap,
          customer: cust,
          customerCreated: false,
          enquiry: 'OPP-001',
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    // Tap convert
    await tester.tap(find.text('Создать заявку'));
    await tester.pumpAndSettle();

    expect(find.text('Найдено несколько похожих клиентов'), findsOneWidget);
    expect(find.text('Айгуль Серикова'), findsOneWidget);
    expect(find.text('Айгуль Мухтарова'), findsOneWidget);

    // Tap the first candidate
    await tester.tap(find.text('Айгуль Серикова'));
    await tester.pumpAndSettle();

    expect(convertCalls, 2);
    expect(selectedCustomer, 'CUST-001');
  });

  testWidgets('records measurement on step 2 and drafts proposal on step 3', (
    tester,
  ) async {
    const capture = CaptureSummary(
      id: 'CAP-001',
      spokenText: 'Кухня 3.2 метра',
      customerHint: 'Айгуль',
      status: 'Converted',
      enquiry: 'OPP-001',
    );

    final repo = _FakeEnquiryFlowRepository(captures: [capture]);

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    // On Step 2: enter dimensions and notes
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Размеры помещения / изделия'),
      '3200x600, h=2100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Примечания и материалы'),
      'МДФ белый глянец',
    );

    await tester.tap(find.text('Записать результат замера'));
    await tester.pumpAndSettle();

    // Now on Step 3: Proposal
    expect(find.text('Создать черновик КП'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Наименование позиции'),
      'Кухонный гарнитур 3.2м',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Цена за единицу (₸)'),
      '450000',
    );

    await tester.tap(find.text('Создать черновик КП'));
    await tester.pumpAndSettle();

    // Now on Step 4: Order
    expect(find.text('Принять и создать заказ'), findsOneWidget);

    // Pick delivery date and submit
    await tester.tap(find.text('Выбрать дату'));
    await tester.pumpAndSettle();
    // Material DatePicker confirm button in Russian locale is Cyrillic 'ОК'
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Принять и создать заказ'));
    await tester.pumpAndSettle();

    expect(find.text('Заказ передан в производство'), findsOneWidget);
    expect(find.text('Перейти к заказу'), findsOneWidget);
  });

  testWidgets('shows empty state when no captures exist', (tester) async {
    final repo = _FakeEnquiryFlowRepository(captures: []);

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Нет доступных обращений'), findsOneWidget);
  });
}
