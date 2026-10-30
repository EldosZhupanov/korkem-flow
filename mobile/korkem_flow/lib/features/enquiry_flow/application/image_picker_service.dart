import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Thrown when the user or platform denies camera or photo access.
class ImagePickerPermissionException implements Exception {
  const ImagePickerPermissionException([this.message]);
  final String? message;

  @override
  String toString() =>
      message ?? 'Permission denied to access camera or gallery.';
}

abstract class ImagePickerService {
  Future<XFile?> pickImageFromCamera();
  Future<List<XFile>> pickMultiImage();
}

class ImagePickerServiceImpl implements ImagePickerService {
  ImagePickerServiceImpl([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' ||
          e.code == 'permission_denied' ||
          (e.message?.toLowerCase().contains('permission') ?? false)) {
        throw ImagePickerPermissionException(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<List<XFile>> pickMultiImage() async {
    try {
      return await _picker.pickMultiImage(
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied' ||
          e.code == 'permission_denied' ||
          (e.message?.toLowerCase().contains('permission') ?? false)) {
        throw ImagePickerPermissionException(e.message);
      }
      rethrow;
    }
  }
}

final imagePickerServiceProvider = Provider<ImagePickerService>((ref) {
  return ImagePickerServiceImpl();
});
