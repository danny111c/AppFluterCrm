// ===== CÓDIGO CORRECTO Y COMPLETO PARA cliente_provider.dart =====

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/cliente_repository.dart';
import '../../infrastructure/repositories/venta_repository.dart'; // Necesario para la lógica de borrado
import '../../domain/models/cliente_model.dart';

// --- Providers para los Repositorios ---
final clienteRepositoryProvider = Provider((ref) => ClienteRepository());
final ventaRepositoryProvider = Provider((ref) => VentaRepository());

// --- Clase de Estado (Soluciona errores de 'currentPage' y 'totalPages') ---
class ClientesState {
  final List<Cliente> clientes;
  final bool isLoading;
  final int currentPage; // <--- PROPIEDAD QUE FALTABA
  final int totalPages;  // <--- PROPIEDAD QUE FALTABA{}
  final String? searchQuery; // <--- AÑADE ESTA LÍNEA

  ClientesState({
    this.clientes = const [],
    this.isLoading = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.searchQuery,
  });

  ClientesState copyWith({
    List<Cliente>? clientes,
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    String? searchQuery, // <--- AÑADE ESTA LÍNEA

  }) {
    return ClientesState(
      clientes: clientes ?? this.clientes,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      searchQuery: searchQuery,
    );
  }
}

// --- El Notifier (Soluciona errores de 'saveCliente', 'deleteCliente', 'changePage') ---
class ClientesNotifier extends StateNotifier<ClientesState> {
  final ClienteRepository _clienteRepo;
  final VentaRepository _ventaRepo;
  final int _perPage = 10;
  RealtimeChannel? _clienteChannel;
  RealtimeChannel? _ventaChannel;

  ClientesNotifier(this._clienteRepo, this._ventaRepo) : super(ClientesState()) {
    _loadClientes();
    _listenToChanges();
  }

  Future<void> _loadClientes({int page = 1, String? searchQuery, bool showLoading = true}) async {
    if (state.isLoading) return;
    if (showLoading) state = state.copyWith(isLoading: true);
    try {
      final totalCount = await _clienteRepo.getClientesCount(searchQuery: searchQuery);
      final totalPages = (totalCount / _perPage).ceil();
      final clientes = await _clienteRepo.getClientes(page: page, perPage: _perPage, searchQuery: searchQuery);
      state = state.copyWith(
          clientes: clientes, isLoading: false, currentPage: page,
          totalPages: totalPages > 0 ? totalPages : 1);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void refresh() {
    _loadClientes(page: state.currentPage, searchQuery: state.searchQuery, showLoading: false);
  }

  Future<void> changePage(int page) async {
    await _loadClientes(page: page);
  }

  Future<String> saveCliente(Cliente cliente) async {
    try {
      if (cliente.id == null) {
        final result = await _clienteRepo.addCliente(cliente); 
        refresh(); 
        return result['restaurado'] ? 'restaurado' : 'agregado';
      } else {
        await _clienteRepo.updateCliente(cliente);
        refresh();
        return 'actualizado';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getVentasCount(String clienteId) async {
    try {
      return await _ventaRepo.getVentasCountByClienteId(clienteId);
    } catch (e) {
      return 0;
    }
  }

  Future<bool> deleteCliente(Cliente cliente) async {
    if (cliente.id == null) return false;
    await _clienteRepo.deleteCliente(cliente.id!);
    refresh();
    return true;
  }

  Future<void> search(String? query) async {
    state = state.copyWith(searchQuery: query); 
    await _loadClientes(page: 1, searchQuery: query);
  }
  
  void _listenToChanges() {
    // ... (Mantén tu código de _listenToChanges y dispose igual)    print('[CLIENTE_PROVIDER] Activando listeners de tiempo real...');
    
    // Listener para cambios en la tabla clientes
    _clienteChannel = Supabase.instance.client
        .channel('cliente_provider_clientes_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'clientes',
            callback: (payload) {
              print('[CLIENTE_PROVIDER] Evento Realtime en clientes recibido: $payload');
              // Usamos Future.microtask para evitar conflictos con mouse tracker
              Future.microtask(() {
                _loadClientes(page: state.currentPage, searchQuery: state.searchQuery, showLoading: false);
              });
            })
        .subscribe();
    
    // Listener para cambios en la tabla ventas (para actualizar estado de clientes)
    _ventaChannel = Supabase.instance.client
        .channel('cliente_provider_ventas_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ventas',
            callback: (payload) {
              print('[CLIENTE_PROVIDER] ========================================');
              print('[CLIENTE_PROVIDER] EVENTO REALTIME EN VENTAS DETECTADO');
              print('[CLIENTE_PROVIDER] Tipo de evento: ${payload.eventType}');
              print('[CLIENTE_PROVIDER] Datos del evento: $payload');
              print('[CLIENTE_PROVIDER] ========================================');
              
              // Agregar un pequeño delay para asegurar que la transacción se complete
              Future.delayed(const Duration(milliseconds: 500), () {
                print('[CLIENTE_PROVIDER] Iniciando recarga de clientes tras cambio en ventas...');
                _loadClientes(page: state.currentPage, searchQuery: state.searchQuery, showLoading: false);
              });
            })
        .subscribe();
        
    print('[CLIENTE_PROVIDER] Listeners de tiempo real configurados exitosamente');
    print('[CLIENTE_PROVIDER] - Listener de clientes: ${_clienteChannel != null ? "ACTIVO" : "INACTIVO"}');
    print('[CLIENTE_PROVIDER] - Listener de ventas: ${_ventaChannel != null ? "ACTIVO" : "INACTIVO"}');
  }

  @override
  void dispose() {
    _clienteChannel?.unsubscribe();
    _ventaChannel?.unsubscribe();
    super.dispose();
  }
}

// --- El Provider Final ---
final clientesProvider = StateNotifierProvider<ClientesNotifier, ClientesState>((ref) {
  return ClientesNotifier(
      ref.watch(clienteRepositoryProvider), ref.watch(ventaRepositoryProvider));
});