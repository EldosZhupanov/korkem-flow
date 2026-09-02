import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_exception.dart';
import 'package:korkem_flow/core/auth/auth_credentials.dart';
import 'package:korkem_flow/core/auth/session_controller.dart';
import 'package:korkem_flow/core/design/theme/app_theme.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/team/application/team_controller.dart';
import 'package:korkem_flow/features/team/data/team_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/features/team/presentation/team_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeTeamRepository extends TeamRepository {
  _FakeTeamRepository({
    required this.fetchMembersHandler,
    this.inviteHandler,
  }) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());
  final Future<List<TeamMember>> Function() fetchMembersHandler;
  final Future<TeamInviteResult> Function(
    String email,
    String firstName,
    EmployeePosition position,
  )?
  inviteHandler;

  @override
  Future<List<TeamMember>> fetchTeamMembers() => fetchMembersHandler();

  @override
  Future<TeamInviteResult> inviteEmployee({
    required String email,
    required EmployeePosition position,
    String firstName = '',
  }) {
    if (inviteHandler != null) {
      return inviteHandler!(email, firstName, position);
    }
    return Future.value(
      TeamInviteResult(
        user: email,
        company: 'KORKEM',
        created: true,
        position: position,
        rolesAdded: const [],
      ),
    );
  }
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required TeamRepository repository,
    String currentUser = 'owner@korkem.kz',
    bool isOwner = true,
  }) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: [
        teamRepositoryProvider.overrideWithValue(repository),
        sessionProvider.overrideWith(
          () => _TestSessionController(
            Session(
              serverUrl: 'https://korkem.test',
              credentials: SessionCredentials(
                user: currentUser,
                sid: 'test_sid',
              ),
            ),
          ),
        ),
        canInviteProvider.overrideWith((ref) => isOwner),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TeamScreen(),
      ),
    );
  }

  testWidgets('renders list of team members with position badges', (
    tester,
  ) async {
    final repo = _FakeTeamRepository(
      fetchMembersHandler: () async => [
        const TeamMember(
          email: 'owner@korkem.kz',
          firstName: 'Aidos',
          fullName: 'Aidos Owner',
          position: EmployeePosition.owner,
          roles: ['System Manager'],
          enabled: true,
        ),
        const TeamMember(
          email: 'manager@korkem.kz',
          firstName: 'Dana',
          fullName: 'Dana Manager',
          position: EmployeePosition.manager,
          roles: ['Sales Manager'],
          enabled: true,
        ),
        const TeamMember(
          email: 'worker@korkem.kz',
          firstName: 'Berik',
          fullName: 'Berik Worker',
          position: EmployeePosition.shopFloor,
          roles: ['Manufacturing User', 'Stock User'],
          enabled: true,
        ),
      ],
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Команда'), findsOneWidget);
    expect(find.text('Aidos Owner'), findsOneWidget);
    expect(find.text('Владелец'), findsOneWidget);

    expect(find.text('Dana Manager'), findsOneWidget);
    expect(find.text('Менеджер'), findsOneWidget);

    expect(find.text('Berik Worker'), findsOneWidget);
    expect(find.text('Рабочий цеха'), findsOneWidget);
  });

  testWidgets('renders empty state when only owner or nobody is present', (
    tester,
  ) async {
    final repo = _FakeTeamRepository(
      fetchMembersHandler: () async => [
        const TeamMember(
          email: 'owner@korkem.kz',
          firstName: 'Aidos',
          fullName: 'Aidos Owner',
          position: EmployeePosition.owner,
          roles: ['System Manager'],
          enabled: true,
        ),
      ],
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Пока вы один'), findsOneWidget);
    expect(
      find.text(
        'Пригласите сотрудников цеха, склада или отдела продаж, '
        'чтобы распределять задачи и контролировать производство.',
      ),
      findsOneWidget,
    );
    expect(find.text('Пригласить сотрудника'), findsWidgets);
  });

  testWidgets(
    'renders forbidden notice and hides invite action when user is not owner',
    (tester) async {
      final repo = _FakeTeamRepository(
        fetchMembersHandler: () async => [
          const TeamMember(
            email: 'worker@korkem.kz',
            firstName: 'Berik',
            fullName: 'Berik Worker',
            position: EmployeePosition.shopFloor,
            roles: ['Manufacturing User'],
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        buildHarness(
          tester,
          repository: repo,
          currentUser: 'worker@korkem.kz',
          isOwner: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Только для владельца'), findsOneWidget);
      expect(
        find.text(
          'Приглашать новых сотрудников и назначать должности '
          'может только владелец компании.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.add), findsNothing);
    },
  );

  testWidgets('opens invite dialog, validates, and sends invitation', (
    tester,
  ) async {
    String? invitedEmail;
    String? invitedName;
    EmployeePosition? invitedPosition;

    final repo = _FakeTeamRepository(
      fetchMembersHandler: () async => [
        const TeamMember(
          email: 'owner@korkem.kz',
          firstName: 'Aidos',
          fullName: 'Aidos Owner',
          position: EmployeePosition.owner,
          roles: ['System Manager'],
          enabled: true,
        ),
      ],
      inviteHandler: (email, name, position) async {
        invitedEmail = email;
        invitedName = name;
        invitedPosition = position;
        return TeamInviteResult(
          user: email,
          company: 'KORKEM',
          created: true,
          position: position,
          rolesAdded: const ['Accounts User'],
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    // Tap invite button
    await tester.tap(find.text('Пригласить сотрудника').first);
    await tester.pumpAndSettle();

    expect(find.text('Пригласить сотрудника'), findsWidgets);
    expect(
      find.text('Выберите должность и укажите почту для доступа'),
      findsOneWidget,
    );

    // Try submit empty form
    await tester.tap(find.text('Отправить приглашение'));
    await tester.pumpAndSettle();
    expect(find.text('Введите корректный адрес почты'), findsOneWidget);

    // Enter email and name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Электронная почта'),
      'accountant@korkem.kz',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Имя сотрудника'),
      'Saule',
    );

    // Select position from dropdown
    await tester.tap(find.text('Рабочий цеха'));
    await tester.pumpAndSettle();

    // Verify owner is not in dropdown options
    expect(find.text('Владелец'), findsNothing);

    // Choose Бухгалтер
    await tester.tap(find.text('Бухгалтер').last);
    await tester.pumpAndSettle();

    // Submit form
    await tester.tap(find.text('Отправить приглашение'));
    await tester.pumpAndSettle();

    expect(invitedEmail, 'accountant@korkem.kz');
    expect(invitedName, 'Saule');
    expect(invitedPosition, EmployeePosition.accountant);
  });

  testWidgets('shows error state on network error and retries', (tester) async {
    var fail = true;
    final repo = _FakeTeamRepository(
      fetchMembersHandler: () async {
        if (fail) throw const NetworkFailure('Timeout');
        return const [
          TeamMember(
            email: 'owner@korkem.kz',
            firstName: 'Aidos',
            fullName: 'Aidos Owner',
            position: EmployeePosition.owner,
            roles: ['System Manager'],
            enabled: true,
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

    expect(find.text('Пока вы один'), findsOneWidget);
  });
}

class _TestSessionController extends SessionController {
  _TestSessionController(this._initial);
  final Session _initial;

  @override
  Future<Session> build() async => _initial;
}
