import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/capture_aspect_ratio.dart';
import '../models/capture_draft.dart';
import '../models/capture_target.dart';
import '../models/detection_result.dart';
import '../models/model_option.dart';
import '../services/camera_service.dart';
import '../services/detection_exception.dart';
import '../services/detection_service.dart';
import '../services/image_processor.dart';
import '../services/model_catalog_service.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import 'capture_review_screen.dart';
import '../widgets/analysis_settings_sheet.dart';
import '../widgets/aspect_ratio_selector.dart';
import '../widgets/camera_stage.dart';
import '../widgets/capture_controls.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/results_panel.dart';
import 'photo_viewer_screen.dart';

/// Primary screen: frame a shelf, capture it, and read back the analysis.
///
/// The viewfinder is full-bleed and the controls float over it, which is what
/// every camera app does for a reason -- framing a shelf is easier when the
/// shelf occupies the whole screen. Results arrive in a draggable sheet so the
/// photo stays visible behind them.
class CaptureScreen extends StatefulWidget {
  final DetectionService? detectionService;
  final CameraService? cameraService;
  final ModelCatalogService? catalogService;

  /// Compresses captures before upload. Injectable so widget tests can skip
  /// real JPEG work, which is far too slow to complete inside a pumped frame.
  final ImageProcessor? imageProcessor;

  /// What this capture is being recorded against.
  ///
  /// Null puts the screen in preview mode: it analyses and displays, and saves
  /// nothing. That is the right behaviour for an admin trying the camera out
  /// from the dashboard, who has no open visit and whose test shots must not
  /// land in a customer's numbers.
  final CaptureTarget? target;

  /// Required whenever [target] is set.
  final VisitService? visitService;

  const CaptureScreen({
    super.key,
    this.detectionService,
    this.cameraService,
    this.catalogService,
    this.imageProcessor,
    this.target,
    this.visitService,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  late final CameraService _cameraService =
      widget.cameraService ?? CameraService();
  late final ModelCatalogService _catalogService =
      widget.catalogService ?? ModelCatalogService();

  late final ImageProcessor _imageProcessor =
      widget.imageProcessor ?? const ImageProcessor();

  /// Bytes of the current capture, already cropped to the chosen framing.
  Uint8List? _capturedBytes;

  DetectionResult? _result;
  bool _isAnalyzing = false;
  String? _errorMessage;

  bool _isCameraReady = false;
  String? _cameraError;
  bool _isInitializingCamera = false;

  /// True while a capture is being cropped and compressed for upload.
  bool _isPreparing = false;

  ModelCatalog _catalog = const ModelCatalog.empty();
  bool _isLoadingCatalog = false;

  AnalysisSettings _settings = const AnalysisSettings();
  CaptureAspectRatio _aspect = CaptureAspectRatio.full;

  static const String _heroTag = 'capture-photo';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadCatalog();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _catalogService.dispose();
    super.dispose();
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

  /// Releases the camera when backgrounded and reacquires it on resume --
  /// without this, Android reclaims the sensor and the preview returns black.
  ///
  /// Teardown is tied to `paused`/`hidden` rather than `inactive`, which also
  /// fires for transient interruptions like a file dialog or permission prompt.
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
        // Must NOT be gated on _isCameraReady: by this point the camera has
        // already been released, so gating on it would make the state
        // unrecoverable and leave the preview permanently blank.
        if (!_isCameraReady && _capturedBytes == null) _initializeCamera();

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Brings the preview up, tolerating concurrent calls.
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
    } catch (_) {
      // Browsers report permission and device failures as plain exceptions,
      // and an unhandled one would leave a spinner with no explanation.
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
      setState(() {
        _isPreparing = false;
        _errorMessage = e.description ?? 'Capture failed.';
      });
    }
  }

  Future<void> _onPickFromGallery() async {
    final photo = await _cameraService.pickFromGallery();
    if (photo != null) await _useImage(photo);
  }

  /// Loads [photo], crops it to the chosen framing, then analyses it.
  Future<void> _useImage(XFile photo) async {
    // Compressing a 12MP capture takes real time. Show the busy state before
    // starting, or the shutter simply appears not to have worked.
    setState(() => _isPreparing = true);

    final raw = await photo.readAsBytes();
    // Always process, not only when a crop applies: an unprocessed phone
    // capture routinely exceeds the serverless request limit, and the model
    // downsamples to 704px regardless, so full resolution buys nothing.
    final bytes = await _imageProcessor.prepareForUpload(raw, _aspect);
    if (!mounted) return;

    // Release the camera while the still is on screen. On iOS Safari a
    // suspended stream cannot be resumed, so reacquiring on retake is the only
    // reliable route back to a live preview.
    _cameraService.dispose();

    setState(() {
      _capturedBytes = bytes;
      _isCameraReady = false;
      _isPreparing = false;
      _result = null;
      _errorMessage = null;
    });

    await _analyze();
  }

  Future<void> _analyze() async {
    final service = widget.detectionService;
    final bytes = _capturedBytes;
    if (service == null || bytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await service.detectProducts(
        bytes,
        modelId: _settings.modelId,
        confidence: _settings.confidence,
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

  Future<void> _openSettings() async {
    final previousModel = _settings.modelId;
    final previousConfidence = _settings.confidence;

    final updated = await showModalBottomSheet<AnalysisSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AnalysisSettingsSheet(
        models: _catalog.models,
        availableClasses: _classChoices,
        initial: _settings,
        isLoadingCatalog: _isLoadingCatalog,
      ),
    );
    if (updated == null || !mounted) return;

    setState(() => _settings = updated);

    // Only the model and threshold change what the model returns. A class
    // filter is a view over the existing result, and re-running would waste a
    // call and upload the photo to the dataset again.
    final needsReanalysis =
        updated.modelId != previousModel ||
        updated.confidence != previousConfidence;
    if (needsReanalysis && _capturedBytes != null) await _analyze();
  }

  /// Opens the review screen, where the count can be corrected before it is
  /// stored, and writes the capture when the rep accepts it.
  Future<void> _openReview() async {
    final target = widget.target;
    final service = widget.visitService;
    final bytes = _capturedBytes;
    final result = _visibleResult;
    if (target == null || service == null || bytes == null || result == null) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (reviewContext) => CaptureReviewScreen(
          imageBytes: bytes,
          initialDraft: CaptureDraft.fromResult(result),
          targetLabel: target.label,
          availableClasses: _classChoices,
          onSave: (draft) async {
            try {
              await service.recordCapture(
                visitId: target.visitId,
                companyId: target.companyId,
                fridgeId: target.fridge.id,
                fridgeSectionId: target.sectionId,
                // What actually ran, which the web proxy is free to override.
                modelId:
                    result.effectiveModelId ??
                    _settings.modelId ??
                    AppConfig.modelId,
                confidenceThreshold: _settings.confidence,
                draft: draft,
              );
              if (reviewContext.mounted) {
                Navigator.of(reviewContext).pop(true);
              }
            } on VisitFailure catch (e) {
              if (!reviewContext.mounted) return;
              ScaffoldMessenger.of(reviewContext)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor: Theme.of(reviewContext).colorScheme.error,
                  ),
                );
            }
          },
        ),
      ),
    );

    // Hand the result back to the fridge list so it can mark this one done.
    if ((saved ?? false) && mounted) Navigator.of(context).pop(true);
  }

  void _openFullScreen() {
    final bytes = _capturedBytes;
    if (bytes == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          imageBytes: bytes,
          result: _visibleResult,
          heroTag: _heroTag,
        ),
      ),
    );
  }

  /// Classes offered in the filter.
  ///
  /// Prefers the project's full class list so products can be selected before
  /// they are ever detected; falls back to the current result's classes.
  List<String> get _classChoices {
    if (_catalog.classes.isNotEmpty) return _catalog.classes;
    return List<String>.from(_result?.classNames ?? const <String>[])..sort();
  }

  /// The result as shown: narrowed to the selected products.
  DetectionResult? get _visibleResult =>
      _result?.filterByClasses(_settings.selectedClasses);

  /// Tears the preview down and brings it back up.
  ///
  /// Reached from the camera error state rather than from a permanent button in
  /// the chrome. A browser can also leave a stream dead while the controller
  /// still reports it as running, which this would fix but nothing can detect
  /// -- the preview is a platform view we do not get to inspect.
  Future<void> _restartCamera() async {
    _cameraService.dispose();
    if (mounted) {
      setState(() {
        _isCameraReady = false;
        _cameraError = null;
      });
    }
    await _initializeCamera();
  }

  /// Clears the capture and returns to the live preview.
  void _reset() {
    setState(() {
      _capturedBytes = null;
      _result = null;
      _errorMessage = null;
      _isAnalyzing = false;
      _isPreparing = false;
    });
    // Unconditional: on iOS Safari the controller can still report ready while
    // its underlying stream is dead.
    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final hasCapture = _capturedBytes != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        // extendBody so the viewfinder runs edge to edge behind the controls.
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildStage(),
            _TopBar(
              onSettings: _openSettings,
              targetLabel: widget.target?.label,
              onFullScreen: hasCapture ? _openFullScreen : null,
              // Only when there is somewhere to go back to. A sales rep who
              // lands straight on this screen has no dashboard behind it, and
              // an arrow that pops to a blank route is worse than no arrow.
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            if (!hasCapture && _cameraError == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 168,
                child: Center(
                  child: AspectRatioSelector(
                    selected: _aspect,
                    onSelected: (a) => setState(() => _aspect = a),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: hasCapture ? _buildResultsSheet() : _buildCaptureBar(),
            ),
          ],
        ),
      ),
    );
  }

  /// Viewfinder or captured still, filling the screen.
  Widget _buildStage() {
    final bytes = _capturedBytes;

    if (bytes != null) {
      return GestureDetector(
        onTap: _openFullScreen,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            // Leaves room for the results sheet so the photo is not hidden.
            padding: const EdgeInsets.only(bottom: 260),
            child: Hero(
              tag: _heroTag,
              child: DetectionOverlay(
                imageBytes: bytes,
                result: _visibleResult,
              ),
            ),
          ),
        ),
      );
    }

    if (_cameraError != null) return _buildCameraError();

    final controller = _cameraService.controller;
    if (!_isCameraReady || controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    // CameraStage owns the rule that framing must never restructure this
    // subtree -- see its doc comment for why, and what breaks otherwise.
    return CameraStage(
      ratio: _aspect.ratio,
      preview: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildCaptureBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xE6000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: CaptureControls(
          canCapture: _isCameraReady && !_isAnalyzing && !_isPreparing,
          hasCapture: false,
          isBusy: _isAnalyzing || _isPreparing,
          onCapture: _onCapture,
          onPickFromGallery: _onPickFromGallery,
          onRetake: _reset,
        ),
      ),
    );
  }

  /// Results in a draggable sheet, so the photo behind stays inspectable.
  Widget _buildResultsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDarkElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Analysis',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retake'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ResultsPanel(
                  result: _visibleResult,
                  isLoading: _isAnalyzing,
                  errorMessage: _errorMessage,
                  onRetry: _analyze,
                  modelId: _settings.modelId,
                  confidence: _settings.confidence,
                  scrollController: scrollController,
                ),
              ),
              if (_result != null && !_isAnalyzing && _errorMessage == null)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: widget.target != null
                        ? SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _openReview,
                              icon: const Icon(
                                Icons.fact_check_outlined,
                                size: 18,
                              ),
                              label: const Text('Check and submit'),
                            ),
                          )
                        // Preview mode has nowhere to file this. Saying so is
                        // the whole point: a missing submit button reads as a
                        // broken app, and someone who photographs a shelf
                        // believing it was recorded has lost the visit.
                        : const _PreviewOnlyNotice(),
                  ),
                ),
            ],
          ),
        );
      },
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white38,
                size: 44,
              ),
              const SizedBox(height: 16),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _restartCamera,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Try camera again'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _onPickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Choose a photo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating controls along the top edge.
/// Chrome over the viewfinder: where you are, and the controls.
///
/// The scrim stays dark in both themes. It sits over a photograph of a fridge,
/// and a light bar over a bright shelf is unreadable -- matching the app's
/// surface colour here would cost legibility for consistency nobody benefits
/// from. What follows the theme is everything that can: type scale, corner
/// radius, and the accent used for state.
class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback? onFullScreen;

  /// Null when this screen is the root and there is nothing behind it.
  final VoidCallback? onBack;

  /// What is being photographed, e.g. `Entrance cooler · Shelf 2`.
  ///
  /// Null in preview mode, where there is no subject to name.
  final String? targetLabel;

  const _TopBar({
    required this.onSettings,
    this.onFullScreen,
    this.onBack,
    this.targetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = targetLabel;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB3000000), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            // Even inset on both sides, so the controls sit square in the
            // corner rather than drifting in from it.
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 22),
            child: Row(
              children: [
                if (onBack != null) ...[
                  _GlassIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: onBack!,
                  ),
                  const SizedBox(width: 8),
                ] else
                  const SizedBox(width: 6),

                // The subject, not the app name. A rep at a fridge door needs
                // to know which shelf this shot is being filed against; they
                // already know what app they opened.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        target ?? 'Shelf Monitor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (target != null)
                        Text(
                          'Photographing',
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                if (onFullScreen != null) ...[
                  _GlassIconButton(
                    icon: Icons.fullscreen,
                    tooltip: 'View full screen',
                    onPressed: onFullScreen!,
                  ),
                  const SizedBox(width: 8),
                ],
                // Always last, so the settings control holds the same corner
                // whether or not a photo has been taken. Discarding used to sit
                // to its right and push it inward after every capture -- a
                // control that moves is a control you have to hunt for, and it
                // duplicated the Retake button already in the results sheet.
                _GlassIconButton(
                  icon: Icons.tune,
                  tooltip: 'Model and product filters',
                  onPressed: onSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Explains why a capture taken outside a visit cannot be submitted.
class _PreviewOnlyNotice extends StatelessWidget {
  const _PreviewOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Preview only — this is not being saved. To record a shelf, '
              'start from a market so the photo has a fridge to belong to.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular translucent button, legible over any scene.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          // 40x40: the smallest target that still clears the accessibility
          // floor for a thumb, which the previous 39px sizing sat just under.
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // A hairline keeps the button findable against a blown-out
              // highlight, where a dark translucent fill disappears.
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
