import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proyectofinal/infrastructure/repositories/historial_renovaciones_cuentas_repository.dart';
import 'package:proyectofinal/domain/providers/transacciones_repository_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proyectofinal/domain/models/historial_renovacion_cuenta_model.dart';

final historialRenovacionesCuentasProvider = StateNotifierProvider<HistorialRenovacionesCuentasNotifier, HistorialRenovacionesCuentasState>(
  (ref) => HistorialRenovacionesCuentasNotifier(ref),
);

class HistorialRenovacionesCuentasState {
  final List<HistorialRenovacionCuenta> historial;
  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final String searchQuery;
    final double totalGlobal; // ✅ 1. PROPIEDAD AÑADIDA


  HistorialRenovacionesCuentasState({
    this.historial = const [],
    this.isLoading = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalCount = 0,
    this.searchQuery = '',
        this.totalGlobal = 0.0, // ✅ 2. VALOR INICIAL

  });

  HistorialRenovacionesCuentasState copyWith({
    List<HistorialRenovacionCuenta>? historial,
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    String? searchQuery,
        double? totalGlobal, // ✅ 3. PARÁMETRO AÑADIDO

  }) {
    return HistorialRenovacionesCuentasState(
      historial: historial ?? this.historial,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      searchQuery: searchQuery ?? this.searchQuery,
            totalGlobal: totalGlobal ?? this.totalGlobal, // ✅ 4. ASIGNACIÓN

    );
  }
}

class HistorialRenovacionesCuentasNotifier extends StateNotifier<HistorialRenovacionesCuentasState> {
  final Ref ref;
  RealtimeChannel? _subscription;
  static const int _pageSize = 20;
  String? _lastDeletedId; // ID del último elemento eliminado localmente

  HistorialRenovacionesCuentasNotifier(this.ref) : super(HistorialRenovacionesCuentasState()) {
    loadHistorial();
    _subscribeRealtime();
  }

  Future<void> loadHistorial({int page = 1, String? searchQuery, bool showLoading = true}) async {
  String queryLimpia = (searchQuery == null || searchQuery == "null" || searchQuery.isEmpty) ? '' : searchQuery;


    print('[DEBUG] loadHistorial llamado: page=\u001b[35m$page\u001b[0m, searchQuery=\u001b[35m$searchQuery\u001b[0m, showLoading=$showLoading');
     if (showLoading) {
    state = state.copyWith(isLoading: true, currentPage: page, searchQuery: queryLimpia);
  } else {
    state = state.copyWith(currentPage: page, searchQuery: queryLimpia);
  }

  final repoHistorial = ref.read(historialRenovacionesCuentasRepositoryProvider);
  final repoTransacciones = ref.read(transaccionesRepositoryProvider);

  try {
    // 1. Cargar lista con queryLimpia
    final result = await repoHistorial.getHistorialRenovacionesCuentas(
      page: page, 
      pageSize: _pageSize, 
      search: queryLimpia
    );

    // 2. Cargar totales con queryLimpia
    final resumenTotales = await repoTransacciones.getTotalesGlobales(queryLimpia);

    state = state.copyWith(
      historial: result.items,
      totalPages: result.totalPages,
      totalCount: result.totalCount,
      totalGlobal: resumenTotales['gastos'], // <-- Guardar total de gastos
      isLoading: false,
    );
    } catch (e, st) {
      state = state.copyWith(isLoading: false);
      print('[ERROR] Error al cargar historial: $e\n$st');
    }
  }


  void search(String? query) {
    loadHistorial(page: 1, searchQuery: query ?? '');
  }

  // ===== MÉTODO DE ELIMINACIÓN GRANULAR REAL =====
  
  /// Elimina un item del historial - SOLO quita la fila de la lista
  Future<bool> deleteHistorialItem(String itemId) async {
    try {
      // Marcar el ID como eliminado localmente
      _lastDeletedId = itemId;
      
      // Primero eliminar de la base de datos
      final repo = ref.read(transaccionesRepositoryProvider);
      await repo.deleteHistorialCuenta(itemId);
      
      // ACTUALIZACIÓN GRANULAR: Solo quitar el item de la lista actual
      final updatedHistorial = state.historial.where((item) => item.id != itemId).toList();
      state = state.copyWith(
        historial: updatedHistorial,
        totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
      );
      
      // Limpiar el ID después de un breve delay para permitir cambios de otros usuarios
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
    final repo = ref.read(historialRenovacionesCuentasRepositoryProvider);
    _subscription = repo.subscribeRealtime((event) {
      print('[DEBUG] Evento realtime recibido: ${event.eventType}');
      
      // Si es una eliminación y coincide con nuestro último ID eliminado, ignorar
      if (event.eventType == 'DELETE' && event.oldRecord != null) {
        final deletedId = event.oldRecord!['id']?.toString();
        if (deletedId == _lastDeletedId) {
          print('[DEBUG] Ignorando eliminación local de ID: $deletedId');
          return;
        }
      }
      
      // Para todos los demás casos (inserciones, actualizaciones, eliminaciones de otros usuarios)
      print('[DEBUG] Recargando tabla por cambio externo');
      loadHistorial(page: state.currentPage, searchQuery: state.searchQuery, showLoading: false);
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
