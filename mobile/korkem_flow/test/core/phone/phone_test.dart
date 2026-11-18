import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/phone/phone.dart';

/// One way to write a phone (owner, 18.11.2026): typed or pasted any way,
/// it reads as +7 (701) 555-12-34.
void main() {
  const mask = PhoneMaskFormatter();

  String typeInto(String start, String added) => mask
      .formatEditUpdate(
        TextEditingValue(text: start),
        TextEditingValue(text: '$start$added'),
      )
      .text;

  String paste(String text) => typeInto('', text);

  String typeKeys(String keys) {
    var text = '';
    for (final key in keys.split('')) {
      text = typeInto(text, key);
    }
    return text;
  }

  test('a pasted phone, written any way, comes out one way', () {
    for (final pasted in [
      '8 701 555 12 34',
      '87015551234',
      '+7 701 555 12 34',
      '+77015551234',
      '7015551234',
      '8 (701) 555-12-34',
    ]) {
      expect(paste(pasted), '+7 (701) 555-12-34', reason: pasted);
    }
  });

  test('typed key by key, brackets and dashes come by themselves', () {
    expect(typeKeys('7015551234'), '+7 (701) 555-12-34');
    expect(typeKeys('87015551234'), '+7 (701) 555-12-34');
    expect(typeKeys('701'), '+7 (701');
    expect(typeKeys('7015'), '+7 (701) 5');
  });

  test('more than ten digits are not taken', () {
    expect(typeKeys('701555123499'), '+7 (701) 555-12-34');
  });

  test('deleting a dash deletes the digit before it', () {
    final out = mask.formatEditUpdate(
      const TextEditingValue(text: '+7 (701) 555-'),
      const TextEditingValue(text: '+7 (701) 555'),
    );
    expect(out.text, '+7 (701) 55');
  });

  test('a foreign phone keeps its own code', () {
    expect(typeKeys('+996 555 123 456'), '+996 555 123 456');
  });

  test('emptied, the field is empty', () {
    final out = mask.formatEditUpdate(
      const TextEditingValue(text: '+7 (7'),
      const TextEditingValue(text: '+7 ('),
    );
    expect(out.text, '+7 ');
    expect(paste(''), '');
  });

  test('kept as +77015551234, shown with brackets and dashes', () {
    expect(Phone.pretty('+77015551234'), '+7 (701) 555-12-34');
    expect(Phone.pretty('+996555123456'), '+996555123456');
    expect(Phone.pretty('звонить после 18'), 'звонить после 18');
    expect(Phone.prettyOrNull(null), isNull);
  });
}
