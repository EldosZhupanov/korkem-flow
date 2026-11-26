import 'package:korkem_flow/features/mdf/domain/mdf_plan.dart';
import 'package:korkem_flow/features/mdf/domain/shop_board.dart';

/// «Жоспар»'s queues, for the design shots of «Цех».
final fakePlan = MdfPlan.fromJson(const {
  'stages': [
    {
      'stage': 'cut',
      'area_m2': 3.04,
      'orders': [
        {
          'name': 'SAL-ORD-1129',
          'customer_name': 'Арман',
          'delivery_date': '2026-11-10',
          'decor_top': 'Венге (Korkem)',
          'area_m2': 3.04,
          'overdue': true,
          'days_left': -1,
          'stages_left': 4,
          'at_risk': false,
        },
        {
          'name': 'SAL-ORD-40',
          'customer_name': 'Ерлан',
          'delivery_date': '2026-11-09',
          'area_m2': 1.2,
          'days_left': 1,
          'stages_left': 5,
          'at_risk': true,
          'tags': ['urgent'],
        },
      ],
    },
    {'stage': 'mill', 'area_m2': 0, 'orders': <Object>[]},
    {
      'stage': 'vacuum',
      'area_m2': 9.6,
      'orders': [
        {
          'name': 'SAL-ORD-36',
          'customer_name': 'Тұрсын',
          'delivery_date': '2026-11-12',
          'area_m2': 9.6,
          'days_left': 4,
          'stages_left': 1,
        },
      ],
    },
  ],
  'intake': [
    {'date': '2026-11-06', 'orders': 2, 'area_m2': 12.64},
  ],
  'in_work_m2': 12.64,
});

/// «Цех»'s board for the shots.
final fakeBoard = ShopBoard.fromJson(const {
  'month': {
    'plan_m2': 400,
    'plan_from': 'due',
    'done_m2': 260,
    'expected_m2': 333,
    'forecast_m2': 312,
    'in_shop_m2': 85,
    'in_shop_orders': 31,
    'taken_m2': 350,
    'taken_orders': 112,
  },
  'stages': [
    {
      'stage': 'cut',
      'waiting_m2': 4.24,
      'waiting_orders': 2,
      'today_m2': 9,
      'month_m2': 305,
      'per_day_m2': 10,
      'days': 0.4,
      'posts': [
        {
          'post': 'cut.cutter',
          'title': 'Раскройщик',
          'people': [
            {
              'employee': 'HR-1',
              'name': 'Владимир',
              'today_m2': 9,
              'in_work': 3,
            },
          ],
        },
      ],
    },
    {
      'stage': 'mill',
      'waiting_m2': 24,
      'today_m2': 6,
      'days': 3.0,
      'jam': true,
      'posts': [
        {'post': 'cnc.operator', 'title': 'ЧПУшник', 'people': <Object>[]},
      ],
      'nobody': true,
    },
    {
      'stage': 'sand',
      'waiting_m2': 7,
      'waiting_orders': 3,
      'month_m2': 270,
      'posts': [
        {
          'post': 'pvc.sander',
          'title': 'Шкурщик ПВХ',
          'department': 'ПВХ плёнка',
          'people': <Object>[],
        },
        {
          'post': 'paint.sander',
          'title': 'Шкурщик покраски',
          'department': 'Покраска',
          'people': <Object>[],
        },
      ],
      'nobody': true,
    },
    {
      'stage': 'vacuum',
      'waiting_m2': 9.6,
      'waiting_orders': 1,
      'today_m2': 4,
      'month_m2': 180,
      'days': 1.2,
      'posts': [
        {
          'post': 'pvc.vacuum',
          'title': 'Вакуумщик',
          'people': [
            {'employee': 'HR-2', 'name': 'Ералы', 'today_m2': 4, 'in_work': 1},
            {'employee': 'HR-3', 'name': 'Тима'},
          ],
        },
      ],
    },
    {
      'stage': 'paint',
      'waiting_m2': 2,
      'posts': [
        {'post': 'paint.painter', 'title': 'Маляр', 'people': <Object>[]},
      ],
      'nobody': true,
    },
    {
      'stage': 'ready',
      'waiting_m2': 11,
      'month_m2': 260,
      'posts': [
        {'post': 'pack.packer', 'title': 'Упаковщик', 'people': <Object>[]},
      ],
      'nobody': true,
    },
  ],
  'late': [
    {
      'order': 'SAL-ORD-1129',
      'number': 1129,
      'customer': 'Арман',
      'stage': 'cut',
      'delivery_date': '2026-11-10',
      'area_m2': 3.04,
      'overdue': true,
    },
  ],
  'side': [
    {
      'department': 'film_sales',
      'title': 'Продажа плёнки',
      'sales_today': 4,
      'metres_today': 120,
      'posts': [
        {
          'post': 'film_sales.seller',
          'title': 'Продажник',
          'people': <Object>[],
        },
      ],
    },
  ],
});
