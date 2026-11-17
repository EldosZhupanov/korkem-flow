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
import 'package:korkem_flow/features/team/data/team_structure_repository.dart';
import 'package:korkem_flow/features/team/domain/team_models.dart';
import 'package:korkem_flow/features/team/domain/team_structure.dart';
import 'package:korkem_flow/features/team/presentation/team_screen.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

class _FakeTeamRepository extends TeamRepository {
  _FakeTeamRepository({
    required this.fetchMembersHandler,
    this.positionsHandler,
    this.inviteHandler,
    this.changePositionHandler,
    this.deactivateHandler,
    this.reactivateHandler,
  }) : super(dummyClient);

  static final dummyClient = FrappeClient(Dio());
  final Future<List<TeamMember>> Function() fetchMembersHandler;
  final Future<List<PositionOption>> Function()? positionsHandler;
  final Future<TeamInviteResult> Function(
    String email,
    String firstName,
    EmployeePosition position,
  )?
  inviteHandler;
  final Future<ChangePositionResult> Function(String email, String position)?
  changePositionHandler;
  final Future<DeactivateResult> Function(String email)? deactivateHandler;
  final Future<ReactivateResult> Function(String email)? reactivateHandler;
  final savedTrades = <(String, List<String>)>[];

  @override
  Future<ShopTrades> fetchTrades() async => const ShopTrades(
    trades: [
      ShopTrade(trade: 'TRADE-00001', title: 'Раскройщик'),
      ShopTrade(trade: 'TRADE-00002', title: 'Кромщик'),
      ShopTrade(trade: 'TRADE-00003', title: 'Маляр', enabled: false),
    ],
    canEdit: true,
  );

  @override
  Future<void> setMemberTrades(String user, List<String> titles) async =>
      savedTrades.add((user, titles));

  @override
  Future<List<PositionOption>> fetchPositions() {
    if (positionsHandler != null) {
      return positionsHandler!();
    }
    return Future.value(const [
      PositionOption(
        position: 'shop_floor',
        roles: ['Manufacturing User', 'Stock User'],
      ),
      PositionOption(
        position: 'manager',
        roles: ['Sales Manager'],
      ),
      PositionOption(
        position: 'warehouse',
        roles: ['Stock User'],
      ),
      PositionOption(
        position: 'accountant',
        roles: ['Accounts User'],
      ),
    ]);
  }

  @override
  Future<List<TeamMember>> fetchTeamMembers() => fetchMembersHandler();

  @override
  Future<TeamInviteResult> inviteEmployee({
    required String email,
    required dynamic position,
    String firstName = '',
  }) {
    final ep = position is EmployeePosition
        ? position
        : EmployeePosition.fromId('$position');
    if (inviteHandler != null) {
      return inviteHandler!(email, firstName, ep);
    }
    return Future.value(
      TeamInviteResult(
        user: email,
        company: 'KORKEM',
        created: true,
        position: ep,
        rolesAdded: const [],
        nextStep:
            'Set a password for this account in the desk '
            '(User → Set New Password), or configure SMTP '
            "and use Frappe's password reset.",
      ),
    );
  }

  @override
  Future<ChangePositionResult> changePosition({
    required String email,
    required String position,
  }) {
    if (changePositionHandler != null) {
      return changePositionHandler!(email, position);
    }
    return Future.value(
      ChangePositionResult(
        user: email,
        position: position,
        roles: const [],
        enabled: true,
      ),
    );
  }

  @override
  Future<DeactivateResult> deactivate({required String email}) {
    if (deactivateHandler != null) {
      return deactivateHandler!(email);
    }
    return Future.value(
      DeactivateResult(
        user: email,
        enabled: false,
        sessionsClosed: 1,
        status: 'disabled',
      ),
    );
  }

  @override
  Future<ReactivateResult> reactivate({required String email}) {
    if (reactivateHandler != null) {
      return reactivateHandler!(email);
    }
    return Future.value(
      ReactivateResult(
        user: email,
        enabled: true,
        status: 'enabled',
      ),
    );
  }
}

/// Departments and people as the server sends them (owner, 17.11.2026).
const _structure = TeamPeople(
  canEdit: true,
  departments: [
    TeamDepartment(
      key: 'cut',
      title: 'Раскрой',
      posts: [TeamPost(key: 'cut.cutter', title: 'Раскройщик')],
    ),
    TeamDepartment(
      key: 'pvc',
      title: 'ПВХ плёнка',
      posts: [
        TeamPost(key: 'pvc.sander', title: 'Шкурщик'),
        TeamPost(key: 'pvc.vacuum', title: 'Вакуумщик'),
      ],
    ),
  ],
  people: [
    TeamPerson(employee: 'HR-EMP-1', name: 'Ерлан', posts: ['cut.cutter']),
    TeamPerson(
      employee: 'HR-EMP-2',
      name: 'Нурлан',
      user: 'nurlan@korkem.kz',
      posts: ['pvc.sander'],
    ),
  ],
);

class _FakeStructure implements TeamStructureRepository {
  final added = <(String, List<String>)>[];

  @override
  Future<TeamPeople> add({
    required String name,
    required List<String> posts,
    String? phone,
  }) async {
    added.add((name, posts));
    return _structure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TeamPeople _peopleOf(List<TeamMember> members) => TeamPeople(
  departments: const [],
  people: [
    for (final m in members)
      TeamPerson(
        employee: null,
        name: m.fullName,
        user: m.email,
        login: TeamLogin(
          user: m.email,
          position: m.position.id,
          enabled: m.enabled,
          isOwner: m.isOwner,
        ),
        active: m.enabled,
      ),
  ],
);

/// Opens a person's card from the one list.
Future<void> _open(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(InputChip, name));
  await tester.pumpAndSettle();
}

void main() {
  Widget buildHarness(
    WidgetTester tester, {
    required TeamRepository repository,
    String currentUser = 'owner@korkem.kz',
    bool isOwner = true,
    TeamPeople? people,
    TeamStructureRepository? structure,
  }) {
    tester.view.physicalSize = const Size(1200, 2400);
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
        // «Команда» and its people are one list: with none given, the
        // logins as the server would send them — a login with no person.
        teamPeopleProvider.overrideWith(
          (ref) async =>
              people ??
              _peopleOf(
                await ref.watch(teamRepositoryProvider).fetchTeamMembers(),
              ),
        ),
        if (structure != null)
          teamStructureRepositoryProvider.overrideWithValue(structure),
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
    expect(find.text('Dana Manager'), findsOneWidget);
    expect(find.text('Berik Worker'), findsOneWidget);

    // A login's access is shown on its person.
    await _open(tester, 'Dana Manager');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('teamPersonAccess'))).data,
      'Менеджер',
    );
  });

  testWidgets('a person with a login is one entry, not a second list', (
    tester,
  ) async {
    final repo = _FakeTeamRepository(fetchMembersHandler: () async => []);
    await tester.pumpWidget(
      buildHarness(
        tester,
        repository: repo,
        people: const TeamPeople(
          canEdit: true,
          departments: [
            TeamDepartment(
              key: 'cut',
              title: 'Раскрой',
              posts: [TeamPost(key: 'cut.cutter', title: 'Раскройщик')],
            ),
          ],
          people: [
            TeamPerson(
              employee: 'HR-EMP-1',
              name: 'Ерлан',
              user: 'erlan@korkem.kz',
              login: TeamLogin(user: 'erlan@korkem.kz', position: 'cutter'),
              posts: ['cut.cutter'],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ерлан'), findsOneWidget);
    expect(find.text('ВХОД В ПРОГРАММУ'), findsNothing);
    await _open(tester, 'Ерлан');
    expect(find.byKey(const ValueKey('teamPersonLoginBlock')), findsOneWidget);
    expect(find.byKey(const ValueKey('teamLoginClose')), findsOneWidget);
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
    await tester.tap(find.byTooltip('Пригласить сотрудника'));
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

    expect(find.text('Aidos Owner'), findsOneWidget);
  });

  testWidgets(
    'positions in dropdown are fetched dynamically from server endpoint',
    (tester) async {
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
        positionsHandler: () async => [
          const PositionOption(
            position: 'custom_role',
            roles: ['Custom Permission Role'],
          ),
          const PositionOption(
            position: 'manager',
            roles: ['Sales Manager'],
          ),
        ],
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Пригласить сотрудника'));
      await tester.pumpAndSettle();

      // Tap the dropdown
      await tester.tap(find.text('custom_role'));
      await tester.pumpAndSettle();

      // Verify server position exists
      expect(find.text('custom_role'), findsWidgets);
      expect(find.text('Менеджер'), findsWidgets);

      // Verify positions not returned by server are NOT shown
      expect(find.text('Бухгалтер'), findsNothing);
      expect(find.text('Кладовщик'), findsNothing);
    },
  );

  testWidgets('shows server next_step and password_not_set on success', (
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
      inviteHandler: (email, name, position) async => TeamInviteResult(
        user: email,
        company: 'KORKEM',
        created: true,
        position: position,
        rolesAdded: const ['Stock User'],
        nextStep:
            'Set a password for this account in the desk '
            '(User → Set New Password), or configure SMTP '
            "and use Frappe's password reset.",
      ),
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Пригласить сотрудника'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Электронная почта'),
      'warehouse@korkem.kz',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Имя сотрудника'),
      'Nurlan',
    );

    await tester.tap(find.text('Отправить приглашение'));
    await tester.pumpAndSettle();

    // Verify success dialog
    expect(find.text('Сотрудник приглашён'), findsOneWidget);
    expect(find.text('Следующий шаг'), findsOneWidget);
    expect(
      find.text(
        'Set a password for this account in the desk '
        '(User → Set New Password), or configure SMTP '
        "and use Frappe's password reset.",
      ),
      findsOneWidget,
    );
    expect(find.text('Пароль не установлен'), findsOneWidget);

    // Close success dialog
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Сотрудник приглашён'), findsNothing);
  });

  testWidgets('shows exact server refusal message on invite error', (
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
      inviteHandler: (email, name, position) async {
        throw const ValidationFailure(
          'Unknown position. '
          'Choose manager, warehouse, accountant or shop_floor.',
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Пригласить сотрудника'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Электронная почта'),
      'bad@korkem.kz',
    );

    await tester.tap(find.text('Отправить приглашение'));
    await tester.pumpAndSettle();

    // Verify server's exact refusal message is shown verbatim
    expect(
      find.text(
        'Unknown position. '
        'Choose manager, warehouse, accountant or shop_floor.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deactivation requires confirmation with person name', (
    tester,
  ) async {
    String? deactivatedEmail;

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
          email: 'worker@korkem.kz',
          firstName: 'Кайрат',
          fullName: 'Кайрат Мастеров',
          position: EmployeePosition.shopFloor,
          roles: ['Manufacturing User'],
          enabled: true,
        ),
      ],
      deactivateHandler: (email) async {
        deactivatedEmail = email;
        return DeactivateResult(
          user: email,
          enabled: false,
          sessionsClosed: 2,
          status: 'disabled',
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    // His card, then his login's «Закрыть доступ».
    await _open(tester, 'Кайрат Мастеров');
    await tester.tap(find.byKey(const ValueKey('teamLoginClose')));
    await tester.pumpAndSettle();

    // Verify confirmation dialog includes person's name
    expect(find.text('Закрыть доступ?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Кайрат Мастеров'),
      ),
      findsOneWidget,
    );

    // Confirm deactivation
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Закрыть доступ'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(deactivatedEmail, 'worker@korkem.kz');
    expect(find.text('Доступ закрыт, завершено сеансов: 2'), findsOneWidget);
  });

  testWidgets('shows sessions_closed count even when zero sessions closed', (
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
          email: 'worker@korkem.kz',
          firstName: 'Кайрат',
          fullName: 'Кайрат',
          position: EmployeePosition.shopFloor,
          roles: ['Manufacturing User'],
          enabled: true,
        ),
      ],
      deactivateHandler: (email) async => DeactivateResult(
        user: email,
        enabled: false,
        sessionsClosed: 0,
        status: 'disabled',
      ),
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await _open(tester, 'Кайрат');
    await tester.tap(find.byKey(const ValueKey('teamLoginClose')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Закрыть доступ'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Доступ закрыт, завершено сеансов: 0'), findsOneWidget);
  });

  testWidgets(
    'self-protection: no action menu or deactivate on current user card',
    (tester) async {
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

      await tester.pumpWidget(
        buildHarness(
          tester,
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      // On his own card the owner cannot close his own login.
      await _open(tester, 'Aidos Owner');
      expect(
        find.byKey(const ValueKey('teamPersonLoginBlock')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('teamLoginClose')), findsNothing);
      expect(find.byKey(const ValueKey('teamPersonLeft')), findsNothing);
    },
  );

  testWidgets(
    'displays exact server refusal when attempting to deactivate last owner',
    (tester) async {
      final repo = _FakeTeamRepository(
        fetchMembersHandler: () async => [
          const TeamMember(
            email: 'current_owner@korkem.kz',
            firstName: 'Aidos',
            fullName: 'Aidos Owner',
            position: EmployeePosition.owner,
            roles: ['System Manager'],
            enabled: true,
          ),
          const TeamMember(
            email: 'other_owner@korkem.kz',
            firstName: 'Baurzhan',
            fullName: 'Baurzhan Owner',
            position: EmployeePosition.owner,
            roles: ['System Manager'],
            enabled: true,
          ),
        ],
        deactivateHandler: (email) async {
          throw const PermissionFailure(
            'Это последний владелец. Компания без него не сможет ни '
            'пригласить, ни исправить, ни включить обратно.',
          );
        },
      );

      await tester.pumpWidget(
        buildHarness(
          tester,
          repository: repo,
          currentUser: 'current_owner@korkem.kz',
        ),
      );
      await tester.pumpAndSettle();

      await _open(tester, 'Baurzhan Owner');
      await tester.tap(find.byKey(const ValueKey('teamLoginClose')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Закрыть доступ'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Это последний владелец. Компания без него не сможет ни '
          'пригласить, ни исправить, ни включить обратно.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('changes employee position via change position dialog', (
    tester,
  ) async {
    String? changedEmail;
    String? changedPosition;

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
          email: 'worker@korkem.kz',
          firstName: 'Кайрат',
          fullName: 'Кайрат Мастеров',
          position: EmployeePosition.shopFloor,
          roles: ['Manufacturing User'],
          enabled: true,
        ),
      ],
      changePositionHandler: (email, position) async {
        changedEmail = email;
        changedPosition = position;
        return ChangePositionResult(
          user: email,
          position: position,
          roles: const ['Accounts User'],
          enabled: true,
        );
      },
    );

    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();

    await _open(tester, 'Кайрат Мастеров');
    await tester.tap(find.byKey(const ValueKey('teamLoginPosition')));
    await tester.pumpAndSettle();

    expect(find.text('Сменить должность'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Кайрат Мастеров'),
      ),
      findsOneWidget,
    );

    // Open positions dropdown and select accountant
    await tester.tap(find.text('Рабочий цеха').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Бухгалтер').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить должность'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(changedEmail, 'worker@korkem.kz');
    expect(changedPosition, 'accountant');
    expect(
      find.text('Должность сотрудника Кайрат Мастеров изменена на «Бухгалтер»'),
      findsOneWidget,
    );
  });

  testWidgets(
    'deactivated employee remains visible in list and can be reactivated',
    (tester) async {
      String? reactivatedEmail;

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
            email: 'ex_worker@korkem.kz',
            firstName: 'Серик',
            fullName: 'Серик Бывший',
            position: EmployeePosition.shopFloor,
            roles: [],
            enabled: false,
          ),
        ],
        reactivateHandler: (email) async {
          reactivatedEmail = email;
          return ReactivateResult(
            user: email,
            enabled: true,
            status: 'enabled',
          );
        },
      );

      await tester.pumpWidget(buildHarness(tester, repository: repo));
      await tester.pumpAndSettle();

      // A closed login stays on the list, among those who left.
      expect(find.text('Ушли из компании'), findsOneWidget);
      expect(find.text('Серик Бывший'), findsOneWidget);

      await _open(tester, 'Серик Бывший');
      expect(find.text('Доступ закрыт'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('teamLoginOpen')));
      await tester.pumpAndSettle();

      // Verify confirmation dialog includes employee name
      expect(find.text('Вернуть доступ?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Серик Бывший'),
        ),
        findsOneWidget,
      );

      // Confirm
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Вернуть доступ'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(reactivatedEmail, 'ex_worker@korkem.kz');
      expect(find.text('Доступ возвращён'), findsOneWidget);
    },
  );

  testWidgets('a worker has several trades, set from the team list', (
    tester,
  ) async {
    final repo = _FakeTeamRepository(
      fetchMembersHandler: () async => [
        const TeamMember(
          email: 'cutter@korkem.kz',
          firstName: 'Ержан',
          fullName: 'Ержан Раскрой',
          position: EmployeePosition.cutter,
          roles: ['Manufacturing User'],
          enabled: true,
          trades: ['Раскройщик'],
        ),
      ],
    );
    await tester.pumpWidget(buildHarness(tester, repository: repo));
    await tester.pumpAndSettle();
    await _open(tester, 'Ержан Раскрой');
    await tester.tap(find.byKey(const ValueKey('teamLoginTrades')));
    await tester.pumpAndSettle();
    // A switched-off trade is not offered.
    expect(find.byKey(const ValueKey('trade:Маляр')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('trade:Кромщик')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tradesSave')));
    await tester.pumpAndSettle();

    // Records compare lists by identity, so the parts are checked apart.
    expect(repo.savedTrades.single.$1, 'cutter@korkem.kz');
    expect(repo.savedTrades.single.$2, ['Раскройщик', 'Кромщик']);
  });

  test('trades come from the server with the person', () {
    final member = TeamMember.fromJson(const {
      'email': 'cutter@korkem.kz',
      'position': 'cutter',
      'enabled': true,
      'trades': ['Раскройщик', 'Кромщик'],
    });
    expect(member.trades, ['Раскройщик', 'Кромщик']);
  });

  testWidgets('departments show their posts and people, and a person is '
      'added on a post with no login', (tester) async {
    final structure = _FakeStructure();
    await tester.pumpWidget(
      buildHarness(
        tester,
        repository: _FakeTeamRepository(fetchMembersHandler: () async => []),
        people: _structure,
        structure: structure,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Раскрой'), findsOneWidget);
    expect(find.text('ПВХ плёнка'), findsOneWidget);
    expect(find.text('Ерлан'), findsOneWidget);
    expect(find.text('Нурлан'), findsOneWidget);
    // Nobody presses yet: the post offers to add someone.
    expect(find.byKey(const ValueKey('teamAddTo:pvc.vacuum')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('teamAddTo:pvc.vacuum')));
    await tester.pumpAndSettle();
    final vacuum = tester.widget<FilterChip>(
      find.byKey(const ValueKey('teamPost:pvc.vacuum')),
    );
    expect(vacuum.selected, isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('teamPersonName')),
      'Бек Вакуумов',
    );
    await tester.tap(find.byKey(const ValueKey('teamPersonSave')));
    await tester.pumpAndSettle();

    expect(structure.added.single.$1, 'Бек Вакуумов');
    expect(structure.added.single.$2, ['pvc.vacuum']);
  });
}

class _TestSessionController extends SessionController {
  _TestSessionController(this._initial);
  final Session _initial;

  @override
  Future<Session> build() async => _initial;
}
