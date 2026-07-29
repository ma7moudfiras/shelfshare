import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

/// Owns the device camera lifecycle for the capture screen.
///
/// The `camera` package is used rather than `image_picker` for the primary flow
/// because it gives an in-app live preview -- the operator needs to frame the
/// shelf before shooting. `image_picker` is kept only as a gallery fallback for
/// devices, emulators, and browsers with no usable camera.
///
/// Captures are returned as [XFile] rather than `dart:io` File so the same code
/// runs on web.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  final ImagePicker _picker = ImagePicker();

  /// The live controller, or null before [initialize] succeeds.
  CameraController? get controller => _controller;

  /// True once the preview is running and [capture] is safe to call.
  bool get isReady => _controller?.value.isInitialized ?? false;

  /// True when the device reported no cameras at all.
  bool get hasNoCamera => _cameras.isEmpty;

  /// Starts the rear camera preview.
  ///
  /// Throws [CameraException] when no camera is available or permission was
  /// denied; the screen turns that into the gallery-fallback state.
  Future<void> initialize() async {
    // Release any previous controller first. Re-initialising over a live one
    // leaks the old controller and, on Android, can leave the sensor held.
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    _cameras = await availableCameras();

    if (_cameras.isEmpty) {
      throw CameraException(
        'no_camera',
        'This device has no available camera.',
      );
    }

    // Prefer the rear camera; shelves are photographed away from the operator.
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      camera,
      // High is a deliberate ceiling: max resolution produces multi-megabyte
      // frames that inflate the base64 payload without helping detection.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    _controller = controller;
  }

  /// Takes a photo.
  Future<XFile> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw CameraException('not_ready', 'Camera is not initialized yet.');
    }

    return controller.takePicture();
  }

  /// Fallback path: pick an existing shelf photo from the gallery.
  ///
  /// Returns null when the user dismisses the picker.
  Future<XFile?> pickFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      // Cap the long edge so a 12MP gallery shot does not become a huge
      // base64 request body.
      maxWidth: 2048,
      maxHeight: 2048,
    );
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
