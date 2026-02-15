import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/cuenta_model.dart';
import '../supabase_config.dart';

// 1. Creamos un enum para las opciones de ordenamiento de Cuentas
enum CuentaSortOption {
  porFechaFinal,
  porCreacionReciente,
  conProblemas, // Opción para ordenar por cuentas con fallos
}

class CuentaRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ===== MÉTODO `getCuentas` MODIFICADO PARA USAR RPC =====
  Future<List<Cuenta>> getCuentas({
    int page = 1,
    int perPage = 10,
    String? searchQuery,
    // 2. Añadimos el nuevo parámetro con un valor por defecto
    CuentaSortOption sortOption = CuentaSortOption.porFechaFinal,
  }) async {
    print('[CUENTA_REPOSITORY] getCuentas llamado con:');
    print('[CUENTA_REPOSITORY] - page: $page');
    print('[CUENTA_REPOSITORY] - perPage: $perPage');
    print('[CUENTA_REPOSITORY] - searchQuery: "$searchQuery"');
    print('[CUENTA_REPOSITORY] - sortOption: $sortOption');
    
    try {
      final offset = (page - 1) * perPage;
      print('[CUENTA_REPOSITORY] - offset calculado: $offset');
      
      // Convierte la opción de ordenamiento del enum a la cadena de texto que espera la RPC
      final sortOptionStr = {
        CuentaSortOption.porFechaFinal: 'por_fecha_final',
        CuentaSortOption.porCreacionReciente: 'por_creacion_reciente',
        CuentaSortOption.conProblemas: 'con_problemas',
      }[sortOption];

      final response = await _supabase.rpc(
        'get_cuentas_con_datos',
        params: {
          'search_query': searchQuery,
          'page_limit': perPage,
          'page_offset': offset,
          'sort_option': sortOptionStr, // Envía el parámetro de ordenamiento
        },
      );
      
      print('[CUENTA_REPOSITORY] RPC response recibido: ${response.length} items');
      
      if (response is List) {
        print('[CUENTA_REPOSITORY] Respuesta de RPC recibida: ${response.length} registros');
      
      // Log detallado de los datos crudos de la RPC
      for (int i = 0; i < response.length; i++) {
        final data = response[i];
        print('[CUENTA_REPOSITORY] Registro $i datos crudos:');
        print('[CUENTA_REPOSITORY] - id: ${data['id']}');
        print('[CUENTA_REPOSITORY] - email: ${data['email']}');
        print('[CUENTA_REPOSITORY] - plataforma_id: ${data['plataforma_id']}');
        print('[CUENTA_REPOSITORY] - plataforma_nombre: ${data['plataforma_nombre']}');
        print('[CUENTA_REPOSITORY] - costo_compra: ${data['costo_compra']}');
        print('[CUENTA_REPOSITORY] - fecha_inicio: ${data['fecha_inicio']}');
        print('[CUENTA_REPOSITORY] - fecha_final: ${data['fecha_final']}');
        print('[CUENTA_REPOSITORY] - tipo_cuenta_nombre: ${data['tipo_cuenta_nombre']}');
        print('[CUENTA_REPOSITORY] - proveedor_nombre: ${data['proveedor_nombre']}');
        print('[CUENTA_REPOSITORY] - proveedor_contacto: ${data['proveedor_contacto']}');
        print('[CUENTA_REPOSITORY] - num_perfiles: ${data['num_perfiles']}');
        print('[CUENTA_REPOSITORY] - perfiles_disponibles: ${data['perfiles_disponibles']}');
      }
      
      final cuentas = response.map((data) {
        print('[CUENTA_REPOSITORY] Procesando cuenta con fromJson...');
        final cuenta = Cuenta.fromJson(data);
        print('[CUENTA_REPOSITORY] Cuenta procesada:');
        print('[CUENTA_REPOSITORY] - id: ${cuenta.id}');
        print('[CUENTA_REPOSITORY] - plataforma.nombre: ${cuenta.plataforma.nombre}');
        print('[CUENTA_REPOSITORY] - costoCompra: ${cuenta.costoCompra}');
        print('[CUENTA_REPOSITORY] - fechaInicio: ${cuenta.fechaInicio}');
        print('[CUENTA_REPOSITORY] - fechaFinal: ${cuenta.fechaFinal}');
        return cuenta;
      }).toList();
      
      print('[CUENTA_REPOSITORY] Cuentas procesadas: ${cuentas.length}');
      
      return cuentas;
      }
      
      print('[CUENTA_REPOSITORY] Response no es List, retornando lista vacía');
      return [];

    } catch (error) {
      print('[ERROR] getCuentas: $error');
      rethrow;
    }
  }

  // El resto de tus métodos no necesitan cambios para esta funcionalidad.

  Future<int> getCuentasCount({String? searchQuery}) async {
    print('[CUENTA_REPOSITORY] getCuentasCount llamado con searchQuery: "$searchQuery"');
    
    try {
      // Usar la misma RPC con límite alto para contar
      final response = await _supabase.rpc(
        'get_cuentas_con_datos',
        params: {
          'search_query': searchQuery,
          'page_limit': 10000, // Límite alto para contar todos
          'page_offset': 0,
        },
      );
      
      final count = response is List ? response.length : 0;
      print('[CUENTA_REPOSITORY] Count obtenido: $count');
      return count;
    } catch (e) {
      print('[ERROR] getCuentasCount: $e');
      rethrow;
    }
  }

Future<Cuenta> addCuenta(Cuenta cuenta) async {
  try {
    print('[CUENTA_REPOSITORY] Iniciando guardado de cuenta...');

    // 1. Preparamos los datos para enviar a Supabase
    final Map<String, dynamic> cuentaData = cuenta.toJson();

    // LÓGICA CLAVE: 
    // Si numPerfiles es 0, es una "Cuenta Completa".
    // Le asignamos 1 cupo disponible internamente para que solo se pueda vender una vez.
    if (cuenta.numPerfiles == 0) {
      cuentaData['perfiles_disponibles'] = 1;
    }

    // 2. INSERTAR LA CUENTA
    // Usamos 'cuentaData' que ya tiene el ajuste del cupo si era 0
    final response = await _supabase
        .from('cuentas')
        .insert(cuentaData) 
        .select('*, plataformas(*), tipos_cuenta(*), proveedores(*)') 
        .single();
    
    final cuentaCreada = Cuenta.fromJson(response);
    print('[CUENTA_REPOSITORY] Cuenta creada exitosamente con ID: ${cuentaCreada.id}');

    // 3. CREACIÓN AUTOMÁTICA DE PERFILES
    try {
      if (cuentaCreada.numPerfiles > 0) { 
        List<Map<String, dynamic>> perfilesParaInsertar = [];
        for (int i = 1; i <= cuentaCreada.numPerfiles; i++) {
          perfilesParaInsertar.add({
            'cuenta_id': cuentaCreada.id,
            'nombre_perfil': 'Perfil $i',
            'pin': '0000',
            'estado': 'disponible'
          });
        }
        await _supabase.from('perfiles').insert(perfilesParaInsertar);
        print('[CUENTA_REPOSITORY] Perfiles creados correctamente.');
      } else {
        print('[CUENTA_REPOSITORY] Es cuenta completa, no se crean slots en la tabla perfiles.');
      }
    } catch (e) {
      print('[ERROR NO CRÍTICO] La cuenta se creó pero los perfiles fallaron: $e');
    }

    return cuentaCreada; 
  } catch (e) {
    print('[ERROR CRÍTICO] addCuenta falló: $e');
    rethrow;
  }
}

Future<void> updateCuenta(Cuenta cuenta) async {
  if (cuenta.id == null) throw ArgumentError('Falta ID');
  
  try {
    print('[CUENTA_REPOSITORY] Iniciando actualización de cuenta: ${cuenta.id}');

    // 1. Convertimos el objeto a JSON
    final Map<String, dynamic> cuentaData = cuenta.toJson();

    // 🛡️ PROTECCIÓN DE ESTADO: Eliminamos estos campos del mapa
    // Así Supabase NO los toca y mantiene el fallo/pausa que ya existía.
    cuentaData.remove('problema_cuenta');
    cuentaData.remove('fecha_reporte_cuenta');
    cuentaData.remove('is_paused');
    cuentaData.remove('fecha_pausa');
    cuentaData.remove('prioridad_actual');
    cuentaData.remove('tiene_cascada'); // Este es calculado, no se guarda

    // Lógica de perfiles (mantener igual)
    final resActual = await _supabase.from('cuentas').select('num_perfiles, perfiles_disponibles').eq('id', cuenta.id!).single();
    final int numPerfilesViejos = resActual['num_perfiles'];
    final int disponiblesViejos = resActual['perfiles_disponibles'];
    final int vendidosActualmente = numPerfilesViejos == 0 ? 0 : (numPerfilesViejos - disponiblesViejos);

    if (cuenta.numPerfiles == 0) {
      cuentaData['perfiles_disponibles'] = 1; 
    } else {
      if (numPerfilesViejos == 0) {
        cuentaData['perfiles_disponibles'] = cuenta.numPerfiles;
      } else {
        cuentaData['perfiles_disponibles'] = cuenta.numPerfiles - vendidosActualmente;
      }
    }

    // 2. ACTUALIZAR TABLA (Ahora es seguro)
    await _supabase.from('cuentas').update(cuentaData).eq('id', cuenta.id!);

    // 4. SINCRONIZAR TABLA 'perfiles' (Crear o Borrar Slots)
    final resPerfiles = await _supabase
        .from('perfiles')
        .select()
        .eq('cuenta_id', cuenta.id!)
        .order('nombre_perfil', ascending: true);
    
    List<Map<String, dynamic>> perfilesExistentes = List<Map<String, dynamic>>.from(resPerfiles);
    int cantidadActualEnTablaPerfiles = perfilesExistentes.length;
    int nuevaCantidadObjetivo = cuenta.numPerfiles;

    if (nuevaCantidadObjetivo > cantidadActualEnTablaPerfiles) {
      // --- ESCENARIO A: AUMENTAR PERFILES ---
      List<Map<String, dynamic>> nuevosPerfiles = [];
      for (int i = cantidadActualEnTablaPerfiles + 1; i <= nuevaCantidadObjetivo; i++) {
        nuevosPerfiles.add({
          'cuenta_id': cuenta.id,
          'nombre_perfil': 'Perfil $i',
          'pin': '0000',
          'estado': 'disponible'
        });
      }
      if (nuevosPerfiles.isNotEmpty) {
        await _supabase.from('perfiles').insert(nuevosPerfiles);
        print('✅ Se agregaron ${nuevosPerfiles.length} perfiles nuevos.');
      }

    } else if (nuevaCantidadObjetivo < cantidadActualEnTablaPerfiles) {
      // --- ESCENARIO B: DISMINUIR PERFILES ---
      int aBorrar = cantidadActualEnTablaPerfiles - nuevaCantidadObjetivo;
      
      // Filtramos solo los que están libres (disponibles) para no borrar uno vendido
      final perfilesParaBorrar = perfilesExistentes
          .where((p) => p['estado'] == 'disponible')
          .toList()
          .reversed // Empezamos borrando desde el número más alto
          .take(aBorrar);

      if (perfilesParaBorrar.length < aBorrar) {
        print('⚠️ Advertencia: No se pudieron borrar todos los perfiles solicitados porque algunos están ocupados.');
      }

      for (var p in perfilesParaBorrar) {
        await _supabase.from('perfiles').delete().eq('id', p['id']);
      }
      print('✅ Se eliminaron ${perfilesParaBorrar.length} perfiles sobrantes.');
    }

    print('✨ Actualización completa finalizada con éxito.');

  } catch (e) {
    print('🚨 ERROR CRÍTICO en updateCuenta: $e');
    rethrow;
  }
}

  // Soft delete - marca la cuenta como eliminada
  Future<void> deleteCuenta(String id) async {
    try {
      // Verificar si la cuenta puede ser eliminada (no tiene ventas activas)
      final puedeEliminar = await _supabase.rpc('puede_eliminar_cuenta', params: {
        'p_cuenta_id': id,
      });
      
      if (!puedeEliminar) {
        throw Exception('No se puede eliminar la cuenta porque tiene ventas activas asociadas.');
      }
      
      await _supabase
          .from('cuentas')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      print('[ERROR] deleteCuenta: $e');
      rethrow;
    }
  }
      /// Devuelve el número de cuentas activas asociadas a un ID de proveedor específico.
  Future<int> getCuentasCountByProveedorId(String proveedorId) async {
    try {
      final response = await _supabase
        .from('cuentas')
        .select('id')
        .eq('proveedor_id', proveedorId) // Asegúrate de que la columna se llame 'proveedor_id'
        .isFilter('deleted_at', null) // Solo cuentas activas
        .count(CountOption.exact);
      
      return response.count ?? 0;
    } catch (e) {
      print('[ERROR] getCuentasCountByProveedorId: $e');
      rethrow;
    }
  }

  // Métodos adicionales para soft delete
  
  /// Obtiene las cuentas eliminadas (soft deleted)
  Future<List<Cuenta>> getCuentasEliminadas({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final start = (page - 1) * perPage;
      final end = start + perPage - 1;

      final response = await _supabase
          .from('cuentas')
          .select('*, plataformas(*), tipos_cuenta(*), proveedores(*)')
          .not('deleted_at', 'is', null) // Solo cuentas eliminadas
          .order('deleted_at', ascending: false)
          .range(start, end);

      final List<Map<String, dynamic>> dataList = List<Map<String, dynamic>>.from(response);
      return dataList.map<Cuenta>((data) => Cuenta.fromJson(data)).toList();
    } catch (error) {
      print('[ERROR] getCuentasEliminadas: $error');
      rethrow;
    }
  }

  /// Restaura una cuenta eliminada (soft delete)
  Future<void> restaurarCuenta(String id) async {
    try {
      await _supabase
          .from('cuentas')
          .update({'deleted_at': null})
          .eq('id', id);
    } catch (e) {
      print('[ERROR] restaurarCuenta: $e');
      rethrow;
    }
  }

  /// Elimina permanentemente una cuenta (hard delete)
  Future<void> eliminarPermanentemente(String id) async {
    try {
      await _supabase.from('cuentas').delete().eq('id', id);
    } catch (e) {
      print('[ERROR] eliminarPermanentemente: $e');
      rethrow;
    }
  }
}