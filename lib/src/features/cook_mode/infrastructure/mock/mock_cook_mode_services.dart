import '../../domain/cook_mode_services.dart';

class MockTextToSpeechService implements TextToSpeechService {
  String? lastSpoken;
  bool isPaused = false;

  @override
  Future<void> pause() async {
    isPaused = true;
  }

  @override
  Future<void> speak(String text) async {
    isPaused = false;
    lastSpoken = text;
  }

  @override
  Future<void> stop() async {
    lastSpoken = null;
    isPaused = false;
  }
}

class MockKeepScreenAwakeService implements KeepScreenAwakeService {
  bool enabled = false;

  @override
  Future<void> disable() async {
    enabled = false;
  }

  @override
  Future<void> enable() async {
    enabled = true;
  }
}
