// lib/presentation/widgets/modals/tipo_cuenta_modal.dart
import 'package:flutter/material.dart';
import 'package:proyectofinal/domain/models/tipo_cuenta_model.dart';
import 'dart:ui';
// Asegúrate de que la ruta de importación sea correcta
import '../../widgets/dialogs/dialogo_confirma_actualizar.dart';

class TipoCuentaModal extends StatefulWidget {
  final TipoCuenta? tipoCuenta;
  // CAMBIO: La firma de onSave ahora debe devolver un Future<bool>
  final Future<bool> Function(TipoCuenta) onSave;

  const TipoCuentaModal({
    super.key,
    this.tipoCuenta,
    required this.onSave,
  });

  @override
  State<TipoCuentaModal> createState() => _TipoCuentaModalState();
}

class _TipoCuentaModalState extends State<TipoCuentaModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tipoController;
  late final TextEditingController _notasController;
  bool _isSaving = false; // Estado para deshabilitar botones
  bool _showNoChangesWarning = false; // Added state for warning

  @override
  void initState() {
    super.initState();
    _tipoController = TextEditingController(text: widget.tipoCuenta?.nombre ?? '');
    _notasController = TextEditingController(text: widget.tipoCuenta?.nota ?? '');
  }

  @override
  void dispose() {
    _tipoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  // ===== NUEVO: Método para manejar el guardado y la confirmación =====
  Future<void> _saveTipoCuenta() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    bool proceedWithSave = true;

    if (widget.tipoCuenta != null) {
      final List<CambioDetalle> cambiosAActualizar = [];
      final TipoCuenta original = widget.tipoCuenta!;

      final nuevoNombre = _tipoController.text.trim();
      final nuevaNota = _notasController.text.trim();

      if (original.nombre != nuevoNombre) {
        cambiosAActualizar.add(CambioDetalle(
          label: 'Tipo',
          valorAnterior: original.nombre,
          valorNuevo: nuevoNombre,
        ));
      }
      final notaOriginalSegura = original.nota ?? '';
      if (notaOriginalSegura != nuevaNota) {
          cambiosAActualizar.add(CambioDetalle(
            label: 'Notas',
            valorAnterior: original.nota ?? '(vacío)',
            valorNuevo: nuevaNota,
          ));
      }
      
      if (cambiosAActualizar.isEmpty) {
        setState(() => _showNoChangesWarning = true);
        return;
      } else {
        setState(() => _showNoChangesWarning = false);
      }

      if (cambiosAActualizar.isNotEmpty) {
        final bool? confirmed = await DialogoConfirmaActualizar.show(
          context: context,
          title: 'Confirmar Actualización de Tipo de Cuenta',
          cambios: cambiosAActualizar,
        );
        proceedWithSave = confirmed ?? false;
      }
    }

    if (proceedWithSave) {
      setState(() => _isSaving = true);
      
      final tipoCuenta = TipoCuenta(
        id: widget.tipoCuenta?.id,
        nombre: _tipoController.text.trim(),
        nota: _notasController.text.trim(),
      );

      try {
        final success = await widget.onSave(tipoCuenta);
        if (mounted) {
          if (success) {
            Navigator.pop(context, true);
          } else {
            setState(() => _isSaving = false);
            // El error se muestra en la pantalla padre, donde se definió el onSave
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'))
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
                      widget.tipoCuenta == null ? 'Añadir Tipo de Cuenta' : 'Editar Tipo de Cuenta',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildTextField('Tipo', _tipoController, isRequired: true),
                    _buildTextField('Notas', _notasController, maxLines: 3),
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

                    // ===== INICIO BOTONES GUARDAR Y CANCELAR =====
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
                            onPressed: _isSaving ? null : _saveTipoCuenta,
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
                                    widget.tipoCuenta == null ? 'Guardar' : 'Actualizar',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    //FIN BOTONES GUARDAR Y CANCELAR
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