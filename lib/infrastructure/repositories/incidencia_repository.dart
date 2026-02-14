import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import '../../domain/models/incidencia_model.dart';

class IncidenciaRepository {
  final _supabase = Supabase.instance.client;

  // Obtener incidencias abiertas
  Future<List<Incidencia>> getIncidenciasAbiertas(String? ventaId, String? cuentaId) async {
    var query = _supabase.from('incidencias').select().eq('estado', 'abierta');

    if (ventaId != null) {
      query = query.eq('venta_id', ventaId);
    } else if (cuentaId != null) {
      query = query.eq('cuenta_id', cuentaId);
    } else {
      return [];
    }

    final res = await query;
    return (res as List).map((i) => Incidencia.fromJson(i)).toList();
  }

  // Crear reporte (LÓGICA CORREGIDA)
  Future<void> crearIncidencia({
    String? ventaId,
    String? cuentaId,
    required String descripcion,
    required bool pausar,
    bool efectoCascada = false,
  }) async {
    
    // 1. Insertar la incidencia en el historial (Siempre se hace)
    await _supabase.from('incidencias').insert({
      if (ventaId != null) 'venta_id': ventaId,
      if (cuentaId != null) 'cuenta_id': cuentaId,
      'descripcion': descripcion,
      'congelar_tiempo': pausar,
    });

    // 2. Actualizar Tabla VENTAS
    if (ventaId != null) {
      // Creamos un mapa base solo con el texto (esto siempre se actualiza)
      final Map<String, dynamic> datosActualizar = {
        'problema_venta': descripcion, 
      };

      // SOLO si el usuario marcó PAUSAR, añadimos los campos de pausa
      if (pausar) {
        datosActualizar['is_paused'] = true;
        datosActualizar['fecha_pausa'] = DateTime.now().toIso8601String();
      }
      // NOTA: Si pausar es false, NO enviamos 'is_paused', así no se activa accidentalmente.

      await _supabase.from('ventas').update(datosActualizar).eq('id', ventaId);
    } 
    
    // 3. Actualizar Tabla CUENTAS
    else if (cuentaId != null) {
      // Mapa base
      final Map<String, dynamic> datosActualizar = {
        'problema_cuenta': descripcion,
      };

      if (pausar) {
        datosActualizar['is_paused'] = true;
        datosActualizar['fecha_pausa'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('cuentas').update(datosActualizar).eq('id', cuentaId);

      // Efecto Cascada (Solo aplica si marcaste pausar Y cascada)
      if (pausar && efectoCascada) {
        await _supabase.from('ventas').update({
          'is_paused': true,
          'fecha_pausa': DateTime.now().toIso8601String(),
        }).eq('cuenta_id', cuentaId);
      }
    }
  }

  // Resolver incidencia
  Future<void> resolverIncidencia(String incidenciaId) async {
    await _supabase.rpc('resolver_incidencia_y_compensar', params: {
      'p_incidencia_id': incidenciaId,
    });
  }
}