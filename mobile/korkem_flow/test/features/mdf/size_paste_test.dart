import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/domain/size_paste.dart';

void main() {
  (int, int, int, String?) row(SizePaste p, int i) => (
    p.lines[i].heightMm,
    p.lines[i].widthMm,
    p.lines[i].qty,
    p.lines[i].note,
  );

  test('the ways people write a facade size', () {
    final p = parseSizes('''
348 997 2
348х997 - 2шт
2027*497*4
1577 × 517 (2)
130 на 1040
''');
    expect(p.skipped, isEmpty);
    expect(row(p, 0), (348, 997, 2, null));
    expect(row(p, 1), (348, 997, 2, null));
    expect(row(p, 2), (2027, 497, 4, null));
    expect(row(p, 3), (1577, 517, 2, null));
    expect(row(p, 4), (130, 1040, 1, null));
  });

  test('Excel cells, with a note after the count', () {
    final p = parseSizes(
      '348\t997\t2\tОйықталған 16-14\n2480\t60\t1\tКесу 90°',
    );
    expect(row(p, 0), (348, 997, 2, 'Ойықталған 16-14'));
    expect(row(p, 1), (2480, 60, 1, 'Кесу 90°'));
  });

  test('a milling number in the note is not the count', () {
    final p = parseSizes('348 997 Рифлёный 16-14');
    expect(row(p, 0), (348, 997, 1, 'Рифлёный 16-14'));
  });

  test('what is not a size is skipped and shown, never guessed', () {
    final p = parseSizes('Здравствуйте!\n348 997 2\nцвет белый\n5 7\n');
    expect(p.lines, hasLength(1));
    expect(p.skipped, ['Здравствуйте!', 'цвет белый', '5 7']);
  });

  test('the milling chosen for the paste lands on every line', () {
    final p = parseSizes('348 997 2\n100 597 2', milling: 'Тегіс 90°');
    expect(p.lines.map((l) => l.milling), ['Тегіс 90°', 'Тегіс 90°']);
  });
}
