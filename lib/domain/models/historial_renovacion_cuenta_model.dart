// lib/domain/models/historial_renovacion_cuenta_model.dart

class HistorialRenovacionCuenta {
  final String id;
  final DateTime createdAt;
  final String cuentaId;
  final String correo;
  final String proveedorNombre;
  final String proveedorContacto;
  final String plataformaNombre; // El nombre del campo aquí está bien
  final String tipoRegistro;
  final double montoGastado;
  final DateTime periodoInicio;
  final DateTime periodoFin;
  final int? totalCount;

  HistorialRenovacionCuenta({
    required this.id,
    required this.createdAt,
    required this.cuentaId,
    required this.correo,
    required this.proveedorNombre,
    required this.proveedorContacto,
    required this.plataformaNombre,
    required this.tipoRegistro,
    required this.montoGastado,
    required this.periodoInicio,
    required this.periodoFin,
    this.totalCount,
  });

  factory HistorialRenovacionCuenta.fromJson(Map<String, dynamic> json) {
    return HistorialRenovacionCuenta(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      cuentaId: json['cuenta_id'],
      correo: json['correo'] ?? '',
      proveedorNombre: json['proveedor_nombre'] ?? 'Sin proveedor',
      proveedorContacto: json['proveedor_contacto'] ?? 'Sin contacto',
      
      // ===== CAMBIO CRÍTICO AQUÍ =====
      // La RPC devuelve la columna con el alias 'plataforma', no 'plataforma_nombre'
      plataformaNombre: json['plataforma'] ?? '', 
      
      tipoRegistro: json['tipo_registro'],
      montoGastado: (json['monto_gastado'] as num).toDouble(),
      periodoInicio: DateTime.parse(json['periodo_inicio']),
      periodoFin: DateTime.parse(json['periodo_fin']),
      totalCount: json['total_count'] != null ? int.tryParse(json['total_count'].toString()) : null,
    );
  }

  // El método toJson no se usa para leer datos, pero lo dejamos por consistencia
  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'cuenta_id': cuentaId,
        'correo': correo,
        'proveedor_nombre': proveedorNombre,
        'proveedor_contacto': proveedorContacto,
        'plataforma': plataformaNombre, // <-- Al enviar datos, podríamos usar 'plataforma'
        'tipo_registro': tipoRegistro,
        'monto_gastado': montoGastado,
        'periodo_inicio': periodoInicio.toIso8601String(),
        'periodo_fin': periodoFin.toIso8601String(),
        'total_count': totalCount,
      };
}