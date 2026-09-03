import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  Map<String, dynamic> data, {
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(data),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?headers,
  },
);

void main() {
  Dio createDio(Future<ResponseBody> Function(RequestOptions options) handler) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
      ),
    )..httpClientAdapter = _FakeAdapter(handler);
  }

  group('Team domain models', () {
    test('TeamMember serialization and equality', () {
      const member1 = TeamMember(
        email: 'worker@korkem.kz',
        firstName: 'Berik',
        fullName: 'Berik Worker',
        position: EmployeePosition.shopFloor,
        roles: ['Manufacturing User'],
        enabled: true,
      );

      final member2 = member1.copyWith(position: EmployeePosition.manager);
      expect(member2.position, EmployeePosition.manager);
      expect(member2.email, 'worker@korkem.kz');

      final fromJson = TeamMember.fromJson(const {
        'name': 'worker@korkem.kz',
        'email': 'worker@korkem.kz',
        'first_name': 'Berik',
        'full_name': 'Berik Worker',
        'enabled': 1,
        'roles': [
          {'role': 'Manufacturing User'},
        ],
      });

      expect(fromJson, member1);
    });

    test('ChangePositionResult fromJson and equality', () {
      final res1 = ChangePositionResult.fromJson(const {
        'message': {
          'user': 'worker@korkem.kz',
          'position': 'manager',
          'roles': ['Sales Manager'],
          'enabled': true,
        },
      });

      expect(res1.user, 'worker@korkem.kz');
      expect(res1.position, 'manager');
      expect(res1.roles, ['Sales Manager']);
      expect(res1.enabled, isTrue);

      final res2 = ChangePositionResult.fromJson(const {
        'user': 'worker@korkem.kz',
        'position': 'manager',
        'roles': ['Sales Manager'],
        'enabled': true,
      });

      expect(res1, res2);
      expect(res1.hashCode, res2.hashCode);
    });

    test('DeactivateResult fromJson and equality', () {
      final res1 = DeactivateResult.fromJson(const {
        'message': {
          'user': 'worker@korkem.kz',
          'enabled': false,
          'sessions_closed': 2,
          'status': 'disabled',
        },
      });

      expect(res1.user, 'worker@korkem.kz');
      expect(res1.enabled, isFalse);
      expect(res1.sessionsClosed, 2);
      expect(res1.status, 'disabled');

      final res2 = DeactivateResult.fromJson(const {
        'user': 'worker@korkem.kz',
        'enabled': false,
        'sessions_closed': 2,
        'status': 'disabled',
      });

      expect(res1, res2);
      expect(res1.hashCode, res2.hashCode);
    });

    test('ReactivateResult fromJson and equality', () {
      final res1 = ReactivateResult.fromJson(const {
        'message': {
          'user': 'worker@korkem.kz',
          'enabled': true,
          'status': 'enabled',
        },
      });

      expect(res1.user, 'worker@korkem.kz');
      expect(res1.enabled, isTrue);
      expect(res1.status, 'enabled');

      final res2 = ReactivateResult.fromJson(const {
        'user': 'worker@korkem.kz',
        'enabled': true,
        'status': 'enabled',
      });

      expect(res1, res2);
      expect(res1.hashCode, res2.hashCode);
    });
  });

  group('TeamRepository', () {
    test(
      'команду и должности отдаёт сервер, а не выводит приложение',
      () async {
        // Роли клиенту не видны: `Has Role` — детская таблица, и Frappe
        // закрывает её даже от владельца компании. Пока приложение выводило
        // должность из ролей, отказ ловился пустым `catch`, роли приходили
        // пустыми, и владелец видел себя «рабочим цеха» — а кнопки «Пригласить
        // сотрудника» не было вовсе.
        final dio = createDio((options) async {
          expect(
            options.path,
            '/api/method/korkem_manufacturing.api.staff.members',
            reason: 'к таблице ролей приложение больше не ходит',
          );
          return _json({
            'message': [
              {
                'email': 'owner@korkem.kz',
                'full_name': 'Aidos Owner',
                'first_name': 'Aidos',
                'enabled': true,
                'position': 'owner',
                'is_owner': true,
              },
              {
                'email': 'cutter@korkem.kz',
                'full_name': 'Berik Cutter',
                'first_name': 'Berik',
                'enabled': true,
                'position': 'cutter',
                'is_owner': false,
              },
            ],
          });
        });

        final members = await TeamRepository(
          FrappeClient(dio),
        ).fetchTeamMembers();

        expect(members.length, 2);
        expect(members[0].position, EmployeePosition.owner);
        expect(members[0].isOwner, isTrue);
        expect(members[1].position, EmployeePosition.cutter);
        expect(members[1].isOwner, isFalse);
      },
    );

    test('право приглашать — ответ сервера, одним словом', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.staff.can_invite',
        );
        return _json({'message': true});
      });

      expect(await TeamRepository(FrappeClient(dio)).canInvite(), isTrue);
    });

    test('fetches positions from the server endpoint', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.invitations.positions',
        );
        return _json({
          'message': [
            {
              'position': 'accountant',
              'roles': ['Accounts User'],
            },
            {
              'position': 'manager',
              'roles': ['Sales Manager'],
            },
            {
              'position': 'shop_floor',
              'roles': ['Manufacturing User', 'Stock User'],
            },
            {
              'position': 'warehouse',
              'roles': ['Stock User'],
            },
          ],
        });
      });

      final client = FrappeClient(dio);
      final repo = TeamRepository(client);

      final positions = await repo.fetchPositions();
      expect(positions.length, 4);
      expect(positions[0].position, 'accountant');
      expect(positions[0].roles, ['Accounts User']);
      expect(positions[2].position, 'shop_floor');
    });

    test(
      'сломанный список должностей — это отказ, а не пустая форма',
      () async {
        // Должности заданы в коде сервера: пустого списка там не бывает. Если
        // ответ не список, значит сломался ответ, а не кончились должности.
        // Тихая пустота показала бы владельцу форму без единой должности и ни
        // слова о том, почему он не может никого пригласить.
        final dio = createDio((_) async => _json({'message': 'что-то не то'}));
        final repo = TeamRepository(FrappeClient(dio));

        await expectLater(repo.fetchPositions(), throwsA(isA<ServerFailure>()));
      },
    );

    test('invites employee with mapped position payload', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.invitations.invite',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['email'], 'accountant@korkem.kz');
        expect(data['first_name'], 'Saule');
        expect(data['position'], 'accountant');

        return _json({
          'message': {
            'user': 'accountant@korkem.kz',
            'company': 'KORKEM',
            'created': true,
            'roles_added': ['Accounts User'],
            'position': 'accountant',
            'password_set': false,
            'next_step':
                'Set a password for this account in the desk '
                '(User → Set New Password), or configure SMTP '
                "and use Frappe's password reset.",
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = TeamRepository(client);

      final result = await repo.inviteEmployee(
        email: 'accountant@korkem.kz',
        position: EmployeePosition.accountant.id,
        firstName: 'Saule',
      );

      expect(result.user, 'accountant@korkem.kz');
      expect(result.created, isTrue);
      expect(result.position, EmployeePosition.accountant);
      expect(result.rolesAdded, contains('Accounts User'));
      expect(result.passwordSet, isFalse);
      expect(result.nextStep, contains('User → Set New Password'));
    });

    test('throws TeamForbiddenException on permission error', () async {
      final dio = createDio((options) async {
        return _json({
          'exc_type': 'PermissionError',
          '_server_messages': jsonEncode([
            jsonEncode({
              'message':
                  'You cannot change your own roles. Ask the factory owner.',
            }),
          ]),
        }, statusCode: 403);
      });

      final client = FrappeClient(dio);
      final repo = TeamRepository(client);

      expect(
        () => repo.inviteEmployee(
          email: 'test@korkem.kz',
          position: EmployeePosition.warehouse.id,
        ),
        throwsA(isA<TeamForbiddenException>()),
      );
    });

    test(
      'changePosition sends correct payload to staff.change_position',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            '/api/method/korkem_manufacturing.api.staff.change_position',
          );
          final data = options.data as Map<String, dynamic>;
          expect(data['email'], 'worker@korkem.kz');
          expect(data['position'], 'manager');

          return _json({
            'message': {
              'user': 'worker@korkem.kz',
              'position': 'manager',
              'roles': ['Sales Manager'],
              'enabled': true,
            },
          });
        });

        final repo = TeamRepository(FrappeClient(dio));
        final result = await repo.changePosition(
          email: 'worker@korkem.kz',
          position: 'manager',
        );

        expect(result.user, 'worker@korkem.kz');
        expect(result.position, 'manager');
        expect(result.roles, ['Sales Manager']);
        expect(result.enabled, isTrue);
      },
    );

    test('changePosition validates non-empty arguments', () async {
      final repo = TeamRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.changePosition(email: '', position: 'manager'),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => repo.changePosition(email: 'worker@korkem.kz', position: ''),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test(
      'changePosition throws ServerFailure on unexpected response',
      () async {
        final dio = createDio((options) async {
          return _json({'message': null});
        });

        final repo = TeamRepository(FrappeClient(dio));
        expect(
          () => repo.changePosition(
            email: 'worker@korkem.kz',
            position: 'manager',
          ),
          throwsA(isA<ServerFailure>()),
        );
      },
    );

    test(
      'deactivate sends email to staff.deactivate and returns sessions_closed',
      () async {
        final dio = createDio((options) async {
          expect(
            options.path,
            '/api/method/korkem_manufacturing.api.staff.deactivate',
          );
          final data = options.data as Map<String, dynamic>;
          expect(data['email'], 'worker@korkem.kz');

          return _json({
            'message': {
              'user': 'worker@korkem.kz',
              'enabled': false,
              'sessions_closed': 2,
              'status': 'disabled',
            },
          });
        });

        final repo = TeamRepository(FrappeClient(dio));
        final result = await repo.deactivate(email: 'worker@korkem.kz');

        expect(result.user, 'worker@korkem.kz');
        expect(result.enabled, isFalse);
        expect(result.sessionsClosed, 2);
        expect(result.status, 'disabled');
      },
    );

    test('deactivate validates non-empty email', () async {
      final repo = TeamRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.deactivate(email: '  '),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('deactivate throws ServerFailure on unexpected response', () async {
      final dio = createDio((options) async {
        return _json({'message': <String, dynamic>{}});
      });

      final repo = TeamRepository(FrappeClient(dio));
      expect(
        () => repo.deactivate(email: 'worker@korkem.kz'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('reactivate sends email to staff.reactivate', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.api.staff.reactivate',
        );
        final data = options.data as Map<String, dynamic>;
        expect(data['email'], 'worker@korkem.kz');

        return _json({
          'message': {
            'user': 'worker@korkem.kz',
            'enabled': true,
            'status': 'enabled',
          },
        });
      });

      final repo = TeamRepository(FrappeClient(dio));
      final result = await repo.reactivate(email: 'worker@korkem.kz');

      expect(result.user, 'worker@korkem.kz');
      expect(result.enabled, isTrue);
      expect(result.status, 'enabled');
    });

    test('reactivate validates non-empty email', () async {
      final repo = TeamRepository(
        FrappeClient(createDio((_) async => _json({}))),
      );

      expect(
        () => repo.reactivate(email: ''),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('reactivate throws ServerFailure on unexpected response', () async {
      final dio = createDio((options) async {
        return _json({'message': null});
      });

      final repo = TeamRepository(FrappeClient(dio));
      expect(
        () => repo.reactivate(email: 'worker@korkem.kz'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
