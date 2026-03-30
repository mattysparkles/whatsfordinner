import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/services/pantry_intelligence_service.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';

void main() {
  const service = PantryIntelligenceService();

  test('normalizes aliases, plural forms, and strips known brand prefix', () {
    final normalized = service.normalizeRaw('Kirkland diced tomatoes');

    expect(normalized.canonicalName, 'tomato');
    expect(normalized.displayName, 'Tomato');
    expect(normalized.brandText, 'Kirkland');
  });

  test('parses common grocery quantity patterns', () {
    final cans = service.parseQuantity('2 cans black beans');
    final ounces = service.parseQuantity('16 oz pasta');
    final pounds = service.parseQuantity('1.5 lb chicken breast');
    final tbsp = service.parseQuantity('3 tbsp olive oil');
    expect(cans?.amount, 2);
    expect(cans?.unit, 'can');
    expect(ounces?.amount, 16);
    expect(ounces?.unit, 'oz');
    expect(pounds?.amount, 1.5);
    expect(pounds?.unit, 'lb');
    expect(tbsp?.amount, 3);
    expect(tbsp?.unit, 'tbsp');
  });

  test('merge duplicate detections combines confidence and quantity conservatively', () {
    final merged = service.mergeDuplicateDetections([
      const ParsedIngredient(
        id: '1',
        rawText: '2 cans diced tomatoes',
        suggestedName: 'Diced tomatoes',
        confidenceScore: 0.7,
        parseConfidence: ParseConfidence.possible,
        sourceImageId: 'image-a',
        inferredQuantity: 2,
        inferredUnit: 'can',
      ),
      const ParsedIngredient(
        id: '2',
        rawText: 'tomatoes',
        suggestedName: 'Tomatoes',
        confidenceScore: 0.91,
        parseConfidence: ParseConfidence.likely,
        sourceImageId: 'image-b',
      ),
    ]);

    expect(merged, hasLength(1));
    expect(merged.single.suggestedName, 'Tomato');
    expect(merged.single.confidenceScore, 0.91);
    expect(merged.single.inferredQuantity, 2);
  });

  test('pantry merge preserves provenance and confidence while merging exact duplicates', () {
    final now = DateTime(2026, 3, 30);
    final existing = PantryItem(
      id: 'item-1',
      ingredient: const Ingredient(
        id: 'ingredient-1',
        name: 'Tomato',
        normalizedName: 'tomato',
        category: IngredientCategory.produce,
      ),
      quantityInfo: const QuantityInfo(amount: 1, unit: 'can'),
      confidence: 0.6,
      provenance: const [PantryItemProvenance(type: PantryItemProvenanceType.manual)],
      storedAt: now.subtract(const Duration(days: 5)),
    );

    final incoming = PantryItem(
      id: 'item-2',
      ingredient: const Ingredient(
        id: 'ingredient-2',
        name: 'Tomatoes',
        normalizedName: 'tomato',
        category: IngredientCategory.produce,
      ),
      quantityInfo: const QuantityInfo(amount: 2, unit: 'can'),
      confidence: 0.85,
      provenance: const [PantryItemProvenance(type: PantryItemProvenanceType.captureSession, sourceId: 'session-1')],
      storedAt: now,
    );

    final merged = service.mergePantryItems(existing: existing, incoming: incoming);

    expect(merged.quantityInfo.amount, 3);
    expect(merged.quantityInfo.unit, 'can');
    expect(merged.confidence, 0.85);
    expect(merged.provenance.length, 2);
    expect(merged.storedAt, now);
  });
}
