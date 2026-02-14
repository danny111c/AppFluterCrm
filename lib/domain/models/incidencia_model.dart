class Incidencia {
  final String id;
  final String? ventaId;
  final String? cuentaId;
  final String descripcion;
  final bool congelarTiempo;
  final String estado; // 'abierta' o 'resuelta'
  final DateTime creadoAt;
  final DateTime? resueltoAt;

  Incidencia({
    required this.id,
    this.ventaId,
    this.cuentaId,
    required this.descripcion,
    required this.congelarTiempo,
    required this.estado,
    required this.creadoAt,
    this.resueltoAt,
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
    );
  }
}