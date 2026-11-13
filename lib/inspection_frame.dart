import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Immutable copy of the selected frame. Camera buffers may be reused.
class InspectionFrame {
  InspectionFrame(CameraImage image, this.rotation)
    : width = image.width,
      height = image.height,
      bgra = image.format.group == ImageFormatGroup.bgra8888,
      planes = image.planes.map((p) => Uint8List.fromList(p.bytes)).toList(),
      rowStrides = image.planes.map((p) => p.bytesPerRow).toList(),
      pixelStrides = image.planes
          .map(
            (p) =>
                p.bytesPerPixel ??
                (image.format.group == ImageFormatGroup.bgra8888 ? 4 : 1),
          )
          .toList();
  final int width, height, rotation;
  final bool bgra;
  final List<Uint8List> planes;
  final List<int> rowStrides, pixelStrides;
}

List<int> sampleLuminance(CameraImage image) {
  if (image.format.group != ImageFormatGroup.yuv420 &&
      image.format.group != ImageFormatGroup.bgra8888) {
    throw const FormatException('Неподдерживаемый формат кадров');
  }
  final plane = image.planes.first;
  final bgra = image.format.group == ImageFormatGroup.bgra8888;
  final result = <int>[];
  for (var gy = 0; gy < 24; gy++) {
    final y = ((gy + 0.5) * image.height / 24).floor();
    for (var gx = 0; gx < 24; gx++) {
      final x = ((gx + 0.5) * image.width / 24).floor();
      final i =
          y * plane.bytesPerRow + x * (plane.bytesPerPixel ?? (bgra ? 4 : 1));
      result.add(
        bgra
            ? ((plane.bytes[i] + 2 * plane.bytes[i + 1] + plane.bytes[i + 2]) ~/
                  4)
            : plane.bytes[i],
      );
    }
  }
  return result;
}

class EncodedFrame {
  EncodedFrame(this.jpeg, this.width, this.height, this.sample);
  final Uint8List jpeg;
  final int width, height;
  final List<int> sample;
}

/// Runs off the UI isolate on mobile; converts only pixels needed for a 640px JPEG.
EncodedFrame encodeInspectionFrame(InspectionFrame frame) {
  final scale = math.min(1.0, 640 / math.max(frame.width, frame.height));
  final width = (frame.width * scale).round();
  final height = (frame.height * scale).round();
  var image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final sy = (y / scale).floor().clamp(0, frame.height - 1);
    for (var x = 0; x < width; x++) {
      final sx = (x / scale).floor().clamp(0, frame.width - 1);
      if (frame.bgra) {
        final i = sy * frame.rowStrides[0] + sx * frame.pixelStrides[0];
        image.setPixelRgb(
          x,
          y,
          frame.planes[0][i + 2],
          frame.planes[0][i + 1],
          frame.planes[0][i],
        );
      } else {
        if (frame.planes.length != 3) {
          throw const FormatException('Ожидаются три YUV-плоскости');
        }
        final luma = frame
            .planes[0][sy * frame.rowStrides[0] + sx * frame.pixelStrides[0]];
        final u =
            frame.planes[1][(sy ~/ 2) * frame.rowStrides[1] +
                (sx ~/ 2) * frame.pixelStrides[1]] -
            128;
        final v =
            frame.planes[2][(sy ~/ 2) * frame.rowStrides[2] +
                (sx ~/ 2) * frame.pixelStrides[2]] -
            128;
        image.setPixelRgb(
          x,
          y,
          (luma + 1.402 * v).round().clamp(0, 255),
          (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
          (luma + 1.772 * u).round().clamp(0, 255),
        );
      }
    }
  }
  if (frame.rotation != 0) image = img.copyRotate(image, angle: frame.rotation);
  return _encoded(image);
}

/// Web cameras do not necessarily expose an image stream; poll still frames.
EncodedFrame prepareStillFrame(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Не удалось прочитать кадр');
  image = img.bakeOrientation(image);
  if (math.max(image.width, image.height) > 640) {
    image = image.width >= image.height
        ? img.copyResize(image, width: 640)
        : img.copyResize(image, height: 640);
  }
  return _encoded(image);
}

EncodedFrame _encoded(img.Image image) {
  final sample = <int>[];
  for (var y = 0; y < 24; y++) {
    for (var x = 0; x < 24; x++) {
      final p = image.getPixel(
        ((x + 0.5) * image.width / 24).floor(),
        ((y + 0.5) * image.height / 24).floor(),
      );
      sample.add(((p.r + 2 * p.g + p.b) / 4).round());
    }
  }
  return EncodedFrame(
    img.encodeJpg(image, quality: 80),
    image.width,
    image.height,
    sample,
  );
}
