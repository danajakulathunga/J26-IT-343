import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:bananaguard_ai/core/api_client.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/models/scan_result.dart';

class ZoomableImageViewer extends StatefulWidget {
  final String imageUrl;
  final Uint8List? localBytes;
  final HighlightBoxModel? highlightBox;
  final bool showBox;

  const ZoomableImageViewer({
    super.key,
    required this.imageUrl,
    this.localBytes,
    this.highlightBox,
    this.showBox = false,
  });

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<ZoomableImageViewer> {
  Future<Uint8List>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ZoomableImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.localBytes != widget.localBytes) {
      _loadImage();
    }
  }

  void _loadImage() {
    if (widget.localBytes != null && widget.localBytes!.isNotEmpty) {
      _bytesFuture = Future.value(widget.localBytes);
    } else if (widget.imageUrl.isNotEmpty) {
      _bytesFuture = apiClient.fetchImageBytes(widget.imageUrl);
    } else {
      _bytesFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List>(
        future: _bytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppConstants.accentYellow),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'Could not load image',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(_loadImage),
                    icon: const Icon(Icons.refresh, color: AppConstants.accentYellow, size: 16),
                    label: const Text('Retry', style: TextStyle(color: AppConstants.accentYellow)),
                  ),
                ],
              ),
            );
          }

          final imageBytes = snapshot.data!;

          return Stack(
            fit: StackFit.expand,
            children: [
              PhotoView(
                imageProvider: MemoryImage(imageBytes),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
                initialScale: PhotoViewComputedScale.contained,
                basePosition: Alignment.center,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
              // Bounding Box Overlay if requested and present
              if (widget.showBox && widget.highlightBox != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _HighlightBoxPainter(box: widget.highlightBox!),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HighlightBoxPainter extends CustomPainter {
  final HighlightBoxModel box;

  _HighlightBoxPainter({required this.box});

  @override
  void paint(Canvas canvas, Size size) {
    // Normalised coordinates [0.0, 1.0]
    final rect = Rect.fromLTWH(
      box.x * size.width,
      box.y * size.height,
      box.w * size.width,
      box.h * size.height,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFFFFFF00) // Vibrant yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = const Color(0x33FFFF00)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HighlightBoxPainter oldDelegate) =>
      oldDelegate.box != box;
}
