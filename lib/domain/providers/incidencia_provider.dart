import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/repositories/incidencia_repository.dart';
import '../models/incidencia_model.dart';

// Provider del repositorio
final incidenciaRepositoryProvider = Provider((ref) => IncidenciaRepository());

// StateNotifier para gestionar las incidencias de una venta/cuenta
class IncidenciasNotifier extends StateNotifier<AsyncValue<List<Incidencia>>> {
  final IncidenciaRepository _repo;
  final String? ventaId;
  final String? cuentaId;

// Modifica el constructor para que limpie antes de cargar
IncidenciasNotifier(this._repo, {this.ventaId, this.cuentaId}) : super(const AsyncValue.loading()) {
  cargarIncidencias();
}

Future<void> cargarIncidencias() async {
  // No pongas loading aquí si quieres que la UI sea más fluida, 
  // pero asegúrate de limpiar el estado anterior si el ID cambió.
  try {
    final lista = await _repo.getIncidenciasAbiertas(ventaId, cuentaId);
    state = AsyncValue.data(lista);
  } catch (e, stack) {
    state = AsyncValue.error(e, stack);
  }
}

  Future<void> crearIncidencia(String desc, bool pausar, bool cascada) async {
    await _repo.crearIncidencia(
      descripcion: desc,
      pausar: pausar,
      ventaId: ventaId,
      cuentaId: cuentaId,
      efectoCascada: cascada,
    );
    await cargarIncidencias();
  }

  Future<void> resolverIncidencia(String id) async {
    await _repo.resolverIncidencia(id);
    await cargarIncidencias();
  }
}

// Provider dinámico para usar en los diálogos
// Añadimos .autoDispose para que no guarde basura en memoria
final incidenciasFamily = StateNotifierProvider.autoDispose.family<IncidenciasNotifier, AsyncValue<List<Incidencia>>, String>((ref, idCombo) {
  final partes = idCombo.split(':');
  final tipo = partes[0];
  final id = partes[1];
  
  return IncidenciasNotifier(
    ref.read(incidenciaRepositoryProvider),
    ventaId: tipo == 'venta' ? id : null,
    cuentaId: tipo == 'cuenta' ? id : null,
  );
});