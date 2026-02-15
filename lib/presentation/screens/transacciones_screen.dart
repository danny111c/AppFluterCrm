import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/historial_renovacion_cuenta_model.dart';
import '../../domain/models/transaccion_venta_model.dart';
import '../../domain/providers/historial_renovaciones_cuentas_provider.dart';
import '../../domain/providers/historial_ventas_provider.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/notifications/notification_service.dart';
import '../widgets/tables/ReusableDataTablePanel.dart';
import 'package:shimmer/shimmer.dart'; // <-- 1. IMPORTAR SHIMMER

enum HistorialType { cuentas, ventas }

class TransaccionesScreen extends ConsumerStatefulWidget {
  const TransaccionesScreen({super.key});

  @override
  ConsumerState<TransaccionesScreen> createState() => _TransaccionesScreenState();
}

class _TransaccionesScreenState extends ConsumerState<TransaccionesScreen> {
  HistorialType _selectedType = HistorialType.cuentas;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        _onSearchSubmitted('');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    if (_selectedType == HistorialType.cuentas) {
      ref.read(historialRenovacionesCuentasProvider.notifier).search(query);
    } else {
      ref.read(historialVentasProvider.notifier).search(query);
    }
  }

  void _switchView(HistorialType newType) {
    if (_selectedType != newType) {
      setState(() {
        _selectedType = newType;
        _searchController.clear();
      });
    }
  }

  Future<void> _handleDelete(String id, HistorialType type) async {
    final bool? confirm = await ConfirmDialog.show(
      context: context,
      title: 'Confirmar Eliminación',
      message: 'Se eliminará de forma permanente. ¿Seguro que desea eliminar esta transacción?',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    );

    if (confirm == true) {
      try {
        bool success = false;
        if (type == HistorialType.cuentas) {
          success = await ref.read(historialRenovacionesCuentasProvider.notifier).deleteHistorialItem(id);
        } else {
          success = await ref.read(historialVentasProvider.notifier).deleteHistorialItem(id);
        }
        
 if (success && mounted) {
          // ✅ NOTIFICACIÓN UNIFICADA: Usamos showDeleted para el icono de basura
          NotificationService.showDeleted(context, 'Transacción');
        } else if (!success && mounted) {
          // ✅ ERROR UNIFICADO
          NotificationService.showError(context, 'No se pudo eliminar la transacción');
        }
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Error: $e');
        }
      }
    }
  }



  // <-- 2. WIDGET AUXILIAR PARA CREAR UN PLACEHOLDER CON SHIMMER
Widget _buildShimmerPlaceholder({double width = 100.0, double height = 16.0}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color.fromARGB(55, 61, 61, 61)!.withOpacity(0.3),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}




  @override
  Widget build(BuildContext context) {
    final HistorialRenovacionesCuentasState cuentasState = ref.watch(historialRenovacionesCuentasProvider);
    final HistorialVentasState ventasState = ref.watch(historialVentasProvider);

    // LOGS PARA DEBUG
    print('[TRANSACCIONES_SCREEN] Build | Ventas State: isLoading=${ventasState.isLoading}, count=${ventasState.historial.length}');
    if (ventasState.historial.isNotEmpty) {
      print('[TRANSACCIONES_SCREEN] Ventas Data IDs: ${ventasState.historial.map((v) => v.id).toList()}');
    } else {
      print('[TRANSACCIONES_SCREEN] Historial de ventas está vacío.');
    }
    // FIN DE LOGS

    // ✅ USA ESTO EN SU LUGAR:
    final totalVentas = ventasState.totalGlobal;  // Viene del provider de Ventas
    final totalGastos = cuentasState.totalGlobal; // Viene del provider de Cuentas
    final balance = totalVentas - totalGastos;

    return Scaffold(
           // --- BLOQUE DE TÍTULO AÑADIDO ---
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.0,
        title: Container(
          padding: const EdgeInsets.only(top: 20),
          child: const Text(
            'Transacciones', 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 31, // Tamaño solicitado
              color: Colors.white,
            )
          ),
        ),
      ),
      // --------------------------------
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(totalVentas, totalGastos, balance),
            const SizedBox(height: 25),

            Expanded(
              child: _selectedType == HistorialType.cuentas
                  ? _buildCuentasTable(cuentasState)
                  : _buildVentasTable(ventasState),
            ),
            // ------------------------------------------------
          ],
        ),
      ),
    );
  }

Widget _buildHeader(double totalVentas, double totalGastos, double balance) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard('Ventas Totales', totalVentas, Colors.green),
        ),
        const SizedBox(width: 16), // Espacio entre tarjetas
        Expanded(
          child: _buildSummaryCard('Gastos Totales', totalGastos, Colors.red),
        ),
        const SizedBox(width: 16), // Espacio entre tarjetas
        Expanded(
          child: _buildSummaryCard('Balance', balance, Colors.blue),
        ),
      ],
    );
  }

Widget _buildSummaryCard(String title, double amount, Color color) {
    final formatCurrency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return Card(
      elevation: 2,
      // Quitamos márgenes externos para que el Expanded controle el espacio con el SizedBox
      margin: EdgeInsets.zero, 
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Aumentamos un poco el padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title, 
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              )
            ),
            const SizedBox(height: 12),
            FittedBox( // ✅ Esto ayuda a que el texto grande no se corte si la ventana se encoge
              fit: BoxFit.scaleDown,
              child: Text(
                formatCurrency.format(amount),
                style: TextStyle(
                  color: color, 
                  fontSize: 24, // Un poco más grande para resaltar
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return ToggleButtons(
      isSelected: [_selectedType == HistorialType.cuentas, _selectedType == HistorialType.ventas],
      onPressed: (index) {
        _switchView(index == 0 ? HistorialType.cuentas : HistorialType.ventas);
      },
      borderRadius: BorderRadius.circular(8),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Cuentas'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Ventas'),
        ),
      ],
    );
  }

  // <-- 3. MÉTODO MODIFICADO PARA LA TABLA DE CUENTAS
  Widget _buildCuentasTable(HistorialRenovacionesCuentasState state) {
    final notifier = ref.read(historialRenovacionesCuentasProvider.notifier);
    
    List<Map<String, dynamic>> data;
    if (state.isLoading && state.historial.isEmpty) {
      data = List.generate(10, (_) => {
        'Tipo': _buildShimmerPlaceholder(width: 80),
        'Plataforma': _buildShimmerPlaceholder(width: 100),
        'Proveedor': _buildShimmerPlaceholder(width: 120),
        'Contacto': _buildShimmerPlaceholder(width: 100),
        'Cuenta': _buildShimmerPlaceholder(width: 150),
        'Monto': _buildShimmerPlaceholder(width: 70),
        'Periodo Inicio': _buildShimmerPlaceholder(width: 90),
        'Periodo Fin': _buildShimmerPlaceholder(width: 90),
        'Acciones': _buildShimmerPlaceholder(width: 24, height: 24),
      });
    } else {
      data = _getCuentaData(state.historial);
    }

    return ReusableDataTablePanel(
      key: const ValueKey('ventasTable'),
      columns: _getVentaColumns(),
      data: data,
      // ✅ PASAMOS EL NUEVO HEADER AQUÍ
      filterActions: _buildFiltrosTransacciones(),
      // El resto igual...
      currentPage: state.currentPage,
      totalPages: state.totalPages,
      onPageChanged: (page) => notifier.loadHistorial(page: page),
      isLoading: state.isLoading,
    );
  }

  // <-- 4. MÉTODO MODIFICADO PARA LA TABLA DE VENTAS
  Widget _buildVentasTable(HistorialVentasState state) {
    final notifier = ref.read(historialVentasProvider.notifier);
    
    List<Map<String, dynamic>> data;
    if (state.isLoading && state.historial.isEmpty) {
      data = List.generate(10, (_) => {
        'Tipo': _buildShimmerPlaceholder(width: 80),
        'Plataforma': _buildShimmerPlaceholder(width: 100),
        'Cliente': _buildShimmerPlaceholder(width: 120),
        'Contacto': _buildShimmerPlaceholder(width: 100),
        'Cuenta': _buildShimmerPlaceholder(width: 150),
        'Perfil': _buildShimmerPlaceholder(width: 70),
        'Monto': _buildShimmerPlaceholder(width: 70),
        'Fecha Inicio': _buildShimmerPlaceholder(width: 90),
        'Fecha Fin': _buildShimmerPlaceholder(width: 90),
        'Acciones': _buildShimmerPlaceholder(width: 24, height: 24),
      });
    } else {
      data = _getVentaData(state.historial);
    }

    return ReusableDataTablePanel(
      key: const ValueKey('cuentasTable'),
      columns: _getCuentaColumns(),
      data: data,
      // ✅ PASAMOS EL NUEVO HEADER AQUÍ
      filterActions: _buildFiltrosTransacciones(),
      // El resto igual...
      currentPage: state.currentPage,
      totalPages: state.totalPages,
      onPageChanged: (page) => notifier.loadHistorial(page: page),
      isLoading: state.isLoading,
    );
  }
List<DataColumn> _getCuentaColumns() {
  return const [
    DataColumn(label: Text('Tipo')),
    DataColumn(label: Text('Plataforma')),
    DataColumn(label: Text('Proveedor')),
    DataColumn(label: Text('Contacto')),
    DataColumn(label: Text('Cuenta')),
    DataColumn(label: Text('Monto')),
    DataColumn(label: Text('Periodo Inicio')),
    DataColumn(label: Text('Periodo Fin')),
    DataColumn(label: Text('Acciones')),
  ];
}

List<Map<String, dynamic>> _getCuentaData(List<HistorialRenovacionCuenta> transacciones) {
  final dateFormat = DateFormat('dd-MM-yyyy');
  final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  return transacciones.map((h) {
    return {
      'Tipo': Text(h.tipoRegistro),
      'Plataforma': Text(h.plataformaNombre),
      'Proveedor': Text(h.proveedorNombre),
      'Contacto': Text(h.proveedorContacto),
      'Cuenta': Text(h.correo),
      'Monto': Text(currencyFormat.format(h.montoGastado)),
      'Periodo Inicio': Text(dateFormat.format(h.periodoInicio)),
      'Periodo Fin': Text(dateFormat.format(h.periodoFin)),
      'Acciones': IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        tooltip: 'Eliminar transacción',
        onPressed: () => _handleDelete(h.id, HistorialType.cuentas),
      ),
    };
  }).toList();
}

List<DataColumn> _getVentaColumns() {
  return const [
    DataColumn(label: Text('Tipo')),
    DataColumn(label: Text('Plataforma')),
    DataColumn(label: Text('Cliente')),
    DataColumn(label: Text('Contacto')),
    DataColumn(label: Text('Cuenta')),
    DataColumn(label: Text('Perfil')),
    DataColumn(label: Text('Monto')),
    DataColumn(label: Text('Fecha Inicio')),
    DataColumn(label: Text('Fecha Fin')),
    DataColumn(label: Text('Acciones')),
  ];
}

  List<Map<String, dynamic>> _getVentaData(List<TransaccionVenta> transacciones) {
    final dateFormat = DateFormat('dd-MM-yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return transacciones.map((h) {
return {
  'Tipo': Text(h.tipoRegistro),
  'Plataforma': Text(h.plataformaNombre ?? 'N/A'),
  'Cliente': Text(h.clienteNombre ?? 'N/A'),
  'Contacto': Text(h.clienteContacto ?? 'N/A'),
  'Cuenta': Text(h.cuentaCorreo ?? 'N/A'),
  'Perfil': Text(h.perfil ?? 'N/A'),
  'Monto': Text(currencyFormat.format(h.montoTransaccion)),
  'Fecha Inicio': Text(dateFormat.format(h.periodoInicioServicio)),
  'Fecha Fin': Text(dateFormat.format(h.periodoFinServicio)),
        'Acciones': IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Eliminar transacción',
          onPressed: () => _handleDelete(h.id.toString(), HistorialType.ventas),
        ),
      };
    }).toList();
  }
  // --- BARRA DE FILTROS PERSONALIZADA PARA TRANSACCIONES ---
  Widget _buildFiltrosTransacciones() {
    const Color borderColor = Color.fromARGB(255, 35, 35, 35);
    const double borderWidth = 0.5;

    return Row(
      children: [
        // 1. SELECTOR IZQUIERDO (CUENTAS / VENTAS)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabButton('CUENTAS', HistorialType.cuentas),
              _buildTabButton('VENTAS', HistorialType.ventas),
            ],
          ),
        ),
        const SizedBox(width: 15),
        
        // 2. DIVIDER VERTICAL SUTIL
        Container(width: 1, height: 25, color: borderColor),
        const SizedBox(width: 15),

        // 3. BUSCADOR (RECORRIDO A LA DERECHA)
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              onSubmitted: _onSearchSubmitted,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar transacción...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                filled: true,
                fillColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: const BorderSide(color: Color(0xFF232323))
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: const BorderSide(color: Colors.white38, width: 0.5)
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Botón individual del selector
  Widget _buildTabButton(String label, HistorialType type) {
    bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => _switchView(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}