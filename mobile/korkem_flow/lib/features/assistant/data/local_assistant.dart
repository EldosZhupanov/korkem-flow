import 'package:korkem_flow/features/assistant/data/assistant_repository.dart';
import 'package:korkem_flow/features/assistant/domain/assistant_event.dart';
import 'package:korkem_flow/features/assistant/domain/chat_message.dart';

/// The assistant, until a language model is connected to it.
///
/// It matches a few phrasings against a keyword list and answers by attaching
/// the matching data card. It does not understand anything, and the rule this
/// class exists to keep is that it never behaves as though it does: whatever it
/// fails to recognise comes back as [AssistantReply.isUnrecognised], and the
/// screen says plainly that there is no model behind it.
///
/// That matters more than it looks. A demo assistant that improvises is not a
/// demo, it is a claim — and the first time somebody acts on an invented number
/// out of an ERP, the damage is real.
///
/// It writes no prose and no figures at all. A recognised request returns only
/// a [ContextCardKind]; the card reads the same providers the dashboard does,
/// so everything quantitative on screen came from the backend.
class LocalAssistant extends AssistantRepository {
  const LocalAssistant();

  /// Keywords per intent, across the three languages the app ships.
  ///
  /// Deliberately not a regex or a stemmer. A cleverer matcher would recognise
  /// more phrasings and thereby *look* more capable — the wrong direction for
  /// something whose honesty depends on failing visibly.
  static const _intents = <ContextCardKind, List<String>>{
    ContextCardKind.attention: [
      'attention',
      'внимани',
      'важн',
      'срочн',
      'назар',
    ],
    ContextCardKind.tasks: [
      'task',
      'overdue',
      'задач',
      'просроч',
      'тапсырма',
      'мерзім',
    ],
    ContextCardKind.deals: [
      'deal',
      'lead',
      'sale',
      'сделк',
      'лид',
      'продаж',
      'мәміле',
    ],
    ContextCardKind.production: [
      'production',
      'order',
      'factory',
      'производств',
      'заказ',
      'өндіріс',
    ],
  };

  @override
  Stream<AssistantEvent> send({
    required String prompt,
    required List<ChatMessage> history,
  }) async* {
    final text = prompt.toLowerCase();

    for (final MapEntry(key: kind, value: keywords) in _intents.entries) {
      if (keywords.any(text.contains)) {
        yield AssistantDone(card: kind);
        return;
      }
    }

    // No text and no card: the view is what puts words to "I did not
    // understand", because that sentence has to be translated and this layer
    // has no `BuildContext`.
    yield const AssistantDone();
  }
}
