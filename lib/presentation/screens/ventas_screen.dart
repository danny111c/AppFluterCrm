import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/venta_model.dart';
import '../../domain/providers/venta_provider.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/dialogo_reporte_venta.dart';
import '../widgets/dialogs/seleccionar_mensaje_modal.dart';
import '../widgets/modals/venta_modal.dart';
import '../widgets/modals/venta_renovar_modal.dart';
import '../widgets/notifications/notification_service.dart';
import '../widgets/tables/ReusableDataTablePanel.dart';
import '../../domain/providers/cuenta_provider.dart'; // Asegúrate de importar el provider
import 'package:shimmer/shimmer.dart'; // <-- 1. IMPORTAR SHIMMER
import '../widgets/buttons/add_button.dart';
import '../../infrastructure/repositories/transacciones_repository.dart';
import '../widgets/dialogs/dialogo_procesar_devolucion.dart';
import '../../infrastructure/repositories/venta_repository.dart';
import '../widgets/dialogs/gestionar_incidencias_dialog.dart';


class EstadoVentaStyle {
  final String texto;
  final Color color;
  EstadoVentaStyle(this.texto, this.color);
}

class VentasScreen extends ConsumerStatefulWidget {
  const VentasScreen({super.key});

  @override
  _VentasScreenState createState() => _VentasScreenState();
}

class _VentasScreenState extends ConsumerState<VentasScreen> {
  final TextEditingController _searchController = TextEditingController();
    final VentaRepository _ventaRepo = VentaRepository(); // ✅ ESTO DEBE ESTAR AQUÍ


  // ============================================================
  // ✅ AQUÍ SE INSERTA EL MÉTODO INITSTATE
  @override
  void initState() {
    super.initState();
    
    // Este código se ejecuta justo después de que la pantalla se dibuja.
    // Revisa si el provider ya tiene un número de búsqueda (puesto por ClientesScreen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSearch = ref.read(ventasProvider).searchQuery;
      if (currentSearch != null) {
        // Sincroniza el texto del buscador visual con el filtro real.
        _searchController.text = currentSearch;
      }
    });
  }
  // ============================================================


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

Future<void> _eliminarVenta(Venta venta) async {
    if (venta.id == null) return;
    final confirmado = await ConfirmDialog.show(
      context: context,
      title: 'Eliminar Venta',
      message: '¿Seguro que quieres eliminar esta venta? El perfil se devolverá al stock.',
    );
      if (confirmado == true) {
    final success = await ref.read(ventasProvider.notifier).deleteVenta(venta); 
    if (mounted && success) {
      ref.read(cuentasProvider.notifier).refresh(); 
      // ✅ USAR showDeleted
      NotificationService.showDeleted(context, 'Venta');
    }
  }
}

  String _formatDate(String dateStr) {
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

_showRenovarVentaModal(Venta ventaARenovar) async {
  final cuentasState = ref.read(cuentasProvider);
  final cuentaActualizada = cuentasState.cuentas.firstWhere(
    (c) => c.id == ventaARenovar.cuenta.id,
    orElse: () => ventaARenovar.cuenta,
  );

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => VentaRenovarModal(
      venta: ventaARenovar,
      cuentaInicial: cuentaActualizada,
      // ✅ CORRECCIÓN: Ahora recibimos la venta Y el ID del perfil maestro
      onRenewOrUpdate: (Venta ventaActualizada, String? perfilId) async {
        // ✅ Enviamos el ID al provider para que Supabase actualice el PIN maestro
        return await ref.read(ventasProvider.notifier).saveVenta(
          ventaActualizada, 
          perfilId: perfilId
        );
      },
    ),
  );

  if (result == true && mounted) {
    // ✅ USAR showRenewed
    NotificationService.showRenewed(context, 'Venta');
  }
}

  Future<void> _showEditVentaModal(Venta ventaAEditar) async {
  final cuentasState = ref.read(cuentasProvider);
  final cuentaActualizada = cuentasState.cuentas.firstWhere(
    (c) => c.id == ventaAEditar.cuenta.id,
    orElse: () => ventaAEditar.cuenta,
  );
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VentaModal(
        venta: ventaAEditar,
        cuentaInicial: cuentaActualizada,

              onSave: (Venta venta, String? perfilId) async {
        return await ref.read(ventasProvider.notifier).saveVenta(
          venta, 
          perfilId: perfilId  
        );
},
      ),
    );

  if (result == true && mounted) {
    // ✅ USAR showUpdated
    NotificationService.showUpdated(context, 'Venta');
  }
}
Future<void> _showDevolucionDialog(Venta venta) async {
  final inicio = DateTime.parse(venta.fechaInicio);
  final fin = DateTime.parse(venta.fechaFinal);
  final hoy = DateTime.now();
  final totalDias = fin.difference(inicio).inDays;
  final diasRestantes = fin.difference(hoy).inDays;
  double sugerencia = (totalDias > 0 && diasRestantes > 0) ? (venta.precio / totalDias) * diasRestantes : 0;

  final double? montoFinal = await showDialog<double>(
    context: context,
    builder: (context) => DialogoProcesarDevolucion(
      title: 'Devolución al Cliente',
      detalle: 'Se liberará el perfil de ${venta.cliente.nombre}.',
      montoRecibido: venta.precio,
      sugerencia: sugerencia,
    ),
  );

  if (montoFinal != null) {
    await _ventaRepo.registrarDevolucionVenta(venta: venta, montoADevolver: montoFinal);
    await ref.read(ventasProvider.notifier).deleteVenta(venta);
    ref.read(cuentasProvider.notifier).refresh();
    NotificationService.showSuccess(context, 'Devolución registrada');
  }
}

EstadoVentaStyle _getTextoYColorDeEstadoVenta(Venta venta) {
  // 1. Prioridad Máxima: Si la cuenta madre está caída
  if (venta.cuenta.problemaCuenta != null && venta.cuenta.problemaCuenta!.isNotEmpty) {
    return EstadoVentaStyle('⚠️ Cuenta: ${venta.cuenta.problemaCuenta!}', Colors.redAccent);
  }

  // 2. Prioridad Media: Si la venta está pausada
  if (venta.isPaused) {
    return EstadoVentaStyle('⏸️ PAUSADO: ${venta.problemaVenta ?? "Fallo"}', Colors.orange);
  }

  // 3. Prioridad Baja: Hay un problema pero no está pausado
  if (venta.problemaVenta != null && venta.problemaVenta!.isNotEmpty) {
    return EstadoVentaStyle('📝 ${venta.problemaVenta!}', Colors.amber);
  }

  // 4. Estado normal
  if (venta.diasRestantes <= 0) {
    return EstadoVentaStyle('Expirado', Colors.red[400]!);
  }
  return EstadoVentaStyle('OK', Colors.green[400]!);
}

  Color _getColorDiasRestantes(int diasRestantes) {
    if (diasRestantes >= 0 && diasRestantes <= 2) {
      return Colors.red;
    } else if (diasRestantes > 2 && diasRestantes <= 7) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  Future<void> _contactarCliente(Venta venta) async {
  final contacto = venta.cliente.contacto; 
    if (contacto.isEmpty) {
      NotificationService.showWarning(context, 'Este cliente no tiene un número de contacto guardado.');
      return;
    }
    final data = {
    '[plataforma]': venta.cuenta.plataforma.nombre,
    '[correo]': venta.cuenta.correo,
    '[contrasena]': venta.cuenta.contrasena,
    '[perfil]': venta.perfilAsignado ?? 'N/A',
    '[fecha_final]': _formatDate(venta.fechaFinal),
    '[proveedor]': venta.cuenta.proveedor.nombre,
    '[nombre_cliente]': venta.cliente.nombre,
    '[cuenta]': venta.cuenta.correo,
    '[pin_perfil]': venta.pin ?? 'N/A',
    '[fecha_inicio]': _formatDate(venta.fechaInicio),
    '[problema_venta]': venta.problemaVenta ?? 'Sin problema reportado',
    '[fecha_reporte_venta]': venta.fechaReporteVenta != null ? DateFormat('dd-MM-yyyy HH:mm').format(venta.fechaReporteVenta!) : '(sin fecha)',
    '[problema_cuenta]': venta.cuenta.problemaCuenta ?? 'Sin problema reportado en la cuenta',
    '[fecha_reporte_cuenta]': venta.cuenta.fechaReporteCuenta != null ? DateFormat('dd-MM-yyyy HH:mm').format(venta.cuenta.fechaReporteCuenta!) : '(sin fecha de reporte)',
    };
    await showDialog(
      context: context,
      builder: (_) => SeleccionarMensajeModal(
        title: 'Contactar Cliente',
        phoneNumber: contacto,
        dataForVariables: data,
        tipoPlantilla: 'cliente',
  categoriaDestino: 'ventas', // ✅ AÑADIDO

      ),
    );
  }

Widget _buildShimmerPlaceholder({double width = 100.0, double height = 16.0}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      // Este es el mismo color que usas en _generateSkeletonRows dentro de ReusableDataTablePanel
      color: const Color.fromARGB(55, 61, 61, 61)!.withOpacity(0.3),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
  @override

  
  Widget build(BuildContext context) {


    
    final ventasState = ref.watch(ventasProvider);

    final List<DataColumn> columns = [
      const DataColumn(label: Text('Cliente')),
      const DataColumn(label: Text('Contacto')),
      const DataColumn(label: Text('Plataforma')),
      const DataColumn(label: Text('Correo de Cuenta')),
      const DataColumn(label: Text('Contraseña Cuenta')),
      const DataColumn(label: Text('Perfil Asignado')),
      const DataColumn(label: Text('Clave Perfil')),
      const DataColumn(label: Text('Precio Venta')),
      const DataColumn(label: Text('Estado')),
      const DataColumn(label: Text('Fecha Inicio')),
      const DataColumn(label: Text('Días Restantes')),
      const DataColumn(label: Text('Fecha Final')),
      const DataColumn(label: Text('Nota')),
      const DataColumn(label: Text('Acciones')),
    ];

    // <-- ¡CORRECCIÓN! 1. Declaramos la variable 'data' aquí
    List<Map<String, dynamic>> data;

    // <-- ¡CORRECCIÓN! 2. Este bloque if/else ahora solo asigna un valor a 'data'
    if (ventasState.isLoading && ventasState.ventas.isEmpty) {
      data = List.generate(
        10, // Generamos 10 filas fantasma
        (_) => {
          'Cliente': _buildShimmerPlaceholder(width: 120),
          'Contacto': _buildShimmerPlaceholder(width: 100),
          'Plataforma': _buildShimmerPlaceholder(width: 80),
          'Correo de Cuenta': _buildShimmerPlaceholder(width: 150),
          'Contraseña Cuenta': _buildShimmerPlaceholder(width: 100),
          'Perfil Asignado': _buildShimmerPlaceholder(width: 80),
          'Clave Perfil': _buildShimmerPlaceholder(width: 60),
          'Precio Venta': _buildShimmerPlaceholder(width: 70),
          'Estado': _buildShimmerPlaceholder(width: 90),
          'Fecha Inicio': _buildShimmerPlaceholder(width: 90),
          'Días Restantes': _buildShimmerPlaceholder(width: 50),
          'Fecha Final': _buildShimmerPlaceholder(width: 90),
          'Nota': _buildShimmerPlaceholder(width: 120),
'Acciones': Row(
  mainAxisSize: MainAxisSize.min,
  children: List.generate(5, (index) => // Genera 5 placeholders para los 5 iconos
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
        },
      );
    } else {
      data = ventasState.ventas.map((venta) {
         // --- NUEVA LÓGICA DE ESTADO ---
  final String? falloCuenta = venta.cuenta.problemaCuenta;
  final String? falloVenta = venta.problemaVenta;
  final bool tieneFalloCuenta = falloCuenta != null && falloCuenta.isNotEmpty;
  final bool tieneFalloVenta = falloVenta != null && falloVenta.isNotEmpty;
  final bool estaExpirado = venta.diasRestantes <= 0;

  // Creamos un mensaje para el Tooltip que junte ambos
  String mensajeTooltip = '';
  if (tieneFalloCuenta) mensajeTooltip += 'Fallo Cuenta: $falloCuenta\n';
  if (tieneFalloVenta) mensajeTooltip += 'Fallo Venta: $falloVenta';
  if (mensajeTooltip.isEmpty) mensajeTooltip = estaExpirado ? 'Expirado' : 'OK';

        final estadoStyle = _getTextoYColorDeEstadoVenta(venta);
        final String contrasenaFinal = venta.cuenta.contrasena ?? '';

        return {
          'Cliente': Text(venta.cliente.nombre),
          'Contacto': Text(venta.cliente.contacto),
          'Plataforma': Text(venta.cuenta.plataforma.nombre),
          'Correo de Cuenta': Text(venta.cuenta.correo),
          'Contraseña Cuenta': Text(contrasenaFinal),
          'Perfil Asignado': Text(venta.perfilAsignado ?? 'N/A'),
          'Clave Perfil': Text(venta.pin ?? 'N/A'),
          'Precio Venta': Text(venta.precio.toStringAsFixed(2)),
'Estado': Tooltip(
  message: mensajeTooltip,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (tieneFalloCuenta)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Cuenta: $falloCuenta',
                style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      if (tieneFalloVenta)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.amber, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Venta: $falloVenta',
                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      if (!tieneFalloCuenta && !tieneFalloVenta)
        Text(
          estaExpirado ? 'Expirado' : 'OK',
          style: TextStyle(
            color: estaExpirado ? Colors.red[400] : Colors.green[400],
            fontWeight: FontWeight.bold,
          ),
        ),
    ],
  ),
),
    
          'Fecha Inicio': Text(_formatDate(venta.fechaInicio)),
          // REEMPLAZA LA LÍNEA DE 'Días Restantes' EN VENTAS SCREEN CON ESTO:
'Días Restantes': venta.isPaused 
    ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled, size: 14, color: Colors.amber),
            SizedBox(width: 4),
            Text(
              "PAUSADO",
              style: TextStyle(
                color: Colors.amber, 
                fontWeight: FontWeight.bold, 
                fontSize: 10
              ),
            ),
          ],
        ),
      )
    : Text(
        venta.diasRestantes.toString(),
        style: TextStyle(
          color: _getColorDiasRestantes(venta.diasRestantes),
          fontWeight: FontWeight.bold,
        ),
      ),
          'Fecha Final': Text(_formatDate(venta.fechaFinal)),
          'Nota': Text(venta.nota ?? ''),
          'Acciones': Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.message, color: Colors.green),
                tooltip: 'Contactar Cliente',
                onPressed: () => _contactarCliente(venta),
              ),
IconButton(
  icon: Icon(Icons.report_problem_outlined, 
    color: venta.isPaused ? Colors.red : (venta.problemaVenta != null ? Colors.amber : Colors.grey)
  ),
  onPressed: () {
    showDialog(
      context: context,
      builder: (_) => DialogoIncidenciasLimpio( // ✅ CAMBIADO
        key: UniqueKey(), 
        ventaId: venta.id,
        titulo: "Incidencias de ${venta.cliente.nombre}",
      ),
    );
  },
),
              IconButton(
                icon: const Icon(Icons.autorenew, color: Colors.purple),
                tooltip: 'Renovar Venta',
                onPressed: () => _showRenovarVentaModal(venta),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                tooltip: "Editar Venta",
                onPressed: () => _showEditVentaModal(venta),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: "Eliminar Venta",
                onPressed: () => _eliminarVenta(venta),
              ),
              IconButton(
  icon: const Icon(Icons.keyboard_return, color: Colors.orange),
  tooltip: 'Procesar Devolución',
  onPressed: () => _showDevolucionDialog(venta),
),
            ],
          ),
        };
      }).toList();
    }


return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120, // Aumentamos el alto para que quepa el subtítulo
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.0,
        title: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gestión de Ventas', 
                style: TextStyle(fontWeight: FontWeight.bold)
              ),
              
              // ✅ SUBTÍTULO DINÁMICO (Se muestra solo si hay filtro activo)
              if (ventasState.cuentaId != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mostrando ventas de: ${ventasState.filterInfo ?? 'Cuenta seleccionada'}', 
                        style: const TextStyle(
                          fontSize: 13, 
                          color: Colors.purpleAccent, 
                          fontWeight: FontWeight.normal
                        )
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref.read(ventasProvider.notifier).filterByCuenta(null),
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(Icons.close, size: 16, color: Colors.purpleAccent),
                        ),
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: const [], 
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Container()),
                const Text('Ordenar por más recientes'),
                Switch(
                  value: ventasState.sortByRecent,
                  onChanged: (value) {
                    ref.read(ventasProvider.notifier).toggleSortByRecent();
                  },
                ),
              ],
            ),


            Expanded(
              child: ReusableDataTablePanel(
                columns: columns,
                data: data, // Usamos la variable 'data' que ya tiene el valor correcto
                isLoading: ventasState.isLoading,
                searchController: _searchController,
                onSearchSubmitted: (query) => ref.read(ventasProvider.notifier).search(query),
                currentPage: ventasState.currentPage,
                totalPages: ventasState.totalPages,
                onPageChanged: (page) => ref.read(ventasProvider.notifier).changePage(page),
              ),
            ),
          ],
        ),
      ),
    );
  }
}