import 'dart:ui';

class Detection {
  const Detection(this.label, this.confidence, this.box);
  final String label;
  final double confidence;

  /// Normalized XYXY bounds in the uploaded, upright image.
  final Rect box;
}

class DetectionSnapshot {
  DetectionSnapshot(this.detections, this.capturedAt);
  final List<Detection> detections;
  final DateTime capturedAt;
}

/// Server coordinates must refer to the actual uploaded JPEG, not a letterboxed
/// model tensor. Normalize here once so preview size changes cannot distort boxes.
List<Detection> parseDetections(String body, int width, int height) {
  if (width <= 0 || height <= 0) throw const FormatException('Размер кадра');
  final result = <Detection>[];
  final pattern = RegExp(r'^\s*(.+?):\s*([\d.]+)%\s+at\s*\[([^\]]+)\]\s*$');
  for (final line in body.split('\n')) {
    if (line.trim().isEmpty) continue;
    final match = pattern.firstMatch(line);
    if (match == null) throw const FormatException('Формат ответа модели');
    final confidence = double.tryParse(match[2]!) ?? double.nan;
    final coords = match[3]!
        .split(',')
        .map((v) => double.tryParse(v.trim()) ?? double.nan)
        .toList();
    if (!confidence.isFinite ||
        confidence < 0 ||
        confidence > 100 ||
        coords.length != 4 ||
        coords.any((v) => !v.isFinite) ||
        coords[2] <= coords[0] ||
        coords[3] <= coords[1]) {
      throw const FormatException('Координаты или уверенность модели');
    }
    final box = Rect.fromLTRB(
      (coords[0] / width).clamp(0, 1),
      (coords[1] / height).clamp(0, 1),
      (coords[2] / width).clamp(0, 1),
      (coords[3] / height).clamp(0, 1),
    );
    if (!box.isEmpty) {
      result.add(Detection(match[1]!.trim(), confidence / 100, box));
    }
  }
  return List.unmodifiable(result);
}
