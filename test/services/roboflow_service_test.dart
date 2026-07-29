import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf_monitor/models/detection_result.dart';
import 'package:shelf_monitor/services/detection_exception.dart';
import 'package:shelf_monitor/services/roboflow_service.dart';

/// Smoke test for the detection path.
///
/// Runs [RoboflowService.detectProducts] over a sample image with the HTTP
/// layer stubbed to replay a *real* response recorded from the deployed
/// `aystro-project` workflow (see `test/fixtures/workflow_response.json`).
/// That keeps the test hermetic -- no network, no API key -- while still
/// asserting against the actual response shape the workflow produces.
void main() {
  final fixture = File('test/fixtures/workflow_response.json');
  final sampleImage = File('test/fixtures/sample_shelf.jpg');

  setUp(() {
    // Satisfies AppConfig without touching a real .env file.
    dotenv.loadFromString(
      envString: '''
ROBOFLOW_API_KEY=test_key
ROBOFLOW_WORKSPACE=ma7mouds-workspace
ROBOFLOW_WORKFLOW_ID=aystro-project
ROBOFLOW_BASE_URL=https://serverless.roboflow.com
''',
    );
  });

  /// Builds a service whose HTTP client replays [body] and captures the
  /// outgoing request for inspection.
  (RoboflowService, List<http.Request>) serviceReplaying(
    String body, {
    int status = 200,
  }) {
    final captured = <http.Request>[];
    final client = MockClient((request) async {
      captured.add(request);
      return http.Response(body, status);
    });
    return (RoboflowService(client: client), captured);
  }

  group('detectProducts', () {
    test('parses the recorded workflow response into detections', () async {
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      final result = await service.detectProducts(sampleImage);

      expect(result.isNotEmpty, isTrue);
      expect(result.count, 1);

      // The output key the detections were discovered under -- the workflow
      // declares exactly one JsonField output named `predictions`.
      expect(result.sourceOutputKey, 'predictions');

      // Image dimensions travel with the predictions and drive the overlay.
      expect(result.imageWidth, 720);
      expect(result.imageHeight, 540);

      final detection = result.detections.single;
      expect(detection.className, 'coca-cola');
      expect(detection.classId, 0);
      expect(detection.confidence, closeTo(0.448, 0.001));
      expect(detection.box.centerX, 624);
      expect(detection.box.centerY, 70);
      expect(detection.box.width, 48);
      expect(detection.box.height, 140);

      // This workflow has no visualisation block, so no image comes back.
      expect(result.hasAnnotatedImage, isFalse);
    });

    test('sends the request shape the Workflows API expects', () async {
      final (service, captured) = serviceReplaying(
        fixture.readAsStringSync(),
      );

      await service.detectProducts(sampleImage);

      expect(captured, hasLength(1));
      final request = captured.single;

      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://serverless.roboflow.com/ma7mouds-workspace/workflows/aystro-project',
      );
      expect(request.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['api_key'], 'test_key');

      // Image is sent base64-encoded, since captures are local files.
      final image = (body['inputs'] as Map)['image'] as Map;
      expect(image['type'], 'base64');
      expect(
        base64Decode(image['value'] as String),
        sampleImage.readAsBytesSync(),
      );

      // Parameter names must match the workflow's declared inputs exactly.
      expect(
        (body['parameters'] as Map).keys,
        containsAll([
          'confidence',
          'iou_threshold',
          'class_agnostic_nms',
          'max_detections',
          'model_id',
        ]),
      );
      expect((body['parameters'] as Map)['model_id'], 'aystro-project/1');
    });

    test('computes Share of Shelf from the parsed detections', () async {
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      final result = await service.detectProducts(sampleImage);
      final share = result.shareOfShelf;

      // A single class necessarily holds the whole shelf.
      expect(share.classCount, 1);
      expect(share.shares.single.className, 'coca-cola');
      expect(share.shares.single.percentage, closeTo(100, 0.001));
      expect(share.summaryLine, 'coca-cola: 100%');
    });
  });

  group('failure handling', () {
    test('throws a typed API exception on 401 without retrying', () async {
      final (service, captured) = serviceReplaying(
        '{"message":"Unauthorized"}',
        status: 401,
      );

      await expectLater(
        service.detectProducts(sampleImage),
        throwsA(
          isA<DetectionApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.isRetryable, 'isRetryable', isFalse),
        ),
      );

      // A bad key must fail fast rather than burn all three attempts.
      expect(captured, hasLength(1));
    });

    test('retries retryable server errors up to maxAttempts', () async {
      final (service, captured) = serviceReplaying(
        'upstream failure',
        status: 503,
      );

      await expectLater(
        service.detectProducts(sampleImage),
        throwsA(isA<DetectionApiException>()),
      );

      expect(captured, hasLength(3));
    });

    test('throws a parse exception when no detection output is present', () {
      final (service, _) = serviceReplaying(
        jsonEncode({
          'result': [
            {'some_other_output': 'nothing detection-shaped here'},
          ],
        }),
      );

      expect(
        service.detectProducts(sampleImage),
        throwsA(isA<DetectionParseException>()),
      );
    });

    test('reports a missing API key as a config error', () async {
      dotenv.loadFromString(
        envString: 'ROBOFLOW_WORKSPACE=ma7mouds-workspace',
      );
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      await expectLater(
        service.detectProducts(sampleImage),
        throwsA(isA<DetectionConfigException>()),
      );
    });
  });

  test('empty prediction list yields an empty, non-throwing result', () async {
    final (service, _) = serviceReplaying(
      jsonEncode({
        'result': [
          {
            'predictions': {
              'image': {'width': 720, 'height': 540},
              'predictions': <Object>[],
            },
          },
        ],
      }),
    );

    final result = await service.detectProducts(sampleImage);

    expect(result, isA<DetectionResult>());
    expect(result.isEmpty, isTrue);
    expect(result.shareOfShelf.isEmpty, isTrue);
    expect(result.shareOfShelf.summaryLine, 'No products detected');
  });
}
