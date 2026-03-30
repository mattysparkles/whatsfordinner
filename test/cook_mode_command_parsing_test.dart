import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/features/cook_mode/domain/cook_mode_services.dart';

void main() {
  test('maps short spoken phrases into cook mode commands', () {
    expect(parseVoiceCommand('next'), VoiceCommand.nextStep);
    expect(parseVoiceCommand('go back'), VoiceCommand.previousStep);
    expect(parseVoiceCommand('repeat that'), VoiceCommand.repeatThat);
    expect(parseVoiceCommand('start timer now'), VoiceCommand.startTimer);
    expect(parseVoiceCommand('pause voice'), VoiceCommand.pauseVoice);
    expect(parseVoiceCommand('resume voice'), VoiceCommand.resumeVoice);
    expect(parseVoiceCommand('unrelated words'), isNull);
  });

  test('session snapshot encodes and decodes key progress fields', () {
    final snapshot = CookSessionProgress(
      recipeId: 'recipe-1',
      stepIndex: 2,
      textScale: 1.3,
      darkCookMode: false,
      highContrast: true,
      voicePaused: true,
      timerRemainingSeconds: 150,
      customStepMinutes: const {2: 9},
      savedAt: DateTime.utc(2026, 1, 1),
    );

    final decoded = CookSessionProgress.decode(snapshot.encode());

    expect(decoded.recipeId, 'recipe-1');
    expect(decoded.stepIndex, 2);
    expect(decoded.textScale, 1.3);
    expect(decoded.darkCookMode, isFalse);
    expect(decoded.highContrast, isTrue);
    expect(decoded.voicePaused, isTrue);
    expect(decoded.timerRemainingSeconds, 150);
    expect(decoded.customStepMinutes[2], 9);
  });
}
