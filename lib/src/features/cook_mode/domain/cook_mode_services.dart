import 'dart:async';

enum VoiceCommand { nextStep, previousStep, repeatThat, startTimer, pauseVoice }

abstract class TextToSpeechService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
}

abstract class SpeechCommandService {
  Stream<VoiceCommand> commandStream();
}

abstract class KeepScreenAwakeService {
  Future<void> enable();
  Future<void> disable();
}

/// TODO(voice): Wire a production speech recognizer that maps natural language
/// to [VoiceCommand] values.
abstract class MockSpeechCommandEmitter {
  void emitMockCommand(VoiceCommand command);
}

/// TODO(narration): Integrate platform-native or cloud TTS with queueing,
/// interruption control, and voice selection.
class InMemorySpeechCommandBus implements SpeechCommandService, MockSpeechCommandEmitter {
  InMemorySpeechCommandBus();

  final _controller = StreamController<VoiceCommand>.broadcast();

  @override
  Stream<VoiceCommand> commandStream() => _controller.stream;

  @override
  void emitMockCommand(VoiceCommand command) {
    _controller.add(command);
  }

  void dispose() {
    _controller.close();
  }
}
