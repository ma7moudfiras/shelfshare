import 'dart:typed_data';

import '../models/detection_result.dart';

/// Contract the UI depends on for running detection over a captured photo.
///
/// The camera screen is written against this interface rather than against
/// Roboflow directly, so the inference backend can be swapped -- or faked in a
/// widget test -- without touching a single widget.
///
/// Takes raw bytes rather than a `dart:io` File so the same code path works on
/// web, where `dart:io` is unavailable.
abstract interface class DetectionService {
  /// Runs product detection over the encoded image in [imageBytes].
  ///
  /// [modelId] overrides the configured model version for this call, e.g.
  /// `aystro-project/11`. Null uses whatever the implementation defaults to.
  ///
  /// Throws a [DetectionException] subclass on failure; implementations should
  /// not return a partially-populated result to signal an error.
  Future<DetectionResult> detectProducts(
    Uint8List imageBytes, {
    String? modelId,
  });

  /// Releases any resources held by the implementation, e.g. an HTTP client.
  void dispose();
}
