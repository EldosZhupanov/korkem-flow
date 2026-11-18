import 'package:flutter/services.dart';

/// One way to write a phone (owner, 18.11.2026): kept as `+77015551234`,
/// shown as `+7 (701) 555-12-34`, typed any way at all — the server's
/// `services/phones.py` keeps the spelling, this is how it reads and looks.
abstract final class Phone {
  static final _canonical = RegExp(r'^\+7\d{10}$');
  static final _nonDigit = RegExp(r'\D');

  /// The hint a phone field shows before anything is typed.
  static const hint = '+7 (___) ___-__-__';

  /// `+7 (701) 555-12-34` for a Kazakh phone kept in the one spelling;
  /// anything else — a foreign phone, an old note — exactly as it is.
  static String pretty(String value) {
    if (!_canonical.hasMatch(value)) return value;
    final n = value.substring(2);
    return '+7 (${n.substring(0, 3)}) ${n.substring(3, 6)}-'
        '${n.substring(6, 8)}-${n.substring(8)}';
  }

  /// [pretty] for a phone that may be absent.
  static String? prettyOrNull(String? value) =>
      value == null ? null : pretty(value);

  static String digits(String value) => value.replaceAll(_nonDigit, '');
}

/// The mask `+7 (___) ___-__-__`: brackets and dashes put in as the digits
/// come, whatever is pasted — `8 701 555 12 34`, `87015551234`,
/// `+7 701…`, `701 555 1234` all become `+7 (701) 555-12-34`. A number that
/// starts with «+» and another country's code is left as typed.
class PhoneMaskFormatter extends TextInputFormatter {
  const PhoneMaskFormatter();

  static final _foreignJunk = RegExp(r'[^\d ]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final typed = newValue.text.trimLeft();
    if (typed.isEmpty || typed == '+' || typed == '+7') return _at(typed);
    if (typed.startsWith('+') && !typed.startsWith('+7')) {
      return _at('+${typed.substring(1).replaceAll(_foreignJunk, '')}');
    }
    var digits = Phone.digits(typed);
    // Deleting a bracket or a dash deletes the digit before it, or the
    // mask would put the separator straight back.
    if (newValue.text.length < oldValue.text.length &&
        digits == Phone.digits(oldValue.text) &&
        digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }
    final national = switch (digits) {
      _ when typed.startsWith('+7') => digits.substring(1),
      _ when digits.startsWith('8') => digits.substring(1),
      _ when digits.length == 11 && digits.startsWith('7') => digits.substring(
        1,
      ),
      _ => digits,
    };
    return _at(_mask(national));
  }

  static String _mask(String national) {
    final n = national.length > 10 ? national.substring(0, 10) : national;
    if (n.isEmpty) return '+7 ';
    final buffer = StringBuffer('+7 (')
      ..write(n.substring(0, n.length < 3 ? n.length : 3));
    if (n.length > 3) {
      buffer
        ..write(') ')
        ..write(n.substring(3, n.length < 6 ? n.length : 6));
    }
    if (n.length > 6) {
      buffer
        ..write('-')
        ..write(n.substring(6, n.length < 8 ? n.length : 8));
    }
    if (n.length > 8) {
      buffer
        ..write('-')
        ..write(n.substring(8));
    }
    return buffer.toString();
  }

  static TextEditingValue _at(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}
