// lib/presentation/screens/cuentas_screen.dart (MIGRADO A PROVIDER PATTERN)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Imports de tus archivos locales
import '../../domain/models/cuenta_model.dart';
import '../../infrastructure/repositories/cuenta_repository.dart';

import '../../domain/providers/cuenta_provider.dart';
import '../widgets/dialogs/seleccionar_mensaje_modal.dart';
import '../../infrastructure/repositories/venta_repository.dart';
import '../widgets/modals/cuenta_renovar_modal.dart';

import '../widgets/buttons/add_button.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/dialogo_reporte.dart';

import '../widgets/modals/cuenta_modal.dart';
import '../widgets/modals/venta_modal.dart';
import '../widgets/tables/ReusableDataTablePanel.dart';
import '../../config/app_routes.dart';
import '../widgets/notifications/notification_service.dart';
import 'package:shimmer/shimmer.dart'; // <-- 1. IMPORTAR SHIMMER
import '../widgets/modals/gestionar_perfiles_modal.dart';
import '../../domain/providers/venta_provider.dart';
import '../../infrastructure/repositories/transacciones_repository.dart';
import '../widgets/dialogs/dialogo_procesar_devolucion.dart';
import '../widgets/dialogs/gestionar_incidencias_dialog.dart';
import '../../domain/providers/plataforma_provider.dart'; // <--- AÑADE ESTA LÍNEA

import 'package:collection/collection.dart'; // ✅ Necesario para firstWhereOrNull
import '../../domain/models/plataforma_model.dart'; // ✅ Necesario para reconocer el tipo Plataforma

class CuentasScreen extends ConsumerStatefulWidget {

  const CuentasScreen({super.key});

  @override
  ConsumerState<CuentasScreen> createState() => _CuentasScreenState();
}

class _CuentasScreenState extends ConsumerState<CuentasScreen> {
  // Eliminados los duplicados de _ventaRepo y _searchController


  final VentaRepository _ventaRepo = VentaRepository();
  final TextEditingController _searchController = TextEditingController();

  // --- VARIABLES TEMPORALES PARA FILTRAR ---
  String? _tempPlataforma;
  String? _tempStock = 'todos';
  int? _tempMaxDias;
  bool _tempSoloProblemas = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // (El resto de tus métodos como _loadCuentas, _showCuentaModal, etc., no cambian)
  // ...

  // --- HELPERS DE DISEÑO PARA LA BARRA DE FILTROS ---

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.black,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      // Borde cuando no está seleccionado
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), 
        borderSide: const BorderSide(color: Color(0xFF232323))
      ),
      // Borde cuando haces clic
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), 
        borderSide: const BorderSide(color: Colors.amber, width: 0.5)
      ),
    );
  }

// BORRA LA VERSIÓN DE ARRIBA Y DEJA SOLO ESTA AL FINAL DE LA CLASE:

Widget _dropdownMinimal<T extends Object>({
  required T? value,
  required List<T> options,
  required String hint,
  required String Function(T) displayString,
  required Function(T?) onSelected,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Autocomplete<T>(
        displayStringForOption: displayString,
        initialValue: TextEditingValue(text: value != null ? displayString(value) : ''),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          // Sincronizar texto cuando cambia externamente
          if (value == null) {
            controller.clear();
          } else {
            controller.text = displayString(value);
          }

          return GestureDetector(
            onTap: () => focusNode.requestFocus(),
            child: SizedBox(
              height: 38,
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                readOnly: true, // 🚫 Evita que el usuario escriba
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white38, size: 18),
                  filled: true,
                  fillColor: Colors.black,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF232323)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white, width: 0.5),
                  ),
                ),
              ),
            ),
          );
        },
        optionsBuilder: (TextEditingValue val) => options,
        onSelected: onSelected,
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              color: Colors.white, // Fondo blanco como el modal
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              child: Container(
                width: constraints.maxWidth, // ANCHO IDÉNTICO AL RECUADRO NEGRO
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final T option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                        ),
                        child: Text(
                          displayString(option),
                          style: const TextStyle(color: Colors.black, fontSize: 12), // Letras negras
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
// Dentro de _CuentasScreenState
@override
void initState() {
  super.initState();
  
  // Sincronizamos el buscador visual con el filtro del provider
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final currentState = ref.read(cuentasProvider);
    // Asumiendo que tu CuentasState tiene un campo searchQuery 
    // Si el nombre es diferente en tu provider, ajústalo aquí
    if (currentState.searchQuery != null && currentState.searchQuery!.isNotEmpty) {
      _searchController.text = currentState.searchQuery!;
    }
  });
}


Widget _buildFiltrosHeader(WidgetRef ref, CuentasState state) {
  final plataformas = ref.watch(plataformasProvider).plataformas;
  const Color labelColor = Colors.white38;
  const double labelSize = 9;

  return Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // 1. BUSCADOR RÁPIDO
      Expanded(
        flex: 4, 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BUSCADOR RÁPIDO", style: TextStyle(color: labelColor, fontSize: labelSize, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration("Correo, proveedor o ID..."),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),

// --- 2. STOCK ---
Expanded(
  flex: 1,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("STOCK", style: TextStyle(color: labelColor, fontSize: labelSize, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      _dropdownMinimal<String>(
        value: _tempStock == 'todos' ? 'Todas' : (_tempStock == 'con_stock' ? 'Cupo' : 'Llenas'),
        options: ['Todas', 'Cupo', 'Llenas'],
        hint: 'Todas',
        displayString: (val) => val,
        onSelected: (val) {
          setState(() {
            if (val == 'Todas') _tempStock = 'todos';
            else if (val == 'Cupo') _tempStock = 'con_stock';
            else _tempStock = 'agotados';
          });
        },
      ),
    ],
  ),
),
const SizedBox(width: 8),

// --- 3. VENCIMIENTO ---
Expanded(
  flex: 1,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("VENCIMIENTO", style: TextStyle(color: labelColor, fontSize: labelSize, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      _dropdownMinimal<String>(
        value: _tempMaxDias == null ? 'Todas' : (_tempMaxDias == 2 ? '0-2 d' : '3-5 d'),
        options: ['Todas', '0-2 d', '3-5 d'],
        hint: 'Todas',
        displayString: (val) => val,
        onSelected: (val) {
          setState(() {
            if (val == 'Todas') _tempMaxDias = null;
            else if (val == '0-2 d') _tempMaxDias = 2;
            else _tempMaxDias = 5;
          });
        },
      ),
    ],
  ),
),
const SizedBox(width: 8),

// --- 4. PLATAFORMA ---
Expanded(
  flex: 1,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("PLATAFORMA", style: TextStyle(color: labelColor, fontSize: labelSize, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      _dropdownMinimal<Plataforma>(
        // Creamos un objeto temporal para representar "Todas" y cumplir con <T extends Object>
        value: _tempPlataforma != null 
            ? plataformas.firstWhere((p) => p.id == _tempPlataforma) 
            : Plataforma(id: 'all', nombre: 'Todas'),
        options: [Plataforma(id: 'all', nombre: 'Todas'), ...plataformas],
        hint: 'Todas',
        displayString: (p) => p.nombre,
        onSelected: (val) {
          setState(() => _tempPlataforma = (val?.id == 'all') ? null : val?.id);
        },
      ),
    ],
  ),
),

      // 5. RECIENTES (SWITCH PEQUEÑO)
      Column(
        children: [
          const Text("RECIENTES", style: TextStyle(color: labelColor, fontSize: labelSize, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 40,
            child: Transform.scale(
              scale: 0.65, // Aún más pequeño para ahorrar espacio
              child: Switch(
                value: state.ordenarPorRecientes,
                onChanged: (value) => ref.read(cuentasProvider.notifier).toggleOrdenarPorRecientes(value),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(width: 4),

      // 6. BOTÓN FALLOS
      Column(
        children: [
          const Text("FALLOS", style: TextStyle(color: labelColor, fontSize: labelSize, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Container(
            height: 38,
            width: 36, // Más angosto
            decoration: BoxDecoration(
              color: _tempSoloProblemas ? Colors.amber.withOpacity(0.1) : Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _tempSoloProblemas ? Colors.amber : const Color(0xFF232323)),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.report_problem, color: _tempSoloProblemas ? Colors.amber : Colors.white24, size: 15),
              onPressed: () => setState(() => _tempSoloProblemas = !_tempSoloProblemas),
            ),
          ),
        ],
      ),
      const SizedBox(width: 8),

      // 7. BOTÓN FILTRAR
      Container(
        height: 38,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.filter_alt, color: Colors.amber, size: 18),
          onPressed: () {
            ref.read(cuentasProvider.notifier).setFiltros(
              plataformaId: _tempPlataforma,
              stock: _tempStock,
              maxDias: _tempMaxDias,
              soloProblemas: _tempSoloProblemas,
              query: _searchController.text,
            );
          },
        ),
      ),
    ],
  );
}









// Método removido - ahora usamos el provider

Future<void> _showCuentaModal([Cuenta? cuenta]) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (_) => CuentaModal(
        cuenta: cuenta,
        onSave: (cuentaAGuardar) async {
          final success = await ref.read(cuentasProvider.notifier).saveCuenta(cuentaAGuardar);
          return success;
        },
      ),
    );

    // ✅ NOTIFICACIÓN PERSONALIZADA
    if (guardado == true && mounted) {
      if (cuenta == null) {
        NotificationService.showAdded(context, 'Cuenta');
      } else {
        NotificationService.showUpdated(context, 'Cuenta');
      }
    }
  }

Future<void> _eliminarCuenta(Cuenta cuenta) async {
    if (cuenta.id == null) return;
    try {
      // 1. Verificamos si la cuenta tiene ventas activas
      final ventasCount = await _ventaRepo.getVentasCountByCuentaId(cuenta.id!);
      
      if (ventasCount > 0) {
        // ✅ NOTIFICACIÓN DE BLOQUEO: Usamos ConfirmDialog en lugar de SnackBar
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => ConfirmDialog(
              title: 'No se puede eliminar',
              message: 'Esta cuenta tiene $ventasCount venta(s) asociada(s) y no puede ser eliminada. \n\nPara borrar la cuenta, primero debes finalizar o eliminar todas sus ventas en la pantalla de Ventas.',
              confirmText: 'Entendido',
              cancelText: '', // Ocultamos el botón de cancelar para que sea solo una alerta
            ),
          );
        }
        return; // Salimos de la función sin intentar eliminar
      }

      // 2. Si no tiene ventas, pedimos confirmación normal para eliminar
      if (mounted) {
        final confirmado = await showDialog<bool>(
          context: context,
          builder: (context) => ConfirmDialog(
            title: 'Confirmar eliminación',
            message: '¿Estás seguro de que deseas eliminar esta cuenta?\n\nCorreo: ${cuenta.correo}\nPlataforma: ${cuenta.plataforma.nombre}',
            confirmText: 'Eliminar',
            cancelText: 'Cancelar',
          ),
        );

if (confirmado == true) {
          final success = await ref.read(cuentasProvider.notifier).deleteCuenta(cuenta);
          if (mounted) {
            if (success) {
              // ✅ USAR showDeleted PARA EL ICONO DE BASURA
              NotificationService.showDeleted(context, 'Cuenta');
            } else {
              NotificationService.showCustomError(context, 'Error al eliminar la cuenta');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) NotificationService.showCustomError(context, 'Error al procesar la eliminación: ${e.toString()}');
    }
  }

  Future<void> _showVentaModalDesdeCuenta(Cuenta cuenta) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VentaModal(
        cuentaInicial: cuenta,
        onSave: (venta, perfilId) async { // <--- Añade perfilId aquí
  // Se lo pasamos al provider
  return await ref.read(ventasProvider.notifier).saveVenta(venta, perfilId: perfilId); 
},
      ),
    );
    // ✅ NOTIFICACIÓN PERSONALIZADA
    if (guardado == true && mounted) {
      NotificationService.showAdded(context, 'Venta');
      ref.read(cuentasProvider.notifier).refresh();
    }
  }

Future<void> _showDevolucionProveedorDialog(Cuenta cuenta) async {
  final inicio = DateTime.parse(cuenta.fechaInicio!);
  final fin = DateTime.parse(cuenta.fechaFinal!);
  final hoy = DateTime.now();
  final totalDias = fin.difference(inicio).inDays;
  final diasRestantes = fin.difference(hoy).inDays;
  
  // Cálculo de lo que el proveedor debería devolverte por los días no usados
  double sugerencia = (totalDias > 0 && diasRestantes > 0) ? (cuenta.costoCompra! / totalDias) * diasRestantes : 0;

  final double? montoFinal = await showDialog<double>(
    context: context,
    builder: (context) => DialogoProcesarDevolucion(
      title: 'Reembolso del Proveedor',
      detalle: 'Se anulará la cuenta ${cuenta.correo}.',
      montoRecibido: cuenta.costoCompra ?? 0,
      sugerencia: sugerencia,
      labelMonto: 'Monto recuperado (\$)',
    ),
  );

  if (montoFinal != null) {
await _ventaRepo.registrarDevolucionProveedor(cuenta: cuenta, montoRecuperado: montoFinal);
    await ref.read(cuentasProvider.notifier).deleteCuenta(cuenta);
    NotificationService.showSuccess(context, 'Reembolso de proveedor registrado');
  }
}

  (String, Color) _getTextoYColorDeEstado(Cuenta cuenta) {
    if (cuenta.problemaCuenta != null && cuenta.problemaCuenta!.isNotEmpty) return (cuenta.problemaCuenta!, Colors.amber);
    if (cuenta.diasRestantes <= 0) return ('Expirado', Colors.red[400]!);
    return ('OK', Colors.green[400]!);
  }

  Future<void> _showRenovarCuentaModal(Cuenta cuenta) async {
    final Cuenta? cuentaRenovada = await showDialog<Cuenta>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RenovarCuentaModal(
        cuenta: cuenta,
        onRenew: (cuentaARenovar) async {
          try {
            await ref.read(cuentasProvider.notifier).saveCuenta(cuentaARenovar);
            return cuentaARenovar;
          } catch (e) {
            if (mounted) NotificationService.showError(context, 'Error al renovar la cuenta: ${e.toString()}');
            return null;
          }
        },
      ),
    );
    // ✅ NOTIFICACIÓN PERSONALIZADA
    if (cuentaRenovada != null && mounted) {
      NotificationService.showRenewed(context, 'Cuenta');
    }
  }
  // ===== MÉTODO ACTUALIZADO PARA USAR EL MODAL REUTILIZABLE =====
  Color _getColorDiasRestantes(int diasRestantes) {
    if (diasRestantes >= 0 && diasRestantes <= 2) {
      return Colors.red; // Rojo para 0, 1, 2 días
    } else if (diasRestantes >= 3 && diasRestantes <= 5) {
      return Colors.amber; // Amarillo para 3, 4, 5 días
    } else {
      return Colors.green; // Verde para el resto
    }
  }

  Color _getColorPerfiles(int perfilesDisponibles) {
    if (perfilesDisponibles == 0) {
      return const Color.fromARGB(255, 124, 124, 124); // Gris cuando no hay perfiles disponibles
    } else {
      return const Color.fromARGB(255, 255, 255, 255); // Color normal cuando hay perfiles disponibles
    }
  }

  Future<void> _contactarProveedor(Cuenta cuenta) async {
    if (cuenta.proveedor.contacto.isEmpty) {
      NotificationService.showWarning(context, 'Este proveedor no tiene un número de contacto guardado.');
      return;
    }

    // 1. Preparamos el mapa de datos con las variables y sus valores
    final data = {
      '[plataforma]': cuenta.plataforma.nombre,
      '[correo]': cuenta.correo,
      '[contrasena]': cuenta.contrasena,
      '[fecha_final]': cuenta.fechaFinal != null
          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(cuenta.fechaFinal!))
          : '(sin fecha)',
      '[proveedor]': cuenta.proveedor.nombre,
      // ¡AÑADE ESTAS DOS LÍNEAS PARA INCLUIR LAS VARIABLES DE PROBLEMA!
      '[problema_cuenta]': cuenta.problemaCuenta ?? 'Sin problema reportado', // Texto por defecto si es nulo
      '[fecha_reporte_cuenta]': cuenta.fechaReporteCuenta != null
          ? DateFormat('dd-MM-yyyy').format(cuenta.fechaReporteCuenta!)
          : '(sin fecha de reporte)', // Texto por defecto si es nulo
    };

    // 2. Mostramos el modal reutilizable, pasándole los datos
    await showDialog(
      context: context,
      builder: (_) => SeleccionarMensajeModal(
        title: 'Contactar a ${cuenta.proveedor.nombre}',
        phoneNumber: cuenta.proveedor.contacto,
        dataForVariables: data,
                tipoPlantilla: 'proveedor', // <-- AÑADE ESTA LÍNEA
                  categoriaDestino: 'cuentas', // ✅ AÑADIDO


      ),
    );
  }
  // <-- 2. WIDGET AUXILIAR PARA CREAR UN PLACEHOLDER CON SHIMMER
Widget _buildShimmerPlaceholder({double width = 100.0, double height = 16.0}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      // Este es el color oscuro que definiste en tu ReusableDataTablePanel
      color: const Color.fromARGB(55, 61, 61, 61)!.withOpacity(0.3),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

   @override
  Widget build(BuildContext context) {
    final cuentasState = ref.watch(cuentasProvider);

    const List<DataColumn> columns = [
      DataColumn(label: Text('Plataforma')),
      DataColumn(label: Text('Tipo')),
      DataColumn(label: Text('Proveedor')),
      DataColumn(label: Text('Número')),
      DataColumn(label: Text('Correo')),
      DataColumn(label: Text('Contraseña')),
      DataColumn(label: Text('Precio Compra')),
      DataColumn(label: Text('Estado')),
      DataColumn(label: Text('Stock')),
      DataColumn(label: Text('Fecha Inicio')),
      DataColumn(label: Text('Días Restantes')),
      DataColumn(label: Text('Final')),
      DataColumn(label: Text('Acciones')),
    ];

// 1) Deja de usar el skeleton interno; genera las filas tú mismo
List<Map<String, dynamic>> data;
if (cuentasState.isLoading && cuentasState.cuentas.isEmpty) {
  data = List.generate(
    10,
    (_) => {
      'Plataforma': _buildShimmerPlaceholder(width: 80),
      'Tipo': _buildShimmerPlaceholder(width: 70),
      'Proveedor': _buildShimmerPlaceholder(width: 100),
      'Número': _buildShimmerPlaceholder(width: 90),
      'Correo': _buildShimmerPlaceholder(width: 150),
      'Contraseña': _buildShimmerPlaceholder(width: 100),
      'Precio Compra': _buildShimmerPlaceholder(width: 60),
      'Estado': _buildShimmerPlaceholder(width: 80),
      'Stock': _buildShimmerPlaceholder(width: 50),
      'Fecha Inicio': _buildShimmerPlaceholder(width: 90),
      'Días Restantes': _buildShimmerPlaceholder(width: 50),
      'Final': _buildShimmerPlaceholder(width: 90),
// ===== REEMPLAZA LA Row DE ICONBUTTONS POR ESTA =====
'Acciones': Row(
  mainAxisSize: MainAxisSize.min,
  children: List.generate(7, (index) => // Genera 7 placeholders para los 7 iconos
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0), // Simula el padding de IconButton
      child: Container(
        width: 24, // Ancho estándar de un icono
        height: 24, // Alto estándar de un icono
        decoration: BoxDecoration(
          color: const Color.fromARGB(55, 61, 61, 61)!.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  ),
),
// ======================================================
    },
  );
} else {
  data = cuentasState.cuentas.map((cuenta) {
    final (estadoTexto, estadoColor) = _getTextoYColorDeEstado(cuenta);
    return {
      'Plataforma': Text(cuenta.plataforma.nombre),
      'Tipo': Text(cuenta.tipoCuenta.nombre),
      'Proveedor': Text(cuenta.proveedor.nombre),
      'Número': Text(cuenta.proveedor.contacto.isNotEmpty ? cuenta.proveedor.contacto : 'N/A'),
      'Correo': Text(cuenta.correo),
      'Contraseña': Text(cuenta.contrasena),
      'Precio Compra': Text(cuenta.costoCompra?.toStringAsFixed(2) ?? 'N/A'),
'Estado': (cuenta.problemaCuenta != null && cuenta.problemaCuenta!.isNotEmpty)
    ? _badgePrioridad(cuenta.problemaCuenta!, cuenta.prioridadActual, cuenta.isPaused)
    : Text(
        cuenta.diasRestantes <= 0 ? "EXPIRADO" : "OK",
        style: TextStyle(
          color: cuenta.diasRestantes <= 0 ? Colors.red[400] : Colors.green[400],
          fontWeight: FontWeight.bold,
        ),
      ),
'Stock': Text(
  cuenta.numPerfiles == 0 
      ? cuenta.tipoCuenta.nombre.toUpperCase() // Muestra "COMPLETA" (o el nombre que pusiste)
      : '${cuenta.perfilesDisponibles}/${cuenta.numPerfiles}', // Muestra "1/5"
  style: TextStyle(
    // USAMOS LA MISMA LÓGICA DE COLOR PARA AMBOS:
    // Si no hay perfiles disponibles, se pone Gris. Si hay, se pone Blanco.
    color: cuenta.perfilesDisponibles == 0 
        ? const Color.fromARGB(255, 124, 124, 124) // Gris (mismo que usas en el helper)
        : Colors.white, // Blanco
    fontWeight: FontWeight.bold
  ),
),
      'Fecha Inicio': Text(cuenta.fechaInicio != null ? DateFormat('dd-MM-yyyy').format(DateTime.parse(cuenta.fechaInicio!)) : 'N/A'),
      // REEMPLAZA LA LÍNEA DE 'Días Restantes' EN CUENTAS SCREEN CON ESTO:
'Días Restantes': cuenta.isPaused 
    ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.amber.withOpacity(0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled, size: 12, color: Colors.amber),
            SizedBox(width: 4),
            Text(
              "PAUSADO",
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
      )
    : Text(
        cuenta.diasRestantes.toString(),
        style: TextStyle(
          color: _getColorDiasRestantes(cuenta.diasRestantes), 
          fontWeight: FontWeight.bold
        ),
      ),
      'Final': Text(cuenta.fechaFinal != null ? DateFormat('dd-MM-yyyy').format(DateTime.parse(cuenta.fechaFinal!)) : 'N/A'),
      'Acciones': Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.message, color: Colors.green), tooltip: 'Contactar Proveedor', onPressed: () => _contactarProveedor(cuenta)),
IconButton(
  icon: Icon(Icons.report_problem_outlined, 
    color: cuenta.isPaused ? Colors.red : (cuenta.problemaCuenta != null ? Colors.amber : Colors.grey)
  ),
  onPressed: () {
    showDialog(
      context: context,
      builder: (_) => DialogoIncidenciasLimpio( // ✅ CAMBIADO
        key: UniqueKey(),
        cuentaId: cuenta.id,
        titulo: "${cuenta.correo}",
      ),
    );
  },
),
IconButton(
  icon: const Icon(Icons.list_alt, color: Colors.purpleAccent),
  tooltip: 'Ver Ventas',
  onPressed: () {
    if (cuenta.id != null) {
      // ✅ Pasamos el ID y también el correo para el título
      ref.read(ventasProvider.notifier).filterByCuenta(
        cuenta.id!, 
        info: cuenta.correo
      );
      
      Navigator.pushNamed(context, AppRoutes.VENTAS);
    }
  },
),
IconButton(
  icon: Icon(
    Icons.shopping_cart_checkout, 
    // Si tiene cascada (fallo grave global) se pone gris. 
    // Si solo está pausada (ej. contraseña) sigue azul.
    color: (cuenta.perfilesDisponibles > 0 && !cuenta.tieneCascada) 
        ? Colors.blueAccent 
        : Colors.grey[800]
  ), 
  
  // Tooltip explicativo
  tooltip: cuenta.tieneCascada 
      ? 'BLOQUEADO: Cuenta en Cascada' 
      : (cuenta.perfilesDisponibles > 0 ? 'Vender Perfil' : 'Sin stock'),
  
  // LÓGICA DE NEGOCIO:
  // Permitimos vender si hay stock Y (No tiene cascada).
  // Esto permite vender aunque esté pausada por contraseña.
  onPressed: (cuenta.perfilesDisponibles > 0 && !cuenta.tieneCascada) 
      ? () => _showVentaModalDesdeCuenta(cuenta) 
      : null
),          // BOTÓN RENOVAR (Con protección de Cascada)
IconButton(
  icon: Icon(
    Icons.update, 
    // Si tiene cascada se pone gris, si no, naranja normal
    color: cuenta.tieneCascada ? Colors.grey[800] : Colors.orange
  ),
  tooltip: cuenta.tieneCascada 
      ? 'BLOQUEADO: Cuenta en Cascada' 
      : 'Renovar Cuenta',
  // Si tiene cascada se deshabilita (null)
  onPressed: cuenta.tieneCascada 
      ? null 
      : () => _showRenovarCuentaModal(cuenta),
),
          IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), tooltip: 'Editar', onPressed: () => _showCuentaModal(cuenta)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), tooltip: 'Eliminar', onPressed: () => _eliminarCuenta(cuenta)),
          IconButton(
  icon: const Icon(Icons.badge_outlined, color: Colors.tealAccent),
  tooltip: 'Gestionar Perfiles/PINs',
  onPressed: () async {
    // 1. Esperamos a que el modal se cierre
    await showDialog(
      context: context,
      builder: (_) => GestionarPerfilesModal(
        cuentaId: cuenta.id!,
        correo: cuenta.correo,
      ),
    );
    
    // 2. UNA VEZ CERRADO, refrescamos ambos providers
    // Esto asegura que si cambiaste un nombre, se vea en todas las pantallas
    ref.read(cuentasProvider.notifier).refresh();
    ref.read(ventasProvider.notifier).refresh(); 
  },
),
IconButton(
  icon: const Icon(Icons.assignment_return_outlined, color: Colors.orange),
  tooltip: 'Devolución de Proveedor',
  onPressed: () => _showDevolucionProveedorDialog(cuenta),
),
        ],
      ),
    };
  }).toList();
}


    return Scaffold(
    appBar: AppBar(
      toolbarHeight: 100,
      backgroundColor: Colors.transparent,
      elevation: 0,
              scrolledUnderElevation: 0.0,

      title: Container(
        padding: const EdgeInsets.only(top: 20),
        child: const Text('Gestión de Cuentas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 31,)),
      ),
      actions: [
        AddButton(onPressed: () => _showCuentaModal()),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // SE ELIMINÓ LA FILA DEL SWITCH DE AQUÍ PORQUE YA ESTÁ EN EL HEADER
          Expanded(
            child: ReusableDataTablePanel(
              searchController: _searchController,
              onSearchSubmitted: (query) => ref.read(cuentasProvider.notifier).search(query),
              onSearchChanged: (text) {
                if (text.isEmpty) ref.read(cuentasProvider.notifier).search('');
              },
              columns: columns,
              data: data,
              isLoading: cuentasState.isLoading && cuentasState.cuentas.isEmpty,
              currentPage: cuentasState.currentPage,
              totalPages: cuentasState.totalPages,
              onPageChanged: (page) => ref.read(cuentasProvider.notifier).changePage(page),
              filterActions: _buildFiltrosHeader(ref, cuentasState), 
            ),
          ),
        ],
      ),
    ),
  );
}
  // ✅ HELPER VISUAL DE PRIORIDADES
  Widget _badgePrioridad(String texto, String? prioridad, bool pausado) {
    Color color;
    IconData icono;

    switch (prioridad) {
      case 'critica':
        color = Colors.redAccent;
        icono = Icons.local_fire_department;
        break;
      case 'alta':
        color = Colors.orangeAccent;
        icono = Icons.warning_amber_rounded;
        break;
      case 'media':
        color = Colors.blueAccent;
        icono = Icons.info_outline;
        break;
      default:
        color = Colors.grey;
        icono = Icons.notes;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pausado ? Icons.pause_circle_filled : icono, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto.toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
}