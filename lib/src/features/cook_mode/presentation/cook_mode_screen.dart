import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_models.dart';
import '../domain/cook_mode_services.dart';

class CookModeScreen extends ConsumerStatefulWidget {
  const CookModeScreen({super.key, this.seedRecipe});

  final RecipeSuggestion? seedRecipe;

  @override
  ConsumerState<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends ConsumerState<CookModeScreen> {
  int _index = 0;
  double _textScale = 1.0;
  bool _darkCookMode = true;
  bool _highContrast = false;
  bool _voicePaused = false;
  bool _voiceListening = false;
  Timer? _timer;
  int _timerRemaining = 0;
  StreamSubscription<VoiceCommand>? _commandSub;
  final Map<int, int> _customStepMinutes = {};

  @override
  void initState() {
    super.initState();
    final seedRecipe = widget.seedRecipe;
    if (seedRecipe != null) {
      ref.read(selectedRecipeProvider.notifier).state = seedRecipe;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(keepScreenAwakeServiceProvider).enable();
      _commandSub = ref.read(speechCommandServiceProvider).commandStream().listen(_handleVoiceCommand);
      await _restoreSession();
      await _announceCurrentStep();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commandSub?.cancel();
    ref.read(speechCommandServiceProvider).stopListening();
    ref.read(keepScreenAwakeServiceProvider).disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.seedRecipe ?? ref.watch(selectedRecipeProvider);
    final steps = recipe?.steps ?? const [CookingStep(order: 1, instruction: 'Choose a recipe to start cook mode.')];
    final current = steps[_index.clamp(0, steps.length - 1)];

    final base = _darkCookMode ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final textColor = _highContrast ? Colors.white : base.colorScheme.onSurface;
    final bgColor = _highContrast ? Colors.black : base.scaffoldBackgroundColor;
    final theme = base.copyWith(
      scaffoldBackgroundColor: bgColor,
      colorScheme: base.colorScheme.copyWith(
        primary: _highContrast ? Colors.yellow.shade700 : base.colorScheme.primary,
        secondary: _highContrast ? Colors.cyanAccent : base.colorScheme.secondary,
        surface: _highContrast ? Colors.black : base.colorScheme.surface,
      ),
      cardTheme: CardThemeData(
        color: _highContrast ? Colors.black : base.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _highContrast ? Colors.white70 : Colors.transparent),
        ),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(recipe?.title ?? 'Cook Mode'),
          actions: [
            IconButton(
              tooltip: _darkCookMode ? 'Use light cook mode' : 'Use dark cook mode',
              icon: Icon(_darkCookMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () {
                setState(() => _darkCookMode = !_darkCookMode);
                _persistSession();
              },
            ),
            IconButton(
              tooltip: 'Toggle high contrast',
              icon: const Icon(Icons.contrast),
              onPressed: () {
                setState(() => _highContrast = !_highContrast);
                _persistSession();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Cooking progress',
                  value: 'Step ${_index + 1} of ${steps.length}',
                  child: LinearProgressIndicator(value: (_index + 1) / steps.length, minHeight: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  'Step ${_index + 1} of ${steps.length}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Semantics(
                    label: 'Current cooking instruction',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            current.instruction,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              fontSize: 30 * _textScale,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _IngredientChecklistSummary(recipe: recipe),
                const SizedBox(height: 12),
                _buildControls(steps.length, current),
                const SizedBox(height: 8),
                _buildTextSizeControl(textColor),
                const SizedBox(height: 8),
                if (ref.watch(appConfigProvider).useMocks) const _VoiceCommandPlaceholderRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(int totalSteps, CookingStep current) {
    final buttonStyle = ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(72), textStyle: const TextStyle(fontSize: 22));
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Previous cooking step',
                child: OutlinedButton(
                  onPressed: _index == 0 ? null : () => _moveToStep(_index - 1),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(72), textStyle: const TextStyle(fontSize: 20)),
                  child: const Text('Previous'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Next cooking step',
                child: ElevatedButton(
                  onPressed: _index >= totalSteps - 1 ? null : () => _moveToStep(_index + 1),
                  style: buttonStyle,
                  child: const Text('Next'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Start timer for current step',
                child: ElevatedButton.icon(
                  onPressed: () => _startTimerFor(current),
                  style: buttonStyle,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(_timerRemaining > 0 ? 'Timer ${_formatTimer(_timerRemaining)}' : 'Start timer'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: _voicePaused ? 'Resume narration voice' : 'Pause narration voice',
                child: ElevatedButton.icon(
                  onPressed: _toggleVoicePause,
                  style: buttonStyle,
                  icon: Icon(_voicePaused ? Icons.volume_up : Icons.volume_off),
                  label: Text(_voicePaused ? 'Resume voice' : 'Pause voice'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Listen for a short voice command',
                child: FilledButton.icon(
                  onPressed: _voiceListening ? null : _listenForCommand,
                  icon: Icon(_voiceListening ? Icons.hearing_disabled : Icons.mic),
                  label: Text(_voiceListening ? 'Listening…' : 'Voice command'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Edit timer minutes for this step',
                child: OutlinedButton.icon(
                  onPressed: current.estimatedMinutes == null ? () => _editCurrentStepTimer(current) : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(current.estimatedMinutes == null ? 'Set step timer' : 'Timer preset set'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_index >= totalSteps - 1)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final recipe = widget.seedRecipe ?? ref.read(selectedRecipeProvider);
                if (recipe != null) {
                  await ref.read(favoritesHistoryControllerProvider.notifier).trackEvent(
                        type: HistoryEventType.completedCookMode,
                        recipe: recipe,
                      );
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nice cooking! Added to your history.')),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark as cooked'),
            ),
          ),
      ],
    );
  }

  Widget _buildTextSizeControl(Color textColor) {
    return Semantics(
      label: 'Adjust cook mode text size',
      child: Row(
        children: [
          Icon(Icons.text_decrease, color: textColor),
          Expanded(
            child: Slider(
              min: 0.85,
              max: 1.6,
              value: _textScale,
              divisions: 15,
              label: '${(_textScale * 100).round()}%',
              onChanged: (value) {
                setState(() => _textScale = value);
                _persistSession();
              },
            ),
          ),
          Icon(Icons.text_increase, color: textColor),
        ],
      ),
    );
  }

  Future<void> _toggleVoicePause() async {
    final tts = ref.read(textToSpeechServiceProvider);
    if (_voicePaused) {
      await tts.speak(_currentInstruction());
      setState(() => _voicePaused = false);
      _persistSession();
      return;
    }
    await tts.pause();
    setState(() => _voicePaused = true);
    _persistSession();
  }

  Future<void> _startTimerFor(CookingStep step) async {
    final seconds = await _resolveStepTimerSeconds(step);
    if (seconds == null || seconds <= 0) return;

    _timer?.cancel();
    setState(() => _timerRemaining = seconds);
    _persistSession();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerRemaining <= 1) {
        timer.cancel();
        setState(() => _timerRemaining = 0);
        _persistSession();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timer complete.')));
        return;
      }
      setState(() => _timerRemaining--);
      _persistSession();
    });
  }

  Future<int?> _resolveStepTimerSeconds(CookingStep step) async {
    final fromRecipe = step.estimatedMinutes;
    final custom = _customStepMinutes[step.order];
    final minutes = custom ?? fromRecipe;
    if (minutes != null && minutes > 0) {
      return minutes * 60;
    }
    await _editCurrentStepTimer(step);
    final edited = _customStepMinutes[step.order];
    if (edited == null || edited <= 0) return null;
    return edited * 60;
  }

  Future<void> _editCurrentStepTimer(CookingStep step) async {
    final controller = TextEditingController(text: (_customStepMinutes[step.order] ?? '').toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set step timer'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutes', hintText: 'e.g. 8'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(controller.text.trim());
                Navigator.of(context).pop(minutes);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (value != null && value > 0) {
      setState(() => _customStepMinutes[step.order] = value);
      _persistSession();
    }
  }

  Future<void> _handleVoiceCommand(VoiceCommand command) async {
    switch (command) {
      case VoiceCommand.nextStep:
        if (_index < _stepCount() - 1) {
          await _moveToStep(_index + 1);
        }
        break;
      case VoiceCommand.previousStep:
        if (_index > 0) {
          await _moveToStep(_index - 1);
        }
        break;
      case VoiceCommand.repeatThat:
        await _announceCurrentStep();
        break;
      case VoiceCommand.startTimer:
        final recipe = widget.seedRecipe ?? ref.read(selectedRecipeProvider);
        final steps = recipe?.steps ?? const [CookingStep(order: 1, instruction: 'Choose a recipe to start cook mode.')];
        await _startTimerFor(steps[_index]);
        break;
      case VoiceCommand.pauseVoice:
        if (!_voicePaused) {
          await _toggleVoicePause();
        }
        break;
      case VoiceCommand.resumeVoice:
        if (_voicePaused) {
          await _toggleVoicePause();
        }
        break;
    }
  }

  Future<void> _moveToStep(int nextIndex) async {
    setState(() => _index = nextIndex.clamp(0, _stepCount() - 1));
    await _persistSession();
    if (!_voicePaused) {
      await _announceCurrentStep();
    }
  }

  Future<void> _announceCurrentStep() async {
    if (_voicePaused) return;
    await ref.read(textToSpeechServiceProvider).speak(_currentInstruction());
  }

  int _stepCount() {
    final recipe = widget.seedRecipe ?? ref.read(selectedRecipeProvider);
    return recipe?.steps.length ?? 1;
  }

  String _currentInstruction() {
    final recipe = widget.seedRecipe ?? ref.read(selectedRecipeProvider);
    final steps = recipe?.steps ?? const [CookingStep(order: 1, instruction: 'Choose a recipe to start cook mode.')];
    return steps[_index].instruction;
  }

  String _formatTimer(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  String _sessionKey(String recipeId) => 'cook_session_$recipeId';

  Future<void> _persistSession() async {
    final recipe = widget.seedRecipe ?? ref.read(selectedRecipeProvider);
    if (recipe == null) return;
    final progress = CookSessionProgress(
      recipeId: recipe.id,
      stepIndex: _index,
      textScale: _textScale,
      darkCookMode: _darkCookMode,
      highContrast: _highContrast,
      voicePaused: _voicePaused,
      timerRemainingSeconds: _timerRemaining,
      customStepMinutes: Map<int, int>.from(_customStepMinutes),
      savedAt: DateTime.now().toUtc(),
    );
    await ref.read(localPersistenceProvider).writeString(_sessionKey(recipe.id), progress.encode());
  }

  Future<void> _restoreSession() async {
    final recipe = widget.seedRecipe ?? ref.read(selectedRecipeProvider);
    if (recipe == null) return;
    final raw = await ref.read(localPersistenceProvider).readString(_sessionKey(recipe.id));
    if (raw == null) return;
    try {
      final progress = CookSessionProgress.decode(raw);
      if (progress.recipeId != recipe.id) return;
      setState(() {
        _index = progress.stepIndex.clamp(0, _stepCount() - 1);
        _textScale = progress.textScale;
        _darkCookMode = progress.darkCookMode;
        _highContrast = progress.highContrast;
        _voicePaused = progress.voicePaused;
        _timerRemaining = progress.timerRemainingSeconds;
        _customStepMinutes
          ..clear()
          ..addAll(progress.customStepMinutes);
      });
      if (_timerRemaining > 0) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          if (_timerRemaining <= 1) {
            timer.cancel();
            setState(() => _timerRemaining = 0);
            _persistSession();
            return;
          }
          setState(() => _timerRemaining--);
          _persistSession();
        });
      }
    } catch (_) {
      // Ignore malformed session snapshots.
    }
  }

  Future<void> _listenForCommand() async {
    setState(() => _voiceListening = true);
    await ref.read(speechCommandServiceProvider).startListeningShort();
    if (!mounted) return;
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _voiceListening = false);
      }
    });
  }
}

class _IngredientChecklistSummary extends StatefulWidget {
  const _IngredientChecklistSummary({required this.recipe});

  final RecipeSuggestion? recipe;

  @override
  State<_IngredientChecklistSummary> createState() => _IngredientChecklistSummaryState();
}

class _IngredientChecklistSummaryState extends State<_IngredientChecklistSummary> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final available = (recipe?.availableIngredients ?? const <String>[]).toSet();
    final requirements = recipe?.requirements ?? const <RecipeIngredientRequirement>[];

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        onExpansionChanged: (value) => setState(() => expanded = value),
        title: Text('Ingredient checklist (${available.length}/${requirements.length})'),
        subtitle: Text(expanded ? 'Tap to collapse' : 'Tap to review ingredients'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: requirements.isEmpty
            ? const [ListTile(title: Text('No ingredients provided for this recipe.'))]
            : requirements
                .map(
                  (requirement) => CheckboxListTile(
                    value: available.contains(requirement.ingredientName),
                    onChanged: null,
                    title: Text(requirement.ingredientName),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                )
                .toList(growable: false),
      ),
    );
  }
}

class _VoiceCommandPlaceholderRow extends ConsumerWidget {
  const _VoiceCommandPlaceholderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _voiceChip(ref, 'Next step', VoiceCommand.nextStep),
        _voiceChip(ref, 'Previous step', VoiceCommand.previousStep),
        _voiceChip(ref, 'Repeat that', VoiceCommand.repeatThat),
        _voiceChip(ref, 'Start timer', VoiceCommand.startTimer),
        _voiceChip(ref, 'Pause voice', VoiceCommand.pauseVoice),
        _voiceChip(ref, 'Resume voice', VoiceCommand.resumeVoice),
      ],
    );
  }

  Widget _voiceChip(WidgetRef ref, String label, VoiceCommand command) {
    return Semantics(
      button: true,
      label: 'Mock voice command $label',
      child: ActionChip(
        label: Text(label),
        onPressed: () {
          ref.read(mockSpeechCommandEmitterProvider).emitMockCommand(command);
        },
      ),
    );
  }
}
