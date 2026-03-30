import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/ad_placement.dart';
import '../../monetization/domain/entitlements.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  static const _dietaryOptions = ['Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free', 'Halal', 'Kosher'];
  static const _allergyOptions = ['Peanuts', 'Tree nuts', 'Dairy', 'Eggs', 'Soy', 'Shellfish'];
  static const _aversionOptions = ['Mushrooms', 'Cilantro', 'Spicy food', 'Seafood', 'Raw onion'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesControllerProvider);

    return AppScaffold(
      title: 'Preferences',
      adPlacement: AdPlacement.rewardsPrompt,
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load preferences: $error')),
        data: (preferences) => ListView(
          children: [
            _SectionCard(
              title: 'Diet & sensitivities',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChipMultiSelect(
                    label: 'Dietary restrictions',
                    options: _dietaryOptions,
                    selected: preferences.dietaryFilters,
                    onChanged: (next) => _save(ref, preferences.copyWith(dietaryFilters: next)),
                  ),
                  const SizedBox(height: 12),
                  _ChipMultiSelect(
                    label: 'Allergies',
                    options: _allergyOptions,
                    selected: preferences.allergies,
                    onChanged: (next) => _save(ref, preferences.copyWith(allergies: next)),
                  ),
                  const SizedBox(height: 12),
                  _ChipMultiSelect(
                    label: 'Aversions',
                    options: _aversionOptions,
                    selected: preferences.aversions,
                    onChanged: (next) => _save(ref, preferences.copyWith(aversions: next)),
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'Cooking profile',
              child: Column(
                children: [
                  DropdownButtonFormField<CookingSkillLevel>(
                    initialValue: preferences.cookingSkillLevel,
                    decoration: const InputDecoration(labelText: 'Cooking skill level'),
                    items: CookingSkillLevel.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        _save(ref, preferences.copyWith(cookingSkillLevel: value));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: preferences.householdSize,
                    decoration: const InputDecoration(labelText: 'Default household size'),
                    items: List.generate(
                      8,
                      (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}')),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        _save(ref, preferences.copyWith(householdSize: value));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LeftoverPreference>(
                    initialValue: preferences.leftoverPreference,
                    decoration: const InputDecoration(labelText: 'Leftover preference'),
                    items: LeftoverPreference.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        _save(ref, preferences.copyWith(leftoverPreference: value));
                      }
                    },
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: 'Meal style',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MealTypeSelector(
                    selected: preferences.preferredMealTypes,
                    onChanged: (next) => _save(ref, preferences.copyWith(preferredMealTypes: next)),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.lowSodium,
                    title: const Text('Prefer low sodium'),
                    onChanged: (value) => _save(ref, preferences.copyWith(lowSodium: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.lowSugar,
                    title: const Text('Prefer low sugar'),
                    onChanged: (value) => _save(ref, preferences.copyWith(lowSugar: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: preferences.lowerCalorie,
                    title: const Text('Prefer lower calorie'),
                    onChanged: (value) => _save(ref, preferences.copyWith(lowerCalorie: value)),
                  ),
                ],
              ),
            ),
            const LockedFeatureTile(
              feature: PremiumFeature.advancedHouseholdProfiles,
              title: 'Advanced household profiles',
              subtitle: 'Multiple profile presets, routines, and constraints',
            ),
            const PremiumUpsellCard(compact: true),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About PantryPilot'),
                    subtitle: const Text('Version, build info, and credits'),
                    onTap: () => context.push(AppRoutes.about),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    onTap: () => context.push(AppRoutes.privacy),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of service'),
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, UserPreferences preferences) {
    return ref.read(preferencesControllerProvider.notifier).save(preferences);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChipMultiSelect extends StatelessWidget {
  const _ChipMultiSelect({required this.label, required this.options, required this.selected, required this.onChanged});

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (isSelected) {
                    final next = [...selected];
                    if (isSelected) {
                      next.add(option);
                    } else {
                      next.remove(option);
                    }
                    onChanged(next.toSet().toList(growable: false));
                  },
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _MealTypeSelector extends StatelessWidget {
  const _MealTypeSelector({required this.selected, required this.onChanged});

  final List<MealType> selected;
  final ValueChanged<List<MealType>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferred meal types', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MealType.values
              .map(
                (type) => FilterChip(
                  label: Text(type.name),
                  selected: selected.contains(type),
                  onSelected: (isSelected) {
                    final next = [...selected];
                    if (isSelected) {
                      next.add(type);
                    } else {
                      next.remove(type);
                    }
                    onChanged(next.isEmpty ? const [MealType.dinner] : next.toSet().toList(growable: false));
                  },
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
