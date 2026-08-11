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
ROBOFLOW_WORKFLOW_ID=aystro-detect-classify-brand
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
      expect(result.count, 2);

      // The output key the detections were discovered under. The pipeline
      // declares two JsonField outputs -- `predictions` (brand-refined) and
      // `raw_detections` (the class-agnostic detector's own output) -- and
      // `predictions` is declared first, so it must win.
      expect(result.sourceOutputKey, 'predictions');

      // Image dimensions travel with the predictions and drive the overlay.
      expect(result.imageWidth, 768);
      expect(result.imageHeight, 614);

      final xlEnergy = result.detections.first;
      expect(xlEnergy.className, 'xl_energy');
      expect(xlEnergy.classId, 4);
      // The fixture's classifier confidence is 0.9993, but the fixture also
      // carries a raw_detections output with the detector's own confidence
      // for this box (0.9810...). WorkflowResponseParser multiplies the two,
      // so the displayed number reflects both stages, not just Stage 2's
      // classifier -- see the "confidence blending" group below.
      expect(xlEnergy.confidence, closeTo(0.9803, 0.0001));
      expect(xlEnergy.box.centerX, 212.5);
      expect(xlEnergy.box.centerY, 459.5);
      expect(xlEnergy.box.width, 77);
      expect(xlEnergy.box.height, 187);

      final cocaCola = result.detections.last;
      // Relabelled by CanShapeRule (the default shapeRule): this box's h/w
      // is 2.425, above the 2.05 slim threshold. See can_shape_rule_test.dart
      // for the rule's own dedicated coverage.
      expect(cocaCola.className, 'coca-cola-slim');
      expect(cocaCola.classId, 5);
      expect(cocaCola.confidence, closeTo(0.961, 0.0001));

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
        'https://serverless.roboflow.com/ma7mouds-workspace/workflows/aystro-detect-classify-brand',
      );
      expect(request.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['api_key'], 'test_key');

      // Image is sent base64-encoded, since captures are local files.
      final image = (body['inputs'] as Map)['image'] as Map;
      expect(image['type'], 'base64');
      expect(base64Decode(image['value'] as String), sampleBytes);

      // Parameters must sit INSIDE `inputs`, not in a sibling `parameters`
      // object -- the Workflows REST API ignores the latter entirely, which
      // silently pins every run to the workflow's declared defaults.
      expect(
        body.containsKey('parameters'),
        isFalse,
        reason: 'a top-level parameters block is silently ignored by Roboflow',
      );
      // Only detect_confidence/detect_model_id are sent -- there is no
      // top-level model_id once the workflow runs two models, and
      // brand_model_id has no per-call override.
      expect(
        (body['inputs'] as Map).keys,
        containsAll(['image', 'detect_confidence', 'detect_model_id']),
      );
      expect(
        (body['inputs'] as Map)['detect_model_id'],
        'aystro-project-v2/2',
      );
    });

    test('computes Share of Shelf from the parsed detections', () async {
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      final result = await service.detectProducts(sampleBytes);
      final share = result.shareOfShelf;

      // xl_energy: 77x187 = 14399 sq px. coca-cola: 40x97 = 3880 sq px.
      // Total 18279; xl_energy takes the larger share. The coca-cola
      // detection is relabelled coca-cola-slim by CanShapeRule (h/w 2.425),
      // which changes its class name but not its area or share.
      expect(share.classCount, 2);
      expect(share.shares.first.className, 'xl_energy');
      expect(share.shares.first.percentage, closeTo(78.77, 0.01));
      expect(share.shares.last.className, 'coca-cola-slim');
      expect(share.shares.last.percentage, closeTo(21.23, 0.01));
    });
  });

  group('model selection', () {
    test(
      'defaults to the newest trained detector, not the workflow default',
      () async {
        final (service, captured) = serviceReplaying(
          fixture.readAsStringSync(),
        );

        await service.detectProducts(sampleBytes);

        final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
        expect(
          (body['inputs'] as Map)['detect_model_id'],
          'aystro-project-v2/2',
        );
      },
    );

    test('honours ROBOFLOW_MODEL_ID from the environment', () async {
      dotenv.loadFromString(
        envString: '''
ROBOFLOW_API_KEY=test_key
ROBOFLOW_MODEL_ID=aystro-project-v2/1
''',
      );

      final (service, captured) = serviceReplaying(fixture.readAsStringSync());
      await service.detectProducts(sampleBytes);

      final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
      expect(
        (body['inputs'] as Map)['detect_model_id'],
        'aystro-project-v2/1',
      );
    });

    test('an explicit parameters object still wins', () async {
      final captured = <http.Request>[];
      final client = MockClient((request) async {
        captured.add(request);
        return http.Response(fixture.readAsStringSync(), 200);
      });
      final service = RoboflowService(
        client: client,
        useProxy: false,
        parameters: const RoboflowParameters(modelId: 'aystro-project-v2/1'),
      );

      await service.detectProducts(sampleBytes);

      final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
      expect(
        (body['inputs'] as Map)['detect_model_id'],
        'aystro-project-v2/1',
      );
    });
  });

  group('per-call overrides reach the wire', () {
    test('modelId and confidence are sent inside inputs', () async {
      final (service, captured) = serviceReplaying(fixture.readAsStringSync());

      await service.detectProducts(
        sampleBytes,
        modelId: 'aystro-project-v2/1',
        confidence: 0.15,
      );

      final inputs =
          (jsonDecode(captured.single.body) as Map<String, dynamic>)['inputs']
              as Map;
      expect(inputs['detect_model_id'], 'aystro-project-v2/1');
      expect(inputs['detect_confidence'], closeTo(0.15, 1e-9));
    });
  });

  group('confidence blending against raw_detections', () {
    test(
      'a detection the detector was barely sure about does not read as '
      '100% just because the classifier is confident',
      () async {
        final (service, _) = serviceReplaying(
          jsonEncode({
            'outputs': [
              {
                'predictions': {
                  'image': {'width': 720, 'height': 540},
                  'predictions': [
                    {
                      'x': 624.0,
                      'y': 70.0,
                      'width': 48.0,
                      'height': 140.0,
                      'confidence': 0.999,
                      'class': 'sprite',
                      'class_id': 2,
                    },
                  ],
                },
                'raw_detections': {
                  'image': {'width': 720, 'height': 540},
                  'predictions': [
                    {
                      'x': 624.0,
                      'y': 70.0,
                      'width': 48.0,
                      'height': 140.0,
                      'confidence': 0.21,
                      'class': 'product',
                      'class_id': 0,
                    },
                  ],
                },
              },
            ],
          }),
        );

        final result = await service.detectProducts(sampleBytes);

        expect(result.count, 1);
        expect(result.detections.single.className, 'sprite');
        expect(
          result.detections.single.confidence,
          closeTo(0.999 * 0.21, 1e-9),
        );
      },
    );

    test(
      'leaves confidence unchanged when the response has no raw_detections '
      'output',
      () async {
        final (service, _) = serviceReplaying(
          jsonEncode({
            'outputs': [
              {
                'predictions': {
                  'image': {'width': 720, 'height': 540},
                  'predictions': [
                    {
                      'x': 624.0,
                      'y': 70.0,
                      'width': 48.0,
                      'height': 140.0,
                      'confidence': 0.75,
                      'class': 'sprite',
                      'class_id': 2,
                    },
                  ],
                },
              },
            ],
          }),
        );

        final result = await service.detectProducts(sampleBytes);

        expect(result.detections.single.confidence, closeTo(0.75, 1e-9));
      },
    );

    test(
      'leaves confidence unchanged when raw_detections is a different '
      'length',
      () async {
        // Should not happen in practice -- both outputs come from the same
        // `detect` step -- but a parser must decline rather than misattribute
        // confidence to the wrong box on a mismatch.
        final (service, _) = serviceReplaying(
          jsonEncode({
            'outputs': [
              {
                'predictions': {
                  'image': {'width': 720, 'height': 540},
                  'predictions': [
                    {
                      'x': 624.0,
                      'y': 70.0,
                      'width': 48.0,
                      'height': 140.0,
                      'confidence': 0.75,
                      'class': 'sprite',
                      'class_id': 2,
                    },
                  ],
                },
                'raw_detections': {
                  'image': {'width': 720, 'height': 540},
                  'predictions': <Object>[],
                },
              },
            ],
          }),
        );

        final result = await service.detectProducts(sampleBytes);

        expect(result.detections.single.confidence, closeTo(0.75, 1e-9));
      },
    );
  });

  group('response envelopes', () {
    // The serverless REST endpoint returns {"outputs": [...]}. Some tooling --
    // the Roboflow MCP server among it -- normalises the same payload to
    // {"result": [...]}. Both must parse to the same thing.
    test('parses the "outputs" envelope the REST endpoint returns', () async {
      final (service, _) = serviceReplaying(fixture.readAsStringSync());

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 2);
      expect(result.detections.first.className, 'xl_energy');
      // Relabelled by the default CanShapeRule -- see the assertion above.
      expect(result.detections.last.className, 'coca-cola-slim');
    });

    test('parses a normalised "result" envelope identically', () async {
      final decoded =
          jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
      final normalised = jsonEncode({'result': decoded['outputs']});

      final (service, _) = serviceReplaying(normalised);

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 2);
      expect(result.detections.first.className, 'xl_energy');
      expect(result.imageWidth, 768);
    });

    test(
      'falls back to the source image size when dimensions are null',
      () async {
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
      },
    );
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
      expect(
        (body['inputs'] as Map)['detect_model_id'],
        'aystro-project-v2/2',
      );
    });

    test('parses a proxied response identically', () async {
      final (service, _) = serviceReplaying(
        fixture.readAsStringSync(),
        useProxy: true,
        endpoint: Uri.parse('https://example.test/api/detect'),
      );

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 2);
      expect(result.detections.first.className, 'xl_energy');
    });

    test('works with no API key present at all', () async {
      dotenv.loadFromString(envString: 'ROBOFLOW_WORKSPACE=ma7mouds-workspace');
      final (service, _) = serviceReplaying(
        fixture.readAsStringSync(),
        useProxy: true,
        endpoint: Uri.parse('https://example.test/api/detect'),
      );

      final result = await service.detectProducts(sampleBytes);

      expect(result.count, 2);
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

    test(
      'reports a missing API key as a config error in direct mode',
      () async {
        dotenv.loadFromString(
          envString: 'ROBOFLOW_WORKSPACE=ma7mouds-workspace',
        );
        final (service, _) = serviceReplaying(fixture.readAsStringSync());

        await expectLater(
          service.detectProducts(sampleBytes),
          throwsA(isA<DetectionConfigException>()),
        );
      },
    );

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
