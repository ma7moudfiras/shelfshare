import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import '../services/camera_service.dart';
import '../services/detection_exception.dart';
import '../services/detection_service.dart';
import '../widgets/capture_controls.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/results_panel.dart';

/// Primary screen: frame a shelf, capture it, and read back the analysis.
///
/// Top half is the live preview (or the captured photo with detection boxes
/// drawn over it); bottom half is the results panel.
class CaptureScreen extends StatefulWidget {
  /// Backend used to analyse a captured photo.
  ///
  /// Nullable so the app remains usable as a pure capture tool before the
  /// inference backend is wired up -- the results panel simply stays on its
  /// placeholder state.
  final DetectionService? detectionService;

  const CaptureScreen({super.key, this.detectionService});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();

  /// Bytes of the current capture, held for both display and re-analysis.
  ///
  /// Bytes rather than a file path: `dart:io` is unavailable on web, and the
  /// overlay renders straight from memory anyway.
  Uint8List? _capturedBytes;

  DetectionResult? _result;
  bool _isAnalyzing = false;
  String? _errorMessage;

  bool _isCameraReady = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  /// Releases the camera when backgrounded and reacquires it on resume --
  /// without this, Android reclaims the sensor and the preview returns black.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraReady) return;

    if (state == AppLifecycleState.inactive) {
      _cameraService.dispose();
      if (mounted) setState(() => _isCameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
        _cameraError = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraReady = false;
        _cameraError = e.description ?? 'Camera unavailable.';
      });
    }
  }

  Future<void> _onCapture() async {
    try {
      final photo = await _cameraService.capture();
      await _useImage(photo);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.description ?? 'Capture failed.');
    }
  }

  Future<void> _onPickFromGallery() async {
    final photo = await _cameraService.pickFromGallery();
    if (photo != null) await _useImage(photo);
  }

  /// Loads [photo] into the preview, then kicks off analysis.
  Future<void> _useImage(XFile photo) async {
    final bytes = await photo.readAsBytes();
    if (!mounted) return;

    setState(() {
      _capturedBytes = bytes;
      _result = null;
      _errorMessage = null;
    });

    await _analyze();
  }

  /// Runs the captured photo through the detection service.
  Future<void> _analyze() async {
    final service = widget.detectionService;
    final bytes = _capturedBytes;

    // No backend wired up yet: leave the panel on its placeholder state rather
    // than showing a spurious error.
    if (service == null || bytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await service.detectProducts(bytes);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
    } on DetectionException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isAnalyzing = false;
      });
    }
  }

  /// Clears the capture and returns to the live preview.
  void _reset() {
    setState(() {
      _capturedBytes = null;
      _result = null;
      _errorMessage = null;
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCapture = _capturedBytes != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Monitor'),
        actions: [
          if (hasCapture)
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.close),
              tooltip: 'Discard capture',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(flex: 3, child: _buildViewfinder()),
          CaptureControls(
            canCapture: _isCameraReady && !_isAnalyzing,
            hasCapture: hasCapture,
            isBusy: _isAnalyzing,
            onCapture: _onCapture,
            onPickFromGallery: _onPickFromGallery,
            onRetake: _reset,
          ),
          Expanded(
            flex: 2,
            child: ResultsPanel(
              result: _result,
              isLoading: _isAnalyzing,
              errorMessage: _errorMessage,
              onRetry: _analyze,
            ),
          ),
        ],
      ),
    );
  }

  /// The captured photo with boxes, or the live preview when nothing is held.
  Widget _buildViewfinder() {
    final bytes = _capturedBytes;

    if (bytes != null) {
      return ColoredBox(
        color: Colors.black,
        child: DetectionOverlay(imageBytes: bytes, result: _result),
      );
    }

    if (_cameraError != null) return _buildCameraError();

    final controller = _cameraService.controller;
    if (!_isCameraReady || controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  /// Shown when the camera cannot start -- offers the gallery fallback so the
  /// app stays usable on emulators, browsers, and camera-less devices.
  Widget _buildCameraError() {
    final theme = Theme.of(context);

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 38,
              ),
              const SizedBox(height: 12),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _onPickFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose a photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
