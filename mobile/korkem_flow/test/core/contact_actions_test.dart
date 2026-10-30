import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/contact/contact_actions.dart';

void main() {
  group('phone numbers', () {
    test('strips the formatting Frappe stores but keeps the country code', () {
      // Real shapes seen on this site's records.
      expect(
        ContactActions.normaliseNumber('+7 701 000 11 22'),
        '+77010001122',
      );
      expect(ContactActions.normaliseNumber('+1-555-0135'), '+15550135');
      expect(ContactActions.normaliseNumber('77010001122'), '77010001122');
    });

    test('treats a number with no digits as absent', () {
      expect(ContactActions.normaliseNumber('—'), isNull);
      expect(ContactActions.normaliseNumber('   '), isNull);
      expect(ContactActions.normaliseNumber(null), isNull);
    });

    test('tel: keeps the plus, wa.me drops it', () {
      // wa.me rejects a leading `+`; `tel:` needs it for an international dial.
      // Getting this backwards silently opens a chat with the wrong number.
      expect(
        ContactActions.phoneUri('+7 701 000 11 22').toString(),
        'tel:+77010001122',
      );
      expect(
        ContactActions.whatsAppUri('+7 701 000 11 22').toString(),
        'https://wa.me/77010001122',
      );
    });

    test('builds nothing rather than a broken link', () {
      expect(ContactActions.phoneUri(null), isNull);
      expect(ContactActions.whatsAppUri(''), isNull);
    });
  });

  group('email', () {
    test('builds a mailto without mangling the address', () {
      expect(
        ContactActions.emailUri(' steven.green@example.com ').toString(),
        'mailto:steven.green@example.com',
      );
    });
  });

  group('websites', () {
    test('adds a scheme when the record has none', () {
      // A bare host parses as a relative path and launches nothing at all.
      expect(
        ContactActions.websiteUri('korkem.kz').toString(),
        'https://korkem.kz',
      );
    });

    test('leaves an explicit scheme alone, including plain http', () {
      expect(
        ContactActions.websiteUri('http://10.0.0.5:8000').toString(),
        'http://10.0.0.5:8000',
      );
      expect(
        ContactActions.websiteUri('https://korkem.kz/about').toString(),
        'https://korkem.kz/about',
      );
    });

    test('returns null for an empty field', () {
      expect(ContactActions.websiteUri(''), isNull);
      expect(ContactActions.websiteUri(null), isNull);
    });
  });
}
