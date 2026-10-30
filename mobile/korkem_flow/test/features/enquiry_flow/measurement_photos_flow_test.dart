import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';
import 'package:korkem_flow/features/enquiry_flow/application/image_picker_service.dart';
import 'package:korkem_flow/features/enquiry_flow/data/enquiry_flow_repository.dart';
import 'package:korkem_flow/features/enquiry_flow/data/measurement_photo_repository.dart';
import 'package:korkem_flow/features/enquiry_flow/domain/enquiry_flow_models.dart';
import 'package:korkem_flow/features/enquiry_flow/presentation/enquiry_flow_screen.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeImagePickerService implements ImagePickerService {
  _FakeImagePickerService({
    this.cameraPhoto,
    this.galleryPhotos = const [],
    this.throwPermissionError = false,
  });

  final XFile? cameraPhoto;
  final List<XFile> galleryPhotos;
  final bool throwPermissionError;

  @override
  Future<XFile?> pickImageFromCamera() async {
    if (throwPermissionError) {
      throw const ImagePickerPermissionException('Camera access denied');
    }
    return cameraPhoto;
  }

  @override
  Future<List<XFile>> pickMultiImage() async {
    if (throwPermissionError) {
      throw const ImagePickerPermissionException('Gallery access denied');
    }
    return galleryPhotos;
  }
}

class _FakeEnquiryFlowRepository extends EnquiryFlowRepository {
  _FakeEnquiryFlowRepository({
    required this.captures,
  }) : super(dummyClient, dummyDio);

  static final dummyDio = Dio();
  static final dummyClient = FrappeClient(dummyDio);

  final List<CaptureSummary> captures;
  List<String>? recordedPhotos;

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
  ) async => null;

  @override
  Future<Map<String, dynamic>?> fetchQuotationForEnquiry(
    String enquiryId,
  ) async => null;

  @override
  Future<Map<String, dynamic>?> fetchOrderForQuotation(
    String quotationId,
  ) async => null;

  @override
  Future<MeasurementResult> recordMeasurement({
    required String enquiry,
    String? dimensions,
    String? notes,
    String? addressLine,
    String? city,
    String? measuredOn,
    List<String> photos = const [],
  }) async {
    recordedPhotos = photos;
    return MeasurementResult(
      enquiry: enquiry,
      dimensions: dimensions,
      notes: notes,
      measuredOn: measuredOn ?? '2026-09-03',
      photos: photos,
    );
  }
}

/// Сервер, который сохраняет снимок и возвращает своё имя для него.
class _FakeMeasurementPhotoRepository implements MeasurementPhotoRepository {
  final attached = <String>[];

  @override
  FrappeClient get client => throw UnimplementedError();

  @override
  Future<List<String>> attach(String enquiry, List<XFile> photos) async {
    final names = [
      for (final photo in photos) 'замер-${photo.name}',
    ];
    attached.addAll(names);
    return names;
  }
}

void main() {
  final photoRepository = _FakeMeasurementPhotoRepository();

  Widget buildHarness(
    WidgetTester tester, {
    required EnquiryFlowRepository repository,
    required ImagePickerService pickerService,
  }) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        enquiryFlowRepositoryProvider.overrideWithValue(repository),
        imagePickerServiceProvider.overrideWithValue(pickerService),
        // Отправка снимков — сеть. Здесь проверяется экран, поэтому сервер
        // подменён: он возвращает то имя, под которым сохранил бы файл.
        measurementPhotoRepositoryProvider.overrideWithValue(photoRepository),
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
        home: const EnquiryFlowScreen(initialCaptureId: 'CAP-001'),
      ),
    );
  }

  testWidgets(
    'attaches photos from camera and gallery, allows removal '
    'and submits with measurement',
    (tester) async {
      final transparentPng = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      const capture = CaptureSummary(
        id: 'CAP-001',
        spokenText: 'Замер стены и розеток',
        customerHint: 'Айгуль',
        status: 'Converted',
        enquiry: 'OPP-001',
      );

      final repo = _FakeEnquiryFlowRepository(captures: [capture]);
      final picker = _FakeImagePickerService(
        cameraPhoto: XFile.fromData(
          transparentPng,
          name: 'socket_wall.jpg',
          path: 'socket_wall.jpg',
        ),
        galleryPhotos: [
          XFile.fromData(
            transparentPng,
            name: 'pipes.jpg',
            path: 'pipes.jpg',
          ),
        ],
      );

      await tester.pumpWidget(
        buildHarness(tester, repository: repo, pickerService: picker),
      );
      await tester.pumpAndSettle();

      expect(find.text('Фотографии и референсы'), findsOneWidget);
      expect(find.text('Сделать фото'), findsOneWidget);
      expect(find.text('Из галереи'), findsOneWidget);

      // 1. Take photo with camera
      await tester.tap(find.text('Сделать фото'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(StatusChip, '1'), findsOneWidget);

      // 2. Pick from gallery
      await tester.tap(find.text('Из галереи'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(StatusChip, '2'), findsOneWidget);

      // 3. Remove one photo
      final removeButtons = find.byIcon(AppIcons.close);
      await tester.tap(removeButtons.last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(StatusChip, '1'), findsOneWidget);

      // 4. Fill in dimensions & submit
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Размеры помещения / изделия'),
        '3000x2500',
      );

      await tester.tap(find.text('Записать результат замера'));
      await tester.pumpAndSettle();

      expect(repo.recordedPhotos, isNotNull);
      expect(repo.recordedPhotos!.length, 1);
      // Имя приходит от сервера, а не с телефона: тот пишет в имя что угодно,
      // и сервер файл переименовывает.
      expect(repo.recordedPhotos, contains('замер-socket_wall.jpg'));
    },
  );

  testWidgets(
    'shows helpful permission denied message when camera/gallery permission is refused',
    (tester) async {
      const capture = CaptureSummary(
        id: 'CAP-001',
        spokenText: 'Замер стены и розеток',
        customerHint: 'Айгуль',
        status: 'Converted',
        enquiry: 'OPP-001',
      );

      final repo = _FakeEnquiryFlowRepository(captures: [capture]);
      final picker = _FakeImagePickerService(throwPermissionError: true);

      await tester.pumpWidget(
        buildHarness(tester, repository: repo, pickerService: picker),
      );
      await tester.pumpAndSettle();

      // Tap camera
      await tester.tap(find.text('Сделать фото'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Доступ к камере или галерее не предоставлен'),
        findsOneWidget,
      );
    },
  );
}
