import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';

final productionCommandRepositoryProvider =
    Provider<ProductionCommandRepository>(
      (ref) => ProductionCommandRepository(
        ref.watch(frappeClientProvider),
        ref.watch(mutationOutboxProvider),
      ),
    );

/// Starting production, without a language model in the path.
///
/// Separate from `WorkOrderRepository`, which is read-only by design and says
/// so. This one changes the factory, and until Horizon 1 it could not exist:
/// the only way to start a job was `korkem_ai.korkem_ai.chat.send`, so a button
/// would have cost a model turn and a provider outage stopped the shop floor.
///
/// It calls `korkem_manufacturing.api.production.start_production` — the same
/// function the assistant's tool is registered against, asserted by a backend
/// test rather than left to review.
///
/// Nothing here decides anything. The company comes from the session, the
/// permission check is the endpoint's, and material readiness is re-read on the
/// server at the moment of execution. A client that computed any of that would
/// be a second opinion, and two opinions about whether there is board on the
/// shelf is one too many (ADR-0007).
class ProductionCommandRepository {
  ProductionCommandRepository(this._client, [MutationOutbox? outbox])
    : _outbox = outbox ?? MutationOutbox();

  static const startPath =
      'korkem_manufacturing.api.production.start_production';

  final FrappeClient _client;
  final MutationOutbox _outbox;

  static const completeOperationPath =
      'korkem_manufacturing.api.production.complete_operation';

  /// Plans the work if needed, then moves material into work-in-progress.
  ///
  /// Refusals are outcomes, not exceptions: `StartProductionResult.blocked`
  /// carries the material list a person needs in order to do something about
  /// it. Only a genuine failure — no permission, no such order, no network —
  /// throws.
  Future<StartProductionResult> start(
    String salesOrder, {
    String? itemCode,
  }) async {
    final response = await _outbox.execute(
      _client,
      startPath,
      // POST, because this moves stock. `callMethod` defaults to GET, which is
      // right for a read and wrong for anything a browser or a proxy may
      // retry, prefetch or cache.
      params: {
        'sales_order': salesOrder,
        'item_code': ?itemCode,
      },
    );
    return StartProductionResult.fromJson(response['message'] ?? response);
  }

  /// Books a finished stage: how many came out good, spoiled, or need fixing.
  ///
  /// The three quantities are kept apart all the way down because ERPNext keeps
  /// them apart: good output excludes process loss, and folding scrap into
  /// [qty] would let spoiled panels become finished goods. Omit [qty] and
  /// everything still outstanding is taken.
  Future<CompleteOperationResult> completeOperation({
    String? operation,
    String? salesOrder,
    String? workOrder,
    double? qty,
    double? scrapQty,
    double? reworkQty,
  }) async {
    final response = await _outbox.execute(
      _client,
      completeOperationPath,
      params: {
        'operation': ?operation,
        'sales_order': ?salesOrder,
        'work_order': ?workOrder,
        'qty': ?qty,
        'scrap_qty': ?scrapQty,
        'rework_qty': ?reworkQty,
      },
    );
    return CompleteOperationResult.fromJson(response['message'] ?? response);
  }
}

/// What booking a stage produced. Read from the server, never recomputed.
class CompleteOperationResult {
  const CompleteOperationResult({
    required this.status,
    this.jobCard,
    this.operation,
    this.workOrder,
    this.message,
  });

  factory CompleteOperationResult.fromJson(Object? raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return CompleteOperationResult(
      status: StartProductionResult._text(json['status']) ?? 'unknown',
      jobCard: StartProductionResult._text(json['job_card']),
      operation: StartProductionResult._text(json['operation']),
      workOrder: StartProductionResult._text(json['work_order']),
      message: StartProductionResult._text(json['message']),
    );
  }

  final String status;
  final String? jobCard;
  final String? operation;
  final String? workOrder;
  final String? message;

  /// Saying it twice must not book the hours twice — and the person who said
  /// it needs to know which of the two happened.
  bool get alreadyComplete => status == 'already_complete';
}

/// What the server answered. Every field comes from ERPNext; none is derived
/// here.
class StartProductionResult {
  const StartProductionResult({
    required this.status,
    this.workOrder,
    this.transferredForQty,
    this.toppedUp = false,
    this.blockingMaterials = const [],
    this.message,
  });

  factory StartProductionResult.fromJson(Object? raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return StartProductionResult(
      status: _text(json['status']) ?? 'unknown',
      workOrder: _text(json['work_order']),
      transferredForQty: _number(json['transferred_for_qty']),
      toppedUp: json['topped_up'] == true,
      blockingMaterials: _materials(json['blocking_materials']),
      message: _text(json['message']),
    );
  }

  /// `started` · `blocked` · `already_started` · `nothing_to_start`.
  final String status;
  final String? workOrder;
  final double? transferredForQty;

  /// True when this moved the *next* batch into a job that was already
  /// running, rather than starting a fresh one. Reported so the screen can say
  /// "материал подан" instead of "производство запущено", which would be wrong.
  final bool toppedUp;

  final List<BlockingMaterial> blockingMaterials;
  final String? message;

  bool get started => status == 'started';
  bool get blocked => status == 'blocked';

  static List<BlockingMaterial> _materials(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(BlockingMaterial.fromJson)
        .toList(growable: false);
  }

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// One material the shelf does not hold enough of.
class BlockingMaterial {
  const BlockingMaterial({
    required this.itemCode,
    required this.shortageQty,
    this.uom,
  });

  factory BlockingMaterial.fromJson(Map<String, dynamic> json) =>
      BlockingMaterial(
        itemCode: StartProductionResult._text(json['item_code']) ?? '',
        shortageQty:
            StartProductionResult._number(json['physical_shortage_qty']) ?? 0,
        uom: StartProductionResult._text(json['uom']),
      );

  final String itemCode;
  final double shortageQty;
  final String? uom;
}
