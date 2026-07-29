import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/detection_result.dart';
import '../widgets/detection_overlay.dart';

/// Full-screen, pinch-zoomable view of a capture and its detections.
///
/// Boxes on a shelf photo are small and dense; inspecting whether a detection
/// is actually on the right bottle is impossible in a half-screen thumbnail.
/// The overlay is drawn inside the transform so labels scale with the image
/// rather than drifting away from their boxes.
class PhotoViewerScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final DetectionResult? result;

  /// Tag shared with the thumbnail so the transition is continuous.
  final String heroTag;

  const PhotoViewerScreen({
    super.key,
    required this.imageBytes,
    this.result,
    this.heroTag = 'capture',
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;

  /// Chrome hides on tap so the photo can be inspected unobstructed.
  bool _showChrome = true;

  static const double _doubleTapScale = 2.5;

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _runZoom(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(begin: _controller.value, end: target).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    )..addListener(() => _controller.value = _zoomAnimation!.value);
    _animation.forward(from: 0);
  }

  /// Double tap zooms toward the tapped point, or back out if already zoomed.
  void _onDoubleTapAt(Offset position) {
    final isZoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomed) {
      _runZoom(Matrix4.identity());
      return;
    }

    // Scale about the tap point so the thing being inspected stays put.
    final target = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(
        _doubleTapScale,
        _doubleTapScale,
        _doubleTapScale,
        1,
      );
    _runZoom(target);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showChrome = !_showChrome),
                onDoubleTapDown: (d) => _onDoubleTapAt(d.localPosition),
                // The handler lives on onDoubleTapDown so the tap position is
                // available; this must still be present for it to fire.
                onDoubleTap: () {},
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 6,
                  child: Hero(
                    tag: widget.heroTag,
                    child: DetectionOverlay(
                      imageBytes: widget.imageBytes,
                      result: result,
                    ),
                  ),
                ),
              ),
            ),

            AnimatedOpacity(
              opacity: _showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: IgnorePointer(
                ignoring: !_showChrome,
                child: _Chrome(result: result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Close button and a summary of what is on screen.
class _Chrome extends StatelessWidget {
  final DetectionResult? result;

  const _Chrome({this.result});

  @override
  Widget build(BuildContext context) {
    final result = this.result;

    return Column(
      children: [
        Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                  ),
                  const Spacer(),
                  if (result != null && result.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${result.count} detected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        if (result != null && result.isNotEmpty)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.shareOfShelf.summaryLine,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pinch or double-tap to zoom · tap to hide',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
