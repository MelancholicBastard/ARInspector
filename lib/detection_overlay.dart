import 'package:material_ui/material_ui.dart';

import 'detection.dart';

/// Preview uses contain (no crop); normalized boxes share exactly its bounds.
Rect detectionRect(Rect box, Size size) => Rect.fromLTRB(
  box.left * size.width,
  box.top * size.height,
  box.right * size.width,
  box.bottom * size.height,
);

class DetectionOverlay extends CustomPainter {
  DetectionOverlay(this.detections, this.textDirection);
  final List<Detection> detections;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final detection in detections) {
      final rect = detectionRect(detection.box, size);
      final color = detection.label.toLowerCase().contains('rust')
          ? const Color(0xFFFFD699)
          : const Color(0xFFD9F4A7);
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final text = TextPainter(
        text: TextSpan(
          text:
              '${detection.label}: ${(detection.confidence * 100).toStringAsFixed(2)}%',
          style: const TextStyle(
            color: Color(0xFF121914),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: textDirection,
      )..layout(maxWidth: (size.width - 12).clamp(0, double.infinity));
      final left = rect.left.clamp(
        0,
        (size.width - text.width - 12).clamp(0, double.infinity),
      );
      final top = (rect.top - text.height - 8).clamp(
        0,
        (size.height - text.height - 8).clamp(0, double.infinity),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left.toDouble(),
            top.toDouble(),
            text.width + 12,
            text.height + 8,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = color,
      );
      text.paint(canvas, Offset(left + 6, top + 4));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DetectionOverlay oldDelegate) =>
      oldDelegate.detections != detections ||
      oldDelegate.textDirection != textDirection;
}
