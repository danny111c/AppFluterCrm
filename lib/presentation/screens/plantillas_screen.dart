// lib/presentation/screens/plantillas_screen.dart (VERSION CON VARIABLES SÓLO EN CONTENIDO Y MEJOR GESTIÓN DE FOCO)

import 'package:flutter/material.dart';
import '../../domain/models/plantilla_model.dart';
//import '../../infrastructure/repositories/plantilla_repository.dart';
import '../widgets/buttons/add_button.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/notifications/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <--- ¡AÑADE ESTA LÍNEA!
import '../../domain/providers/plantilla_provider.dart'; // Importamos el nuevo provider


// 1. Convertimos a ConsumerStatefulWidget
class PlantillasScreen extends ConsumerStatefulWidget {
  const PlantillasScreen({super.key});

  @override
  ConsumerState<PlantillasScreen> createState() => _PlantillasScreenState();
}

class _PlantillasScreenState extends ConsumerState<PlantillasScreen> {
  // 2. Estado local reducido al mínimo
  bool _mostrandoPlantillasCliente = false;
  String? _idPlantillaActiva;
  TextEditingController? _controladorActivo;
  bool _isContentFieldActive = false;
  final FocusScopeNode _rootFocusNode = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    // No necesitamos cargar plantillas aquí, el provider lo hace solo.
    _rootFocusNode.addListener(_onRootFocusChange);
  }

  @override
  void dispose() {
    _rootFocusNode.removeListener(_onRootFocusChange);
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _onRootFocusChange() {
    if (!_rootFocusNode.hasFocus && _idPlantillaActiva != null) {
      setState(() => _idPlantillaActiva = null);
    }
  }

  // 3. Métodos ahora interactúan con el Provider
Future<void> _guardarCambios(Plantilla plantilla, TextEditingController nombreController, TextEditingController contenidoController, List<String> visibilidad) async {   // Usamos copyWith para crear una nueva instancia inmutable
  final updatedPlantilla = plantilla.copyWith(
    nombre: nombreController.text.trim(),
    contenido: contenidoController.text,
        visibilidad: visibilidad, // ✅ ASIGNADO AQUÍ

  );

  if (updatedPlantilla.nombre.isEmpty) {
    NotificationService.showCustomWarning(context, 'El nombre de la plantilla no puede estar vacío');
    return;
  }

  try {
    final notifier = ref.read(plantillasProvider.notifier);
    if (updatedPlantilla.id == null || updatedPlantilla.id!.startsWith('temp_')) {
      await notifier.addPlantilla(updatedPlantilla);
      // ✅ NOTIFICACIÓN DE AGREGADO
      if (mounted) NotificationService.showAdded(context, 'Plantilla');
    } else {
      await notifier.updatePlantilla(updatedPlantilla);
      // ✅ NOTIFICACIÓN DE ACTUALIZADO
      if (mounted) NotificationService.showUpdated(context, 'Plantilla');
    }
    FocusScope.of(context).unfocus();
    setState(() => _idPlantillaActiva = null);
  } catch (e) {
    if (mounted) NotificationService.showCustomError(context, 'Error al guardar: ${e.toString()}');
  }
}

  void _crearNuevaPlantilla() {
    final tipo = _mostrandoPlantillasCliente ? 'cliente' : 'proveedor';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final newPlantilla = Plantilla(id: tempId, nombre: '', contenido: '', tipo: tipo);

    final notifier = ref.read(plantillasProvider.notifier);
    final currentPlantillas = notifier.state.plantillas;
    notifier.state = notifier.state.copyWith(plantillas: [newPlantilla, ...currentPlantillas]);
    setState(() => _idPlantillaActiva = newPlantilla.id);
  }

  Future<void> _eliminarPlantilla(Plantilla plantilla) async {
    // Si la plantilla es temporal, solo la quitamos del estado local.
    if (plantilla.id != null && plantilla.id!.startsWith('temp_')) {
      final notifier = ref.read(plantillasProvider.notifier);
      notifier.state = notifier.state.copyWith(
        plantillas: notifier.state.plantillas.where((p) => p.id != plantilla.id).toList(),
      );
      return;
    }

    final confirmado = await ConfirmDialog.show(
      context: context,
      title: 'Eliminar Plantilla',
      message: '¿Estás seguro de eliminar la plantilla "${plantilla.nombre}"?',
      confirmText: 'Eliminar',
    );
  if (confirmado == true && plantilla.id != null) {
    try {
      await ref.read(plantillasProvider.notifier).deletePlantilla(plantilla.id!);
      // ✅ NOTIFICACIÓN DE ELIMINADO (Icono basura roja)
      if (mounted) NotificationService.showDeleted(context, 'Plantilla');
    } catch (e) {
      if (mounted) NotificationService.showCustomError(context, 'Error al eliminar: ${e.toString()}');
    }
  }
}
  
  void _handlePlantillaFocus(String? activePlantillaId, TextEditingController activeController, bool isContentField) {
    setState(() {
      _idPlantillaActiva = activePlantillaId;
      _controladorActivo = activeController;
      _isContentFieldActive = isContentField;
    });
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    // 4. Observamos el provider
    final plantillasState = ref.watch(plantillasProvider);
    
    // Filtramos las plantillas en el momento del build
    final List<Plantilla> plantillasActuales = plantillasState.plantillas
        .where((p) => p.tipo == (_mostrandoPlantillasCliente ? 'cliente' : 'proveedor'))
        .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.0,
        title: Container(
          padding: const EdgeInsets.only(top: 20),
          child: const Text('Plantillas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 31)),
        ),
        actions: [
          AddButton(
            onPressed: _crearNuevaPlantilla,
            tooltip: 'Crear nueva plantilla',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: FocusScope(
          node: _rootFocusNode,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        _mostrandoPlantillasCliente = false;
                        _idPlantillaActiva = null;
                        _controladorActivo = null;
                        _isContentFieldActive = false; // Resetea
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
  color: !_mostrandoPlantillasCliente ? Colors.white : const Color(0xFF111111), // Blanco si activo, Negro si no
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: const Color.fromARGB(255, 35, 35, 35), width: 0.5),
),
                        child: Text(
                          'Proveedores',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_mostrandoPlantillasCliente ? Colors.black : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => setState(() {
                        _mostrandoPlantillasCliente = true;
                        _idPlantillaActiva = null;
                        _controladorActivo = null;
                        _isContentFieldActive = false; // Resetea
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
  color: _mostrandoPlantillasCliente ? Colors.white : const Color(0xFF111111), // Blanco si activo, Negro si no
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: const Color.fromARGB(255, 35, 35, 35), width: 0.5),
),
                        child: Text(
                          'Clientes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _mostrandoPlantillasCliente ? Colors.black : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: plantillasState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder( // Usamos ListView.builder para mejor rendimiento
                        itemCount: plantillasActuales.length,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemBuilder: (context, index) {
                          final plantilla = plantillasActuales[index];
                          final bool isActive = _idPlantillaActiva == plantilla.id;
                          final Widget? seccionVariablesWidget = (isActive && _isContentFieldActive)
                              ? _buildSeccionVariables(_mostrandoPlantillasCliente)
                              : null;

                          return PlantillaCard(
                            key: ValueKey(plantilla.id),
                            plantilla: plantilla,
                            esActiva: isActive,
                            onFocus: _handlePlantillaFocus,
                            onSave: _guardarCambios,
                            onDelete: _eliminarPlantilla,
                            variablesSection: seccionVariablesWidget,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionVariables(bool esParaCliente) {
    // Variables para el contexto del PROVEEDOR
    final Map<String, String> variablesProveedor = {
      'Plataforma': '[plataforma]',
      'Correo': '[correo]',
      'Contraseña': '[contrasena]',
      'Proveedor': '[proveedor]',
      'Fecha Final': '[fecha_final]',
      'Problema Cuenta': '[problema_cuenta]',
      'Fecha Reporte Problema': '[fecha_reporte_cuenta]',
    };

    // --- INICIO DE LA MODIFICACIÓN ---
    // Versión corregida y limpia del mapa de variables para CLIENTE
final Map<String, String> variablesCliente = {
      // Datos del Cliente
      'Nombre Cliente': '[nombre_cliente]',

      // Datos de la Cuenta (la misma que la del proveedor)
      'Plataforma': '[plataforma]',
      'Cuenta': '[cuenta]',
      'Contraseña': '[contrasena]',
      'Perfil': '[perfil]',
      'PIN': '[pin_perfil]',
      'Fecha Inicio': '[fecha_inicio]',
      'Fecha Final': '[fecha_final]',

      // variable servicio activos para la plantilla
  'Resumen de Servicios': '[resumen_servicios]', // <--- ESTA ES LA CLAVE

      // Datos de Problemas (Aquí está el cambio)
      'Problema Venta (Individual)': '[problema_venta]',
      'Fecha Reporte Venta': '[fecha_reporte_venta]',
      'Problema Cuenta (General)': '[problema_cuenta]', // <-- VARIABLE AÑADIDA
      'Fecha Reporte Cuenta': '[fecha_reporte_cuenta]', // <-- VARIABLE AÑADIDA
    };
    // --- FIN DE LA MODIFICACIÓN ---

    final Map<String, String> variablesAMostrar = esParaCliente
        ? variablesCliente
        : variablesProveedor;
    // --- AÑADE ESTAS DOS LÍNEAS AQUÍ ---
    print("--- DEBUG SECCIÓN VARIABLES ---");
    print("Mostrando para cliente: $esParaCliente. Claves a mostrar: ${variablesAMostrar.keys.toList()}");
    // --- FIN DE LAS LÍNEAS A AÑADIR ---
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insertar Variable:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: variablesAMostrar.entries.map((entry) {
              return GestureDetector(
                onTap: () {
                  if (!_isContentFieldActive) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Las variables solo pueden insertarse en el campo de contenido.'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  if (_controladorActivo == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error: No se detectó un campo de texto activo para insertar la variable.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  _insertarVariable(entry.value);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(entry.key, style: const TextStyle(color: Colors.white)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _insertarVariable(String variable) {
    if (_controladorActivo == null) {
      print("DEBUG: _controladorActivo is null in _insertarVariable. This should not happen if previous check passed.");
      return;
    }

    final controller = _controladorActivo!;
    final text = controller.text;
    final selection = controller.selection;

    final int start = selection.start < 0 ? text.length : selection.start;
    final int end = selection.end < 0 ? text.length : selection.end;

    final String newText = text.replaceRange(start, end, variable);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + variable.length),
    );

    // No se necesita setState aquí, la actualización del controlador es suficiente.
    print('DEBUG: Inserted variable "$variable" into controller ${controller.hashCode}. New text length: ${newText.length}');
  }
}

// ****** CLASE PLANTILLA CARD MODIFICADA (PARA PRESERVAR EL TEXTO NO GUARDADO) ******
class PlantillaCard extends StatefulWidget {
  final Plantilla plantilla;
  final bool esActiva;
  final Function(String? activePlantillaId, TextEditingController activeController, bool isContentField) onFocus;
  final Function(Plantilla plantilla, TextEditingController nombreController, TextEditingController contenidoController, List<String> visibilidad) onSave;
  final Function(Plantilla) onDelete;
  final Widget? variablesSection;

  const PlantillaCard({
    required Key? key,
    required this.plantilla,
    required this.esActiva,
    required this.onFocus,
    required this.onSave,
    required this.onDelete,
    this.variablesSection,
  }) : super(key: key);

  @override
  State<PlantillaCard> createState() => _PlantillaCardState();
}

class _PlantillaCardState extends State<PlantillaCard> {
  late TextEditingController _nombreController;
  late TextEditingController _contenidoController;
  final FocusNode _nombreFocusNode = FocusNode();
  final FocusNode _contenidoFocusNode = FocusNode();
    late List<String> _visibilidadLocal; // ✅ VARIABLE LOCAL AÑADIDA


  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.plantilla.nombre);
    _contenidoController = TextEditingController(text: widget.plantilla.contenido);
    _visibilidadLocal = List.from(widget.plantilla.visibilidad);

    // Añade listeners a los nodos de foco para notificar al padre cuando el foco cambia
    _nombreFocusNode.addListener(_onFocusChange);
    _contenidoFocusNode.addListener(_onFocusChange);
  }
// ✅ AQUÍ PEGAS LA FUNCIÓN QUE TE DI ANTES:
Widget _buildCheckboxesVisibilidad() {
    // 1. Detectamos el tipo de plantilla (si es para cliente o proveedor)
    final bool esParaCliente = widget.plantilla.tipo == 'cliente';

    // 2. Filtramos las opciones de visualización según el tipo
    final opciones = [
      if (esParaCliente) ...[
        {'id': 'clientes', 'label': 'Clientes'},
        {'id': 'ventas', 'label': 'Ventas'},
      ],
      if (!esParaCliente) ...[
        {'id': 'cuentas', 'label': 'Cuentas'},
        {'id': 'proveedores', 'label': 'Proveedores'},
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mostrar esta plantilla en:',
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: opciones.map((opt) {
            final bool seleccionado = _visibilidadLocal.contains(opt['id']);
            return FilterChip(
              label: Text(opt['label']!, style: const TextStyle(fontSize: 11)),
              selected: seleccionado,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _visibilidadLocal.add(opt['id']!);
                  } else {
                    _visibilidadLocal.remove(opt['id']!);
                  }
                });
              },
              selectedColor: Colors.white,
              checkmarkColor: Colors.black,
              backgroundColor: Colors.black45,
              labelStyle: TextStyle(color: seleccionado ? Colors.black : Colors.white),
            );
          }).toList(),
        ),
      ],
    );
  }
  void _onFocusChange() {
    // Solo notifica al padre si esta tarjeta está activa Y uno de sus campos tiene foco.
    if (widget.esActiva) {
      if (_nombreFocusNode.hasFocus) {
        widget.onFocus(widget.plantilla.id, _nombreController, false); // Es campo de nombre (false para contenido)
      } else if (_contenidoFocusNode.hasFocus) {
        widget.onFocus(widget.plantilla.id, _contenidoController, true); // Es campo de contenido (true para contenido)
      } else {
        // En este 'else' no necesitamos hacer nada especial para el foco,
        // ya que el _rootFocusNode del padre maneja la pérdida de foco global.
      }
    }
  }

@override
void didUpdateWidget(covariant PlantillaCard oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // ===== LA CORRECCIÓN ESTÁ AQUÍ =====
  // Comparamos el objeto 'plantilla' completo usando Equatable.
  // Si CUALQUIER propiedad (nombre, contenido, etc.) es diferente, la condición será verdadera.
  if (widget.plantilla != oldWidget.plantilla) {
    print("[PlantillaCard] didUpdateWidget: ¡Detectado cambio en la plantilla! Actualizando controladores.");
    _nombreController.text = widget.plantilla.nombre;
    _contenidoController.text = widget.plantilla.contenido;
    
    // Es una buena práctica también mover el cursor al final para evitar comportamientos extraños.
    _nombreController.selection = TextSelection.fromPosition(TextPosition(offset: _nombreController.text.length));
    _contenidoController.selection = TextSelection.fromPosition(TextPosition(offset: _contenidoController.text.length));
  }
}

  @override
  void dispose() {
    _nombreController.dispose();
    _contenidoController.dispose();
    _nombreFocusNode.removeListener(_onFocusChange);
    _contenidoFocusNode.removeListener(_onFocusChange);
    _nombreFocusNode.dispose();
    _contenidoFocusNode.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return Card( 
      margin: const EdgeInsets.only(bottom: 16),
      elevation: widget.esActiva ? 6.0 : 2.0,
      color: const Color.fromARGB(255, 15, 15, 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
      color: Color.fromARGB(255, 35, 35, 35), // El mismo borde de tus tablas
          width: 0.5,
        ),
      ),
child: Padding(
        padding: const EdgeInsets.all(20.0), // Un poco más de aire
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CABECERA: TÍTULO SIN BORDES NI FONDOS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- BLOQUE DEL TÍTULO CORREGIDO ---
Expanded(
  child: TextFormField(
    controller: _nombreController,
    focusNode: _nombreFocusNode,
    style: const TextStyle(
      color: Colors.white, 
      fontSize: 18, 
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5
    ),
    decoration: InputDecoration(
      hintText: 'Nombre de la Plantilla',
      hintStyle: const TextStyle(color: Colors.white24),
      
      // ✅ ESTO ELIMINA EL FONDO POR COMPLETO
      filled: false, 
      fillColor: Colors.transparent,
      
      // ✅ ESTO ELIMINA CUALQUIER BORDE
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
    onTap: () {
      if (!_nombreFocusNode.hasFocus) {
        _nombreFocusNode.requestFocus();
      }
      widget.onFocus(widget.plantilla.id, _nombreController, false);
    },
  ),
),
                // Icono de basura más discreto
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                  onPressed: () => widget.onDelete(widget.plantilla),
                ),
              ],
            ),
            
            const SizedBox(height: 12),

            // --- CUERPO: CAMPO DE CONTENIDO MINIMALISTA ---
            TextField(
              controller: _contenidoController,
              focusNode: _contenidoFocusNode,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Escribe el mensaje aquí...',
                hintStyle: const TextStyle(color: Colors.white12, fontSize: 13),
                filled: true,
                fillColor: Colors.black, // Negro puro fondo
                contentPadding: const EdgeInsets.all(16),
                
                // BORDE GRIS FINO (Idéntico a tus tablas)
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color.fromARGB(255, 35, 35, 35), width: 0.5),
                ),
                
                // BORDE BLANCO FINO AL ENFOCAR (Sin colores llamativos)
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white38, width: 0.5),
                ),
                
                alignLabelWithHint: true,
              ),
              onTap: () {
                if (!_contenidoFocusNode.hasFocus) _contenidoFocusNode.requestFocus();
                widget.onFocus(widget.plantilla.id, _contenidoController, true);
              },
            ),

            // --- SECCIÓN INFERIOR (Solo si está activa) ---
            if (widget.esActiva && widget.variablesSection != null) ...[
              const SizedBox(height: 20),
              
              // Título de visibilidad más pequeño y elegante
              _buildCheckboxesVisibilidad(), 
              
              const SizedBox(height: 16),
              
              // Sección de variables
              widget.variablesSection!,
              
              const SizedBox(height: 24),
              
              // Botón guardar minimalista (Blanco/Negro)
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () => widget.onSave(widget.plantilla, _nombreController, _contenidoController, _visibilidadLocal),
                  child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
  
}
