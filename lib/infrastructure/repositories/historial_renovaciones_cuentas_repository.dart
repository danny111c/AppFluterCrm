import 'package:proyectofinal/domain/models/historial_renovacion_cuenta_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final historialRenovacionesCuentasRepositoryProvider = Provider<HistorialRenovacionesCuentasRepository>((ref) {
  return HistorialRenovacionesCuentasRepository();
});

class HistorialRenovacionesCuentasResult {
  final List<HistorialRenovacionCuenta> items;
  final int totalPages;
  final int totalCount;
  HistorialRenovacionesCuentasResult({required this.items, required this.totalPages, required this.totalCount});
}

class HistorialRenovacionesCuentasRepository {
  final _client = Supabase.instance.client;

  Future<HistorialRenovacionesCuentasResult> getHistorialRenovacionesCuentas({int page = 1, int pageSize = 20, String? search}) async {
    print('[DEBUG] Llamando RPC get_historial_renovaciones_cuentas_con_datos: page=[35m$page[0m, pageSize=[35m$pageSize[0m, search=[35m$search[0m');
    final response = await _client.rpc('get_historial_renovaciones_cuentas_con_datos', params: {
      'p_search': search ?? '',
      'p_page': page,
      'p_page_size': pageSize,
    });
    final List data = response is List ? response : (response.data ?? []);
    print('[DEBUG] Data parseada: $data');
    final items = data.map((e) => HistorialRenovacionCuenta.fromJson(e)).toList();
    print('[DEBUG] Items parseados: $items');
    int totalCount = 0;
    if (data.isNotEmpty && data[0]['total_count'] != null) {
      totalCount = int.tryParse(data[0]['total_count'].toString()) ?? 0;
    }
    final totalPages = (totalCount / pageSize).ceil();
    return HistorialRenovacionesCuentasResult(
      items: items,
      totalPages: totalPages == 0 ? 1 : totalPages,
      totalCount: totalCount,
    );
  }

  RealtimeChannel subscribeRealtime(void Function(dynamic event) onChange) {
    final channel = _client.channel('public:historial_renovaciones_cuentas')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'historial_renovaciones_cuentas',
        callback: (payload) {
          onChange(payload);
        },
      )
      .subscribe();
    return channel;
  }
}
