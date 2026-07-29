import 'dart:convert';
import 'dart:typed_data';

import '../models/bounding_box.dart';
import '../models/detection.dart';
import '../models/detection_result.dart';
import 'detection_exception.dart';

/// Translates a raw Roboflow Workflows response into a [DetectionResult].
///
/// Deliberately free of HTTP concerns so it can be unit-tested against a
/// recorded response with no network and no API key.
///
/// The parser *discovers* which output holds the detections rather than
/// assuming a key name. The `aystro-project` workflow happens to name its only
/// output `predictions`, but renaming it in the Roboflow editor -- or adding a
/// visualisation output -- must not break the app, so every output is probed
/// for a recognisable shape instead.
///
/// A real response from `aystro-project` looks like:
/// ```json
/// {"result": [
///   {"predictions": {
///      "image": {"width": 720, "height": 540},
///      "predictions": [
///        {"x": 624, "y": 70, "width": 48, "height": 140,
///         "confidence": 0.448, "class": "coca-cola", "class_id": 0}
///      ]}}]}
/// ```
class WorkflowResponseParser {
  const WorkflowResponseParser();

  /// Envelope keys seen from the Workflows API. `result` is what the serverless
  /// host returns today; `outputs` is accepted because the self-hosted
  /// inference server uses it.
  static const _envelopeKeys = ['result', 'outputs'];

  /// Keys that have held a detection list across Roboflow block versions.
  static const _detectionListKeys = ['predictions', 'detections'];

  /// Parses [body], the raw JSON response text.
  ///
  /// [fallbackWidth]/[fallbackHeight] are used when the workflow does not
  /// report image dimensions -- without them, boxes cannot be projected onto
  /// the view.
  DetectionResult parse(
    String body, {
    double fallbackWidth = 0,
    double fallbackHeight = 0,
    Duration? inferenceTime,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw DetectionParseException(
        'Roboflow returned a response that was not valid JSON.',
        cause: e,
      );
    }

    final outputs = _firstImageOutputs(decoded);
    if (outputs == null) {
      throw const DetectionParseException(
        'Roboflow response contained no workflow outputs.',
      );
    }

    // Probe every output for detections, then for an annotated image. Both are
    // optional: a workflow may return only one of them.
    List<Detection>? detections;
    String? sourceKey;
    double imageWidth = fallbackWidth;
    double imageHeight = fallbackHeight;
    Uint8List? annotatedImage;

    for (final entry in outputs.entries) {
      final value = entry.value;

      if (detections == null) {
        final found = _tryReadDetections(value);
        if (found != null) {
          detections = found.detections;
          sourceKey = entry.key;
          if (found.imageWidth > 0) imageWidth = found.imageWidth;
          if (found.imageHeight > 0) imageHeight = found.imageHeight;
        }
      }

      annotatedImage ??= _tryReadImageBytes(value);
    }

    if (detections == null) {
      throw DetectionParseException(
        'No detection output found in the Roboflow response. '
        'Outputs present: ${outputs.keys.join(", ")}',
      );
    }

    return DetectionResult(
      detections: detections,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      annotatedImage: annotatedImage,
      sourceOutputKey: sourceKey,
      inferenceTime: inferenceTime,
    );
  }

  /// Unwraps the envelope and returns the outputs for the first input image.
  ///
  /// The API returns one entry per input image; this app always sends exactly
  /// one, so only the first is read.
  Map<String, dynamic>? _firstImageOutputs(Object? decoded) {
    if (decoded is List) return _asOutputMap(decoded.firstOrNull);

    if (decoded is Map) {
      for (final key in _envelopeKeys) {
        final envelope = decoded[key];
        if (envelope is List) return _asOutputMap(envelope.firstOrNull);
        if (envelope is Map) return _asOutputMap(envelope);
      }
      // Some deployments return the per-image map directly, unwrapped.
      return _asOutputMap(decoded);
    }

    return null;
  }

  Map<String, dynamic>? _asOutputMap(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  /// Attempts to read detections out of a single workflow output value.
  ///
  /// Handles both shapes seen in practice: a wrapper object carrying `image`
  /// dimensions plus a nested detection list, and a bare list of detections.
  _ParsedDetections? _tryReadDetections(Object? value) {
    if (value is List) {
      final detections = _readDetectionList(value);
      return detections == null
          ? null
          : _ParsedDetections(detections, 0, 0);
    }

    if (value is! Map) return null;

    final map = value.cast<String, dynamic>();

    // Image dimensions travel alongside the detections and are what the
    // overlay needs to map box coordinates onto the rendered photo.
    var width = 0.0;
    var height = 0.0;
    final image = map['image'];
    if (image is Map) {
      width = _toDouble(image['width']) ?? 0;
      height = _toDouble(image['height']) ?? 0;
    }

    for (final key in _detectionListKeys) {
      final candidate = map[key];
      if (candidate is List) {
        final detections = _readDetectionList(candidate);
        if (detections != null) {
          return _ParsedDetections(detections, width, height);
        }
      }
    }

    return null;
  }

  /// Returns parsed detections, or null when [items] is not detection-shaped.
  ///
  /// An empty list is a legitimate result -- the model simply found nothing --
  /// so it parses successfully rather than being treated as a mismatch.
  List<Detection>? _readDetectionList(List<Object?> items) {
    if (items.isEmpty) return const [];

    final detections = <Detection>[];
    for (final item in items) {
      if (item is! Map) continue;
      final detection = _readDetection(item.cast<String, dynamic>());
      if (detection != null) detections.add(detection);
    }

    // Nothing in the list looked like a detection: this output is something
    // else entirely, so report a mismatch instead of an empty result.
    return detections.isEmpty ? null : detections;
  }

  /// Reads one detection, ignoring every field the UI does not use.
  ///
  /// Segmentation `points` in particular are dropped here and never retained --
  /// polygon arrays dwarf the rest of the payload.
  Detection? _readDetection(Map<String, dynamic> map) {
    final x = _toDouble(map['x']);
    final y = _toDouble(map['y']);
    final width = _toDouble(map['width']);
    final height = _toDouble(map['height']);

    // Roboflow reports boxes as centre + size; without all four this entry is
    // not a bounding box.
    if (x == null || y == null || width == null || height == null) return null;

    final className =
        (map['class'] ?? map['class_name'] ?? map['label'])?.toString();
    if (className == null || className.isEmpty) return null;

    return Detection(
      className: className,
      confidence: _toDouble(map['confidence']) ?? 0,
      box: BoundingBox(
        centerX: x,
        centerY: y,
        width: width,
        height: height,
      ),
      classId: _toInt(map['class_id']),
      trackerId: _toInt(map['tracker_id']),
    );
  }

  /// Extracts an annotated image from an output, if it is image-shaped.
  ///
  /// Visualisation blocks return either a bare base64 string or
  /// `{"type": "base64", "value": "..."}`. The bytes are returned for in-memory
  /// display and never logged.
  Uint8List? _tryReadImageBytes(Object? value) {
    String? encoded;

    if (value is String) {
      encoded = value;
    } else if (value is Map) {
      final type = value['type']?.toString();
      if (type == 'base64' || type == 'image') {
        encoded = value['value']?.toString();
      }
    }

    if (encoded == null || encoded.length < 256) return null;

    // Tolerate data URI prefixes, e.g. "data:image/jpeg;base64,...".
    final commaIndex = encoded.indexOf(',');
    if (encoded.startsWith('data:') && commaIndex != -1) {
      encoded = encoded.substring(commaIndex + 1);
    }

    try {
      return base64Decode(encoded);
    } catch (_) {
      // Not base64 -- just a long string output. Not an error.
      return null;
    }
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Internal carrier for detections plus the dimensions found beside them.
class _ParsedDetections {
  final List<Detection> detections;
  final double imageWidth;
  final double imageHeight;

  const _ParsedDetections(this.detections, this.imageWidth, this.imageHeight);
}
