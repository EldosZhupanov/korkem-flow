/// How the search window reads what was typed for the things it matches on
/// the device itself — the actions and the menu's sections. The same rules
/// as the server's `services/search_text.py`: one letter is one letter
/// (case, «ё», the Kazakh letters), the wrong keyboard layout is read too,
/// and a word of four letters or more may be one letter off.
abstract final class SearchText {
  static const _kazakh = {
    'ә': 'а',
    'ғ': 'г',
    'қ': 'к',
    'ң': 'н',
    'ө': 'о',
    'ұ': 'у',
    'ү': 'у',
    'һ': 'х',
    'і': 'и',
    'ё': 'е',
    'й': 'и',
  };

  static const _english = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`";
  static const _russian = 'йцукенгшщзхъфывапролджэячсмитьбюё';

  static final _word = RegExp('[0-9a-zа-я]+');
  static final _latin = RegExp('[a-z]');
  static final _cyrillic = RegExp('[а-я]');

  /// Lower case, Kazakh letters and «ё» as their Russian neighbours.
  static String fold(String text) {
    final buffer = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      buffer.write(_kazakh[ch] ?? ch);
    }
    return buffer
        .toString()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .join(' ');
  }

  static String _swap(String text, String from, String to) {
    final buffer = StringBuffer();
    for (final ch in text.split('')) {
      final i = from.indexOf(ch);
      buffer.write(i < 0 ? ch : to[i]);
    }
    return buffer.toString();
  }

  /// Every reading of what was typed, the typed one first.
  static List<String> readings(String query) {
    final typed = fold(query);
    if (typed.isEmpty) return const [];
    final raw = query.toLowerCase();
    final latin = _latin.hasMatch(typed);
    final cyrillic = _cyrillic.hasMatch(typed);
    return {
      typed,
      if (latin && !cyrillic) fold(_swap(raw, _english, _russian)),
      if (cyrillic && !latin) fold(_swap(raw, _russian, _english)),
    }.toList();
  }

  static List<String> words(String text) => [
    for (final m in _word.allMatches(fold(text))) m.group(0)!,
  ];

  /// Whether every typed word starts one of [texts]' words — or nearly does.
  static bool matches(String query, Iterable<String> texts) {
    final targets = [for (final t in texts) ...words(t)];
    if (targets.isEmpty) return false;
    for (final reading in readings(query)) {
      final typed = words(reading);
      if (typed.isEmpty) continue;
      if (typed.every((w) => targets.any((t) => _near(w, t)))) return true;
    }
    return false;
  }

  static bool _near(String word, String target) {
    if (target.startsWith(word)) return true;
    if (word.length < 4) return false;
    final head = target.length > word.length
        ? target.substring(0, word.length)
        : target;
    return _distance(word, head) <= 1;
  }

  static int _distance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current.add(
          [
            previous[j] + 1,
            current[j - 1] + 1,
            previous[j - 1] + cost,
          ].reduce((x, y) => x < y ? x : y),
        );
      }
      previous = current;
    }
    return previous.last;
  }
}
