import 'dart:typed_data';

/// Stub for non-web platforms (mobile, desktop).
/// Returns null — native platforms use FilePicker/ImagePicker directly.
Future<Uint8List?> pickFileOnWeb() async => null;
