import 'package:proyectofinal/domain/models/tipo_cuenta_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

class TipoCuentaRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<List<TipoCuenta>> getTiposCuenta({int page = 1, int perPage = 10, String? searchQuery}) async {
    try {
      final pageOffset = (page - 1) * perPage;
      final response = await _supabase
          .rpc('get_tipos_cuenta_con_datos', params: {
            'search_query': searchQuery,
            'page_limit': perPage,
            'page_offset': pageOffset,
          });

      print('[DEBUG] getTiposCuenta - respuesta cruda:');
      print(response);
      final data = response as List<dynamic>;
      print('[DEBUG] getTiposCuenta - filas individuales:');
      for (var i = 0; i < data.length; i++) {
        print('Fila #$i: ' + data[i].toString());
      }
      final tiposCuenta = data.map((json) {
        try {
          final tipoCuenta = TipoCuenta.fromJson(json);
          print('[DEBUG] getTiposCuenta - tipo cuenta mapeado: ' + tipoCuenta.toString());
          return tipoCuenta;
        } catch (e) {
          print('[ERROR] getTiposCuenta - error al mapear fila: $e');
          rethrow;
        }
      }).toList();
      return tiposCuenta;
    } catch (e) {
      print('[ERROR] TipoCuentaRepository.getTiposCuenta: $e');
      rethrow;
    }
  }
  
  Future<TipoCuenta> addTipoCuenta(TipoCuenta tipoCuenta) async {
    try {
      final existingTipoCuenta = await _supabase
          .from('tipos_cuenta')
          .select('id')
          .eq('nombre', tipoCuenta.nombre)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (existingTipoCuenta != null) {
        throw Exception('Ya existe un tipo de cuenta con el mismo nombre.');
      }

      final data = await _supabase
          .from('tipos_cuenta')
          .insert(tipoCuenta.toJsonDb())
          .select()
          .single();
      return TipoCuenta.fromJson(data);
    } catch (e) {
      print('[ERROR] TipoCuentaRepository.addTipoCuenta: $e');
      rethrow;
    }
  }

  Future<void> updateTipoCuenta(TipoCuenta tipoCuenta) async {
    if (tipoCuenta.id == null) {
      throw ArgumentError('No se puede actualizar un tipo de cuenta sin un ID.');
    }
    try {
      await _supabase
          .from('tipos_cuenta')
          .update(tipoCuenta.toJsonDb())
          .eq('id', tipoCuenta.id!);
    } catch (e) {
      print('[ERROR] TipoCuentaRepository.updateTipoCuenta: $e');
      rethrow;
    }
  }

  // Soft delete - marca el tipo de cuenta como eliminado
  // ===== MÉTODO MODIFICADO =====
  /// Elimina un tipo de cuenta usando una función RPC que valida si está en uso.
  Future<void> deleteTipoCuenta(String id) async {
    try {
      // 1. Llamamos a la función que creamos en la base de datos.
      await _supabase.rpc(
        'eliminar_tipo_cuenta_si_no_usado',
        params: {'tipo_cuenta_id_a_eliminar': id},
      );
    } on PostgrestException catch (e) {
      // 2. Capturamos un posible error de la base de datos.
      print('[REPO_ERROR] deleteTipoCuenta (PostgrestException): ${e.message}');
      
      // 3. Verificamos si es nuestro error personalizado.
      // El mensaje que definimos en la función SQL vendrá en e.message.
      if (e.code == 'P0001' || e.message.contains('El tipo de cuenta está en uso')) {
        // 4. Lanzamos una excepción más clara y amigable para la app.
        throw Exception('No se puede eliminar: este tipo de cuenta está siendo utilizado.');
      }
      
      // Si es otro tipo de error de base de datos, lo relanzamos.
      rethrow;
    } catch (e) {
      // Capturamos cualquier otro tipo de error.
      print('[REPO_ERROR] deleteTipoCuenta (General Exception): $e');
      rethrow;
    }
  }


  /// Obtiene los tipos de cuenta eliminados (soft delete)
  Future<List<TipoCuenta>> getTiposCuentaEliminados({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final start = (page - 1) * perPage;
      final end = start + perPage - 1;

      final response = await _supabase
          .from('tipos_cuenta')
          .select()
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false)
          .range(start, end);

      return response.map((data) => TipoCuenta.fromJson(data)).toList();
    } catch (error) {
      print('[ERROR] TipoCuentaRepository.getTiposCuentaEliminados: $error');
      rethrow;
    }
  }

  /// Restaura un tipo de cuenta eliminado (soft delete)
  Future<void> restaurarTipoCuenta(String id) async {
    try {
      await _supabase
          .from('tipos_cuenta')
          .update({'deleted_at': null})
          .eq('id', id);
    } catch (e) {
      print('[ERROR] TipoCuentaRepository.restaurarTipoCuenta: $e');
      rethrow;
    }
  }

  /// Elimina permanentemente un tipo de cuenta (hard delete)
  Future<void> eliminarPermanentemente(String id) async {
    try {
      await _supabase
          .from('tipos_cuenta')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('[ERROR] TipoCuentaRepository.eliminarPermanentemente: $e');
      rethrow;
    }
  }
  
  Future<int> getTiposCuentaCount({String? searchQuery}) async {
    try {
      final response = await _supabase
          .rpc('get_tipos_cuenta_con_datos', params: {
            'search_query': searchQuery,
            'page_limit': 1,
            'page_offset': 0,
          });

      final data = response as List<dynamic>;
      if (data.isEmpty) return 0;
      return data.first['total_count'] ?? 0;
    } catch (e) {
      print('[ERROR] TipoCuentaRepository.getTiposCuentaCount: $e');
      rethrow;
    }
  }

  // ===== MÉTODO CORREGIDO =====
  Future<bool> tieneCuentasAsociadas(String tipoCuentaId) async {
    try {
      final response = await _supabase
          .from('cuentas')
          .select() // Necesario para poder usar .count()
          .eq('tipo_cuenta_id', tipoCuentaId)
          .isFilter('deleted_at', null) // Solo cuentas activas (no soft deleted)
          .count(CountOption.exact);

      return response.count > 0;
    } catch (error) {
      print('[ERROR] TipoCuentaRepository.tieneCuentasAsociadas: $error');
      return true;
    }
  }
}