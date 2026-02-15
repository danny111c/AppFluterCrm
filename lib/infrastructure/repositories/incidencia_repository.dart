import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import '../../domain/models/incidencia_model.dart';
import 'package:flutter/material.dart';

class IncidenciaRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Incidencia>> getIncidenciasAbiertas(String? ventaId, String? cuentaId) async {
    var query = _supabase.from('incidencias').select().eq('estado', 'abierta');
    if (ventaId != null) query = query.eq('venta_id', ventaId);
    else if (cuentaId != null) query = query.eq('cuenta_id', cuentaId);
    else return [];

    final res = await query;
    return (res as List).map((i) => Incidencia.fromJson(i)).toList();
  }

  Future<void> crearIncidencia({
    String? ventaId,
    String? cuentaId,
    required String descripcion,
    required bool pausar,
    required String prioridad,
    bool efectoCascada = false,
  }) async {
    try {
      // 1. Insertar incidencia con flag de cascada
      await _supabase.from('incidencias').insert({
        if (ventaId != null) 'venta_id': ventaId,
        if (cuentaId != null) 'cuenta_id': cuentaId,
        'descripcion': descripcion,
        'congelar_tiempo': pausar,
        'prioridad': prioridad,
        'hubo_cascada': efectoCascada,
      });

      // 2. Lógica para VENTAS
      if (ventaId != null) {
        final Map<String, dynamic> vUpdates = {'problema_venta': descripcion, 'prioridad_actual': prioridad};
        if (pausar) {
          final res = await _supabase.from('ventas').select('fecha_pausa').eq('id', ventaId).single();
          vUpdates['is_paused'] = true;
          if (res['fecha_pausa'] == null) vUpdates['fecha_pausa'] = DateTime.now().toIso8601String();
        }
        await _supabase.from('ventas').update(vUpdates).eq('id', ventaId);
      } 
      // 3. Lógica para CUENTAS
      else if (cuentaId != null) {
        final Map<String, dynamic> cUpdates = {'problema_cuenta': descripcion, 'prioridad_actual': prioridad};
        if (pausar) {
          final res = await _supabase.from('cuentas').select('fecha_pausa').eq('id', cuentaId).single();
          cUpdates['is_paused'] = true;
          if (res['fecha_pausa'] == null) cUpdates['fecha_pausa'] = DateTime.now().toIso8601String();
        }
        await _supabase.from('cuentas').update(cUpdates).eq('id', cuentaId);

        if (efectoCascada) {
          final String ahora = DateTime.now().toIso8601String();
          // Solo pausar las que no tengan pausa previa para no sobreescribir el Día 1
          await _supabase.from('ventas').update({
            'problema_venta': descripcion,
            'prioridad_actual': prioridad,
            'is_paused': true,
            'fecha_pausa': ahora,
          }).eq('cuenta_id', cuentaId).filter('fecha_pausa', 'is', null);
        }
      }
    } catch (e) {
      debugPrint("🚨 ERROR REPO: $e");
      rethrow;
    }
  }

  // ✅ Recibe p_dias_principal y p_dias_cascada
  Future<void> resolverIncidencia(String incidenciaId, int diasPrincipal, int diasCascada) async {
    await _supabase.rpc('resolver_incidencia_y_compensar', params: {
      'p_incidencia_id': incidenciaId,
      'p_dias_principal': diasPrincipal,
      'p_dias_cascada': diasCascada,
    });
  }
 Future<void> resolverGrupoSoporte({
  required String id,
  required bool esCuenta,
  required int diasP,
  required int diasC,
}) async {
  await _supabase.rpc('resolver_grupo_soporte', params: {
    'p_id_sujeto': id,
    'p_es_cuenta': esCuenta,
    'p_dias_principal': diasP,
    'p_dias_cascada': diasC,
  });
}
}