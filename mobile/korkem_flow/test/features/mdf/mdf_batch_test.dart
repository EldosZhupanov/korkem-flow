import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/mdf/domain/mdf_batch.dart';

void main() {
  test('a batch reads its parts long side first, with the orders behind', () {
    final batch = MdfBatch.fromJson(const {
      'orders': [
        {'name': 'SAL-ORD-1129', 'customer_name': 'Арман'},
        {'name': 'SAL-ORD-1130', 'customer_name': 'Бауржан'},
      ],
      'parts': [
        {
          'long_mm': 1040,
          'short_mm': 130,
          'qty': 4,
          'area_m2': 0.56,
          'milling': 'Тегіс 90°',
          'orders': ['SAL-ORD-1129', 'SAL-ORD-1130'],
        },
      ],
      'pieces': 4,
      'area_m2': 0.56,
    });
    expect(batch.orders, ['SAL-ORD-1129 · Арман', 'SAL-ORD-1130 · Бауржан']);
    final part = batch.parts.single;
    expect((part.longMm, part.shortMm, part.qty), (1040, 130, 4));
    expect(part.orders, hasLength(2));
  });
}
