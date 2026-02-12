// FILE: ../../../presentation/widgets/dialogs/dialogo_confirma_renovar.dart

import 'package:flutter/material.dart';
import 'dart:ui';

// --- Clase para la descripción de un cambio específico ---
// Esta clase es la misma que ya tienes, la incluimos aquí para que el archivo sea autocontenido.
// Asegúrate de que la definición de CambioDetalle esté accesible o copiada.
class CambioDetalle {
  final String label;
  final String valorAnterior;
  final String valorNuevo;

  CambioDetalle({
    required this.label,
    required this.valorAnterior,
    required this.valorNuevo,
  });

  Widget toWidget() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              children: [
                TextSpan(text: valorAnterior, style: const TextStyle(color: Color.fromARGB(255, 255, 100, 100))),
                const TextSpan(text: ' -> ', style: TextStyle(color: Colors.white70)),
                TextSpan(text: valorNuevo, style: const TextStyle(color: Color.fromARGB(255, 100, 255, 100))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- El nuevo modal DialogoConfirmaRenovar ---
class DialogoConfirmaRenovar extends StatelessWidget {
  final String title;
  final List<CambioDetalle> cambios;
  final String confirmText; // <-- Este será 'Renovar'
  final String cancelText;

  const DialogoConfirmaRenovar({
    super.key,
    required this.title,
    required this.cambios,
    this.confirmText = 'Renovar', // <-- Valor por defecto es 'Renovar'
    this.cancelText = 'Cancelar',
  });

  @override
  Widget build(BuildContext context) {
    // --- Estilos de botones ---
    final ButtonStyle cancelButtonStyle = TextButton.styleFrom(
      backgroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );

    // Botón Renovar: Fondo blanco, texto negro
    final ButtonStyle confirmButtonStyle = TextButton.styleFrom(
      backgroundColor: Colors.white, // Fondo blanco
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
    // --- FIN Estilos de botones ---

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: const Color.fromARGB(255, 49, 49, 49),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        title: Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: Text(
                  '¿Desea guardar los siguientes cambios?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cambios.map((cambio) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: cambio.toWidget(),
                )).toList(),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (cancelText.isNotEmpty)
            TextButton(
              style: cancelButtonStyle,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText, style: const TextStyle(color: Colors.white)),
            ),
          
          if (cancelText.isNotEmpty)
            const SizedBox(width: 10),
          
          TextButton(
            style: confirmButtonStyle,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText, style: const TextStyle(color: Colors.black)), // Muestra 'Renovar'
          ),
        ],
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required List<CambioDetalle> cambios,
    String confirmText = 'Renovar', // <-- Mantiene el valor por defecto 'Renovar'
    String cancelText = 'Cancelar',
  }) async {
    // Si no hay cambios, mostramos un mensaje y cerramos sin confirmar.
    if (cambios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se detectaron cambios para renovar.'), // Mensaje ajustado
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return false;
    }

    return await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => DialogoConfirmaRenovar( // <-- USAR NUESTRA NUEVA CLASE
        title: title,
        cambios: cambios,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }
}