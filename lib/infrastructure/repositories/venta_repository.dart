import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/venta_model.dart';
import '../supabase_config.dart';
import '../../domain/models/cuenta_model.dart';

class VentaRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

 Future<List<Venta>> getVentas({
    int page = 1,
    int perPage = 10,
    String? searchQuery,
    String? cuentaId,
    bool sortByRecent = false,
    String orderBy = 'fecha_final',
    bool orderDesc = false,
  }) async {
    try {
      final offset = (page - 1) * perPage;
      
      // LOG 1: Ver qué estamos enviando
      final cleanQuery = (searchQuery == "null" || searchQuery == "") ? null : searchQuery;
      print('📡 [REPO-VENTAS] Llamando RPC con query: $cleanQuery, cuentaId: $cuentaId, offset: $offset');

      final response = await _supabase.rpc(
        'get_ventas_con_datos',
        params: {
          'search_query': cleanQuery,
          'filtro_cuenta_id': cuentaId,
          'page_limit': perPage,
          'page_offset': offset,
          'order_by': orderBy,
          'order_desc': orderDesc,
        },
      );

      // LOG 2: Ver la respuesta cruda de Supabase
      print('📥 [REPO-VENTAS] Respuesta recibida (Tipo: ${response.runtimeType})');
      
      if (response == null) {
        print('⚠️ [REPO-VENTAS] La respuesta es NULA');
        return [];
      }

      final responseList = response as List<dynamic>;
      print('📊 [REPO-VENTAS] Cantidad de registros crudos: ${responseList.length}');

      if (responseList.isEmpty) {
        print('ℹ️ [REPO-VENTAS] La lista está vacía en la base de datos.');
        return [];
      }

      final List<Venta> ventasFinales = [];

      // LOG 3: Ver fallos en filas individuales
      for (var i = 0; i < responseList.length; i++) {
        try {
          final venta = Venta.fromJson(responseList[i] as Map<String, dynamic>);
          ventasFinales.add(venta);
        } catch (e) {
          print('❌ [REPO-VENTAS] Error en FILA #$i: $e');
          print('📄 [REPO-VENTAS] Contenido de la fila con error: ${responseList[i]}');
        }
      }

      print('✅ [REPO-VENTAS] Mapeo completado. Ventas listas: ${ventasFinales.length}');
      return ventasFinales;

    } catch (e) {
      print('🚨 [REPO-VENTAS] ERROR CRÍTICO EN RPC: $e');
      rethrow;
    }
  }

// 1. Añade esta nueva función para obtener los perfiles disponibles
Future<List<Map<String, dynamic>>> getPerfilesDisponibles(String cuentaId) async {
  final response = await _supabase
      .from('perfiles')
      .select()
      .eq('cuenta_id', cuentaId)
      .eq('estado', 'disponible')
      .order('nombre_perfil', ascending: true);
  return List<Map<String, dynamic>>.from(response);
}

  Future<int> getVentasCount({
    String? searchQuery,
    String? cuentaId,
    bool sortByRecent = false,
    String orderBy = 'fecha_final',
    bool orderDesc = false,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_ventas_con_datos',
        params: {
          'search_query': searchQuery,
          'filtro_cuenta_id': cuentaId, // ⬅️ Agregado
          'page_limit': 10000,
          'page_offset': 0,
          'order_by': orderBy,
          'order_desc': orderDesc,
        },
      );

      return (response as List<dynamic>).length;
    } catch (e) {
      print('[ERROR] getVentasCount: $e');
      rethrow;
    }
  }
// 2. Actualiza tu método addVenta para que sincronice con la tabla perfiles
// ACTUALIZA addVenta
// ACTUALIZA el método addVenta
// 1. ACTUALIZA addVenta (Le pasamos el id del perfil seleccionado)
// CAMBIO: Quita el 'required' y ponle el signo '?' a String
Future<void> addVenta(Venta venta, {String? perfilId}) async {
  try {
    // Usamos el ID que viene en la venta o el que pasan por parámetro
    final idReal = perfilId ?? venta.perfilId; 

    final dataToInsert = venta.toJson();
    dataToInsert['perfil_id'] = idReal; // ✅ Forzamos que el ID vaya a Supabase
    dataToInsert.remove('id');
    
    // 1. Insertar la venta
    await _supabase.from('ventas').insert(dataToInsert);
    
    // 2. Restar stock global
    await _supabase.rpc('decrementar_perfil_cuenta', params: {'cuenta_id': venta.cuenta.id!});

    // 3. Sincronizar Perfil Maestro
    if (idReal != null) {
      await _supabase.from('perfiles').update({
        'estado': 'ocupado',
        'pin': venta.pin,
        'nombre_perfil': venta.perfilAsignado
      }).eq('id', idReal);
    }
  } catch (e) {
    print('🚨 ERROR addVenta: $e');
    rethrow;
  }
}

Future<bool> updateVenta(Venta venta, {String? perfilId}) async {
  if (venta.id == null) return false;
  try {
    final idReal = perfilId ?? venta.perfilId;

    final dataToUpdate = venta.toJson();
    dataToUpdate['perfil_id'] = idReal; // ✅ Aseguramos el vínculo

    // 1. Actualizar venta
    await _supabase.from('ventas').update(dataToUpdate).eq('id', venta.id!);

    // 2. Sincronizar Perfil Maestro
    if (idReal != null) {
      await _supabase.from('perfiles').update({
        'pin': venta.pin,
        'nombre_perfil': venta.perfilAsignado 
      }).eq('id', idReal);
    }
    return true;
  } catch (e) {
    print('🚨 ERROR updateVenta: $e');
    rethrow;
  }
}

// 3. Modificar el borrado para que el perfil vuelva a estar disponible
Future<void> deleteVentaConObjeto(Venta venta) async {
  try {
    print('[VENTA_REPOSITORY] Iniciando eliminación de venta ID: ${venta.id}');

    // 1. Borrado lógico de la venta
    await _supabase.rpc('soft_delete_venta_con_stock', params: {
      'venta_id': venta.id!,
    });

    // 2. REGRESO AL STOCK USANDO EL ID (No el nombre)
    if (venta.perfilId != null) {
      // ✅ PLAN A: Usar el ID único (Infalible)
      await _supabase.from('perfiles')
          .update({'estado': 'disponible'})
          .eq('id', venta.perfilId!);
      print('✅ Perfil liberado usando ID.');
    } else if (venta.perfilAsignado != null) {
      // ⚠️ PLAN B: Fallback por nombre (solo para ventas viejas que no tengan perfil_id)
      await _supabase.from('perfiles')
          .update({'estado': 'disponible'})
          .eq('cuenta_id', venta.cuenta.id!)
          .eq('nombre_perfil', venta.perfilAsignado!.trim());
      print('⚠️ Perfil liberado usando Nombre (Venta antigua).');
    }
  } catch (e) {
    print('[ERROR] deleteVentaConObjeto: $e');
    rethrow;
  }
}
  /// Obtiene las ventas eliminadas (soft delete)
  Future<List<Venta>> getVentasEliminadas({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final start = (page - 1) * perPage;
      final end = start + perPage - 1;

      final response = await _supabase
          .from('ventas')
          .select(
            '*, '
            'clientes(*), '
            'cuentas(*, '
              'plataformas(*), '
              'tipos_cuenta(*), '
              'proveedores(*)'
            ')'
          )
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false)
          .range(start, end);
      
      return (response as List<dynamic>)
          .map<Venta>((json) => Venta.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[ERROR] getVentasEliminadas: $e');
      rethrow;
    }
  }

  /// Restaura una venta eliminada (soft delete)
  Future<void> restaurarVenta(String id) async {
    try {
      // Usar función SQL que maneja tanto la restauración como el decremento de stock
      await _supabase.rpc('restaurar_venta_con_stock', params: {
        'venta_id': id,
      });
    } catch (e) {
      print('[ERROR] restaurarVenta: $e');
      rethrow;
    }
  }

  /// Elimina permanentemente una venta (hard delete)
  Future<void> eliminarPermanentemente(String id) async {
    try {
      await _supabase
          .from('ventas')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('[ERROR] eliminarPermanentemente: $e');
      rethrow;
    }
  }

  Future<void> reportarProblema({
    required String ventaId, 
    required String problema,
    required bool afectaATodas,
    required String cuentaId
  }) async {
    try {
      await _supabase
        .from('ventas')
        .update({'problema': problema, 'fecha_reporte': DateTime.now().toIso8601String()})
        .eq(afectaATodas ? 'cuenta_id' : 'id', afectaATodas ? cuentaId : ventaId);
    } catch (e) {
      print('[ERROR] reportarProblema: $e');
      rethrow;
    }
  }
  /// Devuelve el número de ventas asociadas a un ID de cuenta específico.
  Future<int> getVentasCountByCuentaId(String cuentaId) async {
    try {
      final response = await _supabase
        .from('ventas')
        .select('id')
        .eq('cuenta_id', cuentaId)
        .isFilter('deleted_at', null)
        .count(CountOption.exact);
      
      return response.count;
    } catch (e) {
      print('[ERROR] getVentasCountByCuentaId: $e');
      rethrow;
    }
  }

  /// Devuelve el número de ventas asociadas a un ID de cliente específico.
  Future<int> getVentasCountByClienteId(String clienteId) async {
    try {
      final response = await _supabase
        .from('ventas')
        .select('id')
        .eq('cliente_id', clienteId)
        .isFilter('deleted_at', null)
        .count(CountOption.exact);
      
      return response.count;
    } catch (e) {
      print('[ERROR] getVentasCountByClienteId: $e');
      rethrow;
    }
  }

  /// Verifica si ya existe un perfil con el mismo nombre en ventas activas
  /// Excluye la venta actual si se proporciona ventaId (para ediciones)
  Future<bool> existePerfilDuplicado(String nombrePerfil, String cuentaId, {String? ventaId}) async {
    try {
      var query = _supabase
        .from('ventas')
        .select('id')
        .eq('perfil_asignado', nombrePerfil.trim())
        .eq('cuenta_id', cuentaId)  // Filtrar por cuenta específica
        .isFilter('deleted_at', null);
      
      // Si estamos editando una venta, excluirla de la búsqueda
      if (ventaId != null) {
        query = query.neq('id', ventaId);
      }
      
      final response = await query.count(CountOption.exact);
      
      print('[VENTA_REPOSITORY] Verificando perfil duplicado: "$nombrePerfil"');
      print('[VENTA_REPOSITORY] Ventas encontradas con ese perfil: ${response.count}');
      
      return response.count > 0;
    } catch (e) {
      print('[ERROR] existePerfilDuplicado: $e');
      rethrow;
    }
  }

  // Obtener TODOS los perfiles de una cuenta (para el inventario)
Future<List<Map<String, dynamic>>> getTodosLosPerfilesDeCuenta(String cuentaId) async {
  final response = await _supabase
      .from('perfiles')
      .select()
      .eq('cuenta_id', cuentaId)
      .order('nombre_perfil', ascending: true);
  return List<Map<String, dynamic>>.from(response);
}

// Actualizar un PIN o Nombre de perfil manualmente
Future<void> actualizarPerfilMaestro(String perfilId, String nuevoNombre, String nuevoPin) async {
  // 1. Actualizamos el Maestro (Tabla perfiles)
  await _supabase.from('perfiles').update({
    'nombre_perfil': nuevoNombre,
    'pin': nuevoPin,
  }).eq('id', perfilId);

  // 2. OPCIONAL PERO RECOMENDADO: Actualizar las ventas activas que usan este perfil
  // Esto hará que el cambio se vea inmediatamente en la pantalla de Ventas
  await _supabase.from('ventas').update({
    'perfil_asignado': nuevoNombre,
    'pin_perfil': nuevoPin,
  }).eq('perfil_asignado', nuevoNombre); // O busca por una relación más exacta si la tienes
  
  print('✅ Perfil Maestro y Ventas sincronizadas.');
}





///////////////////////////////
Future<List<Venta>> getVentasActivasPorCliente(String clienteId) async {
  try {
    // Usamos tu RPC para traer los datos ya procesados (nombres, pins, etc)
    final response = await _supabase.rpc(
      'get_ventas_con_datos',
      params: {
        'search_query': null,
        'filtro_cuenta_id': null,
        'page_limit': 100, // Traemos todas las ventas del cliente
        'page_offset': 0,
      },
    );

    final responseList = response as List<dynamic>;
    
    // Filtramos para quedarnos solo con las de este cliente
    return responseList
        .where((json) => json['cliente_id'] == clienteId)
        .map<Venta>((json) => Venta.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print('🚨 [ERROR REPO] getVentasActivasPorCliente: $e');
    return [];
  }
}


// ✅ Método para Devoluciones a Clientes (Registra monto negativo en historial de VENTAS)
  Future<void> registrarDevolucionVenta({required Venta venta, required double montoADevolver}) async {
    try {
      await _supabase.from('historial_transacciones_ventas').insert({
        'venta_id': venta.id,
        'cliente_id': venta.cliente.id,
        'cuenta_id': venta.cuenta.id,
        'monto_transaccion': -montoADevolver, // Valor negativo para el balance
        'tipo_registro': 'Devolucion',
        'fecha_transaccion': DateTime.now().toIso8601String(),
        'periodo_inicio_servicio': venta.fechaInicio,
        'periodo_fin_servicio': venta.fechaFinal,
        'cliente_nombre_historico': venta.cliente.nombre,
        'cliente_contacto_historico': venta.cliente.contacto,
        'cuenta_correo_historico': venta.cuenta.correo,
        'plataforma_nombre_historico': venta.cuenta.plataforma.nombre,
        'perfil_historico': venta.perfilAsignado,
      });
      print('✅ Devolución de venta registrada en historial');
    } catch (e) {
      print('🚨 Error en registrarDevolucionVenta: $e');
      rethrow;
    }
  }

  // ✅ Método para Devoluciones de Proveedores (Registra monto negativo en historial de CUENTAS)
  Future<void> registrarDevolucionProveedor({required Cuenta cuenta, required double montoRecuperado}) async {
    try {
      await _supabase.from('historial_renovaciones_cuentas').insert({
        'cuenta_id': cuenta.id,
        'monto_gastado': -montoRecuperado, // Valor negativo para restar del gasto total
        'tipo_registro': 'Devolucion Proveedor',
        'fecha_gasto': DateTime.now().toIso8601String(),
        'periodo_inicio': cuenta.fechaInicio,
        'periodo_fin': cuenta.fechaFinal,
        'proveedor_nombre_historico': cuenta.proveedor.nombre,
        'proveedor_contacto_historico': cuenta.proveedor.contacto,
        'cuenta_correo_historico': cuenta.correo,
        'plataforma_nombre_historico': cuenta.plataforma.nombre,
      });
      print('✅ Devolución de proveedor registrada en historial');
    } catch (e) {
      print('🚨 Error en registrarDevolucionProveedor: $e');
      rethrow;
    }
  }
}