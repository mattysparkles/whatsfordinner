import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/models.dart';

enum CaptureImportErrorType { permissionDenied, canceledSelection, missingFile, invalidMedia, unknown }

class CaptureImportException implements Exception {
  const CaptureImportException(this.type, this.message);

  final CaptureImportErrorType type;
  final String message;
}

class CaptureImportService {
  CaptureImportService({
    ImagePicker? imagePicker,
    Uuid? uuid,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _uuid = uuid ?? const Uuid();

  final ImagePicker _imagePicker;
  final Uuid _uuid;

  Future<List<CapturedImage>> captureFromCamera({required CaptureCategory category}) async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.camera);
      if (picked == null) {
        throw const CaptureImportException(
          CaptureImportErrorType.canceledSelection,
          'Camera capture was canceled before a photo was selected.',
        );
      }

      return [_toCapturedImage(await _persistImage(picked), category, CaptureInputMethod.camera)];
    } on ImagePickerException catch (error) {
      throw _mapPickerException(error.code);
    }
  }

  Future<List<CapturedImage>> importFromLibrary({required CaptureCategory category, required bool screenshotMode}) async {
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (picked.isEmpty) {
        throw const CaptureImportException(
          CaptureImportErrorType.canceledSelection,
          'No photos were selected from your photo library.',
        );
      }

      final method = screenshotMode ? CaptureInputMethod.screenshotUpload : CaptureInputMethod.photoLibrary;
      final images = <CapturedImage>[];
      for (final file in picked) {
        images.add(_toCapturedImage(await _persistImage(file), category, method));
      }
      return images;
    } on ImagePickerException catch (error) {
      throw _mapPickerException(error.code);
    }
  }

  Future<List<CapturedImage>> recoverLostImports() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) return const [];

      final exception = response.exception;
      if (exception != null) {
        throw _mapPickerException(exception.code);
      }

      final recoveredFiles = response.files;
      if (recoveredFiles == null || recoveredFiles.isEmpty) return const [];

      final recovered = <CapturedImage>[];
      for (final file in recoveredFiles) {
        recovered.add(
          _toCapturedImage(
            await _persistImage(file),
            CaptureCategory.pantry,
            CaptureInputMethod.photoLibrary,
          ),
        );
      }
      return recovered;
    } on ImagePickerException catch (error) {
      throw _mapPickerException(error.code);
    }
  }

  Future<File> _persistImage(XFile picked) async {
    final extension = p.extension(picked.path).toLowerCase();
    if (!_supportedExtensions.contains(extension)) {
      throw CaptureImportException(
        CaptureImportErrorType.invalidMedia,
        'Unsupported media type "$extension". Please select a photo image.',
      );
    }

    final sourceFile = File(picked.path);
    if (!await sourceFile.exists()) {
      throw const CaptureImportException(
        CaptureImportErrorType.missingFile,
        'Selected image file could not be found on device storage.',
      );
    }

    final appSupportDirectory = await getApplicationSupportDirectory();
    final captureDirectory = Directory(p.join(appSupportDirectory.path, 'capture_imports'));
    if (!await captureDirectory.exists()) {
      await captureDirectory.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$extension';
    final destination = File(p.join(captureDirectory.path, fileName));
    return sourceFile.copy(destination.path);
  }

  CapturedImage _toCapturedImage(File file, CaptureCategory category, CaptureInputMethod method) {
    return CapturedImage(
      id: _uuid.v4(),
      path: file.path,
      category: category,
      inputMethod: method,
      createdAt: DateTime.now(),
    );
  }

  CaptureImportException _mapPickerException(String? code) {
    final lowerCode = code?.toLowerCase() ?? '';
    if (lowerCode.contains('permission')) {
      return const CaptureImportException(
        CaptureImportErrorType.permissionDenied,
        'PantryPilot does not have permission to access your camera or photos. Please grant access in Settings.',
      );
    }

    return CaptureImportException(
      CaptureImportErrorType.unknown,
      'Could not import image due to device error${code == null ? '' : ' ($code)'}',
    );
  }

  static const Set<String> _supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.webp',
  };
}
