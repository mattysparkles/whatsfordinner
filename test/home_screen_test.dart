import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home screen renders primary CTA', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: HomeScreen())));

    expect(find.text('What are we making?'), findsOneWidget);
    expect(find.text('Scan ingredients'), findsOneWidget);
  });
}
