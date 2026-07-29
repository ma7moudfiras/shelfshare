import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/models/detection_result.dart';
import 'package:shelf_monitor/screens/capture_screen.dart';
import 'package:shelf_monitor/services/detection_service.dart';
import 'package:shelf_monitor/services/model_catalog_service.dart';
import 'package:shelf_monitor/models/model_option.dart';
import 'package:shelf_monitor/widgets/results_panel.dart';
import 'package:shelf_monitor/widgets/share_of_shelf_panel.dart';

/// Stand-in for the Roboflow client so widget tests need no network.
class FakeDetectionService implements DetectionService {
  final DetectionResult result;

  FakeDetectionService(this.result);

  @override
  Future<DetectionResult> detectProducts(
    Uint8List imageBytes, {
    String? modelId,
    double? confidence,
  }) async => result;

  @override
  void dispose() {}
}

/// Keeps the screen off the network under test.
class FakeCatalogService implements ModelCatalogService {
  @override
  Future<ModelCatalog> fetchCatalog() async => const ModelCatalog.empty();

  @override
  Uri get endpoint => Uri.parse('https://example.test/api/models');

  @override
  Duration get timeout => const Duration(seconds: 1);

  @override
  void dispose() {}
}

DetectionResult resultWith(List<(String, double)> classesAndSizes) {
  return DetectionResult(
    detections: [
      for (final (className, size) in classesAndSizes)
        Detection(
          className: className,
          confidence: 0.9,
          box: BoundingBox(
            centerX: 100,
            centerY: 100,
            width: size,
            height: size,
          ),
        ),
    ],
    imageWidth: 720,
    imageHeight: 540,
  );
}

void main() {
  group('ResultsPanel', () {
    testWidgets('shows the placeholder before any capture', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ResultsPanel())),
      );

      expect(find.text('No analysis yet'), findsOneWidget);
    });

    testWidgets('shows a spinner while analysing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ResultsPanel(isLoading: true))),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing shelf…'), findsOneWidget);
    });

    testWidgets('shows the error message and a retry action', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultsPanel(
              errorMessage: 'Roboflow rejected the API key.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Roboflow rejected the API key.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('renders the Share of Shelf breakdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultsPanel(
              result: resultWith([
                ('coca_cola', 20), // 400
                ('coca_cola', 20), // 400
                ('pepsi', 20), // 400
                ('pepsi', 20), // 400
              ]),
            ),
          ),
        ),
      );

      expect(find.byType(ShareOfShelfPanel), findsOneWidget);
      expect(find.text('Share of Shelf'), findsOneWidget);
      expect(find.text('coca_cola: 50% | pepsi: 50%'), findsOneWidget);
      expect(find.text('4 items · 2 brands'), findsOneWidget);
    });

    testWidgets('reports when nothing was detected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultsPanel(result: DetectionResult.empty())),
        ),
      );

      expect(find.text('No products detected'), findsOneWidget);
    });
  });

  group('CaptureScreen', () {
    testWidgets('builds and shows the results placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CaptureScreen(
            detectionService: FakeDetectionService(resultWith([])),
            catalogService: FakeCatalogService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Shelf Monitor'), findsOneWidget);
      expect(find.byType(ResultsPanel), findsOneWidget);
      expect(find.text('No analysis yet'), findsOneWidget);
    });
  });
}
