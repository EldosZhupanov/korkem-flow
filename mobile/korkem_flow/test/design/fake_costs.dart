import 'package:korkem_flow/features/costs/data/costs_repository.dart';
import 'package:korkem_flow/features/costs/domain/costs.dart';

/// A shop's month, bills, shelf and cost items — for the design shots.
class FakeCosts implements CostsRepository {
  FakeCosts({this.owner = true});

  final bool owner;
  final months = <String>[];
  final put = <(String, String, double, double?, double?)>[];
  final taken = <(String, double)>[];
  final added = <String>[];
  final saved = <(String?, String, CostMode, bool)>[];
  final merged = <(String, String)>[];

  @override
  Future<MoneyFlow> money(String month) async {
    months.add(month);
    return MoneyFlow.fromJson(const {
      'month': '2026-11-01',
      'revenue': 4200000,
      'orders': 31,
      'm2': 920,
      'costs': 3444000,
      'profit': 756000,
      'profit_share': 18,
      'groups': [
        {'group': 'Сырьё', 'amount': 1848000, 'share': 44},
        {'group': 'Зарплата', 'amount': 1008000, 'share': 24},
        {'group': 'Коммуналка', 'amount': 378000, 'share': 9},
        {'group': 'Расходники', 'amount': 210000, 'share': 5},
      ],
      'items': [
        {
          'key': 'Сырьё',
          'title': 'Сырьё',
          'group': 'Сырьё',
          'behaviour': 'variable',
          'amount': 1848000,
        },
        {
          'key': 'CI-POWER',
          'item': 'CI-POWER',
          'title': 'Электричество',
          'group': 'Коммуналка',
          'area': 'Весь цех',
          'behaviour': 'fixed',
          'amount': 238000,
          'usual': 190000,
          'limit': 200000,
          'used': 3700,
        },
      ],
      'areas': [
        {'area': 'Весь цех', 'amount': 238000},
      ],
      'cost_per_m2': 3743,
      'overhead_per_m2': 640,
      'fixed': 900000,
      'variable': 2544000,
      'break_even_m2': 610,
      'alerts': [
        {
          'kind': 'limit',
          'title': 'Электричество',
          'amount': 238000,
          'limit': 200000,
          'over': 19,
        },
        {
          'kind': 'jump',
          'title': 'Наждачная бумага',
          'amount': 42000,
          'usual': 20000,
          'times': 2.1,
        },
      ],
    });
  }

  @override
  Future<CostBills> bills(String month) async => CostBills.fromJson(const {
    'month': '2026-11-01',
    'total': 400000,
    'filled': 1,
    'bills': [
      {
        'item': 'CI-RENT',
        'title': 'Аренда цеха',
        'group': 'Аренда',
        'amount': 400000,
        'last_amount': 400000,
      },
      {
        'item': 'CI-POWER',
        'title': 'Электричество',
        'group': 'Коммуналка',
        'unit': 'кВт·ч',
        'last_amount': 185000,
        'meter_start': 44900,
      },
    ],
  });

  @override
  Future<CostBills> putBill(
    String item, {
    required String month,
    required double amount,
    double? meterFrom,
    double? meterTo,
    String? note,
  }) async {
    put.add((item, month, amount, meterFrom, meterTo));
    return bills(month);
  }

  @override
  Future<Consumables> consumables() async => Consumables.fromJson({
    'can_receive': owner,
    'low': 1,
    'items': [
      {
        'item': 'CI-KNIFE',
        'title': 'Нож для раскроя',
        'unit': 'шт',
        'on_hand': 1,
        'minimum': 3,
        'low': true,
        'taken_30d': 6,
        'price': owner ? 2500 : null,
      },
      {
        'item': 'CI-STRETCH',
        'title': 'Стрейч-плёнка',
        'unit': 'рулон',
        'on_hand': 4,
        'minimum': 2,
        'price': owner ? 4000 : null,
      },
    ],
  });

  @override
  Future<Consumables> take(String item, double qty, {String? note}) async {
    taken.add((item, qty));
    return consumables();
  }

  @override
  Future<CostItem> quickAdd(String title, {String? unit}) async {
    added.add('$title/$unit');
    return CostItem(name: 'NEW', title: title, group: 'Расходники');
  }

  @override
  Future<CostCatalog> items({bool archived = false}) async =>
      CostCatalog.fromJson(const {
        'groups': ['Сырьё', 'Расходники', 'Коммуналка'],
        'areas': ['Весь цех', 'Раскрой', 'Упаковка'],
        'items': [
          {
            'name': 'CI-POWER',
            'title': 'Электричество',
            'group': 'Коммуналка',
            'mode': 'bill',
            'behaviour': 'fixed',
            'area': 'Весь цех',
            'monthly_limit': 200000,
          },
          {
            'name': 'CI-KNIFE',
            'title': 'Нож для раскроя',
            'group': 'Расходники',
            'mode': 'stock',
            'area': 'Раскрой',
          },
          {
            'name': 'CI-KNIVES',
            'title': 'Ножи',
            'group': 'Расходники',
            'mode': 'stock',
            'new': true,
          },
        ],
      });

  @override
  Future<CostItem> saveItem({
    required String title,
    required String group,
    required CostMode mode,
    required bool fixed,
    required String area,
    String? name,
    String unit = '',
    double monthlyLimit = 0,
  }) async {
    saved.add((name, title, mode, fixed));
    return CostItem(name: name ?? 'NEW', title: title, group: group);
  }

  @override
  Future<CostItem> merge(String source, String target) async {
    merged.add((source, target));
    return CostItem(name: target, title: target, group: 'Расходники');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
