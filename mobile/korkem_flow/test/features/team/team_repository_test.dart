import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
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

  group('TeamRepository', () {
    test('fetches and maps team members with roles', () async {
      final dio = createDio((options) async {
        if (options.path.contains('/api/resource/User')) {
          return _json({
            'data': [
              {
                'name': 'owner@korkem.kz',
                'email': 'owner@korkem.kz',
                'first_name': 'Aidos',
                'full_name': 'Aidos Owner',
                'enabled': 1,
                'user_type': 'System User',
              },
              {
                'name': 'worker@korkem.kz',
                'email': 'worker@korkem.kz',
                'first_name': 'Berik',
                'full_name': 'Berik Worker',
                'enabled': 1,
                'user_type': 'System User',
              },
            ],
          });
        }
        if (options.path.contains('/api/resource/Has%20Role') ||
            options.path.contains('/api/resource/Has Role')) {
          return _json({
            'data': [
              {'parent': 'owner@korkem.kz', 'role': 'System Manager'},
              {'parent': 'worker@korkem.kz', 'role': 'Manufacturing User'},
              {'parent': 'worker@korkem.kz', 'role': 'Stock User'},
            ],
          });
        }
        return _json({'data': <Map<String, dynamic>>[]});
      });

      final client = FrappeClient(dio);
      final repo = TeamRepository(client);

      final members = await repo.fetchTeamMembers();

      expect(members.length, 2);
      expect(members[0].email, 'owner@korkem.kz');
      expect(members[0].position, EmployeePosition.owner);
      expect(members[0].isOwner, isTrue);

      expect(members[1].email, 'worker@korkem.kz');
      expect(members[1].position, EmployeePosition.shopFloor);
      expect(members[1].isOwner, isFalse);
    });

    test('invites employee with mapped position payload', () async {
      final dio = createDio((options) async {
        expect(
          options.path,
          '/api/method/korkem_manufacturing.services.invitations.invite_employee',
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
          },
        });
      });

      final client = FrappeClient(dio);
      final repo = TeamRepository(client);

      final result = await repo.inviteEmployee(
        email: 'accountant@korkem.kz',
        position: EmployeePosition.accountant,
        firstName: 'Saule',
      );

      expect(result.user, 'accountant@korkem.kz');
      expect(result.created, isTrue);
      expect(result.position, EmployeePosition.accountant);
      expect(result.rolesAdded, contains('Accounts User'));
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
          position: EmployeePosition.warehouse,
        ),
        throwsA(isA<TeamForbiddenException>()),
      );
    });
  });
}
