import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proyectofinal/domain/models/transaccion_venta_model.dart';
import 'package:proyectofinal/infrastructure/repositories/transacciones_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. State
class HistorialVentasState {
  final bool isLoading;
  final List<TransaccionVenta> historial;
  final int currentPage;
  final int totalPages;
  final String? errorMessage;
final String searchQuery;
  final double totalGlobal; // ✅ 1. AÑADE ESTO

  HistorialVentasState({
    this.isLoading = false,
    this.historial = const [],
    this.currentPage = 1,
    this.totalPages = 1,
      this.searchQuery = '',
          this.totalGlobal = 0.0, // ✅ 2. AÑADE ESTO


    this.errorMessage,
  });

  HistorialVentasState copyWith({
    bool? isLoading,
    List<TransaccionVenta>? historial,
    int? currentPage,
    int? totalPages,
    String? errorMessage,
    String? searchQuery,
    double? totalGlobal,

  }) {
    return HistorialVentasState(
      isLoading: isLoading ?? this.isLoading,
      historial: historial ?? this.historial,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      totalGlobal: totalGlobal ?? this.totalGlobal,
    );
  }
}

class HistorialVentasNotifier extends StateNotifier<HistorialVentasState> {
  final TransaccionesRepository _repository;
  RealtimeChannel? _channel;
  String? _lastDeletedId; // ID del último elemento eliminado localmente

HistorialVentasNotifier(this._repository) : super(HistorialVentasState()) {
  loadHistorial(showLoading: false); // 👈 sin shimmer al construir
  _subscribeRealtime();
}

Future<void> loadHistorial({
  int page = 1,
  String searchQuery = '',
  bool showLoading = true,
  
}) async {
  print('[VENTAS] 🔄 loadHistorial: page=$page, search="$searchQuery", showLoading=$showLoading');
  String queryLimpia = (searchQuery == "null" || searchQuery.isEmpty) ? '' : searchQuery;

  // ❌ ELIMINA ESTA CONDICIÓN COMPLETAMENTE
  // final isSamePage = page == state.currentPage && searchQuery == state.searchQuery;
  // final skipLoading = !showLoading && state.historial.isNotEmpty && isSamePage;
  // if (skipLoading) {
  //   print('[VENTAS] 🔁 Evitando shimmer: ya hay ${state.historial.length} items');
  //   return;
  // }

if (showLoading) {
    state = state.copyWith(isLoading: true, errorMessage: null);
  }

  try {
    // 1. Usar queryLimpia para la lista
    final Map<String, dynamic> response = await _repository.getHistorialVentas(
      page: page,
      perPage: 15,
      searchQuery: queryLimpia,
    );

    // 2. Usar queryLimpia para los totales
    final resumenTotales = await _repository.getTotalesGlobales(queryLimpia);

    final List<TransaccionVenta> historial = response['data'] as List<TransaccionVenta>;
    final int totalPages = response['totalPages'] as int;

    state = state.copyWith(
      isLoading: false,
      historial: historial,
      currentPage: page,
      totalPages: totalPages,
      searchQuery: queryLimpia,
      totalGlobal: resumenTotales['ventas'], // <-- Asegúrate de guardar esto
    );
  } catch (e) {
    print('[VENTAS] ❌ Error en loadHistorial: $e');
    state = state.copyWith(isLoading: false, errorMessage: e.toString());
  }
}

  void search(String? query) {
    loadHistorial(page: 1, searchQuery: query ?? '');
  }

  // ===== MÉTODOS PARA ACTUALIZACIONES GRANULARES =====
  
  /// Agrega un nuevo item al historial sin recargar toda la tabla
  void addHistorialItem(TransaccionVenta item) {
    final updatedHistorial = [item, ...state.historial];
    state = state.copyWith(
      historial: updatedHistorial,
    );
  }

  /// Elimina un item específico del historial sin recargar toda la tabla
  void removeHistorialItem(String itemId) {
    final updatedHistorial = state.historial.where((item) => item.id.toString() != itemId).toList();
    state = state.copyWith(
      historial: updatedHistorial,
    );
  }

  /// Elimina un item del historial y maneja la eliminación en BD
Future<bool> deleteHistorialItem(String itemId) async {
  // ===== AÑADE ESTA VALIDACIÓN DE SEGURIDAD =====
  if (itemId == 'id-nulo-desde-db') {
    print('[ERROR] Intento de borrar un historial con ID inválido. Refrescando la UI.');
    // Quita el item de la lista local para que el usuario vea que desaparece
    final updatedHistorial = state.historial.where((item) => item.id != itemId).toList();
    state = state.copyWith(historial: updatedHistorial);
    // Devuelve 'false' porque la operación en la BD no se realizó
    return false; 
  }
  // ===============================================
  
  try {
    _lastDeletedId = itemId;
    await _repository.deleteHistorialVenta(itemId); // Ahora solo se llamará con UUIDs válidos

    // Actualización granular
    final updatedHistorial = state.historial.where((item) => item.id != itemId).toList();
    state = state.copyWith(historial: updatedHistorial);

    Future.delayed(const Duration(milliseconds: 1000), () {
      _lastDeletedId = null;
    });

    return true;
  } catch (e) {
    _lastDeletedId = null;
    print('[ERROR] deleteHistorialItem: $e');
    return false;
  }
}

void _subscribeRealtime() {
  _channel = Supabase.instance.client.channel('historial-ventas-realtime');

  _channel!.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'historial_transacciones_ventas',
    callback: (payload) {
      print('[REALTIME] Evento recibido: ${payload.eventType} en tabla ${payload.table}');
      print('[REALTIME] Datos: ${payload.newRecord}');

      // Siempre recargar la página actual sin shimmer
loadHistorial(
  page: state.currentPage,
  searchQuery: state.searchQuery,
  showLoading: false, // 👈 Esto evita shimmer
);
    },
  ).subscribe();
}

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }
}

// 3. Provider
final historialVentasProvider = StateNotifierProvider<HistorialVentasNotifier, HistorialVentasState>((ref) {
  final repository = TransaccionesRepository();
  return HistorialVentasNotifier(repository);
});
