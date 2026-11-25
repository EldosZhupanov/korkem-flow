import 'package:korkem_flow/features/team/data/people_report_repository.dart';
import 'package:korkem_flow/features/team/domain/people_report.dart';

const Map<String, Object?> _erlan = {
  'employee': 'HR-EMP-00001',
  'name': 'Ерлан Сапаров',
  'user': 'erlan@korkem.kz',
  'post_titles': ['Раскройщик'],
  'stages': [
    {'stage': 'cut', 'orders': 14, 'm2': 42.5},
  ],
  'stages_done': 14,
  'm2': 42.5,
  'orders': 14,
  'days': 18,
  'money': {
    'earned': 212500,
    'piece': 197500,
    'pending': 4000,
    'daily_bonus': 15000,
    'monthly_bonus': 0,
    'bonus': 0,
    'fine': 5000,
    'advance': 80000,
    'to_pay': 127500,
    'paid': 0,
    'left': 127500,
  },
};

const Map<String, Object?> _aset = {
  'employee': 'HR-EMP-00002',
  'name': 'Асет Нурланов',
  'user': null,
  'post_titles': ['Шлифовщик'],
  'stages': [
    {'stage': 'sand', 'orders': 9, 'm2': 27.0},
  ],
  'stages_done': 9,
  'm2': 27.0,
  'orders': 9,
  'days': 12,
  'money': null,
};

/// A shop's people for a month — for the widget tests and the design shots.
class FakePeople implements PeopleReportRepository {
  final reports = <PeopleQuery>[];
  final cards = <PersonQuery>[];

  @override
  Future<PeopleReport> report(PeopleQuery q) async {
    reports.add(q);
    return PeopleReport.fromJson(const {
      'people': [_erlan, _aset, ..._more],
      'total': {
        'm2': 69.5,
        'stages_done': 23,
        'earned': 212500,
        'advance': 80000,
        'left': 127500,
      },
    });
  }

  @override
  Future<PersonCard> card(PersonQuery q) async {
    cards.add(q);
    if (q.employee == _aset['employee']) {
      return PersonCard.fromJson(const {
        ..._aset,
        'by_day': <Map<String, Object>>[],
      });
    }
    return PersonCard.fromJson({
      ..._erlan,
      'by_day': [
        for (var d = 1; d <= 30; d++)
          {
            'day': '2026-11-${d.toString().padLeft(2, '0')}',
            'm2': d.isEven ? 3.0 : 0,
            'earned': d.isEven ? 15000 : 0,
          },
      ],
      'works': const [
        {
          'order': 'SAL-ORD-2026-00245',
          'number': 245,
          'customer': 'Арман Қалдыбаев',
          'stage': 'cut',
          'on': '2026-11-24',
          'm2': 3.04,
        },
      ],
      'entries': const [
        {
          'on': '2026-11-24',
          'operation': 'Раскрой',
          'quantity': 3.04,
          'unit': 'м²',
          'amount': 4560,
          'status': 'Approved',
        },
      ],
      'adjustments': const [
        {
          'on': '2026-11-15',
          'kind': 'Аванс',
          'amount': 80000,
          'status': 'Approved',
        },
        {
          'on': '2026-11-20',
          'kind': 'Штраф',
          'amount': 5000,
          'reason': 'брак: скол на фасаде',
          'status': 'Approved',
        },
      ],
      'payouts': const <Map<String, Object>>[],
      'me': false,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const List<Map<String, Object?>> _more = [
  {
    'employee': 'HR-EMP-00003',
    'name': 'Нұрсұлтан Жақсыбеков',
    'user': 'nursultan@korkem.kz',
    'post_titles': ['Фрезеровщик ЧПУ', 'Шлифовщик'],
    'stages': [
      {'stage': 'mill', 'orders': 11, 'm2': 31.2},
      {'stage': 'sand', 'orders': 4, 'm2': 9.6},
    ],
    'stages_done': 15,
    'm2': 40.8,
    'orders': 13,
    'days': 16,
    'money': {'earned': 184000, 'advance': 100000, 'left': 84000},
  },
  {
    'employee': 'HR-EMP-00004',
    'name': 'Дана Вакуумова',
    'user': 'dana@korkem.kz',
    'post_titles': ['Вакуумщица'],
    'stages': [
      {'stage': 'vacuum', 'orders': 7, 'm2': 18.4},
    ],
    'stages_done': 7,
    'm2': 18.4,
    'orders': 7,
    'days': 9,
    'money': {'earned': 92000, 'advance': 0, 'left': 92000},
  },
  {
    'employee': 'HR-EMP-00005',
    'name': 'Айгерим Приёмова',
    'user': 'aigerim@korkem.kz',
    'post_titles': ['Менеджер приёма'],
    'stages': <Map<String, Object>>[],
    'stages_done': 0,
    'm2': 0,
    'orders': 0,
    'days': 0,
    'money': {'earned': 0, 'advance': 30000, 'left': -30000},
  },
];
