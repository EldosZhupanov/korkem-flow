import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/format/money_words.dart';

/// The sum under an invoice's total, as an accountant reads it (owner,
/// 20.11.2026: «счёт на оплату»).
void main() {
  test('thousands are feminine and decline', () {
    expect(
      tengeInWordsRu(294300),
      'Двести девяносто четыре тысячи триста тенге 00 тиын',
    );
    expect(tengeInWordsRu(1000), 'Одна тысяча тенге 00 тиын');
    expect(tengeInWordsRu(2000), 'Две тысячи тенге 00 тиын');
    expect(tengeInWordsRu(5000), 'Пять тысяч тенге 00 тиын');
    expect(tengeInWordsRu(11000), 'Одиннадцать тысяч тенге 00 тиын');
    expect(tengeInWordsRu(21000), 'Двадцать одна тысяча тенге 00 тиын');
  });

  test('millions, teens, tiyn and nothing at all', () {
    expect(
      tengeInWordsRu(1_212_014.5),
      'Один миллион двести двенадцать тысяч четырнадцать тенге 50 тиын',
    );
    expect(tengeInWordsRu(3_000_002), 'Три миллиона два тенге 00 тиын');
    expect(
      tengeInWordsRu(17083),
      'Семнадцать тысяч восемьдесят три тенге 00 тиын',
    );
    expect(tengeInWordsRu(0), 'Ноль тенге 00 тиын');
  });
}
