import 'package:flutter/foundation.dart';
import 'package:korkem_flow/features/assistant/presentation/widgets/chat_composer.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictation, using whatever recogniser the device already has.
///
/// Nothing of ours is involved: no key, no endpoint, no audio kept. On Android
/// this is the platform `SpeechRecognizer`, which is why
/// `docs/privacy_policy.md` names it — the app should not claim audio never
/// leaves the device when the platform service may send it.
///
/// Availability is discovered rather than assumed. A device without a
/// recogniser, or a user who declines the microphone permission, ends up with
/// no button at all — the composer draws it only when this reports available,
/// so nobody is offered a control that cannot work.
class SpeechDictation implements ChatDictation {
  final SpeechToText _speech = SpeechToText();

  bool _available = false;
  bool _initialised = false;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  /// Whether the button should exist at all.
  ///
  /// False until [ensureReady] has run, so the first build of a fresh screen
  /// shows no microphone; it appears once the platform has answered. That is
  /// the honest order — the alternative is drawing a button and finding out it
  /// does nothing when it is pressed.
  bool get isAvailable => _available;

  /// Asks the platform once whether dictation can run here.
  @override
  Future<bool> ensureReady() async {
    if (_initialised) return _available;
    _initialised = true;

    try {
      _available = await _speech.initialize(
        onStatus: (status) => _listening = status == 'listening',
        onError: (_) => _listening = false,
      );
    } on Exception catch (error) {
      // A missing recogniser or a refused permission is a normal outcome on a
      // device, not a failure worth interrupting anyone over.
      debugPrint('Dictation unavailable: $error');
      _available = false;
    }
    return _available;
  }

  @override
  Future<void> start(ValueChanged<String> onResult) async {
    if (!await ensureReady()) return;

    _listening = true;
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
    );
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _speech.stop();
  }

  Future<void> dispose() => _speech.cancel();
}
