// ===== CÓDIGO CORREGIDO Y COMPLETO PARA tipo_cuenta_provider.dart =====

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/tipo_cuenta_model.dart';
import '../../infrastructure/repositories/tipo_cuenta_repository.dart';

// --- 1. Provider para el Repositorio (buena práctica) ---
final tipoCuentaRepositoryProvider = Provider((ref) => TipoCuentaRepository());

// --- 2. Clase de Estado (no cambia) ---
class TiposCuentaState {
  final List<TipoCuenta> tiposCuenta;
  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final String? searchQuery;

  TiposCuentaState({
    this.tiposCuenta = const [],
    this.isLoading = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalCount = 0,
    this.searchQuery,
  });

  TiposCuentaState copyWith({
    List<TipoCuenta>? tiposCuenta,
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    String? searchQuery,
  }) {
    return TiposCuentaState(
      tiposCuenta: tiposCuenta ?? this.tiposCuenta,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// --- 3. Notifier Corregido y Conectado ---
class TiposCuentaNotifier extends StateNotifier<TiposCuentaState> {
  // Se elimina el repo del constructor y se añade Ref
  final Ref _ref;
  late final TipoCuentaRepository _repo;
  RealtimeChannel? _realtimeChannel;
  bool _isLocalOperation = false;

  // Se modifica el constructor para aceptar 'ref'
  TiposCuentaNotifier(this._ref) : super(TiposCuentaState()) {
    _repo = _ref.read(tipoCuentaRepositoryProvider); // Se lee el repo desde el ref
    print('[PROVIDER] TiposCuentaNotifier creado');
    _subscribeToRealtime();
    loadTiposCuenta(); // Se añade la carga inicial
  }

  // El resto de tus métodos (add, update, delete, load, etc.) están perfectos
  // y no necesitan cambios, así que los dejamos como los tienes.

  void _subscribeToRealtime() {
    print('[PROVIDER] Suscribiendo a Realtime tipos_cuenta...');
    final supabase = Supabase.instance.client;
    _realtimeChannel = supabase.channel('public:tipos_cuenta')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tipos_cuenta',
        callback: (payload) {
          print('[PROVIDER] Evento Realtime recibido (raw): $payload');
          try {
            Future.microtask(() {
              _handleRealtimeChange(payload);
            });
          } catch (e) {
            print('[PROVIDER] Error en callback Realtime: $e');
          }
        },
      )
      ..subscribe();
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    print('[PROVIDER] Procesando cambio Realtime: ${payload.eventType}');

    if (_isLocalOperation) {
      print('[PROVIDER] Ignorando evento Realtime - operación local en progreso');
      return;
    }
    
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final nuevoTipoCuenta = TipoCuenta.fromJson(payload.newRecord);
        if (!state.tiposCuenta.any((tc) => tc.id == nuevoTipoCuenta.id)) {
            final newList = [nuevoTipoCuenta, ...state.tiposCuenta];
            state = state.copyWith(
                tiposCuenta: newList,
                totalCount: state.totalCount + 1,
            );
        }
        break;

      case PostgresChangeEvent.update:
        final tipoCuentaActualizado = TipoCuenta.fromJson(payload.newRecord);
        if (tipoCuentaActualizado.deletedAt != null) {
            final newList = state.tiposCuenta.where((tc) => tc.id != tipoCuentaActualizado.id).toList();
            state = state.copyWith(
                tiposCuenta: newList,
                totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
            );
        } else {
            final index = state.tiposCuenta.indexWhere((tc) => tc.id == tipoCuentaActualizado.id);
            if (index != -1) {
                final newList = List<TipoCuenta>.from(state.tiposCuenta);
                newList[index] = tipoCuentaActualizado;
                state = state.copyWith(tiposCuenta: newList);
            }
        }
        break;

      case PostgresChangeEvent.delete:
        final deletedId = payload.oldRecord['id'];
        final newList = state.tiposCuenta.where((tc) => tc.id != deletedId).toList();
        state = state.copyWith(
            tiposCuenta: newList,
            totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
        );
        break;
        
      default:
        break;
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> addTipoCuenta(TipoCuenta tipoCuenta) async {
    print('[PROVIDER] addTipoCuenta llamado: $tipoCuenta');
    _isLocalOperation = true;
    try {
      final nuevoTipoCuenta = await _repo.addTipoCuenta(tipoCuenta);
      final newList = [nuevoTipoCuenta, ...state.tiposCuenta];
      state = state.copyWith(
          tiposCuenta: newList,
          totalCount: state.totalCount + 1,
      );
      print('[PROVIDER] Tipo de cuenta agregado y estado local actualizado');
    } catch (e, stack) {
      print('[PROVIDER][ERROR] addTipoCuenta: $e\n$stack');
      rethrow;
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLocalOperation = false;
      });
    }
  }

Future<void> updateTipoCuenta(TipoCuenta tipoCuenta) async {
  print('[PROVIDER] updateTipoCuenta llamado: $tipoCuenta');
  _isLocalOperation = true;
  try {
    await _repo.updateTipoCuenta(tipoCuenta);
    
    final index = state.tiposCuenta.indexWhere((tc) => tc.id == tipoCuenta.id);
    if (index != -1) {
        final newList = List<TipoCuenta>.from(state.tiposCuenta);
        newList[index] = tipoCuenta;

        // AÑADE ESTE PRINT DE DEPURACIÓN
        print('✅ EMISOR: ¡EMITIENDO NUEVO ESTADO PARA TIPOS DE CUENTA!');
        
        state = state.copyWith(tiposCuenta: newList);
    }
    print('[PROVIDER] Tipo de cuenta actualizado y estado local actualizado');

  } catch (e, stack) {
    print('[PROVIDER][ERROR] updateTipoCuenta: $e\n$stack');
    rethrow;
  } finally {
    Future.delayed(const Duration(milliseconds: 500), () {
      _isLocalOperation = false;
    });
  }
}

  // ===== AÑADE ESTE NUEVO MÉTODO =====
  /// Verifica si un tipo de cuenta tiene cuentas activas asociadas.
  /// Delega la llamada al repositorio.
  Future<bool> tieneCuentasAsociadas(String tipoCuentaId) async {
    try {
      // Llama al método del repositorio que ya tienes.
      return await _repo.tieneCuentasAsociadas(tipoCuentaId);
    } catch (e) {
      print('[PROVIDER][ERROR] tieneCuentasAsociadas: $e');
      // En caso de error, es más seguro asumir que sí tiene para prevenir borrados accidentales.
      return true; 
    }
  }

  Future<void> deleteTipoCuenta(String id) async {
    print('[PROVIDER] deleteTipoCuenta llamado: $id');
    _isLocalOperation = true;
    try {
      await _repo.deleteTipoCuenta(id);
      final newList = state.tiposCuenta.where((tc) => tc.id != id).toList();
      state = state.copyWith(
          tiposCuenta: newList,
          totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
      );
      print('[PROVIDER] Tipo de cuenta eliminado y estado local actualizado');
    } catch (e, stack) {
      print('[PROVIDER][ERROR] deleteTipoCuenta: $e\n$stack');
      rethrow;
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLocalOperation = false;
      });
    }
  }

  Future<void> loadTiposCuenta({int page = 1, String? searchQuery, bool showLoading = true}) async {
    print('[PROVIDER] loadTiposCuenta llamado (page=$page, searchQuery=$searchQuery, showLoading=$showLoading)');
    if (showLoading) {
      state = state.copyWith(isLoading: true, currentPage: page, searchQuery: searchQuery);
    } else {
      state = state.copyWith(currentPage: page, searchQuery: searchQuery);
    }
    try {
      final totalCount = await _repo.getTiposCuentaCount(searchQuery: searchQuery);
      final totalPages = (totalCount / 10).ceil();
      final tiposCuenta = await _repo.getTiposCuenta(page: page, perPage: 10, searchQuery: searchQuery);
      state = state.copyWith(
        tiposCuenta: tiposCuenta,
        isLoading: false,
        currentPage: page,
        totalPages: totalPages > 0 ? totalPages : 1,
        totalCount: totalCount,
      );
    } catch (e, stack) {
      print('[PROVIDER][ERROR] loadTiposCuenta: $e\n$stack');
      state = state.copyWith(isLoading: false);
    }
  }

  void search(String? query) {
    loadTiposCuenta(page: 1, searchQuery: query);
  }
}

// --- 4. El Provider Final Modificado ---
final tiposCuentaProvider = StateNotifierProvider.autoDispose<TiposCuentaNotifier, TiposCuentaState>((ref) {
  // Con autoDispose, es bueno mantener el estado vivo si tiene oyentes.
  ref.keepAlive(); 
  return TiposCuentaNotifier(ref);
});