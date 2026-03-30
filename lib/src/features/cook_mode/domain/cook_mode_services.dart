import 'dart:async';
import 'dart:convert';

enum VoiceCommand { nextStep, previousStep, repeatThat, startTimer, pauseVoice, resumeVoice }

abstract class TextToSpeechService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
}

abstract class SpeechCommandService {
  Stream<VoiceCommand> commandStream();
  Future<void> startListeningShort();
  Future<void> stopListening();
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
  Future<void> startListeningShort() async {}

  @override
  Future<void> stopListening() async {}

  @override
  void emitMockCommand(VoiceCommand command) {
    _controller.add(command);
  }

  void dispose() {
    _controller.close();
  }
}

class CookSessionProgress {
  const CookSessionProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.textScale,
    required this.darkCookMode,
    required this.highContrast,
    required this.voicePaused,
    required this.timerRemainingSeconds,
    required this.customStepMinutes,
    required this.savedAt,
  });

  final String recipeId;
  final int stepIndex;
  final double textScale;
  final bool darkCookMode;
  final bool highContrast;
  final bool voicePaused;
  final int timerRemainingSeconds;
  final Map<int, int> customStepMinutes;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'stepIndex': stepIndex,
        'textScale': textScale,
        'darkCookMode': darkCookMode,
        'highContrast': highContrast,
        'voicePaused': voicePaused,
        'timerRemainingSeconds': timerRemainingSeconds,
        'customStepMinutes': customStepMinutes.map((key, value) => MapEntry(key.toString(), value)),
        'savedAt': savedAt.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  factory CookSessionProgress.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final customJson = json['customStepMinutes'] as Map<String, dynamic>? ?? const {};
    return CookSessionProgress(
      recipeId: json['recipeId'] as String,
      stepIndex: json['stepIndex'] as int? ?? 0,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1,
      darkCookMode: json['darkCookMode'] as bool? ?? true,
      highContrast: json['highContrast'] as bool? ?? false,
      voicePaused: json['voicePaused'] as bool? ?? false,
      timerRemainingSeconds: json['timerRemainingSeconds'] as int? ?? 0,
      customStepMinutes: customJson.map((key, value) => MapEntry(int.parse(key), value as int)),
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

VoiceCommand? parseVoiceCommand(String phrase) {
  final normalized = phrase.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  if (normalized.contains('next')) return VoiceCommand.nextStep;
  if (normalized.contains('previous') || normalized.contains('back')) return VoiceCommand.previousStep;
  if (normalized.contains('repeat')) return VoiceCommand.repeatThat;
  if (normalized.contains('timer')) return VoiceCommand.startTimer;
  if ((normalized.contains('resume') || normalized.contains('continue')) && normalized.contains('voice')) {
    return VoiceCommand.resumeVoice;
  }
  if ((normalized.contains('pause') || normalized.contains('stop')) && normalized.contains('voice')) {
    return VoiceCommand.pauseVoice;
  }
  return null;
}
