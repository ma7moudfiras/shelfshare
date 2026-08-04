import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/can_shape_rule.dart';
import '../models/detection_result.dart';
import 'detection_exception.dart';
import 'detection_service.dart';
import 'workflow_response_parser.dart';

/// Runtime parameters accepted by the `aystro-project` workflow.
///
/// Names and defaults mirror the workflow's declared `WorkflowParameter`
/// inputs exactly, as returned by the Roboflow API:
///
/// | name                 | default              |
/// |----------------------|----------------------|
/// | `confidence`         | `0.4`                |
/// | `iou_threshold`      | `0.3`                |
/// | `class_agnostic_nms` | `false`              |
/// | `max_detections`     | `1000`               |
/// | `model_id`           | `aystro-project/1`   |
///
/// The workflow's own `model_id` default is version 1, trained on 27 images
/// before most classes existed. [AppConfig.defaultModelId] points at the newest
/// trained version instead, which is what makes classes beyond `coca-cola`
/// appear.
///
/// Sending a name the workflow does not declare is rejected by the API, so this
/// class is the single place those names are written down.
@immutable
class RoboflowParameters {
  /// Minimum confidence a detection must reach to be returned.
  final double confidence;

  /// IoU threshold used by non-max suppression.
  final double iouThreshold;

  /// Whether NMS ignores class when suppressing overlapping boxes.
  final bool classAgnosticNms;

  /// Hard cap on returned detections.
  final int maxDetections;

  /// Model version to run, e.g. `aystro-project/11`.
  final String modelId;

  const RoboflowParameters({
    this.confidence = 0.4,
    this.iouThreshold = 0.3,
    this.classAgnosticNms = false,
    this.maxDetections = 1000,
    this.modelId = AppConfig.defaultModelId,
  });

  /// Builds parameters using the model configured in `.env`.
  ///
  /// Used as the service default so changing `ROBOFLOW_MODEL_ID` takes effect
  /// without touching code.
  factory RoboflowParameters.fromConfig() =>
      RoboflowParameters(modelId: AppConfig.modelId);

  /// Serialises to the exact parameter names the workflow declares.
  Map<String, dynamic> toJson() => {
    'confidence': confidence,
    'iou_threshold': iouThreshold,
    'class_agnostic_nms': classAgnosticNms,
    'max_detections': maxDetections,
    'model_id': modelId,
  };

  RoboflowParameters copyWith({
    double? confidence,
    double? iouThreshold,
    bool? classAgnosticNms,
    int? maxDetections,
    String? modelId,
  }) {
    return RoboflowParameters(
      confidence: confidence ?? this.confidence,
      iouThreshold: iouThreshold ?? this.iouThreshold,
      classAgnosticNms: classAgnosticNms ?? this.classAgnosticNms,
      maxDetections: maxDetections ?? this.maxDetections,
      modelId: modelId ?? this.modelId,
    );
  }
}

/// Runs the `aystro-project` Roboflow Workflow over a captured photo.
///
/// There is no official Dart SDK, so this posts to the serverless REST endpoint
/// directly and mirrors what the JS/Python SDKs do: a JSON body carrying
/// `api_key`, `inputs`, and `parameters`.
///
/// ```
/// POST https://serverless.roboflow.com/{workspace}/workflows/{workflow_id}
/// Content-Type: application/json
/// {"api_key": "...", "inputs": {"image": {"type": "base64", "value": "..."}}}
/// ```
///
/// Images are sent as base64 because captures are local files, not hosted URLs.
///
/// ## Proxy mode
///
/// When [useProxy] is set the request goes to a same-origin serverless function
/// instead, and **`api_key` is omitted** -- the server attaches it. This is what
/// web builds use, since anything shipped to a browser is publicly readable.
/// The response shape is identical either way, so parsing is unaffected.
///
/// Note: the published workflow includes a `roboflow_dataset_upload` step, so
/// every successful call also uploads the photo into the `aystro-project`
/// dataset for active learning. That is the workflow's behaviour, not this
/// client's -- but it does mean inference is not side-effect free.
class RoboflowService implements DetectionService {
  final http.Client _client;
  final bool _ownsClient;
  final WorkflowResponseParser _parser;

  /// Re-labels 330 ml cans from their box proportions once the response is
  /// parsed. Null runs the workflow's own labels through unchanged.
  ///
  /// See [CanShapeRule]: the classifier in the workflow cannot see the one
  /// feature that separates the two can formats, so this decides it locally.
  final CanShapeRule? shapeRule;

  /// Endpoint to POST to. Defaults to whichever mode [AppConfig] selects.
  final Uri endpoint;

  /// When true, the API key is left to the server and omitted from the body.
  final bool useProxy;

  /// Runtime parameters sent with every request.
  final RoboflowParameters parameters;

  /// Per-attempt timeout. Cold serverless starts can take a while, so this is
  /// generous rather than snappy.
  final Duration timeout;

  /// Total attempts including the first. 3 means one call plus two retries.
  final int maxAttempts;

  RoboflowService({
    http.Client? client,
    Uri? endpoint,
    bool? useProxy,
    RoboflowParameters? parameters,
    this.timeout = const Duration(seconds: 45),
    this.maxAttempts = 3,
    this.shapeRule = const CanShapeRule(),
    WorkflowResponseParser parser = const WorkflowResponseParser(),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       // An initializing formal cannot be used here: the field is private and
       // named parameters may not begin with an underscore.
       // ignore: prefer_initializing_formals
       _parser = parser,
       useProxy = useProxy ?? AppConfig.usesProxy,
       parameters = parameters ?? RoboflowParameters.fromConfig(),
       endpoint = endpoint ?? AppConfig.detectionEndpoint;

  /// Base delay for exponential backoff between retries: 500ms, then 1s.
  static const Duration _baseBackoff = Duration(milliseconds: 500);

  /// Header the web proxy uses to report which model it actually ran.
  ///
  /// Lower-case because `package:http` normalises response header names.
  static const String _effectiveModelHeader = 'x-effective-model-id';

  @override
  Future<DetectionResult> detectProducts(
    Uint8List imageBytes, {
    String? modelId,
    double? confidence,
  }) async {
    if (imageBytes.isEmpty) {
      throw const DetectionConfigException('The captured image was empty.');
    }

    // Per-call overrides from the settings sheet win over the configured
    // defaults, so the picker and confidence slider take effect immediately.
    final parameters = this.parameters.copyWith(
      modelId: modelId,
      confidence: confidence,
    );

    final body = jsonEncode({
      // In proxy mode the key stays server-side and is never sent from the
      // client, so it is not read here at all.
      if (!useProxy) 'api_key': AppConfig.roboflowApiKey,
      'inputs': {
        'image': {'type': 'base64', 'value': base64Encode(imageBytes)},
        // WorkflowParameter values belong INSIDE `inputs`, alongside the image.
        // The Workflows REST API has no top-level `parameters` field: sending
        // one is silently ignored, and the workflow then runs every declared
        // default -- which pinned model_id to aystro-project/1 and made the
        // model picker and confidence control appear to do nothing.
        ...parameters.toJson(),
      },
    });

    final stopwatch = Stopwatch()..start();
    final response = await _postWithRetries(body);
    stopwatch.stop();

    // What the client asked for, unless the server said otherwise.
    final ranModelId = response.effectiveModelId ?? parameters.modelId;

    // Roboflow reports `image: {width: null, height: null}` when the model finds
    // nothing, and the overlay cannot project boxes without dimensions. Decoding
    // the source image locally guarantees they are always available.
    final size = await _decodeImageSize(imageBytes);

    final result = _parser.parse(
      response.body,
      fallbackWidth: size?.width ?? 0,
      fallbackHeight: size?.height ?? 0,
      inferenceTime: stopwatch.elapsed,
      effectiveModelId: ranModelId,
    );

    return shapeRule?.applyTo(result) ?? result;
  }

  /// Reads the pixel dimensions of an encoded image without keeping it decoded.
  ///
  /// Returns null if the bytes are not a decodable image; the caller then falls
  /// back to whatever the response reported.
  Future<({double width, double height})?> _decodeImageSize(
    Uint8List bytes,
  ) async {
    ui.Image? image;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      return (width: image.width.toDouble(), height: image.height.toDouble());
    } catch (_) {
      return null;
    } finally {
      // Free the decoded bitmap immediately; only the dimensions are wanted.
      image?.dispose();
    }
  }

  /// POSTs [body], retrying transient failures with exponential backoff.
  ///
  /// Only retryable failures are repeated -- a 401 from a bad API key fails
  /// immediately rather than burning three attempts.
  Future<_ProxyResponse> _postWithRetries(String body) async {
    DetectionException? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _post(body);
      } on DetectionException catch (e) {
        lastError = e;
        if (!e.isRetryable || attempt == maxAttempts) rethrow;

        // 500ms, 1s, 2s ...
        await Future<void>.delayed(_baseBackoff * (1 << (attempt - 1)));
      }
    }

    // Unreachable: the loop either returns or rethrows on the final attempt.
    throw lastError ??
        const DetectionNetworkException('Detection request failed.');
  }

  Future<_ProxyResponse> _post(String body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw DetectionNetworkException(
        'Roboflow did not respond within ${timeout.inSeconds}s.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      // Wraps socket failures, DNS errors, and browser CORS/network errors.
      throw DetectionNetworkException(
        'Could not reach the detection service. Check your connection.',
        cause: e,
      );
    }

    if (response.statusCode == 200) {
      return _ProxyResponse(
        body: response.body,
        effectiveModelId: response.headers[_effectiveModelHeader],
      );
    }

    throw DetectionApiException(
      _messageForStatus(response.statusCode),
      statusCode: response.statusCode,
      // Truncated: error bodies can echo the request, base64 image and all.
      body: _truncate(response.body),
    );
  }

  String _messageForStatus(int status) {
    return switch (status) {
      400 =>
        'Roboflow rejected the request. The workflow parameters may not '
            'match its current definition.',
      401 || 403 =>
        useProxy
            ? 'The detection proxy rejected the request. Check ROBOFLOW_API_KEY '
                  'in the server environment.'
            : 'Roboflow rejected the API key. Check ROBOFLOW_API_KEY in your '
                  '.env.',
      404 =>
        useProxy
            ? 'Detection proxy not found at $endpoint.'
            : 'Workflow not found. Check ROBOFLOW_WORKSPACE and '
                  'ROBOFLOW_WORKFLOW_ID in your .env.',
      413 =>
        'The captured image was too large to send. Try a tighter aspect '
            'ratio, or retake the photo.',
      429 => 'Roboflow rate limit reached. Try again in a moment.',
      _ when status >= 500 => 'The detection service had an error ($status).',
      _ => 'The detection service returned an unexpected status ($status).',
    };
  }

  static String _truncate(String value, [int max = 300]) =>
      value.length <= max ? value : '${value.substring(0, max)}…';

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// A successful detection response, plus what the server said about it.
///
/// The body alone is not enough: the proxy may substitute a different model
/// version than the one requested, and that substitution has to reach the row
/// that gets written or the reporting silently lies about its own provenance.
class _ProxyResponse {
  final String body;
  final String? effectiveModelId;

  const _ProxyResponse({required this.body, this.effectiveModelId});
}
