// lib/presentation/widgets/modals/cuenta_renovar_modal.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/cuenta_model.dart';
import '../../../domain/models/plataforma_model.dart';
import '../../../domain/models/proveedor_model.dart';
import '../../../domain/models/tipo_cuenta_model.dart';
import '../../../infrastructure/repositories/tipo_cuenta_repository.dart'; // Importar para cargar tipos de cuenta
import '../dialogs/dialogo_confirma_renovar.dart'; // Importar el diálogo de confirmación

class RenovarCuentaModal extends StatefulWidget {
  final Cuenta cuenta;
  final Future<Cuenta?> Function(Cuenta) onRenew;
  const RenovarCuentaModal({
    super.key,
    required this.cuenta,
    required this.onRenew,
  });
  @override
  State<RenovarCuentaModal> createState() => _RenovarCuentaModalState();
}

class _RenovarCuentaModalState extends State<RenovarCuentaModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _duracionRenovacionController;
  late TextEditingController _fechaInicioController;
  late TextEditingController _fechaFinalController;
  late TextEditingController _correoController;
  late TextEditingController _plataformaController; // Sigue siendo de solo lectura
  late TextEditingController _proveedorController; // Sigue siendo de solo lectura
  late TextEditingController _numPerfilesController;
  late TextEditingController _notaController;
  late TextEditingController _contrasenaController;
  late TextEditingController _proveedorContactoController; // Sigue siendo de solo lectura
  late TextEditingController _costoCompraController;
  DateTime? _fechaInicioSeleccionada;
  DateTime? _fechaFinalCalculada;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showDiasServicioWarning = false;
  // --- Nuevas variables para el desplegable de Tipo de Cuenta ---
  TipoCuenta? _selectedTipoCuenta;
  List<TipoCuenta> _tiposCuenta = [];
  // -------------------------------------------------------------
  final DateFormat _displayDateFormat = DateFormat('dd-MM-yyyy');
  final DateFormat _dbDateFormat = DateFormat('yyyy-MM-dd');
  
  @override
  void initState() {
    super.initState();
    _initializeControllers(); // Inicializa controladores
    _loadDropdownData();     // Carga datos para desplegables (TipoCuenta)
  }
  
  void _initializeControllers() {
    // --- INICIO DE LA MODIFICACIÓN ---
    // Simplemente establece el valor por defecto a '30' sin condiciones.
    _duracionRenovacionController = TextEditingController(text: '30');
    // --- FIN DE LA MODIFICACIÓN ---
    DateTime fechaInicioParaRenovacion = DateTime.now();
    if (widget.cuenta.fechaFinal != null && widget.cuenta.fechaFinal!.isNotEmpty) {
      try {
        final fechaFinalGuardada = _dbDateFormat.parse(widget.cuenta.fechaFinal!);
        final DateTime hoy = DateTime.now();
        // La fecha de inicio de la renovación sigue siendo la fecha final de la cuenta si es futura,
        // o la fecha de hoy si ya expiró. Esto es correcto y no lo cambiamos.
        if (fechaFinalGuardada.isAfter(hoy)) {
          fechaInicioParaRenovacion = fechaFinalGuardada;
        }
      } catch (e) {
        // Usar fecha actual si hay error
      }
    }
    
    _fechaInicioSeleccionada = fechaInicioParaRenovacion;
    _fechaInicioController = TextEditingController(text: _displayDateFormat.format(_fechaInicioSeleccionada!));
    _fechaFinalController = TextEditingController();
    _calcularFechaFinal();
    // El resto de la inicialización de controladores permanece igual.
    _correoController = TextEditingController(text: widget.cuenta.correo);
    _plataformaController = TextEditingController(text: widget.cuenta.plataforma.nombre);
    _proveedorController = TextEditingController(text: widget.cuenta.proveedor.nombre);
    _numPerfilesController = TextEditingController(text: widget.cuenta.numPerfiles.toString());
    _notaController = TextEditingController(text: widget.cuenta.nota ?? '');
    _contrasenaController = TextEditingController(text: widget.cuenta.contrasena);
    _proveedorContactoController = TextEditingController(text: widget.cuenta.proveedor.contacto ?? '');
    _costoCompraController = TextEditingController(text: widget.cuenta.costoCompra?.toStringAsFixed(2) ?? '');
  }
  
  // --- Método para cargar datos de desplegables ---
  Future<void> _loadDropdownData() async {
    setState(() {
      _isLoading = true; // Iniciar carga
    });
    try {
      final tipoCuentaRepo = TipoCuentaRepository();
      final results = await tipoCuentaRepo.getTiposCuenta(page: 1, perPage: 1000);
      if (mounted) {
        setState(() {
          _tiposCuenta = results;
          // Seleccionar el tipo de cuenta que tiene la cuenta actual
          _selectedTipoCuenta = _tiposCuenta.firstWhereOrNull(
            (tc) => tc.id == widget.cuenta.tipoCuenta.id,
          );
          _isLoading = false; // Finalizar carga
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error cargando tipos de cuenta: $e";
          _isLoading = false;
        });
      }
    }
  }
  // -------------------------------------------------
  
  void _calcularFechaFinal() {
    final dias = int.tryParse(_duracionRenovacionController.text);
    setState(() {
      _showDiasServicioWarning = (dias != null && dias == 0);
      if (dias != null && dias >= 0 && _fechaInicioSeleccionada != null) {
        final fechaFinalCalculada = _fechaInicioSeleccionada!.add(Duration(days: dias));
        _fechaFinalCalculada = fechaFinalCalculada;
        _fechaFinalController.text = _displayDateFormat.format(fechaFinalCalculada);
      } else {
        _fechaFinalCalculada = null;
        _fechaFinalController.text = '';
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
  
  Future<void> _handleRenew() async {
    final int perfilesVendidos = widget.cuenta.numPerfiles - widget.cuenta.perfilesDisponibles;
    final String numPerfilesText = _numPerfilesController.text.trim();
    if (numPerfilesText.isEmpty) {
      setState(() { _errorMessage = 'El número de perfiles es requerido.'; });
      return;
    }
    final int? nuevosPerfilesTotales = int.tryParse(numPerfilesText);
    if (nuevosPerfilesTotales == null || nuevosPerfilesTotales < 0) {
  setState(() { _errorMessage = 'El número de perfiles debe ser 0 o un número positivo.'; });
  return;
}
    if (nuevosPerfilesTotales < perfilesVendidos) {
      setState(() { _errorMessage = 'No puedes asignar menos perfiles en total ($nuevosPerfilesTotales) de los que ya están vendidos ($perfilesVendidos).'; });
      return;
    }
    // Validar el formulario completo después de las validaciones específicas de perfiles
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }
    // *** LÓGICA DE CONFIRMACIÓN AGREGADA ***
    // Crear lista de cambios para mostrar en el diálogo de confirmación
    final List<CambioDetalle> cambios = [];
    final Cuenta original = widget.cuenta;
    // Comparar campos que pueden cambiar
    final nuevoCorreo = _correoController.text.trim();
    final nuevaContrasena = _contrasenaController.text.trim();
    final nuevoNumPerfiles = nuevosPerfilesTotales;
    final nuevoCosto = double.tryParse(_costoCompraController.text) ?? 0.0;
    final nuevaNota = _notaController.text.trim();
    final nuevoTipoCuenta = _selectedTipoCuenta!;
    
    // Fechas
    final nuevaFechaInicio = _fechaInicioSeleccionada != null ? _dbDateFormat.format(_fechaInicioSeleccionada!) : null;
    final nuevaFechaFinal = _fechaFinalCalculada != null ? _dbDateFormat.format(_fechaFinalCalculada!) : null;
    // Comparar cambios
    if (original.correo != nuevoCorreo) {
      cambios.add(CambioDetalle(label: 'Correo', valorAnterior: original.correo, valorNuevo: nuevoCorreo));
    }
    if (original.contrasena != nuevaContrasena) {
      cambios.add(CambioDetalle(label: 'Contraseña', valorAnterior: original.contrasena, valorNuevo: nuevaContrasena));
    }
    if (original.numPerfiles != nuevoNumPerfiles) {
      cambios.add(CambioDetalle(label: 'Número de Perfiles', valorAnterior: original.numPerfiles.toString(), valorNuevo: nuevoNumPerfiles.toString()));
    }
    if (original.costoCompra != nuevoCosto) {
      cambios.add(CambioDetalle(label: 'Costo de Compra', valorAnterior: original.costoCompra?.toStringAsFixed(2) ?? '0.00', valorNuevo: nuevoCosto.toStringAsFixed(2)));
    }
    if ((original.nota ?? '') != nuevaNota) {
      cambios.add(CambioDetalle(label: 'Nota', valorAnterior: original.nota ?? '(vacío)', valorNuevo: nuevaNota.isEmpty ? '(vacío)' : nuevaNota));
    }
    if (original.tipoCuenta.id != nuevoTipoCuenta.id) {
      cambios.add(CambioDetalle(label: 'Tipo de Cuenta', valorAnterior: original.tipoCuenta.nombre, valorNuevo: nuevoTipoCuenta.nombre));
    }
    if (original.fechaInicio != nuevaFechaInicio) {
      cambios.add(CambioDetalle(label: 'Fecha de Inicio', valorAnterior: original.fechaInicio ?? '(no definida)', valorNuevo: nuevaFechaInicio ?? '(no definida)'));
    }
    if (original.fechaFinal != nuevaFechaFinal) {
      cambios.add(CambioDetalle(label: 'Fecha Final', valorAnterior: original.fechaFinal ?? '(no definida)', valorNuevo: nuevaFechaFinal ?? '(no definida)'));
    }
    // Mostrar diálogo de confirmación
    final confirmed = await DialogoConfirmaRenovar.show(
      context: context,
      title: 'Confirmar Renovación de Cuenta',
      cambios: cambios.isNotEmpty ? cambios : [CambioDetalle(label: 'Renovación', valorAnterior: 'Sin cambios específicos', valorNuevo: 'Se renueva la cuenta')],
    );
    
    if (!(confirmed ?? false)) {
      return; // Usuario canceló la operación
    }
    // *** FIN LÓGICA DE CONFIRMACIÓN ***
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      // 1. Registrar el pago/renovación en el historial
      final supabaseClient = Supabase.instance.client;
      final double? montoGastado = double.tryParse(_costoCompraController.text);
      if (montoGastado != null && _fechaInicioSeleccionada != null && _fechaFinalCalculada != null) {
        
        // ===== ESTE ES EL BLOQUE A CORREGIR =====
        await supabaseClient.from('historial_renovaciones_cuentas').insert({
          'cuenta_id': widget.cuenta.id,
          'fecha_gasto': _dbDateFormat.format(_fechaInicioSeleccionada!),
          'monto_gastado': montoGastado,
          'periodo_inicio': _dbDateFormat.format(_fechaInicioSeleccionada!),
          'periodo_fin': _dbDateFormat.format(_fechaFinalCalculada!),
          'tipo_registro': 'Renovacion',
          
          // --- AÑADE ESTOS CAMPOS PARA GUARDAR LA FOTO ---
          'proveedor_nombre_historico': widget.cuenta.proveedor.nombre,
          'proveedor_contacto_historico': widget.cuenta.proveedor.contacto,
          'cuenta_correo_historico': widget.cuenta.correo,
          'plataforma_nombre_historico': widget.cuenta.plataforma.nombre,
          // --- FIN DE LA MODIFICACIÓN ---
        });
        print('Historial de pago de renovación registrado correctamente.');
      } else {
        print('Advertencia: No se pudo registrar el historial de pago debido a datos faltantes.');
      }
    // *** FIN DE LA LÓGICA AGREGADA ***
      final int nuevosPerfilesDisponibles = nuevosPerfilesTotales - perfilesVendidos;
      final cuentaRenovada = widget.cuenta.copyWith(
        fechaInicio: _fechaInicioSeleccionada != null ? _dbDateFormat.format(_fechaInicioSeleccionada!) : null,
        fechaFinal: _fechaFinalCalculada != null ? _dbDateFormat.format(_fechaFinalCalculada!) : null,
        numPerfiles: nuevosPerfilesTotales,
        perfilesDisponibles: nuevosPerfilesDisponibles,
        correo: _correoController.text.trim(),
        contrasena: _contrasenaController.text.trim(),
        costoCompra: double.tryParse(_costoCompraController.text) ?? widget.cuenta.costoCompra,
        nota: _notaController.text.trim(),
        // Importante: el tipo de cuenta se actualiza con el valor seleccionado (_selectedTipoCuenta)
        tipoCuenta: _selectedTipoCuenta!,
      );
      final Cuenta? result = await widget.onRenew(cuentaRenovada);
      setState(() { _isLoading = false; });
      if (result != null) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error al renovar: ${e.toString().replaceFirst('Exception: ', '')}";
      });
    }
  }
  
  @override
  void dispose() {
    _duracionRenovacionController.dispose();
    _fechaInicioController.dispose();
    _fechaFinalController.dispose();
    _correoController.dispose();
    _plataformaController.dispose();
    _proveedorController.dispose();
    _numPerfilesController.dispose();
    _notaController.dispose();
    _contrasenaController.dispose();
    _proveedorContactoController.dispose();
    _costoCompraController.dispose();
    super.dispose();
  }
  
  Widget _buildReadOnlyTextField(TextEditingController controller, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(color: Colors.grey),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
  
  Widget _buildEditableTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters ?? (keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color.fromARGB(255, 15, 15, 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: validator,
          onChanged: onChanged,
          obscureText: obscureText,
        ),
        const SizedBox(height: 15),
      ],
    );
  }
  
  // Métodos auxiliares para el Autocomplete de Tipo de Cuenta
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
    } else if (option is TipoCuenta) {
      return option.nombre;
    } else {
      return option.toString();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            height: 700, // ← altura fija
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Renovar Cuenta',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 15.0),
                              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildReadOnlyTextField(_plataformaController, 'Plataforma'),
                                    // --- SECCIÓN DEL TIPO DE CUENTA REEMPLAZADA POR UN DESPLEGABLE ---
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Tipo de Cuenta', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                        const SizedBox(height: 5),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Autocomplete<TipoCuenta>(
                                              displayStringForOption: (TipoCuenta option) => option.nombre,
                                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                                // Sincronizar el texto con nuestro controlador
                                                controller.text = _selectedTipoCuenta?.nombre ?? '';
                                                
                                                return TextFormField(
                                                  controller: controller,
                                                  focusNode: focusNode,
                                                  style: const TextStyle(color: Colors.white),
                                                  decoration: InputDecoration(
                                                    suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
                                                    hintText: 'Tipo de Cuenta',
                                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                                  ),
                                                  validator: (_) => _selectedTipoCuenta == null ? 'Seleccione Tipo de Cuenta' : null,
                                                  onChanged: (value) {
                                                    // No actualizamos el _selectedTipoCuenta aquí, esperamos a que se seleccione una opción
                                                  },
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
                                        const SizedBox(height: 15),
                                      ],
                                    ),
                                    // -------------------------------------------------------------
                                    _buildReadOnlyTextField(_proveedorController, 'Proveedor'),
                                    _buildReadOnlyTextField(_proveedorContactoController, 'Número Proveedor'),
                                    _buildEditableTextField(
                                      _correoController,
                                      'Correo',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Campo obligatorio';
                                        }
                                        return null; // no validamos formato
                                      },
                                    ),
                                    _buildEditableTextField(_contrasenaController, 'Contraseña',
                                      // obscureText: true, // Si se desea ocultar, descomentar esta línea
                                      validator: (value) {
                                        if (value == null || value.isEmpty) { return 'Por favor, ingresa una contraseña.'; }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildEditableTextField(
                                      _numPerfilesController,
                                      'Perfiles',
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Este campo es requerido';
                                        final int? numValue = int.tryParse(value);
                                        if (numValue == null) return 'Número inválido';
    // ✅ CAMBIO: Permitir el 0 (Borramos la validación de <= 0)
    if (numValue < 0) return 'El número de perfiles no puede ser negativo';
    return null;
  },
                                      onChanged: (value) {

                                      },
                                    ),
                                    _buildEditableTextField(
                                      _costoCompraController,
                                      'Costo Compra',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Este campo es requerido';
                                        final double? costo = double.tryParse(value);
                                        if (costo == null || costo < 0) return 'Ingresa un costo válido';
                                        return null;
                                      },
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Fecha de Inicio (Renovación)', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                        const SizedBox(height: 5),
                                        TextFormField(
                                          controller: _fechaInicioController,
                                          readOnly: true,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color.fromARGB(255, 15, 15, 15),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                                            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
                                          onTap: () => _seleccionarFechaInicio(context),
                                          validator: (value) { if (value == null || value.isEmpty) return 'Seleccione una fecha'; return null; }
                                        ),
                                        const SizedBox(height: 15),
                                      ],
                                    ),
                                    _buildEditableTextField(
                                      _duracionRenovacionController,
                                      'Días de servicio',
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        _calcularFechaFinal();
                                      },
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Fecha Final (Renovación)', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                        const SizedBox(height: 5),
                                        TextFormField(
                                          controller: _fechaFinalController,
                                          readOnly: true,
                                          style: const TextStyle(color: Colors.grey),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.black.withOpacity(0.2),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
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
                                    _buildEditableTextField(_notaController, 'Nota'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Botón de Cancelar (Negro con letras blancas)
                              TextButton(
                                onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                              // Botón de Renovar (Blanco con letras negras, sin borde rojo)
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleRenew,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black, // Color del texto (letras negras)
                                  backgroundColor: Colors.white, // Color de fondo (blanco)
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0), // Bordes redondeados del botón
                                    // Eliminamos el side: const BorderSide(color: Colors.red, width: 1.0),
                                  ),
                                  elevation: 0, // Quita la sombra por defecto
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black, // El indicador también toma el color del texto (negro)
                                        ))
                                    : const Text('Renovar'),
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