import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  final sampleBytes = Uint8List.fromList(
    File('test/fixtures/sample_shelf.jpg').readAsBytesSync(),
  );

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
  ///
  /// [useProxy] is passed explicitly rather than left to AppConfig, because
  /// tests run on the VM where `kIsWeb` is always false.
  (RoboflowService, List<http.Request>) serviceReplaying(
    String body, {
    int status = 200,
    bool useProxy = false,
    Uri? endpoint,
  }) {
    final captured = <http.Request>[];
    final client = MockClient((request) async {
      captured.add(request);
      return http.Response(body, status);
    });
    return (
      RoboflowService(client: client, useProxy: useProxy, endpoint: endpoint),
      captured,
    );
  }

  group('detectProducts', () {
    test('parses the recorded workflow response into detections', () async {
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      final result = await service.detectProducts(sampleBytes);

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
      final (service, captured) = serviceReplaying(fixture.readAsStringSync());

      await service.detectProducts(sampleBytes);

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
      expect(base64Decode(image['value'] as String), sampleBytes);

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

      final result = await service.detectProducts(sampleBytes);
      final share = result.shareOfShelf;

      // A single class necessarily holds the whole shelf.
      expect(share.classCount, 1);
      expect(share.shares.single.className, 'coca-cola');
      expect(share.shares.single.percentage, closeTo(100, 0.001));
      expect(share.summaryLine, 'coca-cola: 100%');
    });
  });

  group('response envelopes', () {
    // The serverless REST endpoint returns {"outputs": [...]}. Some tooling --
    // the Roboflow MCP server among it -- normalises the same payload to
    // {"result": [...]}. Both must parse to the same thing.
    test('parses the "outputs" envelope the REST endpoint returns', () async {
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 1);
      expect(result.detections.single.className, 'coca-cola');
    });

    test('parses a normalised "result" envelope identically', () async {
      final decoded =
          jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
      final normalised = jsonEncode({'result': decoded['outputs']});

      final (service, _) = serviceReplaying(normalised);

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 1);
      expect(result.detections.single.className, 'coca-cola');
      expect(result.imageWidth, 720);
    });

    test('falls back to the source image size when dimensions are null', () async {
      // Roboflow reports image: {width: null, height: null} when nothing is
      // detected. Boxes cannot be projected without dimensions, so the service
      // decodes them from the captured bytes instead.
      final (service, _) = serviceReplaying(
        File('test/fixtures/workflow_response_empty.json').readAsStringSync(),
      );

      final result = await service.detectProducts(sampleBytes);

      expect(result.isEmpty, isTrue);
      // sample_shelf.jpg is 720x540.
      expect(result.imageWidth, 720);
      expect(result.imageHeight, 540);
    });
  });

  group('proxy mode', () {
    test('never sends the API key to the proxy', () async {
      final (service, captured) = serviceReplaying(
        fixture.readAsStringSync(),
        useProxy: true,
        endpoint: Uri.parse('https://example.test/api/detect'),
      );

      await service.detectProducts(sampleBytes);

      final body = jsonDecode(captured.single.body) as Map<String, dynamic>;

      // The whole point of the proxy: the browser bundle holds no secret.
      expect(body.containsKey('api_key'), isFalse);
      expect(captured.single.body, isNot(contains('test_key')));

      // Everything else is identical, so the server can forward it as-is.
      expect((body['inputs'] as Map)['image'], isNotNull);
      expect((body['parameters'] as Map)['model_id'], 'aystro-project/1');
    });

    test('parses a proxied response identically', () async {
      final (service, _) = serviceReplaying(
        fixture.readAsStringSync(),
        useProxy: true,
        endpoint: Uri.parse('https://example.test/api/detect'),
      );

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 1);
      expect(result.detections.single.className, 'coca-cola');
    });

    test('works with no API key present at all', () async {
      dotenv.loadFromString(
        envString: 'ROBOFLOW_WORKSPACE=ma7mouds-workspace',
      );
      final (service, _) = serviceReplaying(
        fixture.readAsStringSync(),
        useProxy: true,
        endpoint: Uri.parse('https://example.test/api/detect'),
      );

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 1);
    });
  });

  group('failure handling', () {
    test('throws a typed API exception on 401 without retrying', () async {
      final (service, captured) = serviceReplaying(
        '{"message":"Unauthorized"}',
        status: 401,
      );

      await expectLater(
        service.detectProducts(sampleBytes),
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
        service.detectProducts(sampleBytes),
        throwsA(isA<DetectionApiException>()),
      );

      expect(captured, hasLength(3));
    });

    test('throws a parse exception when no detection output is present', () {
      final (service, _) = serviceReplaying(
        jsonEncode({
          'outputs': [
            {'some_other_output': 'nothing detection-shaped here'},
          ],
        }),
      );

      expect(
        service.detectProducts(sampleBytes),
        throwsA(isA<DetectionParseException>()),
      );
    });

    test('reports a missing API key as a config error in direct mode', () async {
      dotenv.loadFromString(
        envString: 'ROBOFLOW_WORKSPACE=ma7mouds-workspace',
      );
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      await expectLater(
        service.detectProducts(sampleBytes),
        throwsA(isA<DetectionConfigException>()),
      );
    });

    test('rejects empty image bytes', () {
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      expect(
        service.detectProducts(Uint8List(0)),
        throwsA(isA<DetectionConfigException>()),
      );
    });
  });

  test('empty prediction list yields an empty, non-throwing result', () async {
    final (service, _) = serviceReplaying(
      jsonEncode({
        'outputs': [
          {
            'predictions': {
              'image': {'width': 720, 'height': 540},
              'predictions': <Object>[],
            },
          },
        ],
      }),
    );

    final result = await service.detectProducts(sampleBytes);

    expect(result, isA<DetectionResult>());
    expect(result.isEmpty, isTrue);
    expect(result.shareOfShelf.isEmpty, isTrue);
    expect(result.shareOfShelf.summaryLine, 'No products detected');
  });
}
