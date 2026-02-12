// lib/presentation/widgets/modals/proveedor_modal.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../domain/models/proveedor_model.dart';
import '../../../infrastructure/repositories/proveedor_repository.dart';
// Asegúrate de que la ruta de importación sea correcta
import '../../widgets/dialogs/dialogo_confirma_actualizar.dart'; 
  
class ProveedorModal extends StatefulWidget {
  final Proveedor? proveedor;
  final ProveedorRepository proveedorRepository;

  const ProveedorModal({
    super.key,
    this.proveedor,
    required this.proveedorRepository,
  });

  @override
  State<ProveedorModal> createState() => _ProveedorModalState();
}

class _ProveedorModalState extends State<ProveedorModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _contactoController;
  late TextEditingController _notaController;
  String? _errorMessage;
  bool _isSaving = false;
  String? _contactoError;
  bool _showNoChangesWarning = false; // Added state for warning
  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.proveedor?.nombre ?? '');
    _contactoController = TextEditingController(text: widget.proveedor?.contacto ?? '');
    _notaController = TextEditingController(text: widget.proveedor?.nota ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contactoController.dispose();
    _notaController.dispose();
    super.dispose();
  }
  
  // ===== MODIFICADO: Lógica para guardar proveedor, incluyendo confirmación =====
  Future<void> _saveProveedor() async {
    // 1. Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return; // Si el formulario no es válido, no hacer nada.
    }

    // 2. PRIMERO: Validar duplicidad de contacto ANTES del diálogo
    final nuevoContacto = _contactoController.text.trim();
    
    // Si estamos editando, verificar si el contacto cambió y si ya existe
    if (widget.proveedor != null) {
      final original = widget.proveedor!;
      
      // Solo verificar duplicidad si el contacto realmente cambió
      if (original.contacto != nuevoContacto) {
        try {
          final contactoExiste = await widget.proveedorRepository.getProveedores(
            searchQuery: nuevoContacto,
            perPage: 1,
          );
          
          // Si encontramos algún proveedor con ese contacto (que no sea el actual)
          if (contactoExiste.isNotEmpty && contactoExiste.first.id != original.id) {
            setState(() {
              _contactoError = 'Este número de contacto ya está registrado';
            });
            return; // Salir sin mostrar el diálogo
          }
        } catch (e) {
          // Error al verificar duplicidad
          setState(() {
            _errorMessage = 'Error al verificar contacto: ${e.toString()}';
          });
          return;
        }
      }
    } else {
      // Para nuevo proveedor, siempre verificar duplicidad
      try {
        final contactoExiste = await widget.proveedorRepository.getProveedores(
          searchQuery: nuevoContacto,
          perPage: 1,
        );
        
        if (contactoExiste.isNotEmpty) {
          setState(() {
            _contactoError = 'Este número de contacto ya está registrado';
          });
          return; // Salir sin mostrar el diálogo
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error al verificar contacto: ${e.toString()}';
        });
        return;
      }
    }

    // 3. Limpiar errores previos si llegamos aquí
    setState(() {
      _contactoError = null;
      _errorMessage = null;
    });

    // 4. Determinar si se debe proceder con el guardado
    bool proceedWithSave = true; // Por defecto, asumimos que se puede guardar (ej. nuevo proveedor)

    // Si estamos editando un proveedor existente (widget.proveedor no es nulo)...
    if (widget.proveedor != null) {
      // --- Detectar los cambios ---
      final List<CambioDetalle> cambiosAActualizar = [];
      final Proveedor original = widget.proveedor!; // Objeto proveedor original

      final nuevoNombre = _nombreController.text.trim();
      final nuevaNota = _notaController.text.trim();

      if (original.nombre != nuevoNombre) {
        cambiosAActualizar.add(CambioDetalle(
          label: 'Nombre',
          valorAnterior: original.nombre,
          valorNuevo: nuevoNombre,
        ));
      }
      if (original.contacto != nuevoContacto) {
        cambiosAActualizar.add(CambioDetalle(
          label: 'Contacto',
          valorAnterior: original.contacto,
          valorNuevo: nuevoContacto,
        ));
      }
      // Manejar el caso de notas nulas o vacías de forma segura
      final notaOriginalSegura = original.nota ?? '';
      if (notaOriginalSegura != nuevaNota) {
          cambiosAActualizar.add(CambioDetalle(
            label: 'Nota',
            valorAnterior: original.nota ?? '(vacío)', // Mostrar "(vacío)" si la nota original era nula
            valorNuevo: nuevaNota,
          ));
      }

      // Si no hay cambios, mostrar advertencia
      if (cambiosAActualizar.isEmpty) {
        setState(() {
          _showNoChangesWarning = true;
        });
        return;
      } else {
        setState(() {
          _showNoChangesWarning = false;
        });
      }

      // --- AHORA SÍ: Mostrar el diálogo de confirmación (sin riesgo de duplicidad) ---
      final bool? confirmacion = await DialogoConfirmaActualizar.show(
        context: context,
        title: 'Confirmar Actualización de Proveedor',
        cambios: cambiosAActualizar,
        confirmText: 'Actualizar',
        cancelText: 'Volver',
      );

      // Si la confirmación es null (cierre accidental) o false (cancelado), no seguimos.
      proceedWithSave = confirmacion ?? false;
    }
    // Si widget.proveedor es null, estamos creando, por lo que proceedWithSave se mantiene true.

    // 5. Si todo está correcto (es un nuevo proveedor o la actualización fue confirmada)
    if (proceedWithSave && !_isSaving) { // Doble chequeo para evitar dobles pulsaciones
      setState(() {
        _isSaving = true;
        _errorMessage = null; // Limpiar mensaje de error anterior
        _contactoError = null; // Limpiar error de contacto
      });
      
      final proveedor = Proveedor(
        id: widget.proveedor?.id, // Si es edición, se mantiene el ID
        nombre: _nombreController.text.trim(),
        contacto: _contactoController.text.trim(),
        nota: _notaController.text.trim(),
      );
      
try {
        Proveedor proveedorGuardado;
        bool fueRestaurado = false; // Nueva variable para saber qué pasó

        if (widget.proveedor == null) { 
          // CASO NUEVO PROVEEDOR (Aquí usamos la nueva lógica)
          final result = await widget.proveedorRepository.addProveedor(proveedor);
          proveedorGuardado = result['proveedor'] as Proveedor;
          fueRestaurado = result['restaurado'] as bool;
        
        } else { 
          // CASO EDICIÓN (Sigue igual)
          await widget.proveedorRepository.updateProveedor(proveedor);
          proveedorGuardado = proveedor; 
        }

        if (mounted) {
          // Devolvemos más información al cerrar
          Navigator.pop(context, {
            'guardado': true,
            'proveedor': proveedorGuardado,
            'restaurado': fueRestaurado, // Avisamos si fue una restauración
          }); 
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            // Limpiamos el mensaje de error para que se vea bonito
            _errorMessage = e.toString().contains('Exception:') 
                ? e.toString().split('Exception: ')[1] 
                : e.toString();
          });
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
          constraints: const BoxConstraints(
            maxWidth: 400,
          ),
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
                      widget.proveedor == null ? 'Nuevo Proveedor' : 'Actualizar Proveedor',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Mostrar mensaje de error si existe
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[300], fontSize: 14),
                        ),
                      ),
                    // Campo Nombre
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Por favor ingrese un nombre';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    // Campo Contacto
                    Text('Contacto', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 5),
TextFormField(
  controller: _contactoController,
  style: const TextStyle(color: Colors.white),
  keyboardType: TextInputType.phone,
  decoration: InputDecoration(
    filled: true,
    fillColor: const Color.fromARGB(255, 15, 15, 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    errorText: _contactoError,
  ),
  validator: (value) {
    if (value == null || value.isEmpty) return 'Por favor ingrese un contacto';
    return null;
  },
),
                    const SizedBox(height: 15),
                    // Campo Nota
                    Text('Nota', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _notaController,
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


                    // BOTONES GUARDAR Y CANCELAR
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
  mainAxisAlignment: MainAxisAlignment.center, // centrado
  children: [
    ElevatedButton(
      onPressed: _isSaving ? null : () => Navigator.pop(context, null),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: const Text('Cancelar'),
    ),
    const SizedBox(width: 10),
    ElevatedButton(
      onPressed: _isSaving ? null : _saveProveedor,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: _isSaving
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
          )
        : const Text('Guardar'),
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
}