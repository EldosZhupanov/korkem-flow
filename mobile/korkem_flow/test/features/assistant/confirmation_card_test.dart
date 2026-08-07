import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/confirmation_card.dart';

import '../../support/widget_harness.dart';

/// The confirmation card, against a tool it was never written for.
///
/// `ConfirmationCard` was built for `crm.create_lead`. If the abstraction
/// holds, `crm.create_task` — six arguments, a reference to another record, a
/// due date — must render through it with no widget change at all. That is the
/// property these tests exist to pin: adding a write tool should be a backend
/// change, not a UI one.
void main() {
  const request = AssistantNeedsConfirmation(
    text: 'I can create that task.',
    turnId: 't1',
    calls: [
      PendingToolCall(
        id: 'PA-abc',
        tool: 'crm.create_task',
        arguments: {
          'title': 'Позвонить клиенту Мебель Астана',
          'assigned_to': 'crm.supervisor@example.com',
          'priority': 'High',
          'due_date': '2026-09-10 10:00:00',
          'reference_doctype': 'CRM Deal',
          'reference_docname': '_T-CRM Deal-00802',
        },
      ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Locale locale = const Locale('ru'),
  }) => tester.pumpWidget(
    ProviderScope(
      child: harness(
        const ConfirmationCard(request: request),
        brightness: brightness,
        textScale: textScale,
        locale: locale,
      ),
    ),
  );

  testWidgets('names the tool and every argument it would run with', (
    tester,
  ) async {
    // "Approve" on an unnamed action is not consent. The whole value of the
    // pause is that a person can see what the model decided to do.
    await pump(tester);

    expect(find.text('crm.create_task'), findsOneWidget);
    expect(
      find.textContaining('Позвонить клиенту Мебель Астана'),
      findsOneWidget,
    );
    expect(find.textContaining('_T-CRM Deal-00802'), findsOneWidget);
    expect(find.textContaining('crm.supervisor@example.com'), findsOneWidget);
    expect(find.textContaining('2026-09-10 10:00:00'), findsOneWidget);
  });

  testWidgets('offers both answers, and defaults to neither', (tester) async {
    await pump(tester);

    expect(find.text('Подтвердить'), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);
  });

  testWidgets('renders in Kazakh', (tester) async {
    await pump(tester, locale: const Locale('kk'));

    expect(find.text('Растау'), findsOneWidget);
    expect(find.text('Болдырмау'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('lays out without overflow in ${brightness.name}', (
      tester,
    ) async {
      await pump(tester, brightness: brightness);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('survives 1.6x text without overflowing', (tester) async {
    // The row of two buttons is the part that breaks first, which is why it is
    // a Wrap rather than a Row.
    await pump(tester, textScale: 1.6);

    expect(tester.takeException(), isNull);
  });

  testWidgets('is announced as one thing to a screen reader', (tester) async {
    await pump(tester);

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Подтвердите действие'),
    );
    expect(semantics, isNotNull);
  });
}
