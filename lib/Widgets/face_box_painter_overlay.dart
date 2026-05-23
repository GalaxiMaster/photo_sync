import 'package:flutter/material.dart';

class FaceHoverOverlay extends StatefulWidget {
  final GlobalKey imageKey;
  final Rect normalizedBox; // x, y, w, h all 0–1

  const FaceHoverOverlay({super.key, required this.imageKey, required this.normalizedBox});

  @override
  State<FaceHoverOverlay> createState() => _FaceHoverOverlayState();
}

class _FaceHoverOverlayState extends State<FaceHoverOverlay> {
  Rect? _imageRect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlayRB = context.findRenderObject() as RenderBox?;
      final imageRB   = widget.imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (overlayRB == null || imageRB == null) return;
      final origin = overlayRB.globalToLocal(imageRB.localToGlobal(Offset.zero));
      setState(() => _imageRect = origin & imageRB.size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _imageRect;
    if (img == null) return const SizedBox.expand();

    final rect = Rect.fromLTWH(
      img.left   + widget.normalizedBox.left   * img.width,
      img.top    + widget.normalizedBox.top    * img.height,
      widget.normalizedBox.width  * img.width,
      widget.normalizedBox.height * img.height,
    );

    return CustomPaint(
      painter: _HoverBoxPainter(rect),
    );
  }
}

class _HoverBoxPainter extends CustomPainter {
  final Rect rect;
  const _HoverBoxPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_HoverBoxPainter old) => old.rect != rect;
}