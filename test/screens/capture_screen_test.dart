import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/detection_result.dart';
import 'package:shelf_monitor/screens/capture_screen.dart';
import 'package:shelf_monitor/services/camera_service.dart';
import 'package:shelf_monitor/services/detection_service.dart';
import 'package:shelf_monitor/services/model_catalog_service.dart';
import 'package:shelf_monitor/widgets/aspect_ratio_selector.dart';
import 'package:shelf_monitor/models/model_option.dart';

/// A decodable JPEG for tests that put a captured still on screen.
Uint8List sampleJpegBytes() =>
    Uint8List.fromList(File('test/fixtures/sample_shelf.jpg').readAsBytesSync());

/// Camera stand-in that records how often the preview was (re)acquired.
///
/// [controller] stays null so the screen renders its loading branch instead of
/// a real [CameraPreview], which cannot exist without a device camera.
class FakeCameraService implements CameraService {
  int initializeCalls = 0;
  int disposeCalls = 0;
  bool _ready = false;

  /// When set, [initialize] throws this instead of succeeding.
  CameraException? failWith;

  /// Bytes handed back by [capture].
  final Uint8List photoBytes;

  /// Defaults to a real JPEG: the captured still is rendered with
  /// [Image.memory], which throws on bytes it cannot decode.
  FakeCameraService({Uint8List? photoBytes})
    : photoBytes = photoBytes ?? sampleJpegBytes();

  @override
  CameraController? get controller => null;

  @override
  bool get isReady => _ready;

  @override
  bool get hasNoCamera => false;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final failure = failWith;
    if (failure != null) {
      _ready = false;
      throw failure;
    }
    _ready = true;
  }

  @override
  Future<XFile> capture() async => XFile.fromData(photoBytes, name: 'shelf.jpg');

  @override
  Future<XFile?> pickFromGallery() async =>
      XFile.fromData(photoBytes, name: 'gallery.jpg');

  @override
  void dispose() {
    disposeCalls++;
    _ready = false;
  }

  /// Simulates iOS Safari, where the controller reports ready while its
  /// underlying media stream is already dead.
  void forceReady(bool value) => _ready = value;
}

/// Catalog stand-in so the screen makes no network call under test.
class FakeCatalogService implements ModelCatalogService {
  final ModelCatalog catalog;

  FakeCatalogService([this.catalog = const ModelCatalog.empty()]);

  @override
  Future<ModelCatalog> fetchCatalog() async => catalog;

  @override
  Uri get endpoint => Uri.parse('https://example.test/api/models');

  @override
  Duration get timeout => const Duration(seconds: 1);

  @override
  void dispose() {}
}

class StubDetectionService implements DetectionService {
  @override
  Future<DetectionResult> detectProducts(
    Uint8List imageBytes, {
    String? modelId,
    double? confidence,
  }) async =>
      DetectionResult.empty(imageWidth: 100, imageHeight: 100);

  @override
  void dispose() {}
}

/// Advances the clock enough for pending futures and finite animations without
/// waiting for quiescence.
///
/// [WidgetTester.pumpAndSettle] cannot be used here: when the camera is not
/// ready the screen shows a [CircularProgressIndicator], which animates
/// indefinitely, so settling never completes.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  Future<FakeCameraService> pumpScreen(WidgetTester tester) async {
    final camera = FakeCameraService();
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureScreen(
          cameraService: camera,
          detectionService: StubDetectionService(),
          catalogService: FakeCatalogService(),
        ),
      ),
    );
    await settle(tester);
    return camera;
  }

  group('camera lifecycle', () {
    testWidgets('acquires the camera on first build', (tester) async {
      final camera = await pumpScreen(tester);

      expect(camera.initializeCalls, 1);
    });

    // Regression: the lifecycle handler used to bail out early whenever the
    // camera was not ready. Since pausing is exactly what makes it not ready,
    // the resume branch could never run and the preview stayed blank forever.
    testWidgets('reacquires the camera after a pause/resume cycle', (
      tester,
    ) async {
      final camera = await pumpScreen(tester);
      expect(camera.initializeCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(camera.disposeCalls, greaterThan(0));
      expect(camera.isReady, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(
        camera.initializeCalls,
        2,
        reason: 'resume must reacquire the released camera',
      );
      expect(camera.isReady, isTrue);
    });

    testWidgets('does not tear down the camera on transient inactive', (
      tester,
    ) async {
      final camera = await pumpScreen(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await settle(tester);

      // `inactive` fires for file dialogs and permission prompts; tearing down
      // there causes avoidable flicker.
      expect(camera.disposeCalls, 0);
      expect(camera.isReady, isTrue);
    });
  });

  group('retake', () {
    // Regression: Retake cleared the photo but never restarted the preview, so
    // if the camera had been released meanwhile the user was left staring at a
    // black viewfinder and a spinner.
    testWidgets('restarts the preview when the camera was released', (
      tester,
    ) async {
      final camera = await pumpScreen(tester);
      expect(camera.initializeCalls, 1);

      // Capture, so the still is on screen and Retake is offered.
      await tester.tap(find.bySemanticsLabel('Capture shelf photo'));
      await settle(tester);
      expect(find.text('Retake'), findsOneWidget);

      // Something releases the camera while the still is up.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(camera.isReady, isFalse);

      await tester.tap(find.text('Retake'));
      await settle(tester);

      expect(
        camera.initializeCalls,
        greaterThan(1),
        reason: 'Retake must restart a released preview',
      );
      expect(camera.isReady, isTrue);
    });
  });

  group('iOS Safari preview recovery', () {
    // Regression: on iOS Safari a suspended camera stream cannot be resumed.
    // The controller kept reporting ready while its <video> element was dead,
    // so the preview came back black -- no spinner, and only a page refresh
    // cleared it. Releasing on capture and unconditionally reacquiring on
    // retake forces a fresh getUserMedia.
    testWidgets('releases the camera while a still is displayed', (
      tester,
    ) async {
      final camera = await pumpScreen(tester);
      expect(camera.isReady, isTrue);

      await tester.tap(find.bySemanticsLabel('Capture shelf photo'));
      await settle(tester);

      expect(camera.disposeCalls, greaterThan(0));
      expect(
        camera.isReady,
        isFalse,
        reason: 'holding a stream nothing displays is what strands iOS Safari',
      );
    });

    testWidgets('retake reacquires even when the camera still reports ready', (
      tester,
    ) async {
      final camera = await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Capture shelf photo'));
      await settle(tester);
      final afterCapture = camera.initializeCalls;

      // Simulate the iOS case: the service claims to be ready while its stream
      // is actually dead. Retake must not trust that flag.
      camera.forceReady(true);

      await tester.tap(find.text('Retake'));
      await settle(tester);

      expect(
        camera.initializeCalls,
        greaterThan(afterCapture),
        reason: 'retake must restart the stream regardless of the ready flag',
      );
    });
  });

  group('aspect ratio framing', () {
    // Regression: selecting a ratio used to wrap CameraPreview in
    // Center/AspectRatio/ClipRRect. That re-parents the platform view, and on
    // web it orphans the <video> element permanently -- black preview, no
    // recovery even after switching back to Full. Framing must therefore never
    // restructure the preview subtree.
    testWidgets('switching ratio does not touch the camera', (tester) async {
      final camera = await pumpScreen(tester);
      final initialiseCalls = camera.initializeCalls;
      final disposeCalls = camera.disposeCalls;

      for (final label in ['1:1', '4:3', '16:9', 'Full']) {
        await tester.tap(find.text(label));
        await settle(tester);
      }

      expect(
        camera.initializeCalls,
        initialiseCalls,
        reason: 'framing is an overlay; it must not re-acquire the camera',
      );
      expect(
        camera.disposeCalls,
        disposeCalls,
        reason: 'framing must not tear the preview down',
      );
      expect(camera.isReady, isTrue);
    });

    testWidgets('every ratio remains selectable and reversible', (
      tester,
    ) async {
      await pumpScreen(tester);

      for (final label in ['16:9', 'Full', '1:1', 'Full']) {
        await tester.tap(find.text(label));
        await settle(tester);
        // The selector stays on screen throughout: a framing choice that hides
        // its own control is a dead end.
        expect(find.byType(AspectRatioSelector), findsOneWidget);
      }
    });
  });

  group('camera failure', () {
    testWidgets('surfaces an error with a gallery fallback', (tester) async {
      final camera = FakeCameraService()
        ..failWith = CameraException('denied', 'Camera permission denied.');

      await tester.pumpWidget(
        MaterialApp(
          home: CaptureScreen(
            cameraService: camera,
            detectionService: StubDetectionService(),
            catalogService: FakeCatalogService(),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Camera permission denied.'), findsOneWidget);
      expect(find.text('Choose a photo'), findsOneWidget);
    });
  });
}
