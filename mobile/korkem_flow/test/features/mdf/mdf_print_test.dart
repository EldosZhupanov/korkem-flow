import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_dictionaries.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_order.dart';
import 'package:korkem_flow/features/mdf/presentation/mdf_print.dart';

/// The owner's №1129, Kazakh names and all, on paper.
const Map<String, Object?> _orderJson = {
  'name': 'SAL-ORD-1129',
  'status': 'accepted',
  'customer': 'Арман Қалдыбаев',
  'customer_name': 'Арман Қалдыбаев',
  'phone': '8 (777) 177-66-36',
  'created_on': '2026-10-27',
  'delivery_date': '2026-11-10',
  'head': {
    'thickness_mm': 16,
    'finish': 'Пленка ПВХ',
    'decor_top': 'Венге (Korkem)',
    'edge_profile': 'R3',
  },
  'lines': [
    {
      'height_mm': 130,
      'width_mm': 1040,
      'qty': 1,
      'milling': 'Тегіс 90°',
      'area_m2': 0.14,
      'rate_m2': 17000,
      'amount': 2380,
    },
    {
      'height_mm': 1577,
      'width_mm': 517,
      'qty': 2,
      'milling': 'Суреттегі үлгі',
      'area_m2': 1.63,
      'rate_m2': 19500,
      'amount': 31785,
    },
  ],
  'pieces': 3,
  'area_m2': 1.77,
  'total': 34165,
  'paid': 0,
  'debt': 34165,
  'payments': <Object>[],
  'stages': <Object>[],
};

final _order = MdfOrder.fromJson(_orderJson);

final MdfPrintWords _words = (
  title: (name) => 'Тапсырыс №$name',
  accepted: 'Қабылданған күні',
  due: 'Аяқтау',
  customer: 'Тапсырушы',
  phone: 'Телефон',
  thickness: 'Фасад қалыңдығы',
  finish: 'Беті',
  decorTop: 'Түсі (үсті)',
  decorBottom: 'Түсі (асты)',
  patina: 'Зеңжар',
  milling: 'Беткі нақыш',
  edge: 'Шеткі нақыш',
  extraName: 'Қосымша атауы',
  paid: 'Кепілақы',
  debt: 'Қалдық',
  note: 'Ескерту',
  height: 'Биіктігі',
  width: 'Ені',
  qty: 'Саны',
  area: 'Ауданы, м²',
  rate: 'Бағасы',
  amount: 'Сомасы',
  total: 'Барлығы:',
  material: 'Материал',
  film: 'Пленка',
  back: 'асты',
  subtotal: 'Барлығы',
  coating: (c) => c.name,
  materialColumn: 'Матер.',
  client: 'клиента',
  pieces: 'дана',
  radius: 'R',
  thicknessColumn: 'Қалыңдығы',
  tags: 'Белгілер',
  tag: (t) => t.wire,
  weekday: (d) => 'бейсенбі',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an urgent warranty order prints its tags on both copies', () async {
    final order = MdfOrder.fromJson({
      ..._orderJson,
      'head': {
        ...(_orderJson['head']! as Map<String, Object?>),
        'tags': const ['urgent', 'warranty'],
      },
    });
    expect(order.tags, [MdfOrderTag.urgent, MdfOrderTag.warranty]);
    for (final withPrices in [true, false]) {
      final bytes = await buildMdfOrderPdf(
        order,
        _words,
        withPrices: withPrices,
      );
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    }
  });

  test("a position's back side and patina go under its coating", () {
    const plain = MdfLine(
      heightMm: 100,
      widthMm: 100,
      qty: 1,
      areaM2: 0.01,
      rateM2: 0,
      amount: 0,
      note: '  ',
    );
    expect(mdfCoatingExtras(plain, back: 'обр.', patina: 'Патина'), isEmpty);
    expect(mdfLineNote(plain), isNull);
    const rich = MdfLine(
      heightMm: 100,
      widthMm: 100,
      qty: 1,
      areaM2: 0.01,
      rateM2: 0,
      amount: 0,
      filmBack: 'Графит',
      patina: 'Золото',
      note: ' Продолжение узора ',
    );
    expect(mdfCoatingExtras(rich, back: 'обр.', patina: 'патина'), [
      'Обр.: Графит',
      'Патина: Золото',
    ]);
    expect(mdfLineNote(rich), 'Продолжение узора');
  });

  for (final withPrices in [true, false]) {
    test(
      'the ${withPrices ? 'customer' : 'shop'} copy prints as a PDF',
      () async {
        final bytes = await buildMdfOrderPdf(
          _order,
          _words,
          withPrices: withPrices,
        );
        expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(1000));
      },
    );
  }

  test('an order of several films prints each film with its total', () async {
    final order = MdfOrder.fromJson({
      for (final e in _orderJson.entries)
        if (e.key != 'lines') e.key: e.value,
      'lines': const [
        {
          'height_mm': 718,
          'width_mm': 500,
          'qty': 2,
          'area_m2': 0.72,
          'rate_m2': 17000,
          'amount': 12240,
          'film': 'Белый Матовый',
          'material': '16 мм МДФ',
        },
        {
          'height_mm': 300,
          'width_mm': 400,
          'qty': 2,
          'area_m2': 0.24,
          'rate_m2': 21000,
          'amount': 5040,
          'film': 'Палома',
          'coating': 'pvc',
          'film_back': 'Графит',
          'material': '10 мм МДФ',
          'edge': 'R0',
          'patina': 'Алтын',
        },
      ],
    });
    final groups = mdfFilmGroups(order.lines);
    expect([for (final g in groups) g.film], ['Белый Матовый', 'Палома']);
    expect(groups.last.lines.single.$1, 2);
    expect(groups.last.lines.single.$2.edge, 'R0');
    expect(groups.last.lines.single.$2.patina, 'Алтын');
    final bytes = await buildMdfOrderPdf(order, _words, withPrices: false);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('edges and materials sort naturally in the head', () {
    final edges = ['R3', 'Полукруг', 'R10', 'R0', 'Фаска 45°', 'R1']
      ..sort(mdfNaturalCompare);
    expect(edges, ['R0', 'R1', 'R3', 'R10', 'Полукруг', 'Фаска 45°']);
    final materials = ['ХДФ', 'МДФ', 'ЛМДФ']..sort(mdfNaturalCompare);
    expect(materials, ['ЛМДФ', 'МДФ', 'ХДФ']);
  });
}
