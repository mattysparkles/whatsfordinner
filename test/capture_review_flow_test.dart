import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';
import 'package:pantry_pilot/src/features/capture/presentation/capture_screen.dart';

void main() {
  group('ParseReviewScreen', () {
    testWidgets('supports editing, removing, merging, and approving ingredients', (tester) async {
      List<ParsedIngredient> approved = [];

      await tester.pumpWidget(
        MaterialApp(
          home: ParseReviewScreen(
            session: ParseSession(
              id: 'session-1',
              images: const [],
              imageErrors: const ['Image "blurry_1.jpg" appears blurry.'],
              parsedIngredients: const [
                ParsedIngredient(
                  id: '1',
                  rawText: 'pasta box',
                  suggestedName: 'Pasta',
                  confidenceScore: 0.9,
                  parseConfidence: ParseConfidence.likely,
                  sourceImageId: 'img1',
                  category: IngredientCategory.grainsBread,
                ),
                ParsedIngredient(
                  id: '2',
                  rawText: 'pasta package',
                  suggestedName: 'Pasta',
                  confidenceScore: 0.7,
                  parseConfidence: ParseConfidence.possible,
                  sourceImageId: 'img1',
                  category: IngredientCategory.grainsBread,
                ),
                ParsedIngredient(
                  id: '3',
                  rawText: 'mystery jar',
                  suggestedName: 'Unknown spice',
                  confidenceScore: 0.4,
                  parseConfidence: ParseConfidence.unclear,
                  sourceImageId: 'img2',
                  category: IngredientCategory.spicesSeasonings,
                ),
              ],
            ),
            onApprove: (items) async => approved = items,
          ),
        ),
      );

      expect(find.textContaining('blurry'), findsOneWidget);
      expect(find.text('Likely'), findsOneWidget);
      expect(find.text('Possible'), findsOneWidget);
      expect(find.text('Unclear'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Whole wheat pasta');
      await tester.pump();

      await tester.tap(find.byTooltip('Remove ingredient').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Merge duplicates'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.text('Send approved items to inventory'));
      await tester.pumpAndSettle();

      expect(approved.length, 1);
      expect(approved.single.suggestedName, 'Whole wheat pasta');
      expect(approved.single.parseConfidence, ParseConfidence.likely);
    });
  });
}
