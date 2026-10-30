import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_composer.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Диктовка, которой можно управлять из теста.
class _FakeDictation implements ChatDictation {
  _FakeDictation({this.ready = true});

  final bool ready;
  int readyAsked = 0;
  int startCalls = 0;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> ensureReady() async {
    readyAsked++;
    return ready;
  }

  @override
  Future<void> start(ValueChanged<String> onResult) async {
    startCalls++;
    _listening = true;
    onResult('сказано голосом');
  }

  @override
  Future<void> stop() async => _listening = false;
}

Widget _harness(ChatDictation? dictation) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChatComposer(onSend: (_) {}, enabled: true, dictation: dictation),
    ),
  );
}

void main() {
  group('Микрофон в поле ввода ассистента', () {
    // Владелец описал продукт словами «цифровой администратор, которому я могу
    // сказать всё голосом». Кнопки при этом на экране не было: композер рисовал
    // её только когда платформа заранее ответила «умею», а без выданного
    // разрешения она отвечает «нет» — и спросить её было некому. Функция
    // выглядела отсутствующей, хотя код был на месте.

    testWidgets('кнопка есть до того, как платформа что-либо ответила', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_FakeDictation()));
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.microphone), findsOneWidget);
    });

    testWidgets('нажатие сначала спрашивает разрешение, потом слушает', (
      tester,
    ) async {
      final dictation = _FakeDictation();
      await tester.pumpWidget(_harness(dictation));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.microphone));
      await tester.pumpAndSettle();

      expect(
        dictation.readyAsked,
        1,
        reason: 'разрешение спрашивают по нажатию',
      );
      expect(dictation.startCalls, 1);
    });

    testWidgets('отказ в разрешении объясняют, а не молчат', (tester) async {
      final dictation = _FakeDictation(ready: false);
      await tester.pumpWidget(_harness(dictation));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.microphone));
      await tester.pumpAndSettle();

      expect(dictation.startCalls, 0, reason: 'слушать без разрешения нечем');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Микрофон недоступен'), findsOneWidget);
    });
  });
}
