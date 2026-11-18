import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/settings/settings_controller.dart';
import 'package:korkem_flow/features/search/data/smart_search_repository.dart';
import 'package:korkem_flow/features/search/domain/search_text.dart';
import 'package:korkem_flow/features/search/domain/smart_search.dart';
import 'package:meta/meta.dart';

/// The general search's answer for one query (owner, 18.11.2026, variant Б).
///
/// One request to the server — customers, orders, money, film, stock —
/// instead of the five this window used to make. Too little typed is no
/// question yet: the window shows the recent and the actions instead.
// AutoDisposeFutureProviderFamily is not exported as a public type.
// ignore: specify_nonobvious_property_types
final smartSearchProvider = FutureProvider.autoDispose
    .family<SmartSearch, String>((ref, query) async {
      final clean = query.trim();
      if (SearchText.fold(clean).length < 2 && !_isNumber(clean)) {
        return const SmartSearch();
      }
      return ref.watch(smartSearchRepositoryProvider).find(clean);
    });

bool _isNumber(String text) => RegExp(r'^[№#]?\s*\d+$').hasMatch(text);

/// What the window can do rather than find (owner, 18.11.2026): typed as a
/// word — «продать клей», «новый заказ» — it is offered at the top.
enum SearchAction {
  newFacadeOrder,
  newCncOrder,
  sellFilm,
  sellGlue,
  receiveFilm,
  receiveGlue;

  /// The words that find it, in every language the shop speaks — a person
  /// with the menu in Kazakh may still type Russian.
  List<String> get keywords => switch (this) {
    newFacadeOrder => const [
      'новый заказ фасад',
      'создать заказ',
      'жаңа тапсырыс фасад',
      'new facade order',
    ],
    newCncOrder => const [
      'новый заказ чпу',
      'фрезеровка заказ',
      'жаңа тапсырыс чпу',
      'new cnc order',
    ],
    sellFilm => const [
      'продать плёнку продажа плёнки',
      'үлдір сату',
      'sell film',
    ],
    sellGlue => const [
      'продать клей продажа клея',
      'желім сату',
      'sell glue',
    ],
    receiveFilm => const [
      'приход плёнки принять плёнку',
      'үлдір кірісі',
      'receive film',
    ],
    receiveGlue => const [
      'приход клея принять клей',
      'желім кірісі',
      'receive glue',
    ],
  };

  bool allowedBy(SearchAllowed a) => switch (this) {
    newFacadeOrder => a.facades,
    newCncOrder => a.cnc,
    sellFilm || sellGlue => a.film,
    receiveFilm || receiveGlue => a.filmEdit,
  };
}

/// The actions that answer [query], or — for an empty one — every action
/// this person may take, to start from.
List<SearchAction> searchActions(
  String query,
  SearchAllowed allowed, {
  required String Function(SearchAction action) labelOf,
}) => [
  for (final a in SearchAction.values)
    if (a.allowedBy(allowed) &&
        (query.trim().isEmpty ||
            SearchText.matches(query, [labelOf(a), ...a.keywords])))
      a,
];

/// What the window already knows a person may do, before he types: the
/// last answer's permissions, kept while the window lives.
// ignore: specify_nonobvious_property_types
final searchAllowedProvider = FutureProvider.autoDispose<SearchAllowed>(
  (ref) async =>
      (await ref.watch(smartSearchRepositoryProvider).find('')).allowed,
);

/// One thing opened from the window, to be offered again.
@immutable
class SearchRecent {
  const SearchRecent({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.data,
  });

  factory SearchRecent.fromJson(Map<String, dynamic> j) => SearchRecent(
    kind: '${j['kind']}',
    id: '${j['id']}',
    title: '${j['title'] ?? ''}',
    subtitle: j['subtitle'] as String?,
    data: j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : null,
  );

  /// Which kind of thing: `customer`, `facadeOrder`, `cncOrder`, `film`,
  /// `decor`, `order`, `workOrder`, `stock`, `section`.
  final String kind;
  final String id;
  final String title;
  final String? subtitle;

  /// What reopening it needs beyond the id — a customer's film card.
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    'title': title,
    'subtitle': ?subtitle,
    'data': ?data,
  };
}

final searchRecentsProvider =
    NotifierProvider<SearchRecentsNotifier, List<SearchRecent>>(
      SearchRecentsNotifier.new,
    );

/// The last things opened from the search window, on this device only.
class SearchRecentsNotifier extends Notifier<List<SearchRecent>> {
  static const _key = 'search.global.recent';
  static const _limit = 8;

  @override
  List<SearchRecent> build() {
    final raw =
        ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];
    final out = <SearchRecent>[];
    for (final item in raw) {
      try {
        final json = jsonDecode(item);
        if (json is Map) {
          out.add(SearchRecent.fromJson(Map<String, dynamic>.from(json)));
        }
      } on FormatException {
        // A line from an older build: skipped, not fatal.
      }
    }
    return out;
  }

  void record(SearchRecent recent) {
    final next = [
      recent,
      ...state.where((r) => !(r.kind == recent.kind && r.id == recent.id)),
    ].take(_limit).toList();
    state = next;
    unawaited(
      ref.read(sharedPreferencesProvider).setStringList(_key, [
        for (final r in next) jsonEncode(r.toJson()),
      ]),
    );
  }

  void clear() {
    state = const [];
    unawaited(ref.read(sharedPreferencesProvider).remove(_key));
  }
}
