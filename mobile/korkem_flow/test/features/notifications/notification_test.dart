import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/core/api/frappe_query.dart';
import 'package:korkem_flow/core/api/html_text.dart';
import 'package:korkem_flow/features/notifications/data/notification_repository.dart';
import 'package:korkem_flow/features/notifications/domain/app_notification.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements FrappeClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(const FrappeQuery());
  });

  group('stripHtml', () {
    test('unwraps the markup Frappe stores subjects as', () {
      // Verbatim from a live /api/resource/Notification Log response.
      const wire =
          '<strong>Administrator</strong> assigned a new task '
          '<strong>CRM Deal</strong> <b class="subject-title">Smart Solutions</b> '
          'to you';

      expect(
        stripHtml(wire),
        'Administrator assigned a new task CRM Deal Smart Solutions to you',
      );
    });

    test('decodes the entities Frappe emits', () {
      expect(stripHtml('Fasada &amp; Co &lt;test&gt;'), 'Fasada & Co <test>');
      expect(stripHtml('a&nbsp;b'), 'a b');
    });

    test('collapses the whitespace that unwrapping leaves behind', () {
      expect(stripHtml('<p>a</p>\n\n  <p>b</p>'), 'a b');
    });
  });

  group('NotificationRepository', () {
    late _MockClient client;
    late NotificationRepository repository;

    setUp(() {
      client = _MockClient();
      repository = NotificationRepository(client);
      when(() => client.getList(any(), any())).thenAnswer((_) async => []);
    });

    test('always scopes the query to one user', () async {
      // The reason this test exists: Notification Log grants read to the role
      // `All` and Frappe registers no permission query conditions for it, so
      // an unfiltered query returns *everyone's* notifications. Confirmed live
      // — an admin's unfiltered list came back full of another user's
      // assignments. Dropping this filter is a privacy leak, not a bug.
      await repository.fetchPage(forUser: 'aidos@korkem.kz', pageSize: 20);

      final query =
          verify(() => client.getList(any(), captureAny())).captured.single
              as FrappeQuery;

      expect(
        query.filters,
        contains(const FrappeFilter.equals('for_user', 'aidos@korkem.kz')),
      );
    });

    test(
      'unreadOnly adds the read filter without dropping the user one',
      () async {
        await repository.fetchPage(
          forUser: 'aidos@korkem.kz',
          pageSize: 20,
          unreadOnly: true,
        );

        final query =
            verify(() => client.getList(any(), captureAny())).captured.single
                as FrappeQuery;

        expect(query.filters, hasLength(2));
        expect(
          query.filters.first,
          const FrappeFilter.equals('for_user', 'aidos@korkem.kz'),
        );
      },
    );

    test("marks read through Frappe's own scoped method", () async {
      when(
        () => client.callMethod(
          any(),
          params: any(named: 'params'),
          post: any(named: 'post'),
        ),
      ).thenAnswer((_) async => {'message': null});

      await repository.markRead('n1');

      // mark_as_read scopes its update to frappe.session.user server-side.
      // A direct set_value on this doctype would let a caller mark somebody
      // else's notification read.
      verify(
        () => client.callMethod(
          'frappe.desk.doctype.notification_log.notification_log.mark_as_read',
          post: true,
          params: {'docname': 'n1'},
        ),
      ).called(1);
    });

    test('parses the live payload and strips the subject', () {
      final notification = NotificationRepository.fromJson({
        'name': 's524pe5ruq',
        'type': 'Assignment',
        'subject': '<strong>Administrator</strong> assigned a new task to you',
        'document_type': 'CRM Deal',
        'document_name': '_T-CRM Deal-00375',
        'for_user': 'crm.user1@example.com',
        'read': 0,
        'creation': '2026-07-28 17:22:48.215036',
      });

      expect(notification.type, NotificationType.assignment);
      expect(
        notification.subject,
        'Administrator assigned a new task to you',
      );
      expect(notification.isRead, isFalse);
      expect(notification.documentName, '_T-CRM Deal-00375');
    });

    test('an unrecognised type still renders, as a generic alert', () {
      // Frappe apps register their own notification types.
      expect(NotificationType.fromWire('Quality Hold'), NotificationType.alert);
      expect(NotificationType.fromWire(null), NotificationType.alert);
    });

    test('asRead flips only the read flag', () {
      const original = AppNotification(
        id: 'n1',
        type: NotificationType.mention,
        subject: 'x',
        isRead: false,
        documentName: 'D-1',
      );

      final read = original.asRead();

      expect(read.isRead, isTrue);
      expect(read.id, original.id);
      expect(read.subject, original.subject);
      expect(read.documentName, original.documentName);
    });
  });
}
