import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_patterns.dart';
import 'package:korkem_flow/features/cnc_patterns/domain/cnc_relief.dart';

/// The groove each cutter leaves, and the facade read back from it
/// (owner, 20.11.2026: «разрез и 3D, как в Tez3D»).
void main() {
  const v90 = CncTool(name: 'V90');
  const ball = CncTool(name: 'R3', kind: CncToolKind.ball, diameter: 6);
  const flat = CncTool(name: 'F6', kind: CncToolKind.flat, diameter: 6);

  test('a V leaves a wedge, a ball a trough, a straight one a slot', () {
    expect(cncCutAt(v90, 4, 8, 0), 4);
    expect(cncCutAt(v90, 4, 8, 1), closeTo(3, 1e-9));
    expect(cncCutAt(v90, 4, 8, 4), 0);
    expect(cncCutAt(ball, 3, 6, 0), 3);
    expect(cncCutAt(ball, 3, 6, 3), 0);
    expect(cncCutAt(ball, 2, 6, 0), 2);
    expect(cncCutAt(flat, 5, 6, 2.9), 5);
    expect(cncCutAt(flat, 5, 6, 3.1), 0);
    // No card for the cutter: a slot as wide as the server said.
    expect(cncCutAt(null, 2, 10, 4.9), 2);
    expect(cncCutAt(null, 2, 10, 5.1), 0);
  });

  test('an older server sent the width alone: the depth is read off it', () {
    const cut = CncCut(tool: 'V90', width: 8, closed: false, points: []);
    expect(cncDepthOf(cut, v90), closeTo(4, 1e-9));
    expect(cncDepthOf(cut, null), 0);
  });

  const frame = CncCut(
    tool: 'V90',
    width: 8,
    depth: 4,
    closed: true,
    points: [Offset(60, 60), Offset(440, 60), Offset(440, 640), Offset(60, 640)],
  );

  test('the section: the wedge at 60 from the edge, nothing past it', () {
    final s = CncSection.of(
      width: 500,
      height: 700,
      cuts: const [frame],
      tools: const {'V90': v90},
    );
    expect(s.deepest, closeTo(4, 1e-6));
    final (from, to) = s.span!;
    expect(from, closeTo(56, 0.3));
    expect(to, closeTo(64, 0.3));
    expect(s.depths[(100 / s.step).round()], 0);
    expect(
      CncSection.of(width: 500, height: 700, cuts: const [], tools: const {})
          .span,
      isNull,
    );
  });

  test('the relief: the closed frame cut all round, the middle untouched', () {
    final r = CncRelief.of(
      width: 500,
      height: 700,
      cuts: const [frame],
      tools: const {'V90': v90},
      nodes: 20000,
    );
    expect((r.cols + 1) * (r.rows + 1), lessThan(65536));
    expect(r.deepest, greaterThan(3));
    // The closing side, from (60, 640) back to (60, 60).
    final j = (350 / r.step).round();
    final i = (60 / r.step).round();
    expect(r.at(i, j), greaterThan(2));
    expect(r.at((250 / r.step).round(), j), 0);
  });
}
