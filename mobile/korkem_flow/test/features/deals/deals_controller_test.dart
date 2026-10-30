import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/pagination/paged_list_controller.dart';
import 'package:korkem_flow/features/deals/application/deals_controller.dart';
import 'package:korkem_flow/features/deals/data/deal_repository.dart';
import 'package:korkem_flow/features/deals/domain/deal.dart';
import 'package:mocktail/mocktail.dart';

class _MockDealRepository extends Mock implements DealRepository {}

Deal _deal(String id, {String status = 'Qualification'}) =>
    Deal(id: id, organization: 'Org $id', status: status);

List<Deal> _page(int count, {int from = 0}) =>
    List.generate(count, (i) => _deal('D${from + i}'));

void main() {
  late _MockDealRepository repository;

  setUpAll(() {
    registerFallbackValue('Qualification');
  });

  setUp(() {
    repository = _MockDealRepository();
  });

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [dealRepositoryProvider.overrideWithValue(repository)],
      // Riverpod 3 auto-retries a failed provider with backoff. Left on, a
      // failing provider sits in AsyncLoading(retrying) and never settles into
      // AsyncError, so error assertions would hang. Returning null disables it.
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  group('initial load', () {
    test(
      'exposes the first page and flags more when the page is full',
      () async {
        when(
          () => repository.fetchPage(
            pageSize: any(named: 'pageSize'),
            status: any(named: 'status'),
            search: any(named: 'search'),
          ),
        ).thenAnswer((_) async => _page(20));

        final container = containerWith();
        final state = await container.read(dealsControllerProvider.future);

        expect(state.items, hasLength(20));
        expect(state.hasMore, isTrue);
      },
    );

    test('flags no more when a short page comes back', () async {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => _page(3));

      final container = containerWith();
      final state = await container.read(dealsControllerProvider.future);

      expect(state.hasMore, isFalse);
    });

    test('surfaces a repository failure as an error state', () async {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenThrow(const NetworkFailure('offline'));

      final container = containerWith();
      // Subscribe before awaiting: an unlistened provider can be disposed
      // mid-load, which masks the real failure as a StateError.
      final seen = <AsyncValue<PagedList<Deal>>>[];
      container.listen(
        dealsControllerProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );

      await pumpEventQueue();

      final state = container.read(dealsControllerProvider);
      expect(state, isA<AsyncError<PagedList<Deal>>>());
      expect(
        (state as AsyncError<PagedList<Deal>>).error,
        isA<NetworkFailure>(),
      );
      expect(seen.first, isA<AsyncLoading<PagedList<Deal>>>());
    });
  });

  group('pagination', () {
    test('loadMore appends without duplicating the first page', () async {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => _page(20));
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          offset: 20,
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => _page(20, from: 20));

      final container = containerWith();
      await container.read(dealsControllerProvider.future);
      await container.read(dealsControllerProvider.notifier).loadMore();

      final state = container.read(dealsControllerProvider).value!;
      expect(state.items, hasLength(40));
      expect(state.items.map((d) => d.id).toSet(), hasLength(40));
    });

    test('loadMore is a no-op once the list is exhausted', () async {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          offset: any(named: 'offset'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => _page(2));

      final container = containerWith();
      await container.read(dealsControllerProvider.future);
      final notifier = container.read(dealsControllerProvider.notifier);

      await notifier.loadMore();
      await notifier.loadMore();

      // Only the initial fetch should have happened.
      verify(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).called(1);
    });
  });

  group('optimistic status change', () {
    setUp(() {
      when(
        () => repository.fetchPage(
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => [_deal('D0'), _deal('D1')]);
    });

    test('applies the new status immediately', () async {
      when(
        () => repository.updateStatus(any(), any()),
      ).thenAnswer((_) async {});

      final container = containerWith();
      await container.read(dealsControllerProvider.future);
      final notifier = container.read(dealsControllerProvider.notifier);
      final target = container.read(dealsControllerProvider).value!.items.first;

      await notifier.changeStatus(target, 'Won');

      final updated = container
          .read(dealsControllerProvider)
          .value!
          .items
          .first;
      expect(updated.status, 'Won');
    });

    test('rolls back when the backend rejects the change', () async {
      when(
        () => repository.updateStatus(any(), any()),
      ).thenThrow(const PermissionFailure('not allowed'));

      final container = containerWith();
      await container.read(dealsControllerProvider.future);
      final notifier = container.read(dealsControllerProvider.notifier);
      final target = container.read(dealsControllerProvider).value!.items.first;

      await expectLater(
        notifier.changeStatus(target, 'Won'),
        throwsA(isA<PermissionFailure>()),
      );

      // The UI must not keep showing a change the server refused.
      final after = container.read(dealsControllerProvider).value!.items.first;
      expect(after.status, 'Qualification');
    });
  });
}
