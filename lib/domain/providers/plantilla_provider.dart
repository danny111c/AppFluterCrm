import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // <-- 1. IMPORTACIÓN AÑADIDA
import '../../domain/models/plantilla_model.dart';
import '../../infrastructure/repositories/plantilla_repository.dart';

final plantillaRepositoryProvider = Provider((ref) => PlantillaRepository());

class PlantillasState {
  final List<Plantilla> plantillas;
  final bool isLoading;
  PlantillasState({this.plantillas = const [], this.isLoading = false});
  PlantillasState copyWith({List<Plantilla>? plantillas, bool? isLoading}) {
    return PlantillasState(
      plantillas: plantillas ?? this.plantillas,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PlantillasNotifier extends StateNotifier<PlantillasState> {
  final Ref _ref;
  final PlantillaRepository _repo;
  RealtimeChannel? _realtimeChannel;
  bool _isLocalOperation = false;

  PlantillasNotifier(this._ref)
      : _repo = _ref.read(plantillaRepositoryProvider),
        super(PlantillasState()) {
    loadPlantillas();
    _subscribeToRealtime();
  }

  // ===== 2. MÉTODO HELPER DE LOGGING AÑADIDO =====
  void _log(String message) {
    if (kDebugMode) { // Solo imprime en modo de depuración
      print('[PlantillasNotifier] $message');
    }
  }

  Future<void> loadPlantillas({bool showLoading = true}) async {
    if (showLoading) state = state.copyWith(isLoading: true);
    try {
      final plantillas = await _repo.getPlantillas();
      if (!mounted) return;
      state = state.copyWith(plantillas: plantillas, isLoading: false);
      _log('Plantillas cargadas: ${plantillas.length} items.');
    } catch (e) {
      if (!mounted) return;
      _log('[ERROR] loadPlantillas: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addPlantilla(Plantilla plantilla) async {
    _isLocalOperation = true;
    try {
      final nuevaPlantillaConId = await _repo.addPlantilla(plantilla);
      if (!mounted) return;
      
      final newList = state.plantillas.where((p) => !p.id!.startsWith('temp_')).toList();
      newList.insert(0, nuevaPlantillaConId);
      state = state.copyWith(plantillas: newList);
    } catch(e) { rethrow;
    } finally {
      final completer = Completer();
      Timer(const Duration(milliseconds: 500), () {
        _isLocalOperation = false;
        completer.complete();
      });
      await completer.future;
    }
  }

  Future<void> updatePlantilla(Plantilla plantilla) async {
    _log("--- INICIO updatePlantilla ---");
    _log("Plantilla a actualizar: ${plantilla.nombre}, Contenido: ${plantilla.contenido}");
    _isLocalOperation = true;
    _log("_isLocalOperation = true");

    try {
      await _repo.updatePlantilla(plantilla);
      _log("✅ Repositorio completó updatePlantilla.");
      if (!mounted) {
        _log("⚠️ Notifier no montado después del repo. Abortando actualización local.");
        return;
      }
      
      final index = state.plantillas.indexWhere((p) => p.id == plantilla.id);
      if (index != -1) {
        _log("Encontrada plantilla en estado local en el índice $index. Actualizando UI localmente.");
        final newList = List<Plantilla>.from(state.plantillas);
        newList[index] = plantilla;
        state = state.copyWith(plantillas: newList);
        _log("✅ Estado local actualizado para PC1.");
      } else {
        _log("⚠️ No se encontró la plantilla en el estado local para actualizar. ID: ${plantilla.id}");
      }
    } catch(e) { 
      _log("❌ ERROR en updatePlantilla: $e");
      rethrow;
    } finally {
      _log("Entrando en 'finally' de updatePlantilla.");
      final completer = Completer();
      Timer(const Duration(milliseconds: 800), () {
        _isLocalOperation = false;
        _log("_isLocalOperation = false");
        completer.complete();
      });
      await completer.future;
      _log("--- FIN updatePlantilla ---");
    }
  }

  Future<void> deletePlantilla(String id) async {
    _isLocalOperation = true;
    try {
      await _repo.deletePlantilla(id);
      if (!mounted) return;
      
      state = state.copyWith(
        plantillas: state.plantillas.where((p) => p.id != id).toList(),
      );
    } catch(e) { rethrow;
    } finally {
      final completer = Completer();
      Timer(const Duration(milliseconds: 500), () {
        _isLocalOperation = false;
        completer.complete();
      });
      await completer.future;
    }
  }

  void _subscribeToRealtime() {
    _log("Intentando suscribir a Realtime channel 'public:plantillas'...");
    _realtimeChannel = Supabase.instance.client.channel('public:plantillas')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'plantillas',
        callback: (payload) {
          _log("--- INICIO CALLBACK REALTIME ---");
          _log("Evento recibido: ${payload.eventType}, Tabla: ${payload.table}");
          _log("Raw Payload: ${payload.toString()}");
          if (_isLocalOperation) {
            _log("IGNORANDO evento porque _isLocalOperation es TRUE.");
            _log("--- FIN CALLBACK REALTIME (IGNORADO) ---");
            return;
          }
          Future.microtask(() => _handleRealtimeChange(payload));
        },
      ).subscribe((status, [error]) {
         _log("Estado de la suscripción Realtime: $status");
         if(error != null) _log("❌ ERROR en suscripción Realtime: $error");
      });
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    _log("Procesando evento Realtime (PC2): ${payload.eventType}");
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final nuevaPlantilla = Plantilla.fromJson(payload.newRecord);
        if (state.plantillas.any((p) => p.id == nuevaPlantilla.id)) return;
        state = state.copyWith(plantillas: [nuevaPlantilla, ...state.plantillas]);
        break;

      case PostgresChangeEvent.update:
        _log("--> DETECTADO EVENTO UPDATE");
        final plantillaActualizada = Plantilla.fromJson(payload.newRecord);
        _log("    Plantilla del evento: ${plantillaActualizada.nombre}, Contenido: ${plantillaActualizada.contenido}");

        final index = state.plantillas.indexWhere((p) => p.id == plantillaActualizada.id);
        _log("    Buscando ID '${plantillaActualizada.id}' en estado local...");

        if (index != -1) {
          _log("    ✅ Encontrada en el índice $index. Procediendo a actualizar estado.");
          final oldPlantilla = state.plantillas[index];
          _log("       - Contenido ANTERIOR: ${oldPlantilla.contenido}");
          _log("       - Contenido NUEVO:    ${plantillaActualizada.contenido}");

          if (oldPlantilla == plantillaActualizada) {
            _log("    ⚠️ ADVERTENCIA: ¡El objeto antiguo y el nuevo son iguales según Equatable! La UI podría no actualizarse.");
          }

          final newList = List<Plantilla>.from(state.plantillas);
          newList[index] = plantillaActualizada;
          state = state.copyWith(plantillas: newList);
          _log("    ✅ Estado actualizado en PC2.");
        } else {
          _log("    ❌ ERROR: No se encontró la plantilla con ID '${plantillaActualizada.id}' en el estado local de PC2.");
        }
        break;

      case PostgresChangeEvent.delete:
        final idEliminado = payload.oldRecord['id'];
        if (!state.plantillas.any((p) => p.id == idEliminado)) return;
        state = state.copyWith(
          plantillas: state.plantillas.where((p) => p.id != idEliminado).toList(),
        );
        break;
      
      default:
        _log("Evento Realtime no manejado: ${payload.eventType}");
        break;
    }
    _log("--- FIN PROCESAMIENTO REALTIME ---");
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _log("Notifier disposed. Canal Realtime desuscrito.");
    super.dispose();
  }
}

final plantillasProvider = StateNotifierProvider.autoDispose<PlantillasNotifier, PlantillasState>((ref) {
  ref.keepAlive();
  return PlantillasNotifier(ref);
});