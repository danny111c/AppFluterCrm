// dialogo_reporte.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:proyectofinal/domain/models/cuenta_model.dart'; // ¡ASEGÚRATE QUE ESTA RUTA SEA CORRECTA!

// --- IMPORTA TU CLASE CUENTA REAL AQUÍ ---
// Si tu clase Cuenta está en `models/cuenta.dart`, por ejemplo:
// import 'package:tu_app/models/cuenta.dart';

// --- CLASE CUENTA (Ejemplo Mínimo) ---
// Si no tienes la clase Cuenta definida en otro lugar, puedes usar esta
// definición mínima. En una aplicación real, esta clase estaría en su propio archivo
// (e.g., models/cuenta.dart) y deberías importarla aquí.

// --- FIN CLASE CUENTA ---


/// Muestra un diálogo para reportar o actualizar una falla de cuenta.
///
/// Retorna el texto del problema ingresado, 'resuelto' si se marca como resuelto,
/// o null si se cancela.
Future<dynamic> showReporteFallaDialog({
  required BuildContext context, // El contexto es necesario para showDialog
  required Cuenta cuenta,
}) async {
  // El TextEditingController se crea dentro del scope de la función del diálogo
  final TextEditingController problemaController = TextEditingController(text: cuenta.problemaCuenta);

  return await showDialog<dynamic>(
    context: context,
    builder: (dialogContext) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          title: Text(cuenta.problemaCuenta == null
              ? 'Reportar Falla de Cuenta'
              : 'Actualizar/Resolver Falla'),
          content: TextField(
            controller: problemaController,
            decoration: InputDecoration(
              labelText: 'Describe el problema...',
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
                  if (cuenta.problemaCuenta != null)
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
                  if (cuenta.problemaCuenta != null) const SizedBox(width: 16),
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
                    child: Text(cuenta.problemaCuenta == null
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