import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/features/enquiry_flow/data/enquiry_flow_repository.dart';
import 'package:korkem_flow/features/enquiry_flow/data/measurement_photo_repository.dart';
import 'package:korkem_flow/features/enquiry_flow/domain/enquiry_flow_models.dart';

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final recentCapturesProvider = FutureProvider.autoDispose<List<CaptureSummary>>(
  (ref) async {
    final repo = ref.watch(enquiryFlowRepositoryProvider);
    return repo.fetchRecentCaptures();
  },
);

/// The assembled state of one customer request as it moves through
/// the pipeline.
@immutable
class EnquiryFlowPipelineData {
  const EnquiryFlowPipelineData({
    required this.capture,
    required this.currentStep,
    this.customer,
    this.enquiryId,
    this.enquiryDoc,
    this.measurement,
    this.quotation,
    this.order,
  });

  final CaptureSummary capture;
  final EnquiryFlowStep currentStep;
  final String? customer;
  final String? enquiryId;
  final Map<String, dynamic>? enquiryDoc;
  final MeasurementResult? measurement;
  final ProposalResult? quotation;
  final OrderAcceptResult? order;

  bool get isEnquiryCreated => enquiryId != null && enquiryId!.isNotEmpty;
  bool get isMeasured => measurement != null;
  bool get isQuotationDrafted => quotation != null;
  bool get isOrderAccepted => order != null;
}

// AutoDisposeFutureProvider is not exported as a public type.
// ignore: specify_nonobvious_property_types
final enquiryPipelineProvider = FutureProvider.autoDispose
    .family<EnquiryFlowPipelineData, String>((ref, captureId) async {
      final repo = ref.watch(enquiryFlowRepositoryProvider);
      final capture = await repo.fetchCapture(captureId);

      final enquiryId = capture.enquiry;
      Map<String, dynamic>? enquiryDoc;
      var customer = capture.customerHint;
      MeasurementResult? measurement;
      ProposalResult? quotation;
      OrderAcceptResult? order;

      if (enquiryId != null && enquiryId.isNotEmpty) {
        try {
          enquiryDoc = await repo.fetchEnquiry(enquiryId);
          customer = '${enquiryDoc['party_name'] ?? customer ?? ''}';

          // Check if measurement comment/result is already recorded on enquiry
          measurement = await repo.fetchMeasurementForEnquiry(enquiryId);

          final quoteRow = await repo.fetchQuotationForEnquiry(enquiryId);
          if (quoteRow != null) {
            final quoteName = '${quoteRow['name']}';
            quotation = ProposalResult(
              quotation: quoteName,
              status: '${quoteRow['status'] ?? 'drafted'}',
              itemsCount: 1,
              customer: customer,
              validTill: quoteRow['valid_till'] as String?,
            );

            final orderRow = await repo.fetchOrderForQuotation(quoteName);
            if (orderRow != null) {
              order = OrderAcceptResult(
                quotation: quoteName,
                salesOrder: '${orderRow['parent']}',
                status: 'accepted',
                total: (quoteRow['grand_total'] is num)
                    ? (quoteRow['grand_total'] as num).toDouble()
                    : 0.0,
                deliverOn: '${orderRow['delivery_date'] ?? ''}',
              );
            }
          }
        } on Object catch (_) {
          // If fetching sub-documents fails gracefully fallback to capture data
        }
      }

      // Determine current active step
      final EnquiryFlowStep currentStep;
      if (order != null) {
        currentStep = EnquiryFlowStep.order;
      } else if (quotation != null) {
        currentStep = EnquiryFlowStep.order;
      } else if (measurement != null) {
        currentStep = EnquiryFlowStep.proposal;
      } else if (enquiryId != null && enquiryId.isNotEmpty) {
        currentStep = EnquiryFlowStep.measurement;
      } else {
        currentStep = EnquiryFlowStep.enquiry;
      }

      return EnquiryFlowPipelineData(
        capture: capture,
        currentStep: currentStep,
        customer: customer,
        enquiryId: enquiryId,
        enquiryDoc: enquiryDoc,
        measurement: measurement,
        quotation: quotation,
        order: order,
      );
    });

final enquiryFlowActionsProvider = Provider<EnquiryFlowActionsController>((
  ref,
) {
  return EnquiryFlowActionsController(ref);
});

class EnquiryFlowActionsController {
  EnquiryFlowActionsController(this._ref);

  final Ref _ref;

  Future<ConvertResult> convert({
    required String captureId,
    String? customer,
    String? customerName,
    String? assignMeasurer,
    String? measureOn,
  }) async {
    final repo = _ref.read(enquiryFlowRepositoryProvider);
    final result = await repo.convertCapture(
      capture: captureId,
      customer: customer,
      customerName: customerName,
      assignMeasurer: assignMeasurer,
      measureOn: measureOn,
    );
    _ref
      ..invalidate(enquiryPipelineProvider(captureId))
      ..invalidate(recentCapturesProvider);
    return result;
  }

  Future<MeasurementResult> recordMeasurement({
    required String captureId,
    required String enquiry,
    String? dimensions,
    String? notes,
    String? addressLine,
    String? city,
    String? measuredOn,
    List<XFile> photos = const [],
  }) async {
    final repo = _ref.read(enquiryFlowRepositoryProvider);
    final photoRepo = _ref.read(measurementPhotoRepositoryProvider);

    final attachedNames = photos.isNotEmpty
        ? await photoRepo.attach(enquiry, photos)
        : const <String>[];

    final result = await repo.recordMeasurement(
      enquiry: enquiry,
      dimensions: dimensions,
      notes: notes,
      addressLine: addressLine,
      city: city,
      measuredOn: measuredOn,
      photos: attachedNames,
    );
    _ref.invalidate(enquiryPipelineProvider(captureId));
    return result;
  }

  Future<ProposalResult> draftProposal({
    required String captureId,
    required String enquiry,
    required List<ProposalItem> items,
    int validDays = 14,
  }) async {
    final repo = _ref.read(enquiryFlowRepositoryProvider);
    final result = await repo.draftProposal(
      enquiry: enquiry,
      items: items,
      validDays: validDays,
    );
    _ref.invalidate(enquiryPipelineProvider(captureId));
    return result;
  }

  Future<OrderAcceptResult> acceptOrder({
    required String captureId,
    required String quotation,
    required String deliverOn,
  }) async {
    final repo = _ref.read(enquiryFlowRepositoryProvider);
    final result = await repo.acceptQuotation(
      quotation: quotation,
      deliverOn: deliverOn,
    );
    _ref.invalidate(enquiryPipelineProvider(captureId));
    return result;
  }
}
