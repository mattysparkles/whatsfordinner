import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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
  Timer? _timer;
  int _timerRemaining = 0;
  StreamSubscription<VoiceCommand>? _commandSub;

  @override
  void initState() {
    super.initState();
    final seedRecipe = widget.seedRecipe;
    if (seedRecipe != null) {
      ref.read(selectedRecipeProvider.notifier).state = seedRecipe;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(keepScreenAwakeServiceProvider).enable();
      _commandSub = ref.read(speechCommandServiceProvider).commandStream().listen(_handleVoiceCommand);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commandSub?.cancel();
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
    final theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: _highContrast ? Colors.yellow.shade700 : base.colorScheme.primary,
        secondary: _highContrast ? Colors.cyanAccent : base.colorScheme.secondary,
      ),
      cardTheme: CardThemeData(
        color: _highContrast ? Colors.black : base.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              onPressed: () => setState(() => _darkCookMode = !_darkCookMode),
            ),
            IconButton(
              tooltip: 'Toggle high contrast',
              icon: const Icon(Icons.contrast),
              onPressed: () => setState(() => _highContrast = !_highContrast),
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
                  child: LinearProgressIndicator(value: (_index + 1) / steps.length, minHeight: 12),
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
                _buildTextSizeControl(theme, textColor),
                const SizedBox(height: 8),
                const _VoiceCommandPlaceholderRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(int totalSteps, CookingStep current) {
    final buttonStyle = ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(68), textStyle: const TextStyle(fontSize: 24));
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Previous cooking step',
                child: OutlinedButton(
                  onPressed: _index == 0 ? null : () => setState(() => _index--),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(68), textStyle: const TextStyle(fontSize: 22)),
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
                  onPressed: _index >= totalSteps - 1 ? null : () => setState(() => _index++),
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

  Widget _buildTextSizeControl(ThemeData theme, Color textColor) {
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
              onChanged: (value) => setState(() => _textScale = value),
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
      final current = _currentInstruction();
      await tts.speak(current);
      setState(() => _voicePaused = false);
      return;
    }
    await tts.pause();
    setState(() => _voicePaused = true);
  }

  Future<void> _startTimerFor(CookingStep step) async {
    _timer?.cancel();
    setState(() => _timerRemaining = ((step.estimatedMinutes ?? 5) * 60));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerRemaining <= 1) {
        timer.cancel();
        setState(() => _timerRemaining = 0);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timer complete.')));
        return;
      }
      setState(() => _timerRemaining--);
    });
  }

  Future<void> _handleVoiceCommand(VoiceCommand command) async {
    switch (command) {
      case VoiceCommand.nextStep:
        if (_index >= _stepCount() - 1) return;
        setState(() => _index++);
        break;
      case VoiceCommand.previousStep:
        if (_index <= 0) return;
        setState(() => _index--);
        break;
      case VoiceCommand.repeatThat:
        await ref.read(textToSpeechServiceProvider).speak(_currentInstruction());
        break;
      case VoiceCommand.startTimer:
        final recipe = widget.seedRecipe ?? ref.read(selectedRecipeProvider);
        final steps = recipe?.steps ?? const [CookingStep(order: 1, instruction: 'Choose a recipe to start cook mode.')];
        await _startTimerFor(steps[_index]);
        break;
      case VoiceCommand.pauseVoice:
        await _toggleVoicePause();
        break;
    }
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
        _voiceChip(context, ref, 'Next step', VoiceCommand.nextStep),
        _voiceChip(context, ref, 'Previous step', VoiceCommand.previousStep),
        _voiceChip(context, ref, 'Repeat that', VoiceCommand.repeatThat),
        _voiceChip(context, ref, 'Start timer', VoiceCommand.startTimer),
        _voiceChip(context, ref, 'Pause voice', VoiceCommand.pauseVoice),
      ],
    );
  }

  Widget _voiceChip(BuildContext context, WidgetRef ref, String label, VoiceCommand command) {
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
