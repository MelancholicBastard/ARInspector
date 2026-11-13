import 'dart:typed_data';

import 'package:ar_inspector/inspection_frame.dart';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'Padded YUV rows and interleaved UV strides survive 90 degree rotation',
    () {
      final y = Uint8List(56 * 24);
      for (var row = 0; row < 24; row++) {
        for (var col = 0; col < 48; col++) {
          y[row * 56 + col] = col < 24 ? 30 : 220;
        }
      }
      final frame = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
          height: 24,
          width: 48,
          planes: [
            CameraImagePlane(bytes: y, bytesPerRow: 56, bytesPerPixel: 1),
            CameraImagePlane(
              bytes: Uint8List(52 * 12)..fillRange(0, 52 * 12, 128),
              bytesPerRow: 52,
              bytesPerPixel: 2,
            ),
            CameraImagePlane(
              bytes: Uint8List(52 * 12)..fillRange(0, 52 * 12, 128),
              bytesPerRow: 52,
              bytesPerPixel: 2,
            ),
          ],
        ),
      );
      expect(sampleLuminance(frame), hasLength(576));
      final jpeg = encodeInspectionFrame(InspectionFrame(frame, 90));
      expect([jpeg.width, jpeg.height], [24, 48]);
      final decoded = img.decodeJpg(jpeg.jpeg)!;
      expect(decoded.getPixel(10, 6).r, lessThan(60));
      expect(decoded.getPixel(10, 40).r, greaterThan(190));
    },
  );

  test(
    'BGRA without pixel stride uses four bytes and copies camera buffers',
    () {
      final bytes = Uint8List(200 * 24);
      for (var row = 0; row < 24; row++) {
        for (var col = 0; col < 48; col++) {
          final i = row * 200 + col * 4;
          bytes[i] = 0;
          bytes[i + 1] = col < 24 ? 0 : 255;
          bytes[i + 2] = col < 24 ? 255 : 0;
          bytes[i + 3] = 255;
        }
      }
      final frame = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(
            ImageFormatGroup.bgra8888,
            raw: 1111970369,
          ),
          height: 24,
          width: 48,
          planes: [CameraImagePlane(bytes: bytes, bytesPerRow: 200)],
        ),
      );
      final sample = sampleLuminance(frame);
      expect(sample.first, closeTo(63, 1));
      final copy = InspectionFrame(frame, 0);
      bytes.fillRange(0, bytes.length, 0);
      final jpeg = encodeInspectionFrame(copy);
      final decoded = img.decodeJpg(jpeg.jpeg)!;
      expect(decoded.getPixel(5, 10).r, greaterThan(220));
      expect(decoded.getPixel(5, 10).g, lessThan(30));
      expect(decoded.getPixel(40, 10).g, greaterThan(220));
    },
  );
}
