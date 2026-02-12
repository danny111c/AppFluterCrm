import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/plataforma_model.dart';
import '../supabase_config.dart';

class PlataformaRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<List<Plataforma>> getPlataformas({int page = 1, int perPage = 10, String? searchQuery}) async {
    try {
      final pageOffset = (page - 1) * perPage;
      final response = await _supabase
          .rpc('get_plataformas_con_datos', params: {
            'search_query': searchQuery,
            'page_limit': perPage,
            'page_offset': pageOffset,
          });

      print('[DEBUG] getPlataformas - respuesta cruda:');
      print(response);
      final data = response as List<dynamic>;
      print('[DEBUG] getPlataformas - filas individuales:');
      for (var i = 0; i < data.length; i++) {
        print('Fila #$i: ' + data[i].toString());
      }
      final plataformas = data.map((json) {
        try {
          final plataforma = Plataforma.fromJson(json);
          print('[DEBUG] getPlataformas - plataforma mapeada: ' + plataforma.toString());
          return plataforma;
        } catch (e) {
          print('[ERROR] getPlataformas - error al mapear fila: $e');
          rethrow;
        }
      }).toList();
      return plataformas;
    } catch (e) {
      print('[ERROR] PlataformaRepository.getPlataformas: $e');
      rethrow;
    }
  }

  Future<int> getPlataformasCount({String? searchQuery}) async {
    try {
      final response = await _supabase
          .rpc('get_plataformas_con_datos', params: {
            'search_query': searchQuery,
            'page_limit': 1,
            'page_offset': 0,
          });

      final data = response as List<dynamic>;
      if (data.isEmpty) return 0;
      return data.first['total_count'] ?? 0;
    } catch (e) {
      print('[ERROR] PlataformaRepository.getPlataformasCount: $e');
      rethrow;
    }
  }

  Future<Plataforma> addPlataforma(Plataforma plataforma) async {
    try {
      final existingPlatform = await _supabase
          .from('plataformas')
          .select('id')
          .eq('nombre', plataforma.nombre)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (existingPlatform != null) {
        throw Exception('Ya existe una plataforma con el mismo nombre.');
      }

      final data = await _supabase
          .from('plataformas')
          .insert(plataforma.toJsonDb())
          .select()
          .single();
      return Plataforma.fromJson(data);
    } catch (e) {
      print('[ERROR] PlataformaRepository.addPlataforma: $e');
      rethrow;
    }
  }

  Future<void> updatePlataforma(Plataforma plataforma) async {
    if (plataforma.id == null) {
      throw ArgumentError('No se puede actualizar una plataforma sin un ID.');
    }
    try {
      await _supabase
          .from('plataformas')
          .update(plataforma.toJsonDb())
          .eq('id', plataforma.id!);
    } catch (e) {
      print('[ERROR] PlataformaRepository.updatePlataforma: $e');
      rethrow;
    }
  }

  // Soft delete - marca la plataforma como eliminada
  // ===== MÉTODO DE BORRADO MODIFICADO =====
  /// Realiza un soft delete de una plataforma usando una función RPC que valida dependencias.
  Future<void> deletePlataforma(String id) async {
    try {
      // Llamamos a la nueva función SQL en lugar de hacer el update directamente.
      await _supabase.rpc(
        'eliminar_plataforma_si_no_usada',
        params: {'plataforma_id_a_eliminar': id},
      );
    } on PostgrestException catch (e) {
      // Capturamos el error específico de la base de datos.
      if (e.code == 'P0002' || e.message.contains('La plataforma está en uso')) {
        // Lanzamos una excepción clara para la UI.
        throw Exception('No se puede eliminar: esta plataforma está siendo utilizada.');
      }
      // Si es otro error, lo relanzamos.
      rethrow;
    } catch (e) {
      print('[ERROR] PlataformaRepository.deletePlataforma: $e');
      rethrow;
    }
  }

  /// Obtiene las plataformas eliminadas (soft delete)
  Future<List<Plataforma>> getPlataformasEliminadas({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final start = (page - 1) * perPage;
      final end = start + perPage - 1;

      final response = await _supabase
          .from('plataformas')
          .select()
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false)
          .range(start, end);

      return response.map((data) => Plataforma.fromJson(data)).toList();
    } catch (error) {
      print('[ERROR] PlataformaRepository.getPlataformasEliminadas: $error');
      rethrow;
    }
  }

  /// Restaura una plataforma eliminada (soft delete)
  Future<void> restaurarPlataforma(String id) async {
    try {
      await _supabase
          .from('plataformas')
          .update({'deleted_at': null})
          .eq('id', id);
    } catch (e) {
      print('[ERROR] PlataformaRepository.restaurarPlataforma: $e');
      rethrow;
    }
  }

  /// Elimina permanentemente una plataforma (hard delete)
  Future<void> eliminarPermanentemente(String id) async {
    try {
      await _supabase
          .from('plataformas')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('[ERROR] PlataformaRepository.eliminarPermanentemente: $e');
      rethrow;
    }
  }

 // ===== MÉTODO DE VERIFICACIÓN (ASEGÚRATE DE QUE ESTÉ ASÍ) =====
  /// Verifica si una plataforma tiene cuentas activas asociadas.
  Future<bool> tieneCuentasAsociadas(String plataformaId) async {
    try {
      final response = await _supabase
          .from('cuentas')
          .select()
          .eq('plataforma_id', plataformaId)
          .isFilter('deleted_at', null)
          .count(CountOption.exact);
      return response.count > 0;
    } catch (error) {
      print('[ERROR] PlataformaRepository.tieneCuentasAsociadas: $error');
      // Es más seguro devolver true en caso de error para evitar borrados accidentales.
      return true;
    }
  }
}