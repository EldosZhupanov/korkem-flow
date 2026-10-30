import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/press_layout/domain/press_layout.dart';
import 'package:korkem_flow/features/press_layout/presentation/press_print.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const press = PressSettings(
    lengthMm: 2850,
    widthMm: 1210,
    marginMm: 50,
    gapMm: 60,
    sections: [(filmM: 3.1, lengthMm: 2850)],
  );

  FilmLayout film({required bool textured, int loads = 1}) => FilmLayout(
    decor: textured ? 'AS 1804-SFT Какао нубук' : 'ZB 852-2 Авори',
    title: '№1110 Дастан Жақсылықов ZB 852-2 Авори (GreenWood)',
    textured: textured,
    layoutM: 3.1 * loads,
    filmM: 3.1 * loads,
    loads: [
      for (var i = 0; i < loads; i++)
        const PressLoad(
          filmM: 3.1,
          lengthMm: 2850,
          placed: [
            PlacedPart(pos: 1, x: 50, y: 50, width: 598, height: 298),
            PlacedPart(pos: 2, x: 708, y: 50, width: 718, height: 298),
          ],
        ),
    ],
  );

  final words = (
    textured: 'ТЕКСТУРА — НЕ ВРАЩАТЬ',
    plain: 'Однотонная — можно вращать',
    total: (String m) => 'Плёнка: $m м',
    sheet: (int n) => 'Лист № $n',
    copies: (int n) => 'Кол-во копий: $n',
    size: (String s) => 'Размер: $s мм',
    section: (String m) => 'Секция плёнки: $m м',
    area: (String a) => 'S листа: $a м²',
    parts: (String a, String s) => 'S деталей: $a м² ($s%)',
    waste: (String a, String s) => 'Отходы: $a м² ($s%)',
    count: (int n) => 'Кол-во деталей: $n',
    perimeter: (String m) => 'Периметр деталей: $m м',
    gap: (String g, String m) => 'Зазор: $g мм · отступ: $m мм',
    details: 'Детали',
    tooBig: (String p) => 'Больше стола пресса: позиции $p',
    page: (int n) => 'Стр. $n',
  );

  PressLoad load(int second) => PressLoad(
    filmM: 3.1,
    lengthMm: 2850,
    placed: [
      const PlacedPart(pos: 1, x: 50, y: 50, width: 598, height: 298),
      PlacedPart(pos: 2, x: 708, y: 50, width: second.toDouble(), height: 298),
    ],
  );

  test('identical loads print once with a copy count', () {
    final groups = groupLoads([load(718), load(718), load(500)]);
    expect(groups.map((g) => g.copies), [2, 1]);
    expect(groups.last.load.placed.last.width, 500);
  });

  test(
    'the map prints as a PDF, two loads to an A4 page, Cyrillic included',
    () async {
      final bytes = await buildPressPdf(
        [film(textured: false, loads: 2), film(textured: true)],
        press,
        words,
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    },
  );
}
