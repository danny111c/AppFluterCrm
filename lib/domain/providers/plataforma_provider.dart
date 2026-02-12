import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/plataforma_model.dart';
import '../../infrastructure/repositories/plataforma_repository.dart';

final plataformaRepositoryProvider = Provider((ref) => PlataformaRepository());


class PlataformasState {
  final List<Plataforma> plataformas;
  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final String? searchQuery;

  PlataformasState({
    this.plataformas = const [],
    this.isLoading = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalCount = 0,
    this.searchQuery,
  });

  PlataformasState copyWith({
    List<Plataforma>? plataformas,
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    String? searchQuery,
  }) {
    return PlataformasState(
      plataformas: plataformas ?? this.plataformas,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// --- 3. Notifier Corregido y Conectado ---
class PlataformasNotifier extends StateNotifier<PlataformasState> {
  // Se elimina el repo del constructor y se añade Ref
  final Ref _ref;
  late final PlataformaRepository _repo;
  RealtimeChannel? _realtimeChannel;
  bool _isLocalOperation = false;

  // Se modifica el constructor para aceptar 'ref'
  PlataformasNotifier(this._ref) : super(PlataformasState()) {
    _repo = _ref.read(plataformaRepositoryProvider); // Se lee el repo desde el ref
    print('[PROVIDER] PlataformasNotifier creado');
    _subscribeToRealtime();
    loadPlataformas(); // Se añade la carga inicial
  }

  void _subscribeToRealtime() {
    print('[PROVIDER] Suscribiendo a Realtime plataformas...');
    final supabase = Supabase.instance.client;
    _realtimeChannel = supabase.channel('public:plataformas')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'plataformas',
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
        final nuevaPlataforma = Plataforma.fromJson(payload.newRecord);
        // Añade el nuevo elemento solo si no está ya en la lista
        if (!state.plataformas.any((p) => p.id == nuevaPlataforma.id)) {
            final newList = [nuevaPlataforma, ...state.plataformas];
            state = state.copyWith(
                plataformas: newList,
                totalCount: state.totalCount + 1,
            );
        }
        break;

      case PostgresChangeEvent.update:
        final plataformaActualizada = Plataforma.fromJson(payload.newRecord);
        // Si el elemento actualizado tiene un 'deleted_at', trátalo como un borrado (soft delete).
        if (plataformaActualizada.deletedAt != null) {
            final newList = state.plataformas.where((p) => p.id != plataformaActualizada.id).toList();
            state = state.copyWith(
                plataformas: newList,
                totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
            );
        } else {
            // Si es una actualización normal, busca y reemplaza.
            final index = state.plataformas.indexWhere((p) => p.id == plataformaActualizada.id);
            if (index != -1) {
                final newList = List<Plataforma>.from(state.plataformas);
                newList[index] = plataformaActualizada;
                state = state.copyWith(plataformas: newList);
            }
        }
        break;

      case PostgresChangeEvent.delete: // Para Hard Delete
        final deletedId = payload.oldRecord['id'];
        final newList = state.plataformas.where((p) => p.id != deletedId).toList();
        state = state.copyWith(
            plataformas: newList,
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

  Future<void> addPlataforma(Plataforma plataforma) async {
    print('[PROVIDER] addPlataforma llamado: $plataforma');
    _isLocalOperation = true;
    try {
      // 1. Llama al repo, que te debería devolver la plataforma creada con su ID
      final nuevaPlataforma = await _repo.addPlataforma(plataforma);
      
      // 2. Actualiza el estado localmente, sin recargar toda la lista
      final newList = [nuevaPlataforma, ...state.plataformas];
      state = state.copyWith(
          plataformas: newList,
          totalCount: state.totalCount + 1,
      );
      print('[PROVIDER] Plataforma agregada y estado local actualizado');

    } catch (e, stack) {
      print('[PROVIDER][ERROR] addPlataforma: $e\n$stack');
      rethrow;
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLocalOperation = false;
      });
    }
  }

  Future<void> updatePlataforma(Plataforma plataforma) async {
    print('[PROVIDER] updatePlataforma llamado: $plataforma');
    _isLocalOperation = true;
    try {
      await _repo.updatePlataforma(plataforma);
      
      // Actualiza el estado localmente
      final index = state.plataformas.indexWhere((p) => p.id == plataforma.id);
      if (index != -1) {
          final newList = List<Plataforma>.from(state.plataformas);
          newList[index] = plataforma;
          state = state.copyWith(plataformas: newList);
      }
      print('[PROVIDER] Plataforma actualizada y estado local actualizado');

    } catch (e, stack) {
      print('[PROVIDER][ERROR] updatePlataforma: $e\n$stack');
      rethrow;
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLocalOperation = false;
      });
    }
  }

  Future<void> deletePlataforma(String id) async {
    print('[PROVIDER] deletePlataforma llamado: $id');
    _isLocalOperation = true;
    try {
      await _repo.deletePlataforma(id);

      // Actualiza el estado localmente
      final newList = state.plataformas.where((p) => p.id != id).toList();
      state = state.copyWith(
          plataformas: newList,
          totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
      );
      print('[PROVIDER] Plataforma eliminada y estado local actualizado');

    } catch (e, stack) {
      print('[PROVIDER][ERROR] deletePlataforma: $e\n$stack');
      rethrow;
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLocalOperation = false;
      });
    }
    
  }
    // ===== AÑADE ESTE NUEVO MÉTODO =====
  /// Verifica si una plataforma tiene cuentas activas asociadas.
  Future<bool> tieneCuentasAsociadas(String plataformaId) async {
    try {
      return await _repo.tieneCuentasAsociadas(plataformaId);
    } catch (e) {
      print('[PROVIDER][ERROR] tieneCuentasAsociadas: $e');
      return true; 
    }
  }

  Future<void> loadPlataformas({int page = 1, String? searchQuery, bool showLoading = true}) async {
    print('[PROVIDER] loadPlataformas llamado (page=$page, searchQuery=$searchQuery, showLoading=$showLoading)');
    if (showLoading) {
      state = state.copyWith(isLoading: true, currentPage: page, searchQuery: searchQuery);
    } else {
      state = state.copyWith(currentPage: page, searchQuery: searchQuery);
    }
    try {
      final totalCount = await _repo.getPlataformasCount(searchQuery: searchQuery);
      print('[PROVIDER] loadPlataformas - totalCount: $totalCount');
      final totalPages = (totalCount / 10).ceil();
      final plataformas = await _repo.getPlataformas(page: page, perPage: 10, searchQuery: searchQuery);
      print('[PROVIDER] loadPlataformas - plataformas recibidas: ${plataformas.length}');
      state = state.copyWith(
        plataformas: plataformas,
        isLoading: false,
        currentPage: page,
        totalPages: totalPages > 0 ? totalPages : 1,
        totalCount: totalCount,
      );
    } catch (e, stack) {
      print('[PROVIDER][ERROR] loadPlataformas: $e\n$stack');
      state = state.copyWith(isLoading: false);
    }
  }

  void search(String? query) {
    loadPlataformas(page: 1, searchQuery: query);
  }
}
// --- 4. El Provider Final Modificado ---
final plataformasProvider = StateNotifierProvider.autoDispose<PlataformasNotifier, PlataformasState>((ref) {
  // Mantiene el provider vivo para que sus oyentes (CuentasNotifier) lo reciban
  ref.keepAlive();
  // Ahora el Notifier recibe 'ref'
  return PlataformasNotifier(ref);
});
