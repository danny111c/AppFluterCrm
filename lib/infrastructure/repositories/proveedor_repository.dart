import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/proveedor_model.dart';

class ProveedorRepository {
  final SupabaseClient _supabase;

  ProveedorRepository(this._supabase);

  /// Obtiene una lista paginada de proveedores, opcionalmente filtrada por búsqueda.
  /// Los proveedores se ordenan por nombre alfabéticamente.
  Future<List<Proveedor>> getProveedores({
    int page = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    try {
      print('[PROVEEDOR_REPO] getProveedores llamado con:');
      print('[PROVEEDOR_REPO] - page: $page');
      print('[PROVEEDOR_REPO] - perPage: $perPage');
      print('[PROVEEDOR_REPO] - searchQuery: "$searchQuery"');
      
      // Usamos la función RPC optimizada
      final response = await _supabase.rpc(
        'get_proveedores_con_cuentas',
        params: {
          'search_query': searchQuery,
          'page_limit': perPage,
          'page_offset': (page - 1) * perPage,
        },
      );
      
      print('[PROVEEDOR_REPO] Respuesta de RPC: ${response.length} registros');

      // Convertimos directamente a lista de proveedores
      // La función RPC ya incluye cuentas_count
      final proveedores = (response as List)
          .map<Proveedor>((data) => Proveedor.fromJson(data))
          .toList();
      
      print('[PROVEEDOR_REPO] Procesados ${proveedores.length} proveedores');
      for (final proveedor in proveedores) {
        print('[PROVEEDOR_REPO] - Proveedor: ${proveedor.nombre} (${proveedor.contacto}) - Cuentas: ${proveedor.cuentasCount}');
      }
          
      return proveedores;

    } catch (error) {
      print('[ERROR] getProveedores RPC: $error');
      rethrow;
    }
  }

  /// Obtiene el número total de proveedores, opcionalmente filtrado por búsqueda.
  Future<int> getProveedoresCount({String? searchQuery}) async {
    try {
      print('[PROVEEDOR_REPO] getProveedoresCount llamado con searchQuery: "$searchQuery"');
      
      // Usamos la misma función RPC pero con límite alto para contar todos
      final response = await _supabase.rpc(
        'get_proveedores_con_cuentas',
        params: {
          'search_query': searchQuery,
          'page_limit': 999999, // Límite alto para obtener todos los registros
          'page_offset': 0,
        },
      );
      
      final count = (response as List).length;
      print('[PROVEEDOR_REPO] Total de proveedores encontrados: $count');
      return count;
      
    } catch (error) {
      print('[ERROR] getProveedoresCount RPC: $error');
      return 0;
    }
  }

  // --- El resto de los métodos (add, update, delete) no necesitan cambios ---
// Ahora devuelve un MAPA con el objeto y el flag de restaurado
Future<Map<String, dynamic>> addProveedor(Proveedor proveedor) async {
  // 1. Buscamos si el contacto ya existe (activo o borrado)
  final existing = await _supabase
      .from('proveedores')
      .select()
      .eq('contacto', proveedor.contacto)
      .maybeSingle();

  if (existing != null) {
    if (existing['deleted_at'] == null) {
      // Caso A: Ya existe y está activo
      throw Exception('El número de contacto ya está registrado.');
    } else {
      // Caso B: Existe pero estaba borrado -> LO RESTAURAMOS
      final data = await _supabase
          .from('proveedores')
          .update({
            'nombre': proveedor.nombre,
            'nota': proveedor.nota,
            'deleted_at': null, // Quitamos de la papelera
          })
          .eq('id', existing['id'])
          .select()
          .single();
      
      return {'proveedor': Proveedor.fromJson(data), 'restaurado': true};
    }
  }

  // Caso C: No existe -> Insertar normal
  final data = await _supabase
      .from('proveedores')
      .insert(proveedor.toJson())
      .select()
      .single();
      
  return {'proveedor': Proveedor.fromJson(data), 'restaurado': false};
}

  Future<void> updateProveedor(Proveedor proveedor) async {
    if (proveedor.id == null) {
      throw ArgumentError('No se puede actualizar un proveedor sin un ID.');
    }
    try {
      final existing = await _supabase
          .from('proveedores')
          .select('id')
          .eq('contacto', proveedor.contacto)
          .neq('id', proveedor.id!)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (existing != null) {
        throw Exception('El número de contacto ya está en uso por otro proveedor.');
      }
      
      await _supabase
          .from('proveedores')
          .update(proveedor.toJson())
          .eq('id', proveedor.id!);
    } catch (e) {
      print('[ERROR] updateProveedor: $e');
      if (e is PostgrestException && e.message.contains('proveedores_contacto_key')) {
        throw Exception('El número de contacto ya está registrado.');
      }
      rethrow;
    }
  }

  Future<void> deleteProveedor(String id) async {
    print('[DEBUG_DELETE] Iniciando deleteProveedor para ID: $id');
    try {
      // 1. Verificar si el proveedor tiene cuentas activas asociadas
      print('[DEBUG_DELETE] Paso 1: Verificando cuentas para proveedor $id...');
      // Sintaxis corregida y verificada para contar registros.
      final cuentasResponse = await _supabase
          .from('cuentas')
          .select() // No necesitamos los datos, solo el conteo
          .eq('proveedor_id', id)
          .isFilter('deleted_at', null) // Sintaxis correcta para 'IS NULL'
          .count(); // Obtenemos el conteo de los registros que coinciden

      final int cuentasCount = cuentasResponse.count; // El conteo viene en la respuesta


      print('[DEBUG_DELETE] Consulta de cuentas ejecutada. Conteo de cuentas activas: $cuentasCount');

      // 2. Si hay cuentas, lanzar una excepción para evitar el borrado
      if (cuentasCount > 0) {
        print('[DEBUG_DELETE] ¡ERROR! Se encontraron $cuentasCount cuentas. Lanzando excepción.');
        throw Exception('Este proveedor tiene $cuentasCount cuenta(s) activa(s) y no puede ser eliminado.');
      }

      // 3. Si no hay cuentas, proceder con el borrado lógico (soft delete)
      print('[DEBUG_DELETE] Paso 3: No se encontraron cuentas activas. Procediendo con soft delete para proveedor $id.');
      await _supabase
          .from('proveedores')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .match({'id': id});
      
      print('[DEBUG_DELETE] Proveedor $id marcado como eliminado (soft delete) exitosamente.');

    } on PostgrestException catch (e) {
        print('[DEBUG_DELETE] [ERROR] PostgrestException en deleteProveedor: ${e.message}');
        throw Exception('Error de base de datos al eliminar: ${e.message}');
    } catch (e) {
      print('[DEBUG_DELETE] [ERROR] Excepción inesperada en deleteProveedor: $e');
      rethrow;
    }
  }

  /// Obtiene los proveedores eliminados (soft delete)
  Future<List<Proveedor>> getProveedoresEliminados({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final start = (page - 1) * perPage;
      final end = start + perPage - 1;

      final response = await _supabase
          .from('proveedores')
          .select('*')
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false)
          .range(start, end);
      
      // Para cada proveedor eliminado, obtenemos el conteo de cuentas activas
      List<Proveedor> proveedores = [];
      for (var proveedorData in response) {
        // Contar cuentas no eliminadas para este proveedor
        final cuentasCount = await _supabase
            .from('cuentas')
            .select('id')
            .eq('proveedor_id', proveedorData['id'])
            .isFilter('deleted_at', null)
            .count(CountOption.exact);
        
        // Agregar el conteo al data del proveedor
        proveedorData['cuentas'] = [{'count': cuentasCount.count}];
        proveedores.add(Proveedor.fromJson(proveedorData));
      }

      return proveedores;
    } catch (e) {
      print('[ERROR] getProveedoresEliminados: $e');
      rethrow;
    }
  }

  /// Restaura un proveedor eliminado (soft delete)
  Future<void> restaurarProveedor(String id) async {
    try {
      await _supabase
          .from('proveedores')
          .update({'deleted_at': null})
          .eq('id', id);
    } catch (e) {
      print('[ERROR] restaurarProveedor: $e');
      rethrow;
    }
  }

  /// Elimina permanentemente un proveedor (hard delete)
  Future<void> eliminarPermanentemente(String id) async {
    try {
      await _supabase
          .from('proveedores')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('[ERROR] eliminarPermanentemente: $e');
      rethrow;
    }
  }

  /// Obtiene el número de cuentas activas para un proveedor específico.
  Future<int> getCuentasCount(String proveedorId) async {
    try {
      final response = await _supabase
          .from('cuentas')
          .select('id')
          .eq('proveedor_id', proveedorId)
          .isFilter('deleted_at', null)
          .count(); // Obtenemos el conteo de los registros que coinciden

      return response.count; // El conteo viene en la respuesta
    } catch (e) {
      print('[ERROR] getCuentasCount: $e');
      rethrow;
    }
  }

  /// Obtiene un proveedor por su ID
  Future<Proveedor> getProveedorById(String id) async {
    try {
      final response = await _supabase
          .from('proveedores')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        throw Exception('Proveedor no encontrado');
      }

      return Proveedor.fromJson(response);
    } catch (e) {
      print('[ERROR] getProveedorById: $e');
      rethrow;
    }
  }
}