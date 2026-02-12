import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/cliente_model.dart';
import '../supabase_config.dart';

class ClienteRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Obtiene una lista paginada de clientes, opcionalmente filtrada por un término de búsqueda.
  /// Los clientes se ordenan por fecha de creación descendente.
  // ===== MÉTODO `getClientes` MODIFICADO =====
// ===== REEMPLAZA TU MÉTODO getClientes ACTUAL CON ESTA VERSIÓN =====
  // Esta versión llama a la función RPC que YA TIENES en Supabase.
  
  Future<List<Cliente>> getClientes({
    int page = 1,
    int perPage = 10,
    String? searchQuery,
  }) async {
    try {
      print('[CLIENTE_REPO] getClientes llamado con:');
      print('[CLIENTE_REPO] - page: $page');
      print('[CLIENTE_REPO] - perPage: $perPage');
      print('[CLIENTE_REPO] - searchQuery: "$searchQuery"');
      
      // Usamos la función RPC optimizada que ya tienes en Supabase
      final response = await _supabase.rpc(
        'get_clientes_con_ventas',
        params: {
          'search_query': searchQuery,
          'page_limit': perPage,
          'page_offset': (page - 1) * perPage,
        },
      );
      
      print('[CLIENTE_REPO] Respuesta de RPC: ${response.length} registros');

      // Convertimos directamente a lista de clientes
      // La función RPC ya incluye ventas_count
      final clientes = (response as List)
          .map<Cliente>((data) => Cliente.fromJson(data))
          .toList();
      
      print('[CLIENTE_REPO] Procesados ${clientes.length} clientes');
      for (final cliente in clientes) {
        print('[CLIENTE_REPO] - Cliente: ${cliente.nombre} (${cliente.contacto}) - Ventas: ${cliente.ventasCount}');
      }
          
      return clientes;

    } catch (error) {
      print('[ERROR] getClientes RPC: $error');
      rethrow;
    }
  }

  /// Obtiene el número total de clientes, opcionalmente filtrado por búsqueda.
  Future<int> getClientesCount({String? searchQuery}) async {
    try {
      print('[CLIENTE_REPO] getClientesCount llamado con searchQuery: "$searchQuery"');
      
      // Usamos la misma función RPC pero con límite alto para contar todos
      final response = await _supabase.rpc(
        'get_clientes_con_ventas',
        params: {
          'search_query': searchQuery,
          'page_limit': 999999, // Límite alto para obtener todos los registros
          'page_offset': 0,
        },
      );
      
      final count = (response as List).length;
      print('[CLIENTE_REPO] Total de clientes encontrados: $count');
      return count;
      
    } catch (error) {
      print('[ERROR] getClientesCount RPC: $error');
      return 0;
    }
  }
  
  // --- El resto de los métodos (add, update, delete) no necesitan cambios ---

Future<Map<String, dynamic>> addCliente(Cliente cliente) async {
    final existing = await _supabase
        .from('clientes')
        .select()
        .eq('contacto', cliente.contacto)
        .maybeSingle();

    if (existing != null) {
      if (existing['deleted_at'] == null) {
        throw Exception('Ya existe un cliente con este número.');
      } else {
        final data = await _supabase
            .from('clientes')
            .update({
              'nombre': cliente.nombre,
              'nota': cliente.nota,
              'deleted_at': null,
            })
            .eq('id', existing['id'])
            .select()
            .single();
        return {'cliente': Cliente.fromJson(data), 'restaurado': true};
      }
    }

    final data = await _supabase.from('clientes').insert(cliente.toJson()).select().single();
    return {'cliente': Cliente.fromJson(data), 'restaurado': false};
  }

Future<Cliente> updateCliente(Cliente cliente) async {
  if (cliente.id == null) {
    throw Exception('No se puede actualizar un cliente sin ID');
  }

  // Si el contacto ha cambiado, verificar duplicado
  final original = await _supabase.from('clientes').select('contacto').eq('id', cliente.id!).single();
  if (original['contacto'] != cliente.contacto) {
    final existe = await contactoExiste(cliente.contacto);
    if (existe) throw Exception('Contacto ya existe');
  }

  final data = await _supabase
      .from('clientes')
      .update(cliente.toJson())
      .eq('id', cliente.id!)
      .select()
      .single();
  print('[CLIENTE_REPO] Cliente actualizado con éxito');
  return Cliente.fromJson(data);
}

  // ===== MÉTODO deleteCliente CORREGIDO =====
  Future<void> deleteCliente(String id) async { // <-- CAMBIO 2: El parámetro ahora es String
    try {
      await _supabase
          .from('clientes')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      print('[CLIENTE_REPO] Cliente eliminado con éxito');
    } catch (e) {
      print('Error al eliminar cliente: $e');
      rethrow;
    }
  }

  /// Obtiene los clientes eliminados (soft delete)
  Future<List<Cliente>> getClientesEliminados({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final start = (page - 1) * perPage;
      final end = start + perPage - 1;

      final response = await _supabase
          .from('clientes')
          .select('*')
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false)
          .range(start, end);
      
      // Para cada cliente eliminado, obtenemos el conteo de ventas activas
      List<Cliente> clientes = [];
      for (var clienteData in response) {
        // Contar ventas no eliminadas para este cliente
        final ventasCount = await _supabase
            .from('ventas')
            .select('id')
            .eq('cliente_id', clienteData['id'])
            .isFilter('deleted_at', null)
            .count(CountOption.exact);
        
        // Agregar el conteo al data del cliente
        clienteData['ventas'] = [{'count': ventasCount.count}];
        clientes.add(Cliente.fromJson(clienteData));
      }

      return clientes;
    } catch (e) {
      print('[ERROR] getClientesEliminados: $e');
      rethrow;
    }
  }

  /// Restaura un cliente eliminado (soft delete)
  Future<void> restaurarCliente(String id) async {
    try {
      await _supabase
          .from('clientes')
          .update({'deleted_at': null})
          .eq('id', id);
    } catch (e) {
      print('[ERROR] restaurarCliente: $e');
      rethrow;
    }
  }

  /// Elimina permanentemente un cliente (hard delete)
  Future<void> eliminarPermanentemente(String id) async {
    try {
      await _supabase
          .from('clientes')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('[ERROR] eliminarPermanentemente: $e');
      rethrow;
    }
  }


  Future<bool> contactoExiste(String contacto) async {
    final res = await _supabase
        .from('clientes')
        .select('id')
        .eq('contacto', contacto)
        .isFilter('deleted_at', null)
        .maybeSingle();
    return res != null;
  }
}