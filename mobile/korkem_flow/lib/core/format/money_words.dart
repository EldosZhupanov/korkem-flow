/// A sum in tenge in Russian words, as an invoice writes it under the
/// total: «Двести девяносто четыре тысячи триста тенге 00 тиын» (owner,
/// 20.11.2026: «счёт на оплату»). Tenge do not decline; the thousands,
/// millions and billions do, and a thousand is feminine — «одна тысяча»,
/// «две тысячи».
String tengeInWordsRu(double sum) {
  final cents = (sum * 100).round();
  final whole = cents ~/ 100;
  final tiyn = (cents % 100).toString().padLeft(2, '0');
  final words = whole == 0 ? 'ноль' : _number(whole);
  final text = '$words тенге $tiyn тиын';
  return text[0].toUpperCase() + text.substring(1);
}

const _ones = [
  '',
  'один',
  'два',
  'три',
  'четыре',
  'пять',
  'шесть',
  'семь',
  'восемь',
  'девять',
];
const _onesFeminine = ['', 'одна', 'две'];
const _teens = [
  'десять',
  'одиннадцать',
  'двенадцать',
  'тринадцать',
  'четырнадцать',
  'пятнадцать',
  'шестнадцать',
  'семнадцать',
  'восемнадцать',
  'девятнадцать',
];
const _tens = [
  '',
  '',
  'двадцать',
  'тридцать',
  'сорок',
  'пятьдесят',
  'шестьдесят',
  'семьдесят',
  'восемьдесят',
  'девяносто',
];
const _hundreds = [
  '',
  'сто',
  'двести',
  'триста',
  'четыреста',
  'пятьсот',
  'шестьсот',
  'семьсот',
  'восемьсот',
  'девятьсот',
];

/// The scale words: one, two-to-four, five-and-on; and whether feminine.
const List<({String one, String few, String many, bool feminine})> _scales = [
  (one: '', few: '', many: '', feminine: false),
  (one: 'тысяча', few: 'тысячи', many: 'тысяч', feminine: true),
  (one: 'миллион', few: 'миллиона', many: 'миллионов', feminine: false),
  (one: 'миллиард', few: 'миллиарда', many: 'миллиардов', feminine: false),
];

String _number(int n) {
  final parts = <String>[];
  var rest = n;
  for (var i = 0; rest > 0 && i < _scales.length; i++) {
    final triple = rest % 1000;
    rest ~/= 1000;
    if (triple == 0) continue;
    final s = _scales[i];
    final words = _triple(triple, feminine: s.feminine);
    final scale = i == 0 ? '' : _plural(triple, s.one, s.few, s.many);
    parts.insert(0, [words, scale].where((w) => w.isNotEmpty).join(' '));
  }
  return parts.join(' ');
}

String _triple(int n, {required bool feminine}) {
  final out = <String>[_hundreds[n ~/ 100]];
  final t = n % 100;
  if (t >= 10 && t < 20) {
    out.add(_teens[t - 10]);
  } else {
    out.add(_tens[t ~/ 10]);
    final o = t % 10;
    out.add(feminine && o < 3 ? _onesFeminine[o] : _ones[o]);
  }
  return out.where((w) => w.isNotEmpty).join(' ');
}

String _plural(int n, String one, String few, String many) {
  final t = n % 100;
  if (t >= 11 && t <= 14) return many;
  return switch (n % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}
