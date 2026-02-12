// lib/infrastructure/repositories/transacciones_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/transaccion_cuenta_model.dart';
import '../../domain/models/transaccion_venta_model.dart';
import '../../../domain/models/cliente_model.dart';
import '../../../domain/models/cuenta_model.dart';
import '../../../domain/models/venta_model.dart';
class TransaccionesRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> getHistorialCuentas({
    int page = 1,
    int perPage = 5,
    String? searchQuery,
  }) async {
    final response = await _client.rpc(
      'get_historial_cuentas_con_datos',
      params: {
        'p_search_query': searchQuery ?? '',
        'p_page_number': page,
        'p_page_size': perPage,
      },
    );

    final data = response['data'] as List;
    final totalPages = response['total_pages'] as int;

    final cuentas = data.map((e) => TransaccionCuenta.fromJson(e)).toList();

    return {
      'data': cuentas,
      'totalPages': totalPages,
    };
  }

  Future<Map<String, dynamic>> getHistorialVentas({
    int page = 1,
    int perPage = 15,
    String? searchQuery,
  }) async {
    print('[TRANSACCIONES_REPOSITORY] getHistorialVentas: page=$page, perPage=$perPage, search=$searchQuery');
    
    final response = await _client.rpc(
      'get_historial_transacciones_ventas_con_datos',
      params: {
        'p_search': searchQuery ?? '',
        'p_page': page,
        'p_page_size': perPage,
      },
    );

    print('[TRANSACCIONES_REPOSITORY] RPC Response length: ${response.length}');
    
    if (response.isEmpty) {
      print('[TRANSACCIONES_REPOSITORY] No data returned from RPC');
      return {
        'data': <TransaccionVenta>[],
        'totalPages': 1,
      };
    }

    // Get total count from the first row (all rows have the same total_count)
    final totalCount = response.first['total_count'] as int? ?? 0;
    final totalPages = (totalCount / perPage).ceil();
    
    print('[TRANSACCIONES_REPOSITORY] Total count: $totalCount, Total pages: $totalPages');


  final ventas = (response as List).map((e) => TransaccionVenta.fromJson(e)).toList();
    print('[TRANSACCIONES_REPOSITORY] Parsed ventas: ${ventas.length}');

    return {
      'data': ventas,
      'totalPages': totalPages,
    };
  }

  Future<List<TransaccionVenta>> getHistorialVentasHistorico() async {
    final query = _client.from('historial_transacciones_ventas');
    final response = await query
        .select('*')
        .order('created_at', ascending: false)
        .range(0, 49);
    return response.map<TransaccionVenta>((json) => TransaccionVenta.fromJson(json)).toList();
  }

// Dentro de la clase TransaccionesRepository
Future<Map<String, double>> getTotalesGlobales(String search) async {
  final response = await _client.rpc('get_totales_transacciones', params: {
    'p_search': search,
  });
  
  final data = response[0];
  return {
    'ventas': (data['total_ventas'] as num).toDouble(),
    'gastos': (data['total_gastos'] as num).toDouble(),
  };
}

  // --- AÑADIDO: Método para eliminar una transacción de cuenta ---
  Future<void> deleteHistorialCuenta(String id) async {
    try {
      await _client.from('historial_renovaciones_cuentas').delete().match({'id': id});
    } catch (e) {
      throw Exception('Error al eliminar la transacción de cuenta: $e');
    }
  }

  // --- AÑADIDO: Método para eliminar una transacción de venta ---
  Future<void> deleteHistorialVenta(String id) async {
    try {
      await _client.from('historial_transacciones_ventas').delete().match({'id': id});
    } catch (e) {
      throw Exception('Error al eliminar la transacción de venta: $e');
    }
  }

  // --- AÑADIDO: Método para insertar una transacción de venta ---
Future<void> addHistorialVenta({
  required String ventaId,
  required Cliente cliente,
  required Cuenta cuenta,
  required double monto,
  required String tipo,
  required DateTime fechaInicio,
  required DateTime fechaFin,
  String? perfil,
}) async {
  await _client.from('historial_transacciones_ventas').insert({
    'venta_id': ventaId,
    'cliente_id': cliente.id,
    'cuenta_id': cuenta.id,
    'fecha_transaccion': DateTime.now().toIso8601String(),
    'monto_transaccion': monto,
    'periodo_inicio_servicio': fechaInicio.toIso8601String(),
    'periodo_fin_servicio': fechaFin.toIso8601String(),
    'tipo_registro': tipo,
    
    // --- ESTA ES LA PARTE QUE FALTA ---
    // Inserta la "foto" de los datos en el momento de la renovación
    'cliente_nombre_historico': cliente.nombre,
    'cliente_contacto_historico': cliente.contacto,
    'cuenta_correo_historico': cuenta.correo,
    'plataforma_nombre_historico': cuenta.plataforma.nombre,
    'perfil_historico': perfil,
  });
}

  // --- CORREGIDO: Método para insertar una transacción de cuenta ---
  Future<void> addHistorialCuenta({required TransaccionCuenta transaccion}) async {
    await _client.from('historial_transacciones_cuentas').insert({
      'cuenta_id': transaccion.cuentaId,
      'monto_gastado': transaccion.monto,
      'periodo_inicio': transaccion.periodoInicio.toIso8601String(),
      'periodo_fin': transaccion.periodoFin.toIso8601String(),
      'tipo_registro': transaccion.tipoRegistro,
      // Los campos de proveedor, etc., no se guardan aquí para evitar duplicación.
      // Se obtienen con JOINs al leer el historial, si es necesario.
    });
  }
// ✅ Para Devoluciones a Clientes (VENTAS)
Future<void> registrarDevolucionVenta({required Venta venta, required double montoADevolver}) async {
  await _client.from('historial_transacciones_ventas').insert({
    'venta_id': venta.id,
    'cliente_id': venta.cliente.id,
    'monto_transaccion': -montoADevolver,
    'tipo_registro': 'Devolucion',
    'fecha_transaccion': DateTime.now().toIso8601String(),
    'periodo_inicio_servicio': venta.fechaInicio,
    'periodo_fin_servicio': venta.fechaFinal,
    // AQUÍ ESTABA EL ERROR: Faltaban estos campos
    'cliente_nombre_historico': venta.cliente.nombre,
    'cliente_contacto_historico': venta.cliente.contacto, // <--- CONTACTO REAL
    'cuenta_correo_historico': venta.cuenta.correo,       // <--- CUENTA REAL
    'plataforma_nombre_historico': venta.cuenta.plataforma.nombre,
    'perfil_historico': venta.perfilAsignado,
  });
}

// ✅ Para Devoluciones de Proveedores (CUENTAS)
Future<void> registrarDevolucionProveedor({required Cuenta cuenta, required double montoRecuperado}) async {
  await _client.from('historial_renovaciones_cuentas').insert({
    'cuenta_id': cuenta.id,
    'monto_gastado': -montoRecuperado,
    'tipo_registro': 'Devolucion Proveedor',
    'fecha_gasto': DateTime.now().toIso8601String(),
    'periodo_inicio': cuenta.fechaInicio,
    'periodo_fin': cuenta.fechaFinal,
    // AQUÍ ESTABA EL ERROR: Faltaban estos campos
    'proveedor_nombre_historico': cuenta.proveedor.nombre,
    'proveedor_contacto_historico': cuenta.proveedor.contacto, // <--- CONTACTO REAL
    'cuenta_correo_historico': cuenta.correo,                  // <--- CUENTA REAL
    'plataforma_nombre_historico': cuenta.plataforma.nombre,
  });
}
}
