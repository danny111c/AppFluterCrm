// lib/presentation/widgets/modals/plataforma_modal.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../domain/models/plataforma_model.dart';
import '../../widgets/dialogs/dialogo_confirma_actualizar.dart'; // Asegúrate de que esta ruta sea correcta

class PlataformaModal extends StatefulWidget {
  final Plataforma? plataforma;
  // Asegurarse de que onSave sea Future<bool> para poder manejar éxito/fallo explícitamente
  final Future<bool> Function(Plataforma) onSave; 

  const PlataformaModal({
    super.key,
    this.plataforma,
    required this.onSave,
  });

  @override
  State<PlataformaModal> createState() => _PlataformaModalState();
}

class _PlataformaModalState extends State<PlataformaModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _notasController;
  bool _isSaving = false; // Para deshabilitar botones mientras se guarda
  bool _showNoChangesWarning = false; // Added state for warning

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.plataforma?.nombre ?? '');
    _notasController = TextEditingController(text: widget.plataforma?.nota ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _savePlataforma() async {
    if (!_formKey.currentState!.validate()) {
      return; // Formulario no válido
    }

    if (_isSaving) {
      return; // Ya estamos procesando, evitar doble clic
    }

    // --- Detectar cambios y confirmar ---
    bool proceedWithSave = true; // Por defecto, si es nuevo, procedemos.

    if (widget.plataforma != null) { // Solo si es una actualización
      final List<CambioDetalle> cambiosAActualizar = [];
      final Plataforma original = widget.plataforma!;

      final nuevoNombre = _nombreController.text.trim();
      final nuevaNota = _notasController.text.trim();

      if (original.nombre != nuevoNombre) {
        cambiosAActualizar.add(CambioDetalle(label: 'Nombre', valorAnterior: original.nombre, valorNuevo: nuevoNombre));
      }
      final notaOriginalSegura = original.nota ?? '';
      if (notaOriginalSegura != nuevaNota) {
          cambiosAActualizar.add(CambioDetalle(label: 'Detalles', valorAnterior: original.nota ?? '(vacío)', valorNuevo: nuevaNota));
      }

      // Solo mostramos el diálogo si hay realmente cambios que confirmar.
      if (cambiosAActualizar.isNotEmpty) {
        final bool? confirmationResult = await DialogoConfirmaActualizar.show( // Renombramos 'confirmacion' a 'confirmationResult'
          context: context,
          title: 'Confirmar Actualización de Plataforma',
          cambios: cambiosAActualizar,
          confirmText: 'Actualizar',
          cancelText: 'Volver',
        );
        
        // Si confirmationResult es null (cierre accidental) o false (cancelado), no procedemos.
        proceedWithSave = confirmationResult ?? false; 
        
        // Si el usuario canceló o cerró el diálogo, salimos temprano.
        if (!proceedWithSave) {
          return; 
        }
      } else {
        setState(() => _showNoChangesWarning = true);
        return;
      }
    }

    // --- Proceder al guardado si todo está OK ---
    // Si llegamos aquí, es porque:
    // 1. Es una nueva plataforma (widget.plataforma == null) OR
    // 2. Es una actualización Y fue confirmada (proceedWithSave == true)
    if (proceedWithSave) { 
      setState(() {
        _isSaving = true; // Deshabilitar botones
      });

      final plataforma = Plataforma(
        id: widget.plataforma?.id,
        nombre: _nombreController.text.trim(),
        nota: _notasController.text.trim(),
      );

      try {
        // Llamar a la función onSave proporcionada por la pantalla que usa este modal.
        // Se espera que onSave sea Future<bool> y devuelva true para éxito, false para fallo.
        final bool success = await widget.onSave(plataforma);

        if (mounted) { // Asegurarnos de que el widget aún esté montado
          if (success) {
            // Si el guardado fue exitoso, cerrar el modal con resultado 'true'
            Navigator.pop(context, true);
          } else {
            // Si onSave devolvió false (indicando un fallo), reactivar botones y mostrar mensaje.
            setState(() {
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al guardar los datos. Intente de nuevo.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } catch (e) { // Capturar cualquier otra excepción (ej. error de red, etc.)
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ocurrió un error: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
            minWidth: 500,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plataforma == null ? 'Nueva Plataforma' : 'Editar Plataforma',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildTextField('Nombre', _nombreController, isRequired: true),
                    _buildTextField('Detalles', _notasController, maxLines: 3),
                    const SizedBox(height: 25),
                    if (_showNoChangesWarning)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orangeAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No se detectaron cambios para actualizar',
                                  style: TextStyle(color: Colors.orangeAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 150,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _savePlataforma,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Text(
                                    widget.plataforma == null ? 'Guardar' : 'Actualizar',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, 
      {bool isRequired = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color.fromARGB(255, 15, 15, 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: isRequired ? (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingrese $label';
            }
            return null;
          } : null,
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}