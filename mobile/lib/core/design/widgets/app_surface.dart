import 'package:flutter/cupertino.dart';
import '../app_colors.dart';

/// Strokes [shape]'s outline with [AppColors.edgeHighlight] — the faint lit
/// top edge raised surfaces (cards, primary buttons) carry. Use as a
/// `foregroundPainter` so it sits above the surface's fill.
class AppEdgeHighlight extends CustomPainter {
  const AppEdgeHighlight({required this.shape, this.width = 1});

  final ShapeBorder shape;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = AppColors.edgeHighlight.createShader(rect);
    canvas.drawPath(shape.getOuterPath(rect.deflate(width / 2)), paint);
  }

  @override
  bool shouldRepaint(AppEdgeHighlight old) =>
      old.shape != shape || old.width != width;
}
