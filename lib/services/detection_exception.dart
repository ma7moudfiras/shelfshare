/// Base type for every failure the detection layer can surface.
///
/// The UI catches this one type and shows [message]; the subclasses exist so
/// callers can tell a retryable network blip from a bad API key without string
/// matching on error text.
sealed class DetectionException implements Exception {
  /// Operator-facing explanation, safe to show in the UI.
  final String message;

  /// Underlying error, when this wraps one.
  final Object? cause;

  const DetectionException(this.message, {this.cause});

  /// Whether retrying the same request could plausibly succeed.
  bool get isRetryable => false;

  @override
  String toString() => '$runtimeType: $message';
}

/// Configuration is missing or malformed -- typically no `.env`, or no API key
/// in it. Never retryable: the app cannot fix this on its own.
class DetectionConfigException extends DetectionException {
  const DetectionConfigException(super.message, {super.cause});
}

/// The request could not reach Roboflow, or timed out waiting for it.
class DetectionNetworkException extends DetectionException {
  const DetectionNetworkException(super.message, {super.cause});

  @override
  bool get isRetryable => true;
}

/// Roboflow answered, but with an error status.
class DetectionApiException extends DetectionException {
  /// HTTP status code returned by the inference host.
  final int statusCode;

  /// Response body, truncated -- error bodies can echo large payloads back.
  final String? body;

  const DetectionApiException(
    super.message, {
    required this.statusCode,
    this.body,
    super.cause,
  });

  /// 5xx and 429 are transient; 4xx generally means the request itself is wrong.
  @override
  bool get isRetryable => statusCode >= 500 || statusCode == 429;

  @override
  String toString() => 'DetectionApiException($statusCode): $message';
}

/// Roboflow answered successfully, but the body was not shaped as expected --
/// malformed JSON, or no recognisable detection output in it.
class DetectionParseException extends DetectionException {
  const DetectionParseException(super.message, {super.cause});
}
