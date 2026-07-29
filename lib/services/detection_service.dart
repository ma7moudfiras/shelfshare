import 'dart:io';

import '../models/detection_result.dart';

/// Contract the UI depends on for running detection over a captured photo.
///
/// The camera screen is written against this interface rather than against
/// Roboflow directly, so the inference backend can be swapped -- or faked in a
/// widget test -- without touching a single widget.
abstract interface class DetectionService {
  /// Runs product detection over [imageFile] and returns the parsed result.
  ///
  /// Throws a [DetectionException] subclass on failure; implementations should
  /// not return a partially-populated result to signal an error.
  Future<DetectionResult> detectProducts(File imageFile);

  /// Releases any resources held by the implementation, e.g. an HTTP client.
  void dispose();
}
