import 'package:flutter/material.dart';

class StripedBackground extends StatelessWidget {
  final Widget child;
  final Color stripeColor;
  final double opacity;

  const StripedBackground({
    super.key, 
    required this.child, 
    this.stripeColor = Colors.amber,
    this.opacity = 0.3, // Opacidad para las rayas
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // El painter dibuja las rayas encima de lo que haya detrás
      painter: _StripePainter(stripeColor: stripeColor.withOpacity(opacity)),
      // El child se coloca dentro de un Container con un color de fondo sutil
      child: Container(
        // ===== CORRECCIÓN AQUÍ =====
        // Damos un color de fondo con una opacidad muy baja
        color: stripeColor.withOpacity(0.05),
        child: child,
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color stripeColor;

  _StripePainter({required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..style = PaintingStyle.stroke;

    // --- PARÁMETROS PARA AJUSTAR EL DISEÑO ---
    const double stripeThickness = 5.0;  // Grosor de cada raya
    const double gap = 15.0;             // Distancia entre el inicio de una raya y la siguiente

    paint.strokeWidth = stripeThickness;

    final double totalWidth = size.width + size.height;
    
    // Dibuja las líneas diagonales
    for (double i = -stripeThickness; i < totalWidth; i += gap) {
      canvas.drawLine(
        Offset(i - stripeThickness, 0),
        Offset(0, i - stripeThickness),
        paint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}