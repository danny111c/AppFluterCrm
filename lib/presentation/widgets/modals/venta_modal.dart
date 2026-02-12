import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../presentation/widgets/dialogs/dialogo_confirma_actualizar.dart';

import 'package:collection/collection.dart';
import '../../../domain/models/cliente_model.dart';
import '../../../domain/models/cuenta_model.dart';
import '../../../domain/models/venta_model.dart';
import '../../../infrastructure/repositories/transacciones_repository.dart';
import '../../../infrastructure/repositories/cliente_repository.dart';
import '../../../infrastructure/repositories/venta_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/cuenta_provider.dart';

class VentaModal extends ConsumerStatefulWidget {
  final Venta? venta;
  final Cuenta cuentaInicial;
  final Future<bool> Function(Venta venta, String? perfilId) onSave;

  const VentaModal({
    super.key,
    this.venta,
    required this.cuentaInicial,
    required this.onSave,
  });

  @override
  ConsumerState<VentaModal> createState() => _VentaModalState();
}

class _VentaModalState extends ConsumerState<VentaModal> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _perfilesDisponibles = [];
  bool _cargandoPerfiles = false;
  String? _errorMessage;

  final _clienteRepo = ClienteRepository();
  final _transaccionesRepo = TransaccionesRepository();
  final _ventaRepo = VentaRepository();
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
  String? _perfilIdSeleccionado;

  DateTime? _fechaInicioSeleccionada;
  bool _showDiasServicioWarning = false;
  bool _showNoChangesWarning = false;

  final DateFormat _displayFormat = DateFormat('dd-MM-yyyy');
  final DateFormat _dbFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _initializeState();
    _diasController.addListener(_calcularFechaFinal);
    _loadInitialData();

    if (widget.cuentaInicial.numPerfiles > 0) {
      _cargarPerfilesDisponibles();
      if (widget.venta != null) {
        _obtenerIdPerfilActual();
      }
    }

    _perfilController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _obtenerIdPerfilActual() async {
    try {
      final todos = await _ventaRepo.getTodosLosPerfilesDeCuenta(widget.cuentaInicial.id!);
      final este = todos.firstWhereOrNull((p) =>
          p['nombre_perfil'].toString().trim().toLowerCase() ==
          widget.venta!.perfilAsignado?.trim().toLowerCase());

      if (este != null) {
        setState(() {
          _perfilIdSeleccionado = este['id'];
          print('✅ ID capturado: $_perfilIdSeleccionado');
        });
      }
    } catch (e) {
      print("Error obteniendo ID: $e");
    }
  }

  Future<void> _cargarPerfilesDisponibles() async {
    if (widget.venta != null) return;
    setState(() => _cargandoPerfiles = true);
    try {
      final perfiles = await _ventaRepo.getPerfilesDisponibles(widget.cuentaInicial.id!);
      setState(() {
        _perfilesDisponibles = perfiles;
        _cargandoPerfiles = false;
      });
    } catch (e) {
      setState(() => _cargandoPerfiles = false);
    }
  }

  void _initializeState() {
    final venta = widget.venta;

    if (venta != null && venta.fechaInicio.isNotEmpty) {
      try {
        _fechaInicioSeleccionada = _dbFormat.parse(venta.fechaInicio);
      } catch (e) {
        _fechaInicioSeleccionada = DateTime.now();
      }
    } else {
      _fechaInicioSeleccionada = DateTime.now();
    }

    String diasServicioInicial = '30';
    if (venta != null && venta.fechaFinal.isNotEmpty) {
      try {
        final DateTime fechaFinalGuardada = _dbFormat.parse(venta.fechaFinal);
        if (fechaFinalGuardada.isBefore(_fechaInicioSeleccionada!)) {
          diasServicioInicial = '0';
        } else {
          diasServicioInicial = fechaFinalGuardada
              .difference(_fechaInicioSeleccionada!)
              .inDays
              .toString();
        }
      } catch (e) {
        diasServicioInicial = '0';
      }
    }

    _nombreClienteController = TextEditingController(text: venta?.cliente.nombre ?? '');
    _contactoClienteController = TextEditingController(text: venta?.cliente.contacto ?? '');
    _perfilController = TextEditingController(text: venta?.perfilAsignado ?? '');
    _pinController = TextEditingController(text: venta?.pin ?? '');
    _precioController = TextEditingController(text: venta?.precio.toString() ?? '');
    _notaController = TextEditingController(text: venta?.nota ?? '');
    _diasController = TextEditingController(text: diasServicioInicial);
    _fechaInicioController = TextEditingController(text: _displayFormat.format(_fechaInicioSeleccionada!));
    _fechaFinalController = TextEditingController();

    _calcularFechaFinal();
  }

  Future<void> _loadInitialData() async {
    try {
      _listaClientes = await _clienteRepo.getClientes(perPage: 1000);
      if (mounted && widget.venta != null) {
        _clienteSeleccionado = _listaClientes.firstWhereOrNull((c) => c.id == widget.venta!.cliente.id);
        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error cargando clientes: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _calcularFechaFinal() {
    if (_fechaInicioSeleccionada == null) {
      setState(() => _fechaFinalController.text = '');
      return;
    }
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

  // ====================== FUNCIÓN PRINCIPAL DE GUARDADO ======================
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    final String nombrePerfil = _perfilController.text.trim().toLowerCase();
    final String correoMaestro = widget.cuentaInicial.correo.trim().toLowerCase();

    if (nombrePerfil == correoMaestro) {
      setState(() {
        _errorMessage = "No puedes usar el correo principal como perfil.";
      });
      return;
    }

    bool proceedWithSave = true;

    if (widget.venta != null) {
      final List<CambioDetalle> cambios = [];
      final Venta original = widget.venta!;

      final nuevoPerfil = _perfilController.text.trim();
      final nuevoPin = _pinController.text.trim();
      final nuevoPrecio = double.tryParse(_precioController.text);
      final nuevaFechaFinalStr = _fechaFinalController.text;
      final nuevaNota = _notaController.text.trim();

      if (original.perfilAsignado != nuevoPerfil) {
        cambios.add(CambioDetalle(label: 'Perfil', valorAnterior: original.perfilAsignado ?? '(vacío)', valorNuevo: nuevoPerfil));
      }
      if (original.pin != nuevoPin) {
        cambios.add(CambioDetalle(label: 'PIN', valorAnterior: original.pin ?? '(vacío)', valorNuevo: nuevoPin));
      }
      if (original.precio != nuevoPrecio) {
        cambios.add(CambioDetalle(label: 'Precio', valorAnterior: original.precio.toString(), valorNuevo: nuevoPrecio?.toString() ?? '0.0'));
      }
      if (_displayFormat.format(_dbFormat.parse(original.fechaFinal)) != nuevaFechaFinalStr) {
        cambios.add(CambioDetalle(label: 'Fecha Final', valorAnterior: _displayFormat.format(_dbFormat.parse(original.fechaFinal)), valorNuevo: nuevaFechaFinalStr));
      }
      if ((original.nota ?? '') != nuevaNota) {
        cambios.add(CambioDetalle(label: 'Nota', valorAnterior: original.nota ?? '(vacío)', valorNuevo: nuevaNota));
      }

      if (cambios.isNotEmpty) {
        final confirmed = await DialogoConfirmaActualizar.show(
          context: context,
          title: 'Confirmar Actualización de Venta',
          cambios: cambios,
        );
        proceedWithSave = confirmed ?? false;
      } else {
        setState(() => _showNoChangesWarning = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showNoChangesWarning = false);
        });
        return;
      }
    }

    if (proceedWithSave) {
      setState(() { _isSaving = true; _errorMessage = null; });
      try {
        Cliente clienteFinal;
        if (widget.venta != null) {
          clienteFinal = widget.venta!.cliente;
        } else {
          final nombre = _nombreClienteController.text.trim();
          final contacto = _contactoClienteController.text.trim();
          if (nombre.isEmpty || contacto.isEmpty) throw Exception('Nombre y contacto requeridos.');
          
          final existing = _listaClientes.firstWhereOrNull((c) => 
            c.nombre.toLowerCase() == nombre.toLowerCase() && c.contacto == contacto);
          
          if (existing != null) {
            clienteFinal = existing;
          } else {
            final Map<String, dynamic> result = await _clienteRepo.addCliente(Cliente(nombre: nombre, contacto: contacto));
            clienteFinal = result['cliente'] as Cliente;
          }
        }

        final venta = Venta(
          id: widget.venta?.id,
          cliente: clienteFinal,
          cuenta: widget.cuentaInicial,
          perfilId: _perfilIdSeleccionado,
          perfilAsignado: _perfilController.text.trim(),
          pin: _pinController.text.trim(),
          precio: double.tryParse(_precioController.text) ?? 0.0,
          fechaInicio: _dbFormat.format(_fechaInicioSeleccionada!),
          fechaFinal: _dbFormat.format(_displayFormat.parse(_fechaFinalController.text)),
          nota: _notaController.text.trim(),
          createdAt: widget.venta?.createdAt,
        );

        bool success = await widget.onSave(venta, _perfilIdSeleccionado);

        if (mounted) {
          if (success) {
            ref.read(cuentasProvider.notifier).refresh();
            Navigator.pop(context, true);
          } else {
            setState(() {
              _isSaving = false;
              _errorMessage = "Error al guardar la venta.";
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _diasController.removeListener(_calcularFechaFinal);
    _nombreClienteController.dispose();
    _contactoClienteController.dispose();
    _perfilController.dispose();
    _pinController.dispose();
    _precioController.dispose();
    _diasController.dispose();
    _notaController.dispose();
    _fechaInicioController.dispose();
    _fechaFinalController.dispose();
    super.dispose();
  }

  // ====================== MÉTODO BUILD LIMPIO ======================
  @override
  Widget build(BuildContext context) {
    final bool mostrarSeccionPerfiles = widget.cuentaInicial.numPerfiles > 0;
    final bool esEdicion = widget.venta != null;
    final bool habilitarPerfil = mostrarSeccionPerfiles;
    final bool habilitarPin = mostrarSeccionPerfiles;

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
                            esEdicion ? 'Editar Venta' : 'Vender Cuenta',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              color: Colors.red.withOpacity(0.1),
                              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            ),
                          
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    if (esEdicion) ...[
                                      _buildReadOnlyField('Nombre del Cliente', widget.venta?.cliente.nombre ?? 'N/A'),
                                      _buildReadOnlyField('Contacto del Cliente', widget.venta?.cliente.contacto ?? 'N/A'),
                                    ] else ...[
                                      _buildAutocompleteCliente(esEdicion),
                                    ],
                                    _buildReadOnlyField('Plataforma', widget.cuentaInicial.plataforma.nombre),
                                    _buildReadOnlyField('Tipo de Cuenta', widget.cuentaInicial.tipoCuenta.nombre),
                                    _buildReadOnlyField('Correo', widget.cuentaInicial.correo),
                                    _buildReadOnlyField('Contraseña', widget.cuentaInicial.contrasena),
                                    _buildTextField(_precioController, 'Precio', isRequired: true, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  children: [
                                    if (mostrarSeccionPerfiles) ...[
                                      _buildPerfilField(habilitarPerfil, esEdicion),
                                      if (_perfilController.text.trim().toLowerCase() == widget.cuentaInicial.correo.trim().toLowerCase())
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4, bottom: 10),
                                          child: Text(
                                            "⚠️ No puedes usar el correo principal como perfil.",
                                            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      _buildTextField(_pinController, 'PIN', isEnabled: habilitarPin),
                                    ],
                                    _buildDatePicker(),
                                    _buildDiasServicioField(),
                                    _buildReadOnlyField('Fecha Final', _fechaFinalController),
                                    _buildTextField(_notaController, 'Nota', maxLines: 5),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          
                          if (_showNoChangesWarning)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  border: Border.all(color: Colors.orangeAccent),
                                ),
                                child: const Text('No se detectaron cambios para actualizar', style: TextStyle(color: Colors.orangeAccent)),
                              ),
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _isSaving ? null : () => Navigator.pop(context),
                                style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black, padding: const EdgeInsets.all(20)),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _isSaving ? null : _handleSave,
                                style: ElevatedButton.styleFrom(foregroundColor: Colors.black, backgroundColor: Colors.white, padding: const EdgeInsets.all(20)),
                                child: _isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                    : Text(widget.venta == null ? 'Guardar Venta' : 'Actualizar'),
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

  // ====================== MÉTODOS DE CONSTRUCCIÓN DE WIDGETS ======================

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
          inputFormatters: keyboardType == TextInputType.number 
            ? [FilteringTextInputFormatter.digitsOnly] 
            : keyboardType == const TextInputType.numberWithOptions(decimal: true) 
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))] 
                : [],
          decoration: InputDecoration(
            filled: true,
            fillColor: isEnabled ? const Color.fromARGB(255, 15, 15, 15) : Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (value) => (isEnabled && isRequired && (value == null || value.isEmpty)) ? 'Este campo es requerido' : null,
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, dynamic value) {
    return _buildTextField(
      value is TextEditingController ? value : TextEditingController(text: value.toString()), 
      label, 
      isEnabled: false
    );
  }

  Widget _buildAutocompleteCliente(bool esEdicion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nombre del Cliente', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<Cliente>(
              displayStringForOption: (Cliente option) => option.nombre,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                 if (controller.text != _nombreClienteController.text) {
                   controller.text = _nombreClienteController.text;
                 }
                 return TextFormField(
                   controller: controller,
                   focusNode: focusNode,
                   enabled: !esEdicion,
                   style: const TextStyle(color: Colors.white),
                   decoration: const InputDecoration(
                     suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                     filled: true,
                     fillColor: Color.fromARGB(255, 15, 15, 15),
                     border: OutlineInputBorder(),
                     hintText: 'Nombre del cliente',
                     hintStyle: TextStyle(color: Colors.white60),
                   ),
                   onChanged: (val) => _nombreClienteController.text = val,
                 );
              },
              optionsBuilder: (textEditingValue) => textEditingValue.text.isEmpty 
                  ? _listaClientes 
                  : _listaClientes.where((c) => c.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase())),
              onSelected: (Cliente selection) {
                setState(() {
                  _clienteSeleccionado = selection;
                  _nombreClienteController.text = selection.nombre;
                  _contactoClienteController.text = selection.contacto;
                });
              },
              optionsViewBuilder: (context, onSelected, options) => _buildWhiteOptions<Cliente>(
                options, onSelected, constraints.maxWidth, (c) => c.nombre
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        // Campo de contacto
        Text('Contacto del Cliente', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<String>(
              displayStringForOption: (String option) => option,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (controller.text != _contactoClienteController.text) {
                   controller.text = _contactoClienteController.text;
                }
                return TextFormField(
                   controller: controller,
                   focusNode: focusNode,
                   enabled: !esEdicion,
                   style: const TextStyle(color: Colors.white),
                   keyboardType: TextInputType.phone,
                   decoration: const InputDecoration(
                     suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                     filled: true,
                     fillColor: Color.fromARGB(255, 15, 15, 15),
                     border: OutlineInputBorder(),
                     hintText: 'Contacto',
                     hintStyle: TextStyle(color: Colors.white60),
                   ),
                   onChanged: (val) => _contactoClienteController.text = val,
                );
              },
              optionsBuilder: (textEditingValue) {
                final contacts = _listaClientes.map((c) => c.contacto).toSet().toList();
                return textEditingValue.text.isEmpty ? contacts : contacts.where((s) => s.contains(textEditingValue.text));
              },
              onSelected: (String selection) {
                setState(() {
                  _contactoClienteController.text = selection;
                  final cliente = _listaClientes.firstWhereOrNull((c) => c.contacto == selection);
                  if (cliente != null) {
                    _clienteSeleccionado = cliente;
                    _nombreClienteController.text = cliente.nombre;
                  }
                });
              },
              optionsViewBuilder: (context, onSelected, options) => _buildWhiteOptions<String>(
                options, onSelected, constraints.maxWidth, (s) => s
              ),
            );
          },
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildPerfilField(bool habilitar, bool esEdicion) {
    if (esEdicion) {
      return _buildTextField(_perfilController, 'Perfil', isEnabled: habilitar);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seleccionar Perfil', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 5),
        _cargandoPerfiles 
          ? const LinearProgressIndicator() 
          : LayoutBuilder(
              builder: (context, constraints) {
                return RawAutocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => option['nombre_perfil'],
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    if (controller.text != _perfilController.text) {
                      controller.text = _perfilController.text;
                    }
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                        filled: true,
                        fillColor: Color.fromARGB(255, 15, 15, 15),
                        border: OutlineInputBorder(),
                        hintText: 'Seleccione un perfil',
                        hintStyle: TextStyle(color: Colors.white60),
                      ),
                      onTap: () {
                        if(!focusNode.hasFocus) focusNode.requestFocus();
                        controller.text = '${controller.text} '; // Truco para refrescar
                        WidgetsBinding.instance.addPostFrameCallback((_) => controller.text = controller.text.trim());
                      },
                    );
                  },
                  optionsBuilder: (textEditingValue) => _perfilesDisponibles,
                  onSelected: (selection) {
                    setState(() {
                      _perfilController.text = selection['nombre_perfil'];
                      _pinController.text = selection['pin'];
                      _perfilIdSeleccionado = selection['id'];
                    });
                  },
                  optionsViewBuilder: (context, onSelected, options) => _buildWhiteOptions<Map<String, dynamic>>(
                    options, onSelected, constraints.maxWidth, (p) => "${p['nombre_perfil']} (PIN: ${p['pin']})"
                  ),
                );
              },
            ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildWhiteOptions<T extends Object>(
      Iterable<T> options, 
      AutocompleteOnSelected<T> onSelected, 
      double width,
      String Function(T) labelBuilder) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 250, maxWidth: width),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final T option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    labelBuilder(option),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDiasServicioField() {
    return _buildTextField(
      _diasController, 
      'Días de Servicio', 
      keyboardType: TextInputType.number,
      isEnabled: true
    );
  }
  // ✅ Añade este método antes de que cierre la clase _VentaModalState
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fecha de Inicio', style: TextStyle(color: Colors.white.withOpacity(0.8))),
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
          validator: (value) => (value == null || value.isEmpty) ? 'La fecha es requerida' : null,
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}