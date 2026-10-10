import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

/// [data] as a black-on-white QR code, [size] wide with a quiet zone.
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = 220});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(painter: _QrPainter(image)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / image.moduleCount;
    final paint = Paint()..color = const Color(0xFF000000);
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        // Slight overlap avoids hairline gaps between modules.
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
