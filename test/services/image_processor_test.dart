import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shelf_monitor/models/capture_aspect_ratio.dart';
import 'package:shelf_monitor/services/image_processor.dart';

void main() {
  const processor = ImageProcessor();

  // A 4032x3024 capture, the size a modern phone actually produces.
  final large = Uint8List.fromList(
    File('test/fixtures/large_capture.jpg').readAsBytesSync(),
  );
  final small = Uint8List.fromList(
    File('test/fixtures/sample_shelf.jpg').readAsBytesSync(),
  );

  group('prepareForUpload', () {
    // Regression: processing only ran when an aspect ratio was selected, so on
    // the default "Full" setting a full-resolution capture went out untouched
    // and Vercel rejected the request with 413 before it reached the function.
    test('compresses even when no crop applies', () async {
      expect(
        large.length,
        greaterThan(ImageProcessor.maxUploadBytes),
        reason: 'fixture must start over budget for this test to mean anything',
      );

      final out = await processor.prepareForUpload(
        large,
        CaptureAspectRatio.full,
      );

      expect(out.length, lessThanOrEqualTo(ImageProcessor.maxUploadBytes));
    });

    test('base64 of the result fits the serverless request limit', () async {
      final out = await processor.prepareForUpload(
        large,
        CaptureAspectRatio.full,
      );

      // Vercel rejects bodies over ~4.5 MB; base64 inflates by about a third.
      final encodedLength = base64Encode(out).length;
      expect(encodedLength, lessThan(4 * 1024 * 1024));
    });

    test('stays within budget for every aspect ratio', () async {
      for (final aspect in CaptureAspectRatio.values) {
        final out = await processor.prepareForUpload(large, aspect);
        expect(
          out.length,
          lessThanOrEqualTo(ImageProcessor.maxUploadBytes),
          reason: 'aspect ${aspect.label} exceeded the upload budget',
        );
      }
    });

    test('caps the long edge without distorting the image', () async {
      final out = await processor.prepareForUpload(
        large,
        CaptureAspectRatio.full,
      );
      final decoded = img.decodeImage(out)!;

      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      expect(longest, lessThanOrEqualTo(ImageProcessor.maxEdge));

      // 4032x3024 is 4:3; the aspect must survive the downscale.
      expect(decoded.width / decoded.height, closeTo(4 / 3, 0.01));
    });

    // The model preprocesses to 704x704, so the resize must stay well above
    // that or it would be discarding detail the detector would have used.
    test('keeps resolution comfortably above the model input size', () async {
      final out = await processor.prepareForUpload(
        large,
        CaptureAspectRatio.full,
      );
      final decoded = img.decodeImage(out)!;

      final shortest = decoded.width < decoded.height
          ? decoded.width
          : decoded.height;
      expect(shortest, greaterThanOrEqualTo(704));
    });

    test('crops to the requested ratio', () async {
      final out = await processor.prepareForUpload(
        large,
        CaptureAspectRatio.square,
      );
      final decoded = img.decodeImage(out)!;

      expect(decoded.width / decoded.height, closeTo(1.0, 0.01));
    });

    test('leaves an already-small image within budget', () async {
      final out = await processor.prepareForUpload(
        small,
        CaptureAspectRatio.full,
      );

      expect(out.length, lessThanOrEqualTo(ImageProcessor.maxUploadBytes));
      expect(out, isNotEmpty);
    });

    test('returns the input unchanged when it cannot be decoded', () async {
      final garbage = Uint8List.fromList(List.filled(64, 7));

      final out = await processor.prepareForUpload(
        garbage,
        CaptureAspectRatio.full,
      );

      // A processing failure must not cost the operator their shot; the server
      // will report if the result is genuinely unusable.
      expect(out, garbage);
    });
  });
}
