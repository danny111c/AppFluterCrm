import 'package:flutter/material.dart';
import 'dart:ui';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Eliminar',
    this.cancelText = 'Cancelar',
  });

  @override
  Widget build(BuildContext context) {
    // ===== LÓGICA PARA ESTILO DINÁMICO =====
    // Por defecto, usamos el estilo para "Entendido" u otras acciones.
    Color confirmButtonBackgroundColor = Colors.black;
    Color confirmButtonTextColor = Colors.white;

    // Si el texto es específicamente "Eliminar", usamos el estilo de acción peligrosa.
    if (confirmText.toLowerCase() == 'eliminar') {
      confirmButtonBackgroundColor = Colors.white;
      confirmButtonTextColor = Colors.red;
    }
    // =======================================

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: const Color.fromARGB(255, 49, 49, 49),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        contentPadding: const EdgeInsets.all(16),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        title: Text(title, 
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (cancelText.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText, style: const TextStyle(color: Colors.white)),
            ),
          
          if (cancelText.isNotEmpty)
            const SizedBox(width: 10),
          
          // ===== BOTÓN DE CONFIRMACIÓN CON ESTILO DINÁMICO =====
          TextButton(
            style: TextButton.styleFrom(
              // Usamos las variables de color que definimos arriba
              backgroundColor: confirmButtonBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText, style: TextStyle(color: confirmButtonTextColor)),
          ),
          // ====================================================
        ],
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Eliminar',
    String cancelText = 'Cancelar',
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }
}