import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/cook_mode_services.dart';

class DeviceTextToSpeechService implements TextToSpeechService {
  DeviceTextToSpeechService() {
    _tts.setSpeechRate(0.48);
  }

  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> pause() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

class DeviceSpeechCommandService implements SpeechCommandService, MockSpeechCommandEmitter {
  DeviceSpeechCommandService();

  final SpeechToText _speech = SpeechToText();
  final StreamController<VoiceCommand> _controller = StreamController<VoiceCommand>.broadcast();

  bool _ready = false;

  @override
  Stream<VoiceCommand> commandStream() => _controller.stream;

  Future<bool> _ensureInitialized() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize();
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> startListeningShort() async {
    final ready = await _ensureInitialized();
    if (!ready || _speech.isListening) return;
    try {
      await _speech.listen(
        listenFor: const Duration(seconds: 3),
        pauseFor: const Duration(milliseconds: 1200),
        partialResults: false,
        onResult: _onResult,
      );
    } catch (_) {}
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    final command = parseVoiceCommand(result.recognizedWords);
    if (command != null) {
      _controller.add(command);
    }
  }

  @override
  Future<void> stopListening() async {
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }
  }

  @override
  void emitMockCommand(VoiceCommand command) {
    _controller.add(command);
  }

  void dispose() {
    _controller.close();
  }
}

class DeviceKeepScreenAwakeService implements KeepScreenAwakeService {
  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }
}
