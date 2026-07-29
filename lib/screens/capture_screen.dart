import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import '../models/model_option.dart';
import '../services/camera_service.dart';
import '../services/model_catalog_service.dart';
import '../services/detection_exception.dart';
import '../services/detection_service.dart';
import '../widgets/analysis_settings_sheet.dart';
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

  /// Camera backend. Injectable so widget tests can drive the capture and
  /// lifecycle flows without a real device camera.
  final CameraService? cameraService;

  /// Supplies the model/class lists for the settings sheet. Injectable so
  /// tests can provide a catalog without network access.
  final ModelCatalogService? catalogService;

  const CaptureScreen({
    super.key,
    this.detectionService,
    this.cameraService,
    this.catalogService,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  late final CameraService _cameraService =
      widget.cameraService ?? CameraService();

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

  /// Guards against overlapping [_initializeCamera] calls.
  bool _isInitializingCamera = false;

  late final ModelCatalogService _catalogService =
      widget.catalogService ?? ModelCatalogService();

  ModelCatalog _catalog = const ModelCatalog.empty();
  bool _isLoadingCatalog = false;

  /// Chosen model version and product filter.
  AnalysisSettings _settings = const AnalysisSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadCatalog();
  }

  /// Loads the model and class lists in the background.
  ///
  /// Failure is silent by design: the catalog only powers the settings sheet,
  /// so losing it must not block capture or analysis.
  Future<void> _loadCatalog() async {
    setState(() => _isLoadingCatalog = true);
    final catalog = await _catalogService.fetchCatalog();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _isLoadingCatalog = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _catalogService.dispose();
    super.dispose();
  }

  /// Releases the camera when backgrounded and reacquires it on resume --
  /// without this, Android reclaims the sensor and the preview returns black.
  ///
  /// Teardown is deliberately tied to `paused`/`hidden` rather than `inactive`.
  /// `inactive` also fires for transient interruptions -- a file dialog, a
  /// permission prompt, the iOS control centre -- and tearing the camera down
  /// for those causes needless flicker on the way back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_isCameraReady) {
          _cameraService.dispose();
          if (mounted) setState(() => _isCameraReady = false);
        }

      case AppLifecycleState.resumed:
        // Reacquire whenever the viewfinder is what the user is looking at.
        // This must NOT be gated on _isCameraReady: by this point the camera
        // has already been released, so gating on it would make the state
        // unrecoverable and leave the preview permanently blank.
        if (!_isCameraReady && _capturedBytes == null) {
          _initializeCamera();
        }

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Brings the preview up, tolerating concurrent calls.
  ///
  /// Resume events and [_reset] can both ask for the camera at once; without
  /// the in-flight guard that races two controllers into existence and leaks
  /// the loser.
  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;

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
    } catch (e) {
      // Browsers report permission and device failures as plain exceptions
      // rather than CameraException, so this must not go unhandled -- doing so
      // would leave the spinner up with no explanation.
      if (!mounted) return;
      setState(() {
        _isCameraReady = false;
        _cameraError = 'Camera unavailable.';
      });
    } finally {
      _isInitializingCamera = false;
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
      final result = await service.detectProducts(
        bytes,
        modelId: _settings.modelId,
      );
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

  /// Opens the settings sheet and applies whatever comes back.
  ///
  /// Changing the model re-runs detection, since a different model produces
  /// different boxes. Changing only the product filter does not: that is a
  /// view over the existing result, so re-running would waste a call and, on
  /// this workflow, upload the photo to the dataset again.
  Future<void> _openSettings() async {
    final previousModel = _settings.modelId;

    final updated = await showModalBottomSheet<AnalysisSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => AnalysisSettingsSheet(
        models: _catalog.models,
        availableClasses: _classChoices,
        initial: _settings,
        isLoadingCatalog: _isLoadingCatalog,
      ),
    );
    if (updated == null || !mounted) return;

    setState(() => _settings = updated);

    if (updated.modelId != previousModel && _capturedBytes != null) {
      await _analyze();
    }
  }

  /// Classes offered in the filter.
  ///
  /// Prefers the project's full class list so products can be selected before
  /// they are ever detected; falls back to whatever the current result
  /// contains when the catalog is unavailable.
  List<String> get _classChoices {
    if (_catalog.classes.isNotEmpty) return _catalog.classes;
    final fromResult = _result?.classNames ?? const <String>[];
    return List<String>.from(fromResult)..sort();
  }

  /// The result as shown: narrowed to the selected products.
  DetectionResult? get _visibleResult =>
      _result?.filterByClasses(_settings.selectedClasses);

  /// Clears the capture and returns to the live preview.
  ///
  /// The camera may have been released while the still was on screen -- by a
  /// backgrounding, or by the gallery picker taking over -- so the preview is
  /// restarted rather than assumed live. Without this, Retake drops the user
  /// onto a permanently blank viewfinder.
  void _reset() {
    setState(() {
      _capturedBytes = null;
      _result = null;
      _errorMessage = null;
      _isAnalyzing = false;
    });

    if (!_isCameraReady) _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final hasCapture = _capturedBytes != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Monitor'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
            tooltip: 'Analysis settings',
          ),
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
              result: _visibleResult,
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
        child: DetectionOverlay(imageBytes: bytes, result: _visibleResult),
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
