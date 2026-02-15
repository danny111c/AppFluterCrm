import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../widgets/dialogs/dialogo_confirma_actualizar.dart';
import '../../../domain/models/cuenta_model.dart';
import '../../../domain/models/plataforma_model.dart';
import '../../../domain/models/proveedor_model.dart';
import '../../../domain/models/tipo_cuenta_model.dart';
import '../../../infrastructure/repositories/plataforma_repository.dart';
import '../../../infrastructure/repositories/proveedor_repository.dart';
import '../../../infrastructure/repositories/tipo_cuenta_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ 1. ASEGÚRATE DE QUE ESTO ESTÉ AQUÍ
import '../../../domain/providers/cuenta_provider.dart'; // ✅ AÑADE ESTO


class CuentaModal extends ConsumerStatefulWidget { // ✅ 2. Debe ser ConsumerStatefulWidget
  final Cuenta? cuenta;
  final Future<bool> Function(Cuenta) onSave;

  const CuentaModal({
    super.key,
    this.cuenta,
    required this.onSave,
  });

  @override
ConsumerState<CuentaModal> createState() => _CuentaModalState(); // Agregado 'Consumer'
}

class _CuentaModalState extends ConsumerState<CuentaModal> { // Agregado 'Consumer'
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _correoController;
  late TextEditingController _contrasenaController;
  late TextEditingController _numPerfilesController;
  late TextEditingController _costoCompraController;
  late TextEditingController _fechaInicioController;
  late TextEditingController _diasServicioController;
  late TextEditingController _fechaFinalController;
  late TextEditingController _notaController;
  
  // Controladores para campos de solo lectura
  late TextEditingController _plataformaController;
  late TextEditingController _tipoCuentaController;
  late TextEditingController _proveedorNombreController;
  late TextEditingController _proveedorContactoController;

  Plataforma? _selectedPlataforma;
  TipoCuenta? _selectedTipoCuenta;
  Proveedor? _selectedProveedor;
 
  DateTime? _fechaInicioSeleccionada;

  List<Plataforma> _plataformas = [];
  List<TipoCuenta> _tiposCuenta = [];
  List<Proveedor> _proveedores = [];

  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;
  bool _showTipoCuentaWarning = false;
  
  // ===== 1. NUEVA VARIABLE DE ESTADO =====
  // Para controlar la visibilidad de la advertencia de días de servicio.
  bool _showDiasServicioWarning = false;
  
  // Variable para mostrar advertencia de "no se detectaron cambios"
  bool _showNoChangesWarning = false;

  final DateFormat _displayDateFormat = DateFormat('dd-MM-yyyy');
  final DateFormat _dbDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _initializeState();
    _loadDropdownData();
    _diasServicioController.addListener(_calcularFechaFinal);
    _numPerfilesController.addListener(_handleEmptyPerfiles);
  }

  void _initializeState() {
final cuenta = widget.cuenta;

    // --- INICIO DE LA MODIFICACIÓN ---
    // Si estamos editando una cuenta (cuenta no es nulo) Y tiene una fecha de inicio guardada...
    if (cuenta != null && cuenta.fechaInicio != null && cuenta.fechaInicio!.isNotEmpty) {
      try {
        // ...usamos esa fecha de inicio. Asumo que está en formato yyyy-MM-dd.
        _fechaInicioSeleccionada = _dbDateFormat.parse(cuenta.fechaInicio!);
      } catch (e) {
        // Si hay un error de formato, usamos la fecha de hoy como respaldo.
        _fechaInicioSeleccionada = DateTime.now();
      }
    } else {
      // Si es una cuenta nueva, usamos la fecha de hoy.
      _fechaInicioSeleccionada = DateTime.now();
    }
    // --- FIN DE LA MODIFICACIÓN ---
    
    String diasServicioInicial = '30';
    if (cuenta != null && cuenta.fechaFinal != null && cuenta.fechaFinal!.isNotEmpty) {
      try {
        final DateTime fechaFinalGuardada = _dbDateFormat.parse(cuenta.fechaFinal!);
        
        // CORRECCIÓN: Usamos _fechaInicioSeleccionada en lugar de 'hoy' para que el cálculo sea siempre consistente.
        if (fechaFinalGuardada.isBefore(_fechaInicioSeleccionada!)) {
            diasServicioInicial = '0';
        } else {
            // Calculamos la diferencia entre la fecha final guardada y la fecha de inicio (que ahora es la correcta)
            diasServicioInicial = fechaFinalGuardada.difference(_fechaInicioSeleccionada!).inDays.toString();
        }

      } catch (e) {
        diasServicioInicial = '0';
      }
    }

    _correoController = TextEditingController(text: cuenta?.correo ?? '');
    _contrasenaController = TextEditingController(text: cuenta?.contrasena ?? '');
    _numPerfilesController = TextEditingController(text: cuenta?.numPerfiles.toString() ?? '0');
    _costoCompraController = TextEditingController(text: cuenta?.costoCompra?.toString() ?? '');
    _fechaInicioController = TextEditingController(text: _displayDateFormat.format(_fechaInicioSeleccionada!));
    _diasServicioController = TextEditingController(text: diasServicioInicial);
    _notaController = TextEditingController(text: cuenta?.nota ?? '');
    _fechaFinalController = TextEditingController();
    _plataformaController = TextEditingController(text: cuenta?.plataforma?.nombre ?? '');
    _tipoCuentaController = TextEditingController(text: cuenta?.tipoCuenta?.nombre ?? '');
    _proveedorNombreController = TextEditingController(text: cuenta?.proveedor?.nombre ?? '');
    _proveedorContactoController = TextEditingController(text: cuenta?.proveedor?.contacto ?? '');
    
    final initialPerfiles = int.tryParse(_numPerfilesController.text) ?? 1;
    if (initialPerfiles > 1) {
      _showTipoCuentaWarning = true;
    }
    
    if (cuenta != null) {
      _selectedPlataforma = cuenta.plataforma;
      _selectedTipoCuenta = cuenta.tipoCuenta;
      _selectedProveedor = cuenta.proveedor;
    }

    _calcularFechaFinal();
  }

  void _handleEmptyPerfiles() {
      if (_numPerfilesController.text.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _numPerfilesController.text.isEmpty) {
            _numPerfilesController.text = '1';
          }
        });
      }
  }
  
  // ===== 2. LÓGICA DE CÁLCULO ACTUALIZADA =====
  void _calcularFechaFinal() {
    if (_fechaInicioSeleccionada == null) {
      setState(() {
        _fechaFinalController.text = '';
        _showDiasServicioWarning = false;
      });
      return;
    }
    
    // Se intenta parsear el valor. Si está vacío o no es un número, dias será null.
    final dias = int.tryParse(_diasServicioController.text);

    setState(() {
      // Se permite que 'dias' sea 0 o mayor.
      if (dias != null && dias >= 0) {
        final fechaFinalCalculada = _fechaInicioSeleccionada!.add(Duration(days: dias));
        _fechaFinalController.text = _displayDateFormat.format(fechaFinalCalculada);
        // La advertencia solo se muestra si los días son exactamente 0.
        _showDiasServicioWarning = (dias == 0);
      } else {
        // Si el campo está vacío o es inválido, se limpia la fecha final y se oculta la advertencia.
        _fechaFinalController.text = '';
        _showDiasServicioWarning = false;
      }
    });
  }

  Future<void> _seleccionarFechaInicio(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicioSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _fechaInicioSeleccionada) {
      setState(() {
        _fechaInicioSeleccionada = picked;
        _fechaInicioController.text = _displayDateFormat.format(picked);
        _calcularFechaFinal();
      });
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      final plataformaRepo = PlataformaRepository();
      final tipoCuentaRepo = TipoCuentaRepository();
      final proveedorRepo = ProveedorRepository(Supabase.instance.client);

      final results = await Future.wait([
        plataformaRepo.getPlataformas(page: 1, perPage: 1000),
        tipoCuentaRepo.getTiposCuenta(page: 1, perPage: 1000),
        proveedorRepo.getProveedores(page: 1, perPage: 1000),
      ]);

      if (mounted) {
        setState(() {
          _plataformas = results[0] as List<Plataforma>;
          _tiposCuenta = results[1] as List<TipoCuenta>;
          _proveedores = results[2] as List<Proveedor>;

          if (widget.cuenta != null) {
          _selectedPlataforma = _plataformas.firstWhereOrNull((p) => p.id == widget.cuenta!.plataforma.id);
          _selectedTipoCuenta = _tiposCuenta.firstWhereOrNull((t) => t.id == widget.cuenta!.tipoCuenta.id);
          _selectedProveedor = _proveedores.firstWhereOrNull((pr) => pr.id == widget.cuenta!.proveedor?.id);
        }  
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error cargando datos: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _numPerfilesController.removeListener(_handleEmptyPerfiles);
    _diasServicioController.removeListener(_calcularFechaFinal);
    _correoController.dispose();
    _contrasenaController.dispose();
    _numPerfilesController.dispose();
    _costoCompraController.dispose();
    _fechaInicioController.dispose();
    _diasServicioController.dispose();
    _fechaFinalController.dispose();
    _notaController.dispose();
    _proveedorNombreController.dispose();
    _proveedorContactoController.dispose();
    super.dispose();
  }

  // ===== MÉTODO _saveCuenta COMPLETAMENTE MODIFICADO =====
// DENTRO DE _CuentaModalState en cuenta_modal.dart

Future<void> _saveCuenta() async {
  print('DEBUG: _saveCuenta called');
  
  if (_numPerfilesController.text.isEmpty) {
      _numPerfilesController.text = '0';
  }

  if (!_formKey.currentState!.validate() || _isLoading || _isSaving) {
    print('DEBUG: Validation failed or already saving');
    return;
  }

  bool proceedWithSave = true;

  // --- Lógica de confirmación solo para actualizaciones ---
  if (widget.cuenta != null) {
    
    final List<CambioDetalle> cambios = [];
    final Cuenta original = widget.cuenta!;
    
    // Obtener los valores nuevos de los controladores
    final TipoCuenta? nuevoTipoCuenta = _selectedTipoCuenta;
    final String nuevoProveedorNombre = _proveedorNombreController.text.trim();
    final String nuevoCorreo = _correoController.text.trim();
    final String nuevaContrasena = _contrasenaController.text.trim();
    // --- LÓGICA DE VALIDACIÓN AL EDITAR ---
    final int nuevosPerfiles = int.tryParse(_numPerfilesController.text) ?? 0;
    
    // Calculamos cuántos perfiles hay vendidos actualmente
    // (Total original - Disponibles original)
    final int vendidosActualmente = widget.cuenta!.numPerfiles - widget.cuenta!.perfilesDisponibles;

    if (nuevosPerfiles < vendidosActualmente) {
      setState(() {
        _errorMessage = "No puedes bajar a $nuevosPerfiles perfiles porque ya tienes $vendidosActualmente vendidos. Primero finaliza esas ventas.";
      });
      return; // Bloquea el guardado
    }    final double? nuevoCosto = double.tryParse(_costoCompraController.text);
    final String nuevaFechaFinalStr = _fechaFinalController.text;
    final String nuevaNota = _notaController.text.trim();

    // Comparar cada campo (se omite la plataforma)
    if (original.tipoCuenta.id != nuevoTipoCuenta?.id) {
      cambios.add(CambioDetalle(label: 'Tipo Cuenta', valorAnterior: original.tipoCuenta.nombre, valorNuevo: nuevoTipoCuenta?.nombre ?? ''));
    }
    if (original.proveedor.nombre != nuevoProveedorNombre) {
      cambios.add(CambioDetalle(label: 'Proveedor', valorAnterior: original.proveedor.nombre, valorNuevo: nuevoProveedorNombre));
    }
    if (original.correo != nuevoCorreo) {
      cambios.add(CambioDetalle(label: 'Correo', valorAnterior: original.correo, valorNuevo: nuevoCorreo));
    }
    if (original.contrasena != nuevaContrasena) {
      cambios.add(CambioDetalle(label: 'Contraseña', valorAnterior: original.contrasena, valorNuevo: nuevaContrasena));
    }
    if (original.numPerfiles != nuevosPerfiles) {
      cambios.add(CambioDetalle(label: 'Perfiles', valorAnterior: original.numPerfiles.toString(), valorNuevo: nuevosPerfiles.toString()));
    }
    if (original.costoCompra != nuevoCosto) {
      cambios.add(CambioDetalle(label: 'Costo Compra', valorAnterior: original.costoCompra?.toString() ?? '0.0', valorNuevo: nuevoCosto?.toString() ?? '0.0'));
    }
    
    final String originalFechaFinalStr = original.fechaFinal != null ? _displayDateFormat.format(_dbDateFormat.parse(original.fechaFinal!)) : '';
    if (originalFechaFinalStr != nuevaFechaFinalStr) {
      cambios.add(CambioDetalle(label: 'Fecha Final', valorAnterior: originalFechaFinalStr.isEmpty ? '(vacío)' : originalFechaFinalStr, valorNuevo: nuevaFechaFinalStr));
    }
    
    if ((original.nota ?? '') != nuevaNota) {
      cambios.add(CambioDetalle(label: 'Nota', valorAnterior: original.nota ?? '(vacío)', valorNuevo: nuevaNota));
    }
    
    // Mostrar diálogo si hay cambios
    if (cambios.isNotEmpty) {
      final confirmed = await DialogoConfirmaActualizar.show(
        context: context,
        title: 'Confirmar Actualización de Cuenta',
        cambios: cambios,
      );
      proceedWithSave = confirmed ?? false;
    } else {
      // Mostrar advertencia dentro del modal en lugar de SnackBar
      setState(() {
        _showNoChangesWarning = true;
      });
      // Ocultar la advertencia después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNoChangesWarning = false;
          });
        }
      });
      return;
    }
  }
  
  // --- Lógica de guardado (se mantiene igual, ya que usa _selectedPlataforma) ---
  if (proceedWithSave) {
    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      Proveedor proveedorFinal;
      
      // Si hay un proveedor seleccionado del autocomplete, usarlo
      if (_selectedProveedor != null) {
        proveedorFinal = _selectedProveedor!;
      } else {
        // Si no hay proveedor seleccionado, crear uno nuevo con los datos ingresados
        final nombreProveedor = _proveedorNombreController.text.trim();
        final contactoProveedor = _proveedorContactoController.text.trim();
        
        if (nombreProveedor.isEmpty || contactoProveedor.isEmpty) { 
          throw Exception('Debe seleccionar un proveedor o proporcionar nombre y contacto para crear uno nuevo.'); 
        }
        
        // Verificar si ya existe un proveedor con ese nombre
        Proveedor? proveedorExistente = _proveedores.firstWhereOrNull((p) => p.nombre.toLowerCase() == nombreProveedor.toLowerCase());
        
if (proveedorExistente != null) {
          proveedorFinal = proveedorExistente;
        } else {
          final proveedorRepo = ProveedorRepository(Supabase.instance.client);
          final nuevoProveedor = Proveedor(nombre: nombreProveedor, contacto: contactoProveedor);
          
          // ✅ CORRECCIÓN AQUÍ: Capturamos el Mapa
          final result = await proveedorRepo.addProveedor(nuevoProveedor);
          
          // Extraemos el objeto Proveedor del mapa
          proveedorFinal = result['proveedor'] as Proveedor; 
          
          // Opcional: Si quieres avisar que se restauró
          if (result['restaurado'] == true) {
             print('Proveedor restaurado automáticamente al crear cuenta');
          }

          if (mounted) setState(() => _proveedores.add(proveedorFinal));
        }
      }

      final int numPerfilesNuevo = int.tryParse(_numPerfilesController.text) ?? 1;
      int perfilesDisponiblesFinal;

      if (widget.cuenta == null) {
        perfilesDisponiblesFinal = numPerfilesNuevo;
      } else {
        final int perfilesVendidos = widget.cuenta!.numPerfiles - widget.cuenta!.perfilesDisponibles;
        if (numPerfilesNuevo < perfilesVendidos) {
          throw Exception('No puedes establecer un total de $numPerfilesNuevo perfiles. Ya hay $perfilesVendidos perfiles vendidos.');
        }
        perfilesDisponiblesFinal = numPerfilesNuevo - perfilesVendidos;
      }
      
      final cuenta = Cuenta(
        id: widget.cuenta?.id,
        plataforma: _selectedPlataforma!,
        tipoCuenta: _selectedTipoCuenta!,
        proveedor: proveedorFinal,
        correo: _correoController.text.trim(),
        contrasena: _contrasenaController.text.trim(),
        numPerfiles: numPerfilesNuevo,
        perfilesDisponibles: perfilesDisponiblesFinal,
        costoCompra: double.tryParse(_costoCompraController.text),
        fechaInicio: _fechaInicioSeleccionada != null ? _dbDateFormat.format(_fechaInicioSeleccionada!) : null,
        fechaFinal: _fechaFinalController.text.isNotEmpty ? _dbDateFormat.format(_displayDateFormat.parse(_fechaFinalController.text)) : null,
        nota: _notaController.text.trim(),
      );

print('DEBUG: About to call widget.onSave');
      final success = await widget.onSave(cuenta);
      print('DEBUG: widget.onSave returned: $success');

      if (success && mounted) {
        // ✅ REFRESCO DE RIVERPOD: 
        // Obliga a la tabla de Cuentas a pedir los datos nuevos a Supabase.
        // Esto hace que el cambio de "COMPLETA" a "1/1" se vea al instante.
      ref.read(cuentasProvider.notifier).refresh();
        
        Navigator.pop(context, true);
      } else {
        if (mounted) setState(() => _isSaving = false);
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false; // Asegurar que siempre se restablezca el estado
          _errorMessage = null;
          // Debug: Print the full error to console
          print('DEBUG: Full error message: ${e.toString()}');
          
          // Detect duplicate key constraint error for accounts
          final errorMsg = e.toString().toLowerCase();
          print('DEBUG: Lowercase error: $errorMsg');
          
          if (errorMsg.contains('duplicate key') || 
              errorMsg.contains('unique constraint') ||
              errorMsg.contains('23505') || // PostgreSQL unique violation error code
              errorMsg.contains('already exists') ||
              (errorMsg.contains('correo') && errorMsg.contains('plataforma'))) {
            _errorMessage = 'Esta cuenta ya existe';
            print('DEBUG: Setting duplicate account error message');
          } else {
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
            print('DEBUG: Setting generic error message: $_errorMessage');
          }
        });
      }
    }
  }
}

// DENTRO DE _CuentaModalState en cuenta_modal.dart



  Widget _buildTextField(TextEditingController controller, String label, {bool isRequired = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number && label != 'Costo Compra' 
            ? [FilteringTextInputFormatter.digitsOnly] 
            : label == 'Costo Compra' 
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))] 
                : [],
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color.fromARGB(255, 0, 0, 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: isRequired ? (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es requerido';
            }
            return null;
          } : null,
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  

  // ===== 3. MÉTODO BUILD ACTUALIZADO =====
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            height: 700,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 15, 15, 15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.cuenta == null ? 'Nueva Cuenta' : 'Actualizar Cuenta',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
// Campo de Plataforma - Solo lectura cuando se edita una cuenta existente
widget.cuenta != null
    ? _buildReadOnlyField('Plataforma', _plataformaController)
    : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plataforma', style: TextStyle(color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              return Autocomplete<Plataforma>(
                displayStringForOption: (Plataforma option) => option.nombre,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
                    _buildAutocompleteField(
                      controller,
                      focusNode,
                      'Plataforma',
                      false,
                      _selectedPlataforma == null,
                    ),
                optionsBuilder: (val) => val.text.isEmpty
                    ? _plataformas
                    : _plataformas.where((p) => p.nombre
                        .toLowerCase()
                        .contains(val.text.toLowerCase())),
                onSelected: (Plataforma selection) =>
                    setState(() => _selectedPlataforma = selection),
                optionsViewBuilder: (context, onSelected, options) =>
                    _buildWhiteOptionsWidth(
                      options,
                      (option) => onSelected(option as Plataforma),
                      constraints.maxWidth,
                    ),
              );
            },
          ),
        ],
      ),
const SizedBox(height: 15),


// Campo de Tipo de Cuenta - Siempre editable
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Tipo de Cuenta', style: TextStyle(color: Colors.white.withOpacity(0.8))),
    const SizedBox(height: 5),
    LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<TipoCuenta>(
          displayStringForOption: (TipoCuenta option) => option.nombre,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            // Sincronizar el texto con nuestro controlador
            controller.text = _tipoCuentaController.text;
            
            return GestureDetector(
              onTap: () {
                // Mostrar lista completa al hacer clic
                focusNode.requestFocus();
              },
              child: TextFormField(
                controller: controller, // Usar el controlador del Autocomplete
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 11, 11, 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'Tipo de Cuenta',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                validator: (_) => _selectedTipoCuenta == null ? 'Seleccione Tipo de Cuenta' : null,
                onChanged: (value) {
                  // Actualizar nuestro controlador cuando cambie el texto
                  _tipoCuentaController.text = value;
                },
              ),
            );
          },
          optionsBuilder: (TextEditingValue val) {
            final text = val.text.toLowerCase();
            if (text.isEmpty) {
              return _tiposCuenta;
            }
            return _tiposCuenta.where((t) => 
              t.nombre.toLowerCase().contains(text)
            ).toList();
          },
          onSelected: (TipoCuenta selection) {
            setState(() {
              _selectedTipoCuenta = selection;
              _tipoCuentaController.text = selection.nombre;
            });
          },
          optionsViewBuilder: (context, onSelected, options) =>
              _buildWhiteOptionsWidth(
                options,
                (option) => onSelected(option as TipoCuenta),
                constraints.maxWidth,
              ),
        );
      },
    ),
    if (_showTipoCuentaWarning) ...[
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade600, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade600, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Más de 1 perfil. Verifique si el tipo de cuenta es correcto.',
                style: TextStyle(color: Colors.white, fontSize: 13),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 15),
  ],
),


// Campo de Proveedor - Autocomplete al crear, solo lectura al editar
widget.cuenta != null 
  ? _buildReadOnlyField('Proveedor', _proveedorNombreController)
  : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Proveedor', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
return RawAutocomplete<Proveedor>( // ✅ DEBE SER <Proveedor>
  displayStringForOption: (Proveedor option) => option.nombre,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              // Sincronizar el texto con nuestro controlador
              controller.text = _proveedorNombreController.text;
              
              return TextFormField(
                controller: controller, // Usar el controlador del Autocomplete
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 11, 11, 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'Proveedor',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                validator: (_) => _proveedorNombreController.text.trim().isEmpty ? 'Ingrese o seleccione un Proveedor' : null,
                onChanged: (value) {
                  // Actualizar nuestro controlador cuando cambie el texto
                  _proveedorNombreController.text = value;
                },
              );
            },
            optionsBuilder: (TextEditingValue val) {
              final text = val.text.toLowerCase();
              if (text.isEmpty) {
                return _proveedores;
              }
              return _proveedores.where((p) => 
                p.nombre.toLowerCase().contains(text)
              ).toList();
            },
            onSelected: (Proveedor selection) {
              setState(() {
                _selectedProveedor = selection;
                _proveedorNombreController.text = selection.nombre;
                _proveedorContactoController.text = selection.contacto;
              });
              // Force update the autocomplete field for contact number
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {});
              });
            },
            optionsViewBuilder: (context, onSelected, options) =>
                _buildWhiteOptionsWidth(
                  options,
                  (option) => onSelected(option as Proveedor),
                  constraints.maxWidth,
                ),
          );
          },
        ),
      ],
    ),
const SizedBox(height: 15),

// Campo de Número de Proveedor - Solo lectura al actualizar
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Número de Proveedor', style: TextStyle(color: Colors.white.withOpacity(0.8))),
    const SizedBox(height: 5),
    LayoutBuilder(
      builder: (context, constraints) {
        final isUpdating = widget.cuenta != null;
        
        if (isUpdating) {
          // Solo lectura al actualizar
          return TextFormField(
            controller: _proveedorContactoController,
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.2), // Fondo más oscuro para indicar que está bloqueado
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Número de proveedor',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          );
        } else {
          // Editable al agregar
          return Autocomplete<String>(
            displayStringForOption: (String option) => option,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              // Sincronizar el texto con nuestro controlador
              controller.text = _proveedorContactoController.text;
              
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                                    suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),

                  filled: true,
                  fillColor: const Color.fromARGB(255, 11, 11, 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'Número de proveedor',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                validator: (_) => _proveedorContactoController.text.trim().isEmpty ? 'Ingrese o seleccione un Número de Proveedor' : null,
                onChanged: (value) {
                  // Actualizar nuestro controlador cuando cambie el texto
                  _proveedorContactoController.text = value;
                },
              );
            },
            optionsBuilder: (TextEditingValue val) {
              final text = val.text.toLowerCase();
              if (text.isEmpty) {
                return _proveedores.map((p) => p.contacto).toList();
              }
              return _proveedores
                  .where((p) => p.contacto.toLowerCase().contains(text))
                  .map((p) => p.contacto)
                  .toList();
            },
            onSelected: (String selection) {
              final proveedor = _proveedores.firstWhere(
                (p) => p.contacto == selection,
                orElse: () => _proveedores.first,
              );
              setState(() {
                _selectedProveedor = proveedor;
                _proveedorContactoController.text = selection;
                _proveedorNombreController.text = proveedor.nombre;
              });
            },
            optionsViewBuilder: (context, onSelected, options) =>
                _buildWhiteOptionsWidth(
                  options,
                  (option) => onSelected(option.toString()),
                  constraints.maxWidth,
                ),
          );
        }
      },
    ),
  ],
),
const SizedBox(height: 15),
                                    _buildTextField(_correoController, 'Correo', isRequired: true),
                                    _buildTextField(_contrasenaController, 'Contraseña', isRequired: true),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Perfiles', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _numPerfilesController,
                                      style: const TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color.fromARGB(255, 0, 0, 0),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
validator: (value) {
  if (value == null || value.isEmpty) return 'Requerido';
  final int? numValue = int.tryParse(value);
  if (numValue == null) return 'Número inválido';
  // Eliminamos la validación de "no puede ser 0"
  return null; 
},
                                      onChanged: (value) {

                                        final perfiles = int.tryParse(value) ?? 0;
                                        setState(() => _showTipoCuentaWarning = perfiles > 1);
                                      },
                                    ),
                                    const SizedBox(height: 15),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Costo Compra', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                        const SizedBox(height: 5),
                                        TextFormField(
                                          controller: _costoCompraController,
                                          style: const TextStyle(color: Colors.white),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color.fromARGB(255, 0, 0, 0),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'El costo de compra es requerido';
                                            }
                                            final double? costo = double.tryParse(value);
                                            if (costo == null) {
                                              return 'Ingrese un valor numérico válido';
                                            }
                                            if (costo <= 0) {
                                              return 'El costo debe ser mayor a 0';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 15),
                                      ],
                                    ),
                                    Text('Fecha de Inicio', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                    const SizedBox(height: 5),
                                    TextFormField(controller: _fechaInicioController, readOnly: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: const Color.fromARGB(255, 0, 0, 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), onTap: () => _seleccionarFechaInicio(context), validator: (value) {if (value == null || value.isEmpty) return 'Seleccione una fecha'; return null;}),
                                    const SizedBox(height: 15),

                                    // --- Inicio del bloque de "Días de Servicio" modificado ---
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Días de Servicio', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                        const SizedBox(height: 5),
                                        TextFormField(
                                          controller: _diasServicioController,
                                          style: const TextStyle(color: Colors.white),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color.fromARGB(255, 0, 0, 0),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Este campo es requerido';
                                            }
                                            return null;
                                          },
                                        ),
                                        if (_showDiasServicioWarning) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.amber.shade600, width: 1),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade600, size: 20),
                                                const SizedBox(width: 10),
                                                const Expanded(
                                                  child: Text(
                                                    'Valor es 0. La fecha final será igual a la de inicio.',
                                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                                    softWrap: true,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 15),
                                      ],
                                    ),
                                    // --- Fin del bloque modificado ---
                                    
                                    Text('Fecha Final', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                    const SizedBox(height: 5),
                                    TextFormField(controller: _fechaFinalController, readOnly: true, style: const TextStyle(color: Colors.grey), decoration: InputDecoration(filled: true, fillColor: const Color.fromARGB(255, 0, 0, 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                                    const SizedBox(height: 15),
                                    _buildTextField(_notaController, 'Nota'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),

                          // Advertencia de "no se detectaron cambios"
                          if (_showNoChangesWarning)
                            Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                border: Border.all(color: Colors.orange, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'No se detectaron cambios para actualizar.',
                                      style: TextStyle(color: Colors.orange, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Error message display with red background
                          if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                border: Border.all(color: Colors.red, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          //BOTONES DE CANCELAR Y GUARDAR------------------------------------------------
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Botón de Cancelar (Negro con letras blancas)
                              TextButton(
                                onPressed: _isSaving ? null : () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white, // Color del texto
                                  backgroundColor: Colors.black, // Color de fondo
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0), // Bordes redondeados
                                  ),
                                ),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 10),
                              // Botón de Guardar/Actualizar (Blanco con letras negras)
                              ElevatedButton(
                                onPressed: _isSaving ? null : _saveCuenta,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black, // Color del texto (letras negras)
                                  backgroundColor: Colors.white, // Color de fondo (blanco)
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0), // Bordes redondeados del botón
                                    // No hay borde rojo en este caso
                                  ),
                                  elevation: 0, // Quita la sombra por defecto
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black, // Indicador negro para coincidir con el texto
                                        ))
                                    : Text(widget.cuenta == null ? 'Guardar' : 'Actualizar'),
                              ),
                            ],
                          ),
                          //FIN BOTONES DE CANCELAR Y GUARDAR------------------------------------------------
                        ],
                      ),
                    ),
                  ),
            ),
        ),
      ),
    );
  }

  // Campo de entrada común
  Widget _buildAutocompleteField(
    TextEditingController controller,
    FocusNode focusNode,
    String label,
    bool readOnly,
    bool isEmpty,
  ) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
        filled: true,
        fillColor: readOnly
            ? Colors.black.withOpacity(0.2)
            : const Color.fromARGB(255, 11, 11, 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintText: label,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
      readOnly: readOnly,
      validator: (_) => isEmpty ? 'Seleccione $label' : null,
    );
  }

// Campo de solo lectura para mostrar datos de la cuenta
Widget _buildReadOnlyField(String label, TextEditingController controller) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8))),
      const SizedBox(height: 5),
      TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.black.withOpacity(0.2), // Fondo más oscuro para indicar que está bloqueado
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    ],
  );
}

Widget _buildWhiteOptionsWidth<T>(
  Iterable<T> options,
  ValueChanged<T> onSelected,
  double fieldWidth,
) =>
    Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.black.withOpacity(0.15)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 200,
            maxWidth: fieldWidth,
          ),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _getDisplayText(option),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

  String _getDisplayText(dynamic option) {
    if (option is String) {
      return option;
    } else if (option is Plataforma) {
      return option.nombre;
    } else if (option is TipoCuenta) {
      return option.nombre;
    } else if (option is Proveedor) {
      return option.nombre;
    } else {
      return option.toString();
    }
  }
}
