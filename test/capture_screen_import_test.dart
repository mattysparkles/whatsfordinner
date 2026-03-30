import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/app/providers.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';
import 'package:pantry_pilot/src/features/capture/application/capture_import_service.dart';
import 'package:pantry_pilot/src/features/capture/presentation/capture_screen.dart';

void main() {
  testWidgets('adds multiple screenshot images into the session with source labels', (tester) async {
    final service = _FakeCaptureImportService(
      onImportFromLibrary: ({required category, required screenshotMode}) async => [
        CapturedImage(
          id: 'img-1',
          path: '/tmp/screenshot_1.png',
          category: category,
          inputMethod: screenshotMode ? CaptureInputMethod.screenshotUpload : CaptureInputMethod.photoLibrary,
          createdAt: DateTime(2026, 3, 30),
        ),
        CapturedImage(
          id: 'img-2',
          path: '/tmp/screenshot_2.png',
          category: category,
          inputMethod: screenshotMode ? CaptureInputMethod.screenshotUpload : CaptureInputMethod.photoLibrary,
          createdAt: DateTime(2026, 3, 30),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [captureImportServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );

    await tester.tap(find.text('Screenshot upload'));
    await tester.pumpAndSettle();

    expect(find.text('Session images (2)'), findsOneWidget);
    expect(find.textContaining('Grocery Screenshot • Screenshot Upload'), findsNWidgets(2));
  });

  testWidgets('shows a user-friendly canceled-selection error', (tester) async {
    final service = _FakeCaptureImportService(
      onImportFromLibrary: ({required category, required screenshotMode}) async {
        throw const CaptureImportException(
          CaptureImportErrorType.canceledSelection,
          'No photos were selected from your photo library.',
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [captureImportServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );

    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();

    expect(find.text('No photos were selected from your photo library.'), findsOneWidget);
  });
}

class _FakeCaptureImportService extends CaptureImportService {
  _FakeCaptureImportService({
    this.onCaptureFromCamera,
    this.onImportFromLibrary,
    this.onRecover,
  });

  final Future<List<CapturedImage>> Function({required CaptureCategory category})? onCaptureFromCamera;
  final Future<List<CapturedImage>> Function({required CaptureCategory category, required bool screenshotMode})?
      onImportFromLibrary;
  final Future<List<CapturedImage>> Function()? onRecover;

  @override
  Future<List<CapturedImage>> captureFromCamera({required CaptureCategory category}) async {
    return onCaptureFromCamera?.call(category: category) ?? const [];
  }

  @override
  Future<List<CapturedImage>> importFromLibrary({required CaptureCategory category, required bool screenshotMode}) async {
    return onImportFromLibrary?.call(category: category, screenshotMode: screenshotMode) ?? const [];
  }

  @override
  Future<List<CapturedImage>> recoverLostImports() async {
    return onRecover?.call() ?? const [];
  }
}
