import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/repositories/incidencia_repository.dart';
import '../models/incidencia_model.dart';

final incidenciaRepositoryProvider = Provider((ref) => IncidenciaRepository());

class IncidenciasNotifier extends StateNotifier<AsyncValue<List<Incidencia>>> {
  final IncidenciaRepository _repo;
  final String? ventaId;
  final String? cuentaId;

  IncidenciasNotifier(this._repo, {this.ventaId, this.cuentaId}) : super(const AsyncValue.loading()) {
    cargarIncidencias();
  }

  Future<void> cargarIncidencias() async {
    try {
      final lista = await _repo.getIncidenciasAbiertas(ventaId, cuentaId);
      state = AsyncValue.data(lista);
    } catch (e, stack) {
            if (!mounted) return; // <--- AÑADE ESTA TAMBIÉN

      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> crearIncidencia(String desc, bool pausar, bool cascada, String prioridad) async {
    await _repo.crearIncidencia(
      descripcion: desc,
      pausar: pausar,
      ventaId: ventaId,
      cuentaId: cuentaId,
      efectoCascada: cascada,
      prioridad: prioridad,
    );
    await cargarIncidencias();
  }

  Future<void> resolverIncidencia(String id, int dP, int dC) async {
    await _repo.resolverIncidencia(id, dP, dC);
    await cargarIncidencias();
  }

  // ✅ NUEVO MÉTODO PARA EL CIERRE MASIVO
  Future<void> resolverGrupoSoporteMasivo({
    required String id,
    required bool esCuenta,
    required int diasP,
    required int diasC,
  }) async {
    await _repo.resolverGrupoSoporte(
      id: id,
      esCuenta: esCuenta,
      diasP: diasP,
      diasC: diasC,
    );
    await cargarIncidencias();
  }
}

final incidenciasFamily = StateNotifierProvider.autoDispose.family<IncidenciasNotifier, AsyncValue<List<Incidencia>>, String>((ref, idCombo) {
  final partes = idCombo.split(':');
  return IncidenciasNotifier(
    ref.read(incidenciaRepositoryProvider),
    ventaId: partes[0] == 'venta' ? partes[1] : null,
    cuentaId: partes[0] == 'cuenta' ? partes[1] : null,
  );
});