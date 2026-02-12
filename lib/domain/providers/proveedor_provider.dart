import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/proveedor_repository.dart';
import '../models/proveedor_model.dart';

// Estado para la lista de proveedores
class ProveedoresState {
  final List<Proveedor> proveedores;
  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final String? searchQuery;

  const ProveedoresState({
    this.proveedores = const [],
    this.isLoading = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.searchQuery,
  });

  ProveedoresState copyWith({
    List<Proveedor>? proveedores,
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    String? searchQuery,
  }) {
    return ProveedoresState(
      proveedores: proveedores ?? this.proveedores,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Notifier para manejar el estado de proveedores
class ProveedoresNotifier extends StateNotifier<ProveedoresState> {
  final ProveedorRepository _proveedorRepo;
  static const int _perPage = 10;
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _proveedorChannel;
  RealtimeChannel? _cuentaChannel;

  ProveedoresNotifier(this._proveedorRepo) : super(const ProveedoresState()) {
    loadProveedores();
    _listenToChanges();
  }

  /// Carga la lista de proveedores con paginación y búsqueda
  Future<void> loadProveedores({int page = 1, String? searchQuery, bool showLoading = true}) async {
    await _loadProveedores(page: page, searchQuery: searchQuery, showLoading: showLoading);
  }

  /// Método interno para cargar proveedores
  Future<void> _loadProveedores({int page = 1, String? searchQuery, bool showLoading = true}) async {
    if (state.isLoading) return;

    if (showLoading) {
      state = state.copyWith(isLoading: true);
    }

    try {
      print('[PROVEEDOR_PROVIDER] Cargando proveedores - página: $page, búsqueda: "$searchQuery"');
      
      final totalCount = await _proveedorRepo.getProveedoresCount(searchQuery: searchQuery);
      final totalPages = (totalCount / _perPage).ceil();
      
      final proveedores = await _proveedorRepo.getProveedores(
        page: page,
        perPage: _perPage,
        searchQuery: searchQuery,
      );

      print('[PROVEEDOR_PROVIDER] Cargados ${proveedores.length} proveedores de $totalCount total');
      
      // Log detallado del estado de cada proveedor
      for (final proveedor in proveedores) {
        print('[PROVEEDOR_PROVIDER] Proveedor: ${proveedor.nombre} - Cuentas: ${proveedor.cuentasCount} - Estado: ${proveedor.esActivo ? "ACTIVO" : "INACTIVO"}');
      }

      // Usar Future.microtask para evitar conflictos con mouse tracker
      Future.microtask(() {
        state = state.copyWith(
          proveedores: proveedores,
          isLoading: false,
          currentPage: page,
          totalPages: totalPages > 0 ? totalPages : 1,
          searchQuery: searchQuery,
        );
      });

    } catch (e) {
      print('[ERROR] _loadProveedores: $e');
      Future.microtask(() {
        state = state.copyWith(isLoading: false);
      });
    }
  }

  /// Busca proveedores por nombre o contacto
  Future<void> searchProveedores(String query) async {
    print('[PROVEEDOR_PROVIDER] Búsqueda iniciada: "$query"');
    await _loadProveedores(page: 1, searchQuery: query.isEmpty ? null : query);
  }

  /// Cambia a una página específica
  Future<void> changePage(int page) async {
    if (page == state.currentPage || state.isLoading) return;
    await _loadProveedores(page: page, searchQuery: state.searchQuery);
  }

  /// Agregar un proveedor al estado
  Future<void> addProveedor(Proveedor proveedor) async {
    print('[PROVEEDOR_PROVIDER] Agregando proveedor: ${proveedor.nombre}');
    // Recargar la lista completa para mantener el orden por fecha
    await _loadProveedores(page: 1, searchQuery: state.searchQuery, showLoading: false);
  }

  /// Actualizar un proveedor existente en el estado
  Future<void> updateProveedor(Proveedor proveedor) async {
    print('[UPDATE_PROVEEDOR] Actualizando proveedor: ${proveedor.nombre}');
    // Recargar la lista completa para mantener el orden por fecha
    await _loadProveedores(page: 1, searchQuery: state.searchQuery, showLoading: false);
  }

  /// Elimina un proveedor y recarga la lista.
  /// Lanza una excepción si no se puede eliminar (ej. tiene cuentas asociadas).
  Future<void> deleteProveedor(String id) async {
    print('[DEBUG_DELETE] Provider: Solicitud para eliminar proveedor con ID: $id');
    try {
      await _proveedorRepo.deleteProveedor(id);
      print('[DEBUG_DELETE] Provider: El repositorio eliminó el proveedor. Recargando lista...');
      // Forzar la recarga para reflejar el cambio inmediatamente
      await loadProveedores(page: state.currentPage, searchQuery: state.searchQuery, showLoading: false);
      print('[DEBUG_DELETE] Provider: Lista de proveedores recargada.');
    } catch (e) {
      print('[DEBUG_DELETE] Provider: [ERROR] Se capturó una excepción del repositorio: $e');
      // Relanzar la excepción para que la UI pueda mostrar un mensaje
      rethrow;
    }
  }

  /// Verifica si un contacto ya existe
  Future<bool> contactoExiste(String contacto) async {
    final res = await _supabase
        .from('proveedores')
        .select('id')
        .eq('contacto', contacto)
        .isFilter('deleted_at', null)
        .maybeSingle();
    return res != null;
  }

  /// Obtiene el número de cuentas activas para un proveedor.
  Future<int> getCuentasCount(String proveedorId) async {
    try {
      return await _proveedorRepo.getCuentasCount(proveedorId);
    } catch (e) {
      print('[ERROR] getCuentasCount Provider: $e');
      return 0; // Si hay un error, asumimos 0 para no bloquear la UI
    }
  }

  /// Guarda un proveedor (crear o actualizar)
Future<bool> saveProveedor(Proveedor proveedor) async {
    try {
      print('[PROVEEDOR_PROVIDER] Guardando proveedor: ${proveedor.nombre}');
      
      if (proveedor.id == null) {
        // CREAR (O RESTAURAR)
        // Como el repo ahora devuelve un Map, lo capturamos así:
        final result = await _proveedorRepo.addProveedor(proveedor);
        
        // Extraemos el objeto real para añadirlo a la lista local
        final nuevoProveedor = result['proveedor'] as Proveedor;
        
        // Llamamos al método interno con el objeto correcto
        await addProveedor(nuevoProveedor); 
        
        print('[PROVEEDOR_PROVIDER] Proveedor procesado (Restaurado: ${result['restaurado']})');
      } else {
        // ACTUALIZAR (Sigue igual)
        // ... (tu lógica de validación de contacto al editar) ...
        await _proveedorRepo.updateProveedor(proveedor);
        await updateProveedor(proveedor);
      }

      return true;
    } catch (e) {
      print('[ERROR] saveProveedor: $e');
      // Relanzamos para que el modal capture el error
      rethrow; 
    }
  }

  /// Activa el listener de tiempo real para sincronización entre dispositivos
  void _listenToChanges() {
    print('[PROVEEDOR_PROVIDER] Activando listeners de tiempo real...');
    
    // Listener para cambios en la tabla proveedores
    _proveedorChannel = _supabase
        .channel('proveedor_provider_proveedores_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'proveedores',
            callback: (payload) {
              print('[PROVEEDOR_PROVIDER] Evento Realtime en proveedores recibido: $payload');
              // Usamos Future.microtask para evitar conflictos con mouse tracker
              Future.microtask(() {
                loadProveedores(page: state.currentPage, searchQuery: state.searchQuery, showLoading: false);
              });
            })
        .subscribe();
    
    // Listener para cambios en la tabla cuentas (para actualizar estado de proveedores)
    _cuentaChannel = _supabase
        .channel('proveedor_provider_cuentas_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cuentas',
            callback: (payload) {
              print('[PROVEEDOR_PROVIDER] ========================================');
              print('[PROVEEDOR_PROVIDER] EVENTO REALTIME EN CUENTAS DETECTADO');
              print('[PROVEEDOR_PROVIDER] Tipo de evento: ${payload.eventType}');
              print('[PROVEEDOR_PROVIDER] Datos del evento: $payload');
              print('[PROVEEDOR_PROVIDER] ========================================');
              
              // Agregar un pequeño delay para asegurar que la transacción se complete
              Future.delayed(const Duration(milliseconds: 500), () {
                print('[PROVEEDOR_PROVIDER] Iniciando recarga de proveedores tras cambio en cuentas...');
                loadProveedores(page: state.currentPage, searchQuery: state.searchQuery, showLoading: false);
              });
            })
        .subscribe();
        
    print('[PROVEEDOR_PROVIDER] Listeners de tiempo real configurados exitosamente');
    print('[PROVEEDOR_PROVIDER] - Listener de proveedores: ${_proveedorChannel != null ? "ACTIVO" : "INACTIVO"}');
    print('[PROVEEDOR_PROVIDER] - Listener de cuentas: ${_cuentaChannel != null ? "ACTIVO" : "INACTIVO"}');
  }

  @override
  void dispose() {
    _proveedorChannel?.unsubscribe();
    _cuentaChannel?.unsubscribe();
    super.dispose();
  }

  /// Recarga la lista actual
  Future<void> refresh() async {
    await _loadProveedores(
      page: state.currentPage,
      searchQuery: state.searchQuery,
    );
  }
}

// --- Providers para los Repositorios ---
final proveedorRepositoryProvider = Provider((ref) => ProveedorRepository(Supabase.instance.client));

// Provider principal para proveedores
final proveedoresProvider = StateNotifierProvider<ProveedoresNotifier, ProveedoresState>((ref) {
  final proveedorRepo = ref.read(proveedorRepositoryProvider);
  return ProveedoresNotifier(proveedorRepo);
});
