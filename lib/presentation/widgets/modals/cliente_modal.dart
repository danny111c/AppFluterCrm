import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:proyectofinal/domain/models/cliente_model.dart';
import 'package:proyectofinal/infrastructure/repositories/cliente_repository.dart';
import '../../widgets/dialogs/dialogo_confirma_actualizar.dart';

class ClienteModal extends StatefulWidget {
  final Future<bool> Function(Cliente) onSave;
  final Cliente? cliente;
  final ClienteRepository clienteRepository;

  const ClienteModal({
    super.key,
    required this.onSave,
    this.cliente,
    required this.clienteRepository,
  });

  @override
  State<ClienteModal> createState() => _ClienteModalState();
}

class _ClienteModalState extends State<ClienteModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _contactoController;
  late TextEditingController _notasController;
  bool _isSaving = false;
  String? _contactoError;
  String? _errorMessage;
  bool _showNoChangesWarning = false;

  Future<bool> _isContactoRegistrado(String contacto) async {
    return await widget.clienteRepository.contactoExiste(contacto);
  }

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cliente?.nombre ?? '');
    _contactoController = TextEditingController(text: widget.cliente?.contacto ?? '');
    _notasController = TextEditingController(text: widget.cliente?.nota ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contactoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _contactoError = null;
      _errorMessage = null;
      _showNoChangesWarning = false;
    });

    final nuevoNombre = _nombreController.text.trim();
    final nuevoContacto = _contactoController.text.trim();
    final nuevaNota = _notasController.text.trim();

    if (widget.cliente != null) {
      final Cliente original = widget.cliente!;

      if (original.contacto != nuevoContacto) {
        bool contactoRegistrado = await _isContactoRegistrado(nuevoContacto);
        if (contactoRegistrado) {
          setState(() {
            _contactoError = 'Este número de contacto ya está registrado';
          });
          return;
        }
      }

      final List<CambioDetalle> cambiosAActualizar = [];
      if (original.nombre != nuevoNombre) {
        cambiosAActualizar.add(CambioDetalle(label: 'Nombre', valorAnterior: original.nombre, valorNuevo: nuevoNombre));
      }
      if (original.contacto != nuevoContacto) {
        cambiosAActualizar.add(CambioDetalle(label: 'Contacto', valorAnterior: original.contacto, valorNuevo: nuevoContacto));
      }
      final notaOriginalSegura = original.nota ?? '';
      if (notaOriginalSegura != nuevaNota) {
        cambiosAActualizar.add(CambioDetalle(label: 'Nota', valorAnterior: original.nota ?? '(vacío)', valorNuevo: nuevaNota));
      }

      if (cambiosAActualizar.isEmpty) {
        setState(() => _showNoChangesWarning = true);
        return;
      }

      final bool? confirmacion = await DialogoConfirmaActualizar.show(
        context: context,
        title: 'Confirmar Actualización de Cliente',
        cambios: cambiosAActualizar,
        confirmText: 'Actualizar',
        cancelText: 'Volver',
      );

      if (confirmacion != true) {
        return;
      }
    } else {
      bool contactoRegistrado = await _isContactoRegistrado(nuevoContacto);
      if (contactoRegistrado) {
        setState(() {
          _contactoError = 'Este número de contacto ya está registrado';
        });
        return;
      }
    }

    if (!_isSaving) {
      setState(() => _isSaving = true);

      final cliente = Cliente(
        id: widget.cliente?.id,
        nombre: nuevoNombre,
        contacto: nuevoContacto,
        nota: nuevaNota,
      );

      try {
        final success = await widget.onSave(cliente);
        if (mounted) {
          if (success) {
            Navigator.of(context).pop(true);
          } else {
            setState(() => _errorMessage = 'Error al guardar el cliente.');
          }
        }
      } catch (e) {
        if (mounted) {
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('unique constraint') || errorString.contains('contacto')) {
            _contactoError = 'Este número de contacto ya está registrado.';
          } else {
            _errorMessage = 'Ocurrió un error inesperado: $e';
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(20),
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
                      widget.cliente == null ? 'Nuevo Cliente' : 'Actualizar Cliente',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text('Nombre', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _nombreController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color.fromARGB(255, 15, 15, 15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Por favor ingrese un nombre' : null,
                    ),
                    const SizedBox(height: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contacto', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _contactoController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color.fromARGB(255, 15, 15, 15),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            errorText: _contactoError,
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Por favor ingrese un contacto' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text('Notas', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _notasController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color.fromARGB(255, 15, 15, 15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 25),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      ),
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
                                child: Text('No se detectaron cambios para actualizar', style: TextStyle(color: Colors.orangeAccent)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Text(widget.cliente == null ? 'Guardar' : 'Actualizar'),
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
}