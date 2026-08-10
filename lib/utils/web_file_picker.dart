import 'dart:async';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Web-only implementation: directly creates and clicks a hidden <input type="file">
/// within the same synchronous user-gesture call chain so the browser allows it.
Future<Uint8List?> pickFileOnWeb() {
  final completer = Completer<Uint8List?>();

  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = 'image/*,application/pdf'
    ..multiple = false;

  input.addEventListener(
    'change',
    (web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.addEventListener(
        'load',
        (web.Event _) {
          if (!completer.isCompleted) {
            final result = reader.result;
            // result is a JSArrayBuffer on web
            try {
              final bytes = (result as JSArrayBuffer).toDart.asUint8List();
              completer.complete(bytes.isNotEmpty ? bytes : null);
            } catch (_) {
              completer.complete(null);
            }
          }
        }.toJS,
      );

      reader.addEventListener(
        'error',
        (web.Event _) {
          if (!completer.isCompleted) completer.complete(null);
        }.toJS,
      );

      reader.readAsArrayBuffer(file);
    }.toJS,
  );

  // Trigger the browser file dialog synchronously (must be in same gesture)
  input.click();

  // Safety timeout in case neither event fires
  Future.delayed(const Duration(seconds: 60), () {
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
