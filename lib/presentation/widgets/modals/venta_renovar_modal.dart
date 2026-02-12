import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../presentation/widgets/dialogs/dialogo_confirma_renovar.dart';

import 'package:collection/collection.dart';
import '../../../domain/models/cliente_model.dart';
import '../../../domain/models/cuenta_model.dart';
import '../../../domain/models/venta_model.dart';
import '../../../infrastructure/repositories/cliente_repository.dart';
import '../../../infrastructure/repositories/transacciones_repository.dart';
import '../../../infrastructure/repositories/venta_repository.dart'; // ✅ IMPORTANTE


class VentaRenovarModal extends StatefulWidget {
  final Venta venta;
  final Cuenta cuentaInicial;
  // Cambiamos el nombre de la función para que refleja mejor la acción de renovar/actualizar
final Future<bool> Function(Venta venta, String? perfilId) onRenewOrUpdate;

  const VentaRenovarModal({
    super.key,
    required this.venta,
    required this.cuentaInicial,
    required this.onRenewOrUpdate, // Usamos el nuevo nombre aquí
  });

  @override
  State<VentaRenovarModal> createState() => _VentaRenovarModalState();
}

class _VentaRenovarModalState extends State<VentaRenovarModal> {
  final _transaccionesRepo = TransaccionesRepository();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false; // Usaremos este estado para el "Renovar"
  String? _errorMessage;
  String? _perfilIdSeleccionado; // ✅ AÑADIR ESTA

  final _clienteRepo = ClienteRepository();
  List<Cliente> _listaClientes = [];
  Cliente? _clienteSeleccionado;

  late TextEditingController _nombreClienteController;
  late TextEditingController _contactoClienteController;
  late TextEditingController _perfilController;
  late TextEditingController _pinController;
  late TextEditingController _precioController;
  late TextEditingController _diasController;
  late TextEditingController _notaController;
  late TextEditingController _fechaInicioController;
  late TextEditingController _fechaFinalController;
  late TextEditingController _contrasenaController; 
  
  DateTime? _fechaInicioSeleccionada;
  
  bool _showDiasServicioWarning = false;

  final DateFormat _displayFormat = DateFormat('dd-MM-yyyy');
  final DateFormat _dbFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    // ✅ NO LLAMES a _loadInitialData aquí. Lo haremos de otra forma.
    _initializeState();
    _diasController.addListener(_calcularFechaFinal);
    // ✅ LLAMA a la carga de datos DESPUÉS de que el primer frame se construya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
            _obtenerIdPerfilActual(); // ✅ LLAMAR AQUÍ

    });
      // ✅ AÑADE ESTO: Para que el aviso de error bajo el correo sea instantáneo
  _perfilController.addListener(() {
    if (mounted) setState(() {});
  });
  }
  // ✅ AÑADIR ESTA FUNCIÓN (Cópiala igual que la del VentaModal)
  Future<void> _obtenerIdPerfilActual() async {
    final _ventaRepo = VentaRepository(); // Necesitamos el repo aquí
    try {
      final todos = await _ventaRepo.getTodosLosPerfilesDeCuenta(widget.cuentaInicial.id!);
      final este = todos.firstWhereOrNull((p) => 
        p['nombre_perfil'].toString().trim().toLowerCase() == 
        widget.venta.perfilAsignado?.trim().toLowerCase()
      );

      if (este != null) {
        setState(() {
          _perfilIdSeleccionado = este['id'];
          print('✅ ID capturado para renovación: $_perfilIdSeleccionado');
        });
      }
    } catch (e) {
      print("Error obteniendo ID en renovación: $e");
    }
  }
void _initializeState() {
  final venta = widget.venta;
  
  try {
    final fechaFinalGuardada = _dbFormat.parse(venta.fechaFinal);
    final hoy = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _fechaInicioSeleccionada = fechaFinalGuardada.isBefore(hoy) ? hoy : fechaFinalGuardada;
  } catch (e) {
    _fechaInicioSeleccionada = DateTime.now();
  }
  
  // ✅ ¡CAMBIO CRUCIAL! AÑADIMOS LOS CONTROLADORES QUE FALTABAN
  _nombreClienteController = TextEditingController(text: venta.cliente.nombre);
  _contactoClienteController = TextEditingController(text: venta.cliente.contacto);
  _contrasenaController = TextEditingController(text: widget.cuentaInicial.contrasena); 

  _perfilController = TextEditingController(text: venta.perfilAsignado ?? '');
  _pinController = TextEditingController(text: venta.pin ?? '');
  _precioController = TextEditingController(text: venta.precio.toStringAsFixed(2));
  _notaController = TextEditingController(text: venta.nota ?? '');
  _diasController = TextEditingController(text: '30');
  _fechaInicioController = TextEditingController(text: _displayFormat.format(_fechaInicioSeleccionada!));
  _fechaFinalController = TextEditingController();

  _calcularFechaFinal();
}
  // ✅ CORREGIMOS EL MÉTODO DE CARGA PARA QUE SEA ROBUSTO
  Future<void> _loadInitialData() async {
    // Asegurarnos de que el estado de carga esté activo al empezar.
    if (mounted) setState(() => _isLoading = true);

    try {
      _listaClientes = await _clienteRepo.getClientes(perPage: 1000);
      if (mounted && widget.venta != null) {
        _clienteSeleccionado = _listaClientes.firstWhereOrNull(
          (c) => c.id == widget.venta.cliente.id
        );
        if (_clienteSeleccionado?.contacto.isNotEmpty == true) {
          // No necesitamos un setState aquí porque los controladores se inicializan
          // con los datos de widget.venta, lo cual es suficiente.
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error cargando clientes: $e";
        });
      }
    } finally {
      // ✅ ¡ESTA ES LA LÍNEA MÁS IMPORTANTE!
      // Se ejecuta SIEMPRE, tanto si hay éxito como si hay error.
      // Garantiza que el loader desaparezca.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _calcularFechaFinal() {
    if (_fechaInicioSeleccionada == null) return;
    final dias = int.tryParse(_diasController.text);
    setState(() {
      if (dias != null && dias >= 0) {
        final endDate = _fechaInicioSeleccionada!.add(Duration(days: dias));
        _fechaFinalController.text = _displayFormat.format(endDate);
        _showDiasServicioWarning = (dias == 0);
      } else {
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
    if (picked != null) {
      setState(() {
        _fechaInicioSeleccionada = picked;
        _fechaInicioController.text = _displayFormat.format(picked);
        _calcularFechaFinal();
      });
    }
  }

  // Este método ahora representa la acción de "Renovar"
// En venta_renovar_modal.dart

Future<void> _handleRenewOrUpdate() async {
  if (!_formKey.currentState!.validate() || _isSaving) return;
// ============================================================
    // ✅ VALIDACIÓN DE SEGURIDAD (AÑADIR AQUÍ)
    // ============================================================
    final String nombrePerfil = _perfilController.text.trim().toLowerCase();
    final String correoMaestro = widget.cuentaInicial.correo.trim().toLowerCase();

    if (nombrePerfil == correoMaestro) {
      setState(() {
        _errorMessage = "⚠️ ERROR: No puedes usar el correo principal como nombre de perfil.";
      });
      return; // Detiene la renovación
    }
    // ============================================================
  final List<CambioDetalle> cambios = [];
  final Venta original = widget.venta;

  final nuevoPerfil = _perfilController.text.trim();
  final nuevoPin = _pinController.text.trim();
  final nuevoPrecio = double.tryParse(_precioController.text);
  final nuevaFechaFinalStr = _fechaFinalController.text;
  final nuevaNota = _notaController.text.trim();

  // ✅ CORREGIDO: Comparamos con perfilAsignado
  if (original.perfilAsignado != nuevoPerfil) cambios.add(CambioDetalle(label: 'Perfil', valorAnterior: original.perfilAsignado ?? '(vacio)', valorNuevo: nuevoPerfil));
  if (original.pin != nuevoPin) cambios.add(CambioDetalle(label: 'PIN', valorAnterior: original.pin ?? '(vacio)', valorNuevo: nuevoPin));
  if (original.precio != nuevoPrecio) cambios.add(CambioDetalle(label: 'Precio', valorAnterior: original.precio.toStringAsFixed(2), valorNuevo: nuevoPrecio?.toStringAsFixed(2) ?? '0.00'));
  if (_displayFormat.format(_dbFormat.parse(original.fechaFinal)) != nuevaFechaFinalStr) cambios.add(CambioDetalle(label: 'Fecha Final', valorAnterior: _displayFormat.format(_dbFormat.parse(original.fechaFinal)), valorNuevo: nuevaFechaFinalStr));
  if ((original.nota ?? '') != nuevaNota) cambios.add(CambioDetalle(label: 'Nota', valorAnterior: original.nota ?? '(vacio)', valorNuevo: nuevaNota));

  final confirmed = await DialogoConfirmaRenovar.show(
    context: context,
    title: 'Confirmar Renovación',
    cambios: cambios.isNotEmpty ? cambios : [CambioDetalle(label: 'Renovación', valorAnterior: 'Extender Servicio', valorNuevo: 'Confirmar')],
  );
  if (confirmed != true) return;

  setState(() { _isSaving = true; _errorMessage = null; });

  try {
final ventaActualizada = Venta(
  id: widget.venta.id,
  cliente: widget.venta.cliente,
  cuenta: widget.cuentaInicial,
  perfilAsignado: _perfilController.text.trim(), // Captura el nombre del TextField
  pin: _pinController.text.trim(), // Captura el PIN del TextField
  precio: double.tryParse(_precioController.text) ?? 0.0,
  fechaInicio: _dbFormat.format(_fechaInicioSeleccionada!),
  fechaFinal: _dbFormat.format(_displayFormat.parse(_fechaFinalController.text)),
  nota: _notaController.text.trim(),
  createdAt: widget.venta.createdAt,
);

final success = await widget.onRenewOrUpdate(ventaActualizada, _perfilIdSeleccionado);
    if (success) {
      await _transaccionesRepo.addHistorialVenta(
        ventaId: widget.venta.id!,
        cliente: ventaActualizada.cliente,
        cuenta: widget.cuentaInicial,
        monto: ventaActualizada.precio,
        tipo: 'Renovacion',
        fechaInicio: DateTime.parse(ventaActualizada.fechaInicio),
        fechaFin: DateTime.parse(ventaActualizada.fechaFinal),
        // ✅ CORREGIDO: Pasamos perfilAsignado
        perfil: ventaActualizada.perfilAsignado,
      );
      if(mounted) Navigator.pop(context, true);
    } else {
      if(mounted) setState(() => _errorMessage = 'No se pudo guardar la renovación.');
    }
  } catch (e) {
    if (mounted) setState(() => _errorMessage = e.toString());
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}

  @override
  void dispose() {
    _nombreClienteController.dispose();
    _contactoClienteController.dispose();
    _perfilController.dispose();
    _pinController.dispose();
    _precioController.dispose();
    _diasController.dispose();
    _notaController.dispose();
    _fechaInicioController.dispose();
    _fechaFinalController.dispose();
    _contrasenaController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool esCuentaCompartida = widget.cuentaInicial.numPerfiles > 1;
    // Verificamos si la venta que estamos renovando ya tenía estos datos
    final bool tienePerfilPrevio = widget.venta.perfilAsignado != null && widget.venta.perfilAsignado!.trim().isNotEmpty;
    final bool tienePinPrevio = widget.venta.pin != null && widget.venta.pin!.trim().isNotEmpty;
  final bool habilitarCamposDePerfil = widget.cuentaInicial.numPerfiles > 0;

    // Lógica final: Se habilita si es compartida O si ya tenía datos previos
  final bool habilitarPerfil = habilitarCamposDePerfil; 
  final bool habilitarPin = habilitarCamposDePerfil;
  
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
                  height: 800,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
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
                            // Cambiamos el título para reflejar la acción de renovar
                            'Renovar Venta',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                                    // Como solo se renueva, el cliente es fijo. Lo mostramos como solo lectura.
                                    _buildReadOnlyField('Cliente', widget.venta!.cliente.nombre),
                                    _buildContactoClienteField(),
                                    _buildReadOnlyField('Plataforma', widget.cuentaInicial.plataforma.nombre),
                                    _buildReadOnlyField('Tipo de Cuenta', widget.cuentaInicial.tipoCuenta.nombre),
_buildReadOnlyField('Correo', widget.cuentaInicial.correo),
                                   _buildContrasenaField(), 
                                    _buildTextField(_precioController, 'Precio', isRequired: true, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  children: [
_buildTextField(_perfilController, 'Perfil', isEnabled: habilitarPerfil),
// ✅ AVISO DE SEGURIDAD DEBAJO DEL PERFIL
if (_perfilController.text.trim().toLowerCase() == widget.cuentaInicial.correo.trim().toLowerCase())
  const Padding(
    padding: EdgeInsets.only(top: 4, bottom: 10),
    child: Text(
      "⚠️ No puedes usar el correo principal como perfil.",
      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  ),  _buildTextField(_pinController, 'PIN', isEnabled: habilitarPin),
  
                                    _buildDatePicker(), // Permite cambiar la fecha de inicio
                                    _buildDiasServicioField(), // Permite definir cuántos días se renueva
                                    _buildReadOnlyField('Fecha Final (Renovacion)', _fechaFinalController),
                                    _buildTextField(_notaController, 'Nota', maxLines: 5),
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
                              // Botón de Renovar (Blanco con letras negras)
ElevatedButton(
  // ✅ CORREGIDO: La lógica async se mueve a _handleRenewOrUpdate
  onPressed: _isSaving ? null : _handleRenewOrUpdate,
  style: ElevatedButton.styleFrom(
    foregroundColor: Colors.black,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
  child: _isSaving
      ? const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
        )
      : const Text('Renovar'),
)
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

  Widget _buildTextField(TextEditingController controller, String label, {bool isRequired = false, TextInputType? keyboardType, int maxLines = 1, bool isEnabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(isEnabled ? 0.8 : 0.4))),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          enabled: isEnabled,
          maxLines: maxLines,
          style: TextStyle(color: isEnabled ? Colors.white : Colors.grey),
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : 
                            (keyboardType == const TextInputType.numberWithOptions(decimal: true) ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : []), // Para decimales en precio
          decoration: InputDecoration(
            filled: true,
            fillColor: isEnabled ? const Color.fromARGB(255, 15, 15, 15) : Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (isEnabled && isRequired && (value == null || value.isEmpty)) {
              return 'Este campo es requerido';
            }
            if (keyboardType == const TextInputType.numberWithOptions(decimal: true) && value != null && value.isNotEmpty) {
              if (double.tryParse(value) == null) {
                return 'Ingresa un número válido';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, dynamic value) {
    // Permite pasar un controller o un valor directo.
    final controller = value is TextEditingController ? value : TextEditingController(text: value.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4))),
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

  Widget _buildContrasenaField() {
    print('[DEBUG PASSWORD] Building password field with: ${_contrasenaController.text}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contraseña', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          controller: _contrasenaController,
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

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fecha de Inicio (Renovacion) ', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          controller: _fechaInicioController,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color.fromARGB(255, 15, 15, 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onTap: () => _seleccionarFechaInicio(context),
          validator: (value) => (value == null || value.isEmpty) ? 'La fecha de inicio es requerida' : null,
        ),
        const SizedBox(height: 15),
      ],
    );
  }
  
  // Este widget no se usa en VentaRenovarModal porque el cliente es fijo.
  // Lo dejamos comentado por si se quiere referenciar en el futuro.
  /*
  Widget _buildAutocompleteCliente() {
    final bool isEditing = widget.venta != null;
    if (isEditing) {
      return _buildReadOnlyField('Cliente', _nombreClienteController);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nombre del Cliente', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        Autocomplete<Cliente>(
          displayStringForOption: (Cliente option) => option.nombre,
          fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
             if (_nombreClienteController.text != fieldController.text) {
               fieldController.text = _nombreClienteController.text;
             }
             return TextFormField(
               controller: fieldController,
               focusNode: focusNode,
               style: const TextStyle(color: Colors.white),
               decoration: InputDecoration(
                 filled: true,
                 fillColor: const Color.fromARGB(255, 15, 15, 15),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
               ),
               validator: (value) => (value == null || value.isEmpty) ? 'Este campo es requerido' : null,
               onChanged: (text) => _nombreClienteController.text = text,
             );
          },
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return _listaClientes;
            return _listaClientes.where((Cliente option) =>
                option.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (Cliente selection) {
            setState(() {
              _clienteSeleccionado = selection;
              _nombreClienteController.text = selection.nombre;
              _contactoClienteController.text = selection.contacto;
            });
          },
          optionsViewBuilder: (context, onSelected, options) {
              return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                      elevation: 4.0,
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.white.withOpacity(0.2))),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 375),
                          child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                  final Cliente option = options.elementAt(index);
                                  return InkWell(
                                      onTap: () => onSelected(option),
                                      child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(option.nombre, style: const TextStyle(color: Colors.white)),
                                      ),
                                  );
                              },
                          ),
                      ),
                  ),
              );
          },
        ),
        const SizedBox(height: 15),
      ],
    );
  }
  */
  
  Widget _buildContactoClienteField() {
    final contacto = _contactoClienteController.text.trim();
    final isEmpty = contacto.isEmpty;
    print('[DEBUG] Contacto cliente en UI: "$contacto" | Vacío: $isEmpty'); // Verificar valor en UI
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Contacto Cliente', style: TextStyle(color: Colors.white.withOpacity(0.4))),
            if (isEmpty) ...[
              const SizedBox(width: 8),
              Icon(Icons.error, color: Colors.red.shade400, size: 16),
            ],
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: _contactoClienteController,
          readOnly: true,
          style: TextStyle(color: isEmpty ? Colors.red.shade300 : Colors.grey),
          decoration: InputDecoration(
            filled: true,
            fillColor: isEmpty ? Colors.red.withOpacity(0.1) : Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), 
              borderSide: isEmpty ? BorderSide(color: Colors.red.shade400, width: 1) : BorderSide.none
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        if (isEmpty) ...[
          const SizedBox(height: 5),
          Text(
            'El contacto del cliente es requerido para renovar.',
            style: TextStyle(color: Colors.red.shade300, fontSize: 12),
          ),
        ],
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildDiasServicioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Días de Servicio', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          controller: _diasController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color.fromARGB(255, 15, 15, 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es requerido';
            }
            if (int.tryParse(value)! < 0) { // Validar que no sea negativo
              return 'Los días no pueden ser negativos';
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
    );
  }
}