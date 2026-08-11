import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shelf_monitor/services/blur_detector.dart';

Uint8List _jpegOf(img.Image image) =>
    Uint8List.fromList(img.encodeJpg(image));

void main() {
  group('BlurDetector.isBlurry', () {
    test('a flat, featureless image is blurry', () async {
      // Uniform colour: no edges anywhere, Laplacian variance is exactly 0.
      final flat = img.Image(width: 200, height: 200);
      img.fill(flat, color: img.ColorRgb8(128, 128, 128));

      expect(await BlurDetector.isBlurry(_jpegOf(flat)), isTrue);
    });

    test('a high-contrast checkerboard is not blurry', () async {
      final checkerboard = img.Image(width: 200, height: 200);
      const squareSize = 10;
      for (var y = 0; y < checkerboard.height; y++) {
        for (var x = 0; x < checkerboard.width; x++) {
          final isLight =
              ((x ~/ squareSize) + (y ~/ squareSize)).isEven;
          checkerboard.setPixelRgb(
            x,
            y,
            isLight ? 255 : 0,
            isLight ? 255 : 0,
            isLight ? 255 : 0,
          );
        }
      }

      expect(await BlurDetector.isBlurry(_jpegOf(checkerboard)), isFalse);
    });

    test('a real shelf photo is not flagged blurry', () async {
      final bytes = File(
        'test/fixtures/sample_shelf.jpg',
      ).readAsBytesSync();

      expect(await BlurDetector.isBlurry(bytes), isFalse);
    });

    test('heavily gaussian-blurring a real photo flags it', () async {
      final decoded = img.decodeImage(
        File('test/fixtures/sample_shelf.jpg').readAsBytesSync(),
      )!;
      final blurred = img.gaussianBlur(decoded, radius: 15);

      expect(await BlurDetector.isBlurry(_jpegOf(blurred)), isTrue);
    });

    test('declines to judge undecodable bytes rather than throwing', () async {
      final garbage = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(await BlurDetector.isBlurry(garbage), isFalse);
    });
  });
}
