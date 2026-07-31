import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/kpi_tile.dart';

import '../../support/widget_harness.dart';

/// What TalkBack reads out on the home screen.
///
/// The dashboard is six figures, and a figure without its label is not a fact.
/// Left unmerged, a screen-reader user swiping across it hears "Открытые
/// сделки", then "266", then "Лиды", then "424" — four stops for two facts,
/// with every number meaningful only because of what happened to be read
/// before it.
void main() {
  /// The distinct things a screen reader would read out.
  ///
  /// Distinct, because a merged node reports its combined label at more than
  /// one point in the tree — the duplicate is an artefact of walking, not
  /// something anyone hears twice.
  Future<Set<String>> announced(WidgetTester tester, Widget tile) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(SizedBox(width: 187, height: 120, child: tile)),
    );
    await tester.pumpAndSettle();

    final labels = <String>{};

    void walk(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.label.isNotEmpty) labels.add(data.label);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(KpiTile)));

    handle.dispose();
    return labels;
  }

  testWidgets('a metric is one announcement, not two', (tester) async {
    final labels = await announced(
      tester,
      const KpiTile(
        label: 'Открытые сделки',
        value: 266,
        icon: AppIcons.deal,
      ),
    );

    // One announcement carrying both facts, rather than two carrying one each.
    expect(labels, hasLength(1));
    expect(labels.single, contains('Открытые сделки'));
    expect(labels.single, contains('266'));
  });

  testWidgets('a withheld figure is announced as such, not as a number', (
    tester,
  ) async {
    final labels = await announced(
      tester,
      const KpiTile(
        label: 'Ждут решения',
        value: null,
        icon: AppIcons.approval,
      ),
    );

    // Null means the signed-in role may not see this number. It must not be
    // read as zero, and the dash carries that.
    expect(labels.single, contains('Ждут решения'));
    expect(labels.single, isNot(contains('0')));
  });

  testWidgets('a loading tile says nothing rather than nonsense', (
    tester,
  ) async {
    final labels = await announced(
      tester,
      const KpiTile(
        label: 'Открытые сделки',
        value: 266,
        icon: AppIcons.deal,
        isLoading: true,
      ),
    );

    // The shimmering box has nothing to say, and the figure behind it is not
    // on screen yet — announcing it would be reading out data the user cannot
    // see.
    expect(labels.single, 'Открытые сделки');
  });
}
