import 'package:flutter/material.dart';

class AddButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;
  final String? tooltip;

  const AddButton({
    super.key,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 40,
    this.tooltip = 'Añadir nuevo',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0), // Bordes un poco más redondeados
          ),
          // --- CAMBIO 1: Aumentamos el padding interno del botón ---
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18), 
          elevation: 2,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 22), // Añadimos un icono de suma real para que se vea pro
            SizedBox(width: 8),
            // --- CAMBIO 2: Aumentamos el tamaño y grosor de la letra ---
            Text(
              'AÑADIR', 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5
              )
            ),
          ],
        ),
      ),
    );
  }
}