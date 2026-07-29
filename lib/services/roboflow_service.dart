import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
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

  /// Model version to run, e.g. `aystro-project/1`.
  final String modelId;

  const RoboflowParameters({
    this.confidence = 0.4,
    this.iouThreshold = 0.3,
    this.classAgnosticNms = false,
    this.maxDetections = 1000,
    this.modelId = 'aystro-project/1',
  });

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
/// Note: the published workflow includes a `roboflow_dataset_upload` step, so
/// every successful call also uploads the photo into the `aystro-project`
/// dataset for active learning. That is the workflow's behaviour, not this
/// client's -- but it does mean inference is not side-effect free.
class RoboflowService implements DetectionService {
  final http.Client _client;
  final bool _ownsClient;
  final WorkflowResponseParser _parser;

  /// Endpoint to POST to. Defaults to the one built from `.env`.
  final Uri endpoint;

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
    this.parameters = const RoboflowParameters(),
    this.timeout = const Duration(seconds: 45),
    this.maxAttempts = 3,
    WorkflowResponseParser parser = const WorkflowResponseParser(),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       // An initializing formal cannot be used here: the field is private and
       // named parameters may not begin with an underscore.
       // ignore: prefer_initializing_formals
       _parser = parser,
       endpoint = endpoint ?? AppConfig.workflowEndpoint;

  /// Base delay for exponential backoff between retries: 500ms, then 1s.
  static const Duration _baseBackoff = Duration(milliseconds: 500);

  @override
  Future<DetectionResult> detectProducts(File imageFile) async {
    if (!await imageFile.exists()) {
      throw DetectionConfigException(
        'Captured image no longer exists at ${imageFile.path}',
      );
    }

    // Throws DetectionConfigException when .env is missing or unfilled.
    final apiKey = AppConfig.roboflowApiKey;

    final bytes = await imageFile.readAsBytes();
    final body = jsonEncode({
      'api_key': apiKey,
      'inputs': {
        'image': {'type': 'base64', 'value': base64Encode(bytes)},
      },
      'parameters': parameters.toJson(),
    });

    final stopwatch = Stopwatch()..start();
    final response = await _postWithRetries(body);
    stopwatch.stop();

    return _parser.parse(response, inferenceTime: stopwatch.elapsed);
  }

  /// POSTs [body], retrying transient failures with exponential backoff.
  ///
  /// Only retryable failures are repeated -- a 401 from a bad API key fails
  /// immediately rather than burning three attempts.
  Future<String> _postWithRetries(String body) async {
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

  Future<String> _post(String body) async {
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
    } on SocketException catch (e) {
      throw DetectionNetworkException(
        'Could not reach Roboflow. Check your network connection.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw DetectionNetworkException(
        'The request to Roboflow failed.',
        cause: e,
      );
    }

    if (response.statusCode == 200) return response.body;

    throw DetectionApiException(
      _messageForStatus(response.statusCode),
      statusCode: response.statusCode,
      // Truncated: error bodies can echo the request, base64 image and all.
      body: _truncate(response.body),
    );
  }

  String _messageForStatus(int status) {
    return switch (status) {
      400 => 'Roboflow rejected the request. The workflow parameters may not '
          'match its current definition.',
      401 || 403 =>
        'Roboflow rejected the API key. Check ROBOFLOW_API_KEY in your .env.',
      404 =>
        'Workflow not found. Check ROBOFLOW_WORKSPACE and ROBOFLOW_WORKFLOW_ID '
            'in your .env.',
      413 => 'The captured image was too large for Roboflow to accept.',
      429 => 'Roboflow rate limit reached. Try again in a moment.',
      _ when status >= 500 => 'Roboflow had a server error ($status).',
      _ => 'Roboflow returned an unexpected status ($status).',
    };
  }

  static String _truncate(String value, [int max = 300]) =>
      value.length <= max ? value : '${value.substring(0, max)}…';

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
