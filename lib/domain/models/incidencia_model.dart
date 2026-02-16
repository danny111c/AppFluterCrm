class Incidencia {
  final String id;
  final String? ventaId;
  final String? cuentaId;
  final String descripcion;
  final bool congelarTiempo;
  final String estado;
  final DateTime creadoAt;
  final DateTime? resueltoAt;
  final String prioridad;
  final bool huboCascada; // ✅ Debe estar así

  Incidencia({
    required this.id,
    this.ventaId,
    this.cuentaId,
    required this.descripcion,
    required this.congelarTiempo,
    required this.estado,
    required this.creadoAt,
    this.resueltoAt,
    required this.prioridad,
    required this.huboCascada,
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    return Incidencia(
      id: json['id'],
      ventaId: json['venta_id'],
      cuentaId: json['cuenta_id'],
      descripcion: json['descripcion'] ?? '',
      congelarTiempo: json['congelar_tiempo'] ?? false,
      estado: json['estado'] ?? 'abierta',
      creadoAt: DateTime.parse(json['creado_at']),
      resueltoAt: json['resuelto_at'] != null ? DateTime.parse(json['resuelto_at']) : null,
      prioridad: json['prioridad'] ?? 'media',
      huboCascada: json['hubo_cascada'] ?? false, // ✅ Mapeo correcto
    );
  }
    // NUEVA FUNCIÓN: Convierte una lista de incidencias en un texto punteado
  static String formatearLista(List<Incidencia> lista) {
    if (lista.isEmpty) return "Sin problemas reportados";
    // Filtramos para asegurar que solo enviamos las que no están resueltas
    final activas = lista.where((i) => i.resueltoAt == null).toList();
    if (activas.isEmpty) return "Sin problemas reportados";
    
    return activas.map((i) => "• ${i.descripcion}").join("\n");
  }
  

}