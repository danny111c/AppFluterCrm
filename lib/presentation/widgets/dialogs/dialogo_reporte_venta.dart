// lib/presentation/widgets/dialogs/dialogo_reporte_venta.dart

import 'dart:ui';

import 'package:flutter/material.dart';
// IMPORTA TU MODELO VENTA REAL AQUÍ
import 'package:proyectofinal/domain/models/venta_model.dart'; // ¡ASEGÚRATE QUE ESTA RUTA SEA CORRECTA!
// Si necesitas la clase Cuenta para alguna lógica interna (como mostrar info relacionada), impórtala también.

/// Muestra un diálogo para reportar o actualizar una falla de venta.
///
/// Retorna el texto del problema ingresado, 'resuelto' si se marca como resuelto,
/// o null si se cancela.
Future<dynamic> showReporteVentaDialog({
  required BuildContext context,
  required Venta venta,
}) async {
  final TextEditingController problemaController = TextEditingController(text: venta.problemaVenta);

  return await showDialog<dynamic>(
    context: context,
    builder: (dialogContext) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          title: Text(venta.problemaVenta == null
              ? 'Reportar Falla de Venta'
              : 'Actualizar/Resolver Falla'),
          content: TextField(
            controller: problemaController,
            decoration: InputDecoration(
              labelText: 'Describe el problema específico...',
              labelStyle: const TextStyle(color: Colors.white),
              floatingLabelStyle: const TextStyle(color: Colors.white),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: Colors.white, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.5), width: 1.0),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.5), width: 1.0),
              ),
            ),
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
          titleTextStyle: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          actions: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (venta.problemaVenta != null)
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'resuelto'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text('Marcar como Resuelto'),
                    ),
                  if (venta.problemaVenta != null) const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (problemaController.text.isNotEmpty) {
                        Navigator.pop(context, problemaController.text);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Por favor, describe el problema.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: Text(venta.problemaVenta == null
                        ? 'Guardar'
                        : 'Actualizar Problema'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}